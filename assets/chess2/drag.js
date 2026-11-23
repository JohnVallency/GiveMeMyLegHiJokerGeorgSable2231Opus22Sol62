"use strict";

(() => {
  if (board.dataset.dragMoves) return;
  board.dataset.dragMoves = "enabled";
  board.style.touchAction = "none";

  const panel = document.createElement("div");
  panel.style.cssText = "display:flex;align-items:center;gap:8px;margin:6px 0;color:inherit";
  const premoveButton = document.createElement("button");
  premoveButton.type = "button";
  premoveButton.className = "quiet-button";
  const premoveStatus = document.createElement("small");
  premoveStatus.setAttribute("aria-live", "polite");
  panel.append(premoveButton, premoveStatus);
  board.before(panel);

  let planning = false;
  let source = null;
  let queued = null;
  let wake = null;
  let highlighted = [];
  let notice = "";

  function canPlan() {
    return !ending && (remote ? remote.ready && state.side !== remote.color : planning);
  }

  function planSide() {
    return remote ? remote.color : 1 - state.side;
  }

  function updatePanel() {
    for (const cell of highlighted) cell.style.removeProperty("box-shadow");
    highlighted = [];
    for (const index of queued ? [queued.from, queued.to] : source === null ? [] : [source]) {
      const cell = cells[index];
      cell.style.boxShadow = "inset 0 0 0 4px #bd81f1";
      highlighted.push(cell);
    }
    panel.hidden = Boolean(ending || (remote && !canPlan() && !queued));
    premoveButton.hidden = Boolean(remote && !queued && source === null);
    premoveButton.textContent = queued || source !== null || planning ? "Отменить премув" : "Премув";
    premoveStatus.textContent = queued ? `${square(queued.from)} → ${square(queued.to)}`
      : canPlan() ? (source === null ? "Выбери фигуру и клетку заранее" : "Выбери клетку назначения")
      : notice;
  }

  function clearPlan() {
    planning = false;
    source = null;
    queued = null;
  }

  premoveButton.onclick = () => {
    notice = "";
    if (queued || source !== null || planning) clearPlan();
    else planning = true;
    updatePanel();
  };

  function queue(from, to) {
    const piece = state.b[from];
    if (!canPlan() || !piece || piece.c !== planSide() || from === to) return;
    const origin = piece.group ? formation(state.b, piece.c)[0] : from;
    queued = {from: origin, to, type: piece.t, side: piece.c, room: remote?.id,
      history, length: history.length};
    notice = "";
    source = null;
    planning = false;
    updatePanel();
  }

  function flushPremove() {
    if (!queued) {
      updatePanel();
      return;
    }
    const move = queued;
    const changedGame = move.room !== remote?.id ||
      (!remote && (move.history !== history || history.length < move.length));
    if (ending || changedGame) {
      clearPlan();
      updatePanel();
      return;
    }
    if (state.side !== move.side || (remote && !remote.playable)) return;
    if (remote && roomBusy) {
      if (wake === null) wake = setTimeout(() => { wake = null; flushPremove(); }, 80);
      return;
    }
    clearPlan();
    const piece = state.b[move.from];
    if (piece?.t === move.type && piece.c === move.side) {
      select(move.from);
      if (available().some(action => action.to === move.to)) {
        choose(move.to);
        updatePanel();
        return;
      }
      select(null);
    }
    notice = "Премув отменён: ход недоступен";
    updatePanel();
  }

  new MutationObserver(flushPremove).observe(board, {childList: true, subtree: true});
  updatePanel();

  let drag = null;
  let ignoreClick = false;
  const atPoint = (x, y) => document.elementFromPoint(x, y)?.closest(".cell");

  board.addEventListener("pointerdown", event => {
    if (!event.isPrimary || event.button !== 0 || ending) return;
    const cell = event.target.closest(".cell");
    const index = cells.indexOf(cell);
    const figure = cell?.querySelector(".figure");
    const premove = canPlan();
    if (index < 0 || !figure || state.b[index]?.c !== (premove ? planSide() : state.side)) return;
    if (!premove && remote && (!remote.playable || roomBusy)) return;
    drag = {pointer: event.pointerId, index, x: event.clientX, y: event.clientY, figure, premove};
  });

  board.addEventListener("pointermove", event => {
    if (event.pointerId !== drag?.pointer) return;
    if (!drag.preview) {
      if (Math.hypot(event.clientX - drag.x, event.clientY - drag.y) < 8) return;
      const bounds = drag.figure.getBoundingClientRect();
      const preview = drag.figure.cloneNode(true);
      Object.assign(preview.style, {
        position: "fixed", width: bounds.width + "px", height: bounds.height + "px",
        fontSize: getComputedStyle(drag.figure).fontSize,
        pointerEvents: "none", zIndex: "100", transform: "translate(-50%, -50%)",
        opacity: ".9", margin: "0"
      });
      document.body.append(preview);
      drag.preview = preview;
      board.setPointerCapture(event.pointerId);
      if (!drag.premove && selected !== drag.index) select(drag.index);
    }
    drag.preview.style.left = event.clientX + "px";
    drag.preview.style.top = event.clientY + "px";
    drag.hover?.style.removeProperty("outline");
    drag.hover = atPoint(event.clientX, event.clientY);
    if (drag.hover && board.contains(drag.hover)) drag.hover.style.outline = "3px solid #fff";
  });

  function finish(event, cancelled) {
    if (event.pointerId !== drag?.pointer) return;
    const current = drag;
    drag = null;
    if (!current.preview) return;
    current.preview.remove();
    current.hover?.style.removeProperty("outline");
    ignoreClick = true;
    setTimeout(() => { ignoreClick = false; }, 0);
    if (cancelled || ending) return;
    const to = cells.indexOf(atPoint(event.clientX, event.clientY));
    if (to < 0 || to === current.index) return;
    if (current.premove) {
      queue(current.index, to);
      return;
    }
    if (selected === null || (remote && (!remote.playable || roomBusy))) return;
    const valid = available().some(action => action.to === to);
    if (valid || (remote && state.smoke && state.b[to]?.c !== state.side)) choose(to);
  }

  board.addEventListener("pointerup", event => finish(event, false));
  board.addEventListener("pointercancel", event => finish(event, true));
  board.addEventListener("lostpointercapture", event => finish(event, true));
  board.addEventListener("pointerleave", () => { if (drag && !drag.preview) drag = null; });
  board.addEventListener("click", event => {
    if (!ignoreClick && !canPlan()) return;
    event.preventDefault();
    event.stopImmediatePropagation();
    if (ignoreClick) return;
    const index = cells.indexOf(event.target.closest(".cell"));
    if (index < 0) return;
    if (source !== null && source !== index) {
      queue(source, index);
    } else if (state.b[index]?.c === planSide()) {
      source = source === index ? null : index;
      updatePanel();
    }
  }, true);
})();
