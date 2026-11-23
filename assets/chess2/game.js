"use strict";

const $ = id => document.getElementById(id);
const COLORS = ["Белые","Чёрные"];
const GLYPH = {p:"♟", n:"♞", b:"♝", r:"♜", q:"♛", k:"♚", j:"✦"};
const board = $("board");
const choice = $("choice");
const cells = Array.from({length:64},(_,i)=>{
  const cell=document.createElement("button");
  cell.type="button";
  cell.addEventListener("click",()=>choose(i));
  cell.addEventListener("keydown",event=>{
    const direction={ArrowUp:[0,-1],ArrowDown:[0,1],ArrowLeft:[-1,0],ArrowRight:[1,0]}[event.key];
    if(!direction) return;
    event.preventDefault();
    const next=step(i,...direction.map(delta=>remote?.color===BLACK?-delta:delta));
    if(next>=0) cells[next].focus();
  });
  board.append(cell);
  return cell;
});

let state, history, selected, mode, options, ending, drawClaim;
let remote=null, orientation=WHITE;

function button(label,fn,active=false){
  const btn=document.createElement("button");
  btn.type="button";
  btn.className=active?"action on":"action";
  btn.textContent=label;
  btn.addEventListener("click",fn);
  return btn;
}

function ask(title,choices){
  const heading=document.createElement("h2");
  heading.textContent=title;
  const actions=document.createElement("div");
  actions.className="dialog-actions";
  for(const [label,fn] of choices) actions.append(button(label,()=>{choice.close(); fn();}));
  actions.append(button("Отмена",()=>choice.close()));
  choice.replaceChildren(heading,actions);
  choice.showModal();
}

function reset(variant="standard"){
  state=setup(variant);
  history=[];
  drawClaim=false;
  select(null);
}

function repetitions(){
  const key=positionKey(state);
  return 1+history.filter(entry=>entry.key===key).length;
}

function select(i){
  if(i!==null && state.b[i].group) i=formation(state.b,state.side)[0];
  selected=i;
  mode=i!==null && state.b[i].t==="m"?"fire":"move";
  options=i===null?[]:remote?remote.actions.filter(a=>a.from===i):legal(state,i);
  render();
}

function blindMove(i){
  const piece=state.b[selected];
  const kind=mode.startsWith("create-")?"create":mode;
  const action={from:selected,to:i,kind,create:kind==="create"?mode.slice(7):undefined};
  if(piece.t==="p" && y(i)===home(1-state.side)){
    ask("Во что превратить пешку?",promotions(state).map(promote=>[NAME[promote],()=>play({...action,promote})]));
  }else{
    play(action);
  }
}

function available(){
  if(mode.startsWith("create-")) return options.filter(a=>a.create===mode.slice(7));
  if(mode==="move") return options.filter(a=>["move","ep","castle","formation"].includes(a.kind));
  return options.filter(a=>a.kind===mode);
}

function choose(i){
  if(ending || (remote && (!remote.playable || roomBusy))) return;
  const matching=available().filter(a=>a.to===i);
  if(matching.length===1){ play(matching[0]); return; }
  if(matching.length>1){ ask("Во что превратить пешку?",matching.map(a=>[NAME[a.promote],()=>play(a)])); return; }
  const target=state.b[i];
  const own=target?.c===state.side;
  const jokerCapture=selected!==null && state.b[selected].t==="j" && mode==="move" && edible(target) && distance(selected,i)===1;
  if(remote && state.smoke && selected!==null && (!own || jokerCapture)){
    blindMove(i);
    return;
  }
  if(own){
    const sameFormation=target.group && selected!==null && state.b[selected].group;
    select(i===selected || sameFormation?null:i);
  }else if(selected!==null){
    select(null);
  }
}

function play(a){
  if(remote){ sendTurn("move",a); return; }
  history.push({state,action:a,key:positionKey(state)});
  state=apply(state,a);
  drawClaim=false;
  select(null);
}

