"use strict";

let roomBusy = false;
let clubPoll;
const roomInfo = $("room-info");
const onlineDialog = $("online-dialog");
const onlineStatus = $("online-profile");

async function clubRequest(path, data) {
  if (!/^https?:$/.test(location.protocol)) {
    throw new Error("Войдите в общий аккаунт из меню приложения и снова откройте шахматы.");
  }
  const response = await fetch("/api/" + path, data ? {
    method: "POST", headers: {"Content-Type":"application/json"}, body: JSON.stringify(data)
  } : {});
  if (response.status === 401) throw new Error("Войдите в общий аккаунт из меню приложения.");
  const result = await response.json();
  if (!response.ok) throw new Error(result.error || "Ошибка сервера.");
  return result;
}

$("online").onclick = async () => {
  onlineStatus.textContent = "Проверяем аккаунт…";
  $("create-club-room").disabled = $("join-club-room").disabled = true;
  onlineDialog.showModal();
  try {
    const account = await clubRequest("me");
    onlineStatus.textContent = account.name + " · " + account.coins + " монет";
    $("create-club-room").disabled = $("join-club-room").disabled = false;
  } catch (error) {
    onlineStatus.textContent = error.message;
  }
};

function updateClubRoom(view) {
  if (remote && view.code === remote.code && view.revision <= remote.revision) return;
  remote = view;
  state = view.position;
  roomInfo.hidden = false;
  roomInfo.textContent = "Код комнаты: " + view.code + " · " + view.players.join(" / ");
  select(null);
}

function leaveClubRoom() {
  clearInterval(clubPoll);
  remote = null;
  roomInfo.hidden = true;
}

async function joinClubRoom(create) {
  if (roomBusy) return;
  roomBusy = true;
  try {
    const code = $("club-room-code").value.trim().toLowerCase();
    if (!create && !/^[a-f0-9]{8}$/.test(code)) throw new Error("Введите восемь символов кода комнаты.");
    const view = await clubRequest(create ? "rooms" : "rooms/" + code + "/join",
      {game:"chess",variant:$("variant").value});
    leaveClubRoom();
    updateClubRoom(view);
    onlineDialog.close();
    $("resume").hidden = false;
    showMatch(true);
    clubPoll = setInterval(async () => {
      if (roomBusy || !remote || remote.ending) return;
      const activeCode = remote.code;
      try {
        const current = await clubRequest("rooms/" + activeCode);
        if (remote?.code === activeCode) updateClubRoom(current);
      } catch {
        if (remote?.code === activeCode) $("message").textContent = "Проверяем соединение…";
      }
    }, 1000);
  } catch (error) {
    onlineStatus.textContent = error.message;
  } finally {
    roomBusy = false;
  }
}

$("create-club-room").onclick = () => joinClubRoom(true);
$("join-club-room").onclick = () => joinClubRoom(false);

async function sendTurn(route, action = {}) {
  if (roomBusy || !remote?.playable) return;
  roomBusy = true;
  const active = remote;
  try {
    const view = await clubRequest("rooms/" + active.code + "/move",
      {...action, route, revision:active.revision});
    if (remote?.code === active.code) updateClubRoom(view);
  } catch (error) {
    if (remote?.code === active.code) $("message").textContent = error.message;
  } finally {
    roomBusy = false;
  }
}
