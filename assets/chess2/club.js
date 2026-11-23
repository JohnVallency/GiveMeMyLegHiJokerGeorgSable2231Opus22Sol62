"use strict";

const lobby = document.getElementById("lobby");
const match = document.getElementById("match");
const resume = document.getElementById("resume");
const variant = document.getElementById("variant");
const menu = document.getElementById("menu");
menu.hidden = true;

function showMatch(show) {
  lobby.hidden = show;
  match.hidden = !show;
  menu.hidden = !show;
  (show ? board : document.getElementById("local")).scrollIntoView({block: "nearest"});
}

document.getElementById("local").onclick = () => {
  const start = () => {
    leaveClubRoom();
    reset(variant.value);
    resume.hidden = false;
    showMatch(true);
  };
  if (history.length) ask("Заменить текущую партию?", [["Начать", start]]);
  else start();
};
menu.onclick = () => showMatch(false);
resume.onclick = () => showMatch(true);