function undo(){
  if(drawClaim){ drawClaim=false; select(null); return; }
  const last=history.pop();
  if(last){ state=last.state; select(null); }
}

function option(label,value){
  const btn=button(label,()=>{mode=value; render();},mode===value);
  btn.setAttribute("aria-pressed",mode===value);
  return btn;
}

function render(){
  ending=remote?remote.ending:gameResult(state,repetitions(),drawClaim);
  const turn=state.side;
  const inCheck=remote?state.checking:check(state);
  const previous=remote?remote.last:history.at(-1)?.action;
  const fog=state.smoke?[state.smoke.from,...neighbors(state.smoke.from)]:[];
  const valid=ending?[]:available();
  const viewSide=remote?.color??WHITE;
  const observingFog=!!remote && !!state.smoke && turn===remote.color;
  if(orientation!==viewSide){
    orientation=viewSide;
    board.append(...(viewSide===WHITE?cells:cells.slice().reverse()));
  }
  $("turn").textContent=ending?.[0]??"Ходят "+COLORS[turn].toLowerCase();
  $("message").textContent=ending?.[1]??(inCheck?"Шах. Защити короля.":state.smoke?"Дым рассеется после ответа соперника.":"Выбери фигуру или мортиру.");
  if(remote && !ending){
    if(remote.armies && !remote.armies.started) $("message").textContent="Фигуры откроются, когда оба игрока зафиксируют армии.";
    else if(!remote.ready) $("message").textContent="Ждём второго игрока.";
    else if(!remote.playable) $("message").textContent="Ход соперника.";
    else if(observingFog) $("message").textContent=(inCheck?"Шах. ":"")+"Дым на доске. Ходи без подсветки.";
  }
  const actions=$("actions");
  actions.replaceChildren();
  if(!ending && selected!==null){
    const selectedPiece=state.b[selected];
    const type=selectedPiece.t;
    $("message").textContent=(selectedPiece.group?"Пушка Георгия":NAME[type])+" · "+square(selected)+(inCheck?" · шах":"");
    if(type==="m" && !valid.length && !observingFog) $("message").textContent+=" · нет доступных целей";
    if(options.some(a=>a.kind==="smoke") || (observingFog && state.ninja[turn]===selected)){
      actions.append(option("Ход","move"),option("Дым","smoke"));
    }
    if(type==="j" && (options.some(a=>a.kind==="create") || (observingFog && state.joker[turn]>0))){
      actions.append(option("Ход","move"));
      for(const [kind,cost] of Object.entries(PRICE)){
        if(options.some(a=>a.create===kind) || (observingFog && state.joker[turn]>=cost)) actions.append(option(NAME[kind]+" "+cost,"create-"+kind));
      }
    }
  }
  const canClaim=remote?remote.claim:!ending && (state.quiet>=100 || repetitions()>=3);
  if(canClaim){
    actions.append(button("Заявить ничью",()=>ask("Заявить ничью?",[["Заявить",()=>{
      if(remote) sendTurn("draw");
      else {drawClaim=true; select(null);}
    }]])));
  }
  for(const [i,cell] of cells.entries()){
    const p=state.b[i];
    const smoked=fog.includes(i);
    const visible=p && (remote || !smoked || p.t==="k" || p.c===turn);
    const a=valid.find(candidate=>candidate.to===i);
    cell.className="cell";
    cell.classList.toggle("dark",(x(i)+y(i))%2===1);
    cell.classList.toggle("last",!!previous && (previous.from===i || (previous.kind!=="smoke" && previous.to===i)));
    cell.classList.toggle("smoke",smoked);
    cell.classList.toggle("selected",selected===i || !!(visible && p.group && selected!==null && state.b[selected].group && p.c===state.side));
    cell.classList.toggle("danger",inCheck && p?.c===turn && p.t==="k");
    cell.classList.toggle("target",!!a);
    cell.classList.toggle("capture",!!a && (!smoked && !!p || a.kind==="ep") && a.kind!=="fire");
    cell.classList.toggle("fire",a?.kind==="fire");
    cell.classList.toggle("special",a?.kind==="smoke" || a?.kind==="create");
    const title=[square(i)];
    if(visible) title.push((p.group?"Пушка Георгия":NAME[p.t])+(p.c===WHITE?" (белые)":" (чёрные)"));
    if(smoked) title.push("Дым");
    if(a?.kind==="fire") title.push("Выстрел за "+a.cost);
    cell.setAttribute("aria-label",title.join(", "));
    cell.title=title.join(" · ");
    cell.replaceChildren();
    if(visible){
      if(p.group){
        const band=document.createElement("span");
        const top=step(i,0,viewSide===WHITE?-1:1);
        const bottom=step(i,0,viewSide===WHITE?1:-1);
        const isPart=j=>state.b[j]?.group && state.b[j].c===p.c;
        band.className="formation-band "+(p.c===WHITE?"ivory":"ink");
        band.classList.toggle("cap-top",!isPart(top));
        band.classList.toggle("cap-bottom",!isPart(bottom));
        cell.append(band);
      }
      const fig=document.createElement("span");
      fig.className="figure"+(p.c===BLACK?" black":"")+(p.t==="m"?" mortar":p.t==="j"?" joker":"");
      if(p.t==="m"){
        for(let n=0;n<4;n++){
          const star=document.createElement("span");
          star.textContent="✦";
          fig.append(star);
        }
      }else if(p.t==="j"){
        const hat=document.createElement("span");
        hat.className="jester-hat";
        hat.innerHTML="<i></i><i></i><i></i>";
        const face=document.createElement("span");
        face.className="jester-face";
        fig.append(hat,face);
      }else{
        fig.textContent=GLYPH[p.t];
      }
      fig.setAttribute("aria-hidden","true");
      cell.append(fig);
      if(state.ninja[p.c]===i){
        const mark=document.createElement("span");
        mark.className="ninja-mark";
        cell.append(mark);
        cell.setAttribute("aria-label",title.concat("Дым готов").join(", "));
      }
    }
    if(x(i)===(viewSide===WHITE?0:7)) label(cell,8-y(i),"rank");
    if(y(i)===(viewSide===WHITE?7:0)) label(cell,"abcdefgh"[x(i)],"file");
  }
  $("banks").innerHTML=COLORS.map((name,i)=>`<tr><th scope="row">${name}</th><td>${state.bank[i]+state.joker[i]}</td><td>${state.joker[i]}</td></tr>`).join("");
  const log=$("log");
  const notes=remote?remote.log:history.map((entry,i)=>COLORS[entry.state.side]+" · "+moveLabel(entry.state,entry.action,!!state.smoke && i===history.length-1));
  log.replaceChildren(...notes.map(note=>{
    const row=document.createElement("li");
    row.textContent=note;
    return row;
  }));
  if(!notes.length){
    const row=document.createElement("li");
    row.textContent="Партия ещё не началась.";
    row.className="empty-log";
    log.append(row);
  }
  log.scrollTop=log.scrollHeight;
  $("undo").hidden=!!remote;
  $("restart").hidden=!!remote;
  $("undo").disabled=!history.length && !drawClaim;
  $("mode-label").textContent=(remote?"Онлайн-партия":"Игра с собой")+(state.variant==="georgy"?" · Пушка Георгия":state.variant==="custom"?" · Свои армии":"");
}

function label(cell,text,axis){
  const span=document.createElement("span");
  span.className="coord "+axis;
  span.textContent=text;
  span.setAttribute("aria-hidden","true");
  cell.append(span);
}

$("undo").addEventListener("click",undo);
$("restart").addEventListener("click",()=>{if(history.length) ask("Начать новую партию?",[["Начать",()=>reset(state.variant)]]); else reset(state.variant);});
$("rules").addEventListener("click",()=>$("rulebook").showModal());
reset();
