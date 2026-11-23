"use strict";

const WHITE = 0, BLACK = 1;
const PRICE = {p:1, n:3, b:3, r:5, q:9};
const NAME = {p:"Пешка", n:"Конь", b:"Слон", r:"Ладья", q:"Ферзь", k:"Король", m:"Мортира", j:"Джокер"};
const promotions = s => s.variant==="custom"?["q","r","b","n"]:["q","b","n"];
const ORTHOGONAL = [[1,0],[-1,0],[0,1],[0,-1]];
const DIAGONAL = [[1,1],[1,-1],[-1,1],[-1,-1]];
const ADJACENT = [...ORTHOGONAL,...DIAGONAL];
const KNIGHT = [[1,2],[2,1],[-1,2],[-2,1],[1,-2],[2,-1],[-1,-2],[-2,-1]];
const x = i => i % 8;
const y = i => i >> 3;
const at = (col,row) => col >= 0 && col < 8 && row >= 0 && row < 8 ? row*8+col : -1;
const step = (i,dx,dy) => at(x(i)+dx,y(i)+dy);
const square = i => "abcdefgh"[x(i)]+(8-y(i));
const distance = (a,b) => Math.max(Math.abs(x(a)-x(b)),Math.abs(y(a)-y(b)));
const forward = side => side === WHITE ? -1 : 1;
const home = side => side === WHITE ? 7 : 0;
const piece = (t,c,fresh=false) => ({t,c,fresh});
const neighbors = i => ADJACENT.map(([dx,dy])=>step(i,dx,dy)).filter(j=>j>=0);
const edible = p => !!PRICE[p?.t];

const VARIANTS = {standard:"Шахматы 2",georgy:"Пушка Георгия"};

function setup(variant="standard"){
  const b = Array(64).fill(null);
  for(const c of [WHITE,BLACK]){
    [..."mnbqkbnm"].forEach((t,col)=>{b[at(col,home(c))]=piece(t,c);});
    for(let col=0;col<8;col++) b[at(col,home(c)+forward(c))]=piece("p",c,true);
  }
  if(variant==="georgy"){
    for(const c of [WHITE,BLACK]){
      for(let d=1;d<=4;d++){
        b[at(c===WHITE?7:0,home(c)+d*forward(c))]={...piece("p",c),group:true};
      }
    }
  }
  b[at(4,4)]=piece("j",WHITE);
  b[at(3,3)]=piece("j",BLACK);
  return {b,variant,side:WHITE,rights:[[true,true],[true,true]],bank:[0,0],joker:[0,0],ninja:[null,null],ep:null,smoke:null,quiet:0};
}

function formation(board,color){
  return board.flatMap((p,i)=>p?.c===color && p.group?[i]:[]).sort((a,b)=>(y(b)-y(a))*forward(color));
}

function formationTarget(board,group,to,capturing){
  const head=group[0];
  const dx=x(to)-x(head), dy=y(to)-y(head);
  return group.every((i,k)=>{
    const dest=step(i,dx,dy);
    return dest>=0 && (group.includes(dest) || !board[dest] || (capturing && k===0));
  });
}

function attacked(b,target,by){
  for(const dx of [-1,1]){
    const p=b[step(target,dx,-forward(by))];
    if(p?.c!==by || p.t!=="p") continue;
    if(!p.group) return true;
    const group=formation(b,by);
    if(group[0]===step(target,dx,-forward(by)) && formationTarget(b,group,target,true)) return true;
  }
  for(const [dx,dy] of KNIGHT){
    const p=b[step(target,dx,dy)];
    if(p?.c===by && p.t==="n") return true;
  }
  for(const [dx,dy] of ADJACENT){
    for(let d=1;d<8;d++){
      const i=step(target,dx*d,dy*d);
      if(i<0) break;
      const p=b[i];
      if(!p) continue;
      if(p.c===by && (p.t==="q" || (p.t==="k" && d===1) || (p.t==="b" && dx && dy) || (p.t==="r" && (!dx || !dy)))) return true;
      break;
    }
  }
  return false;
}

function check(s,side=s.side){
  const king=s.b.findIndex(p=>p?.c===side && p.t==="k");
  return attacked(s.b,king,1-side);
}

function candidates(s,from){
  const {b,side}=s;
  const p=b[from];
  if(!p || p.c!==side) return [];
  const moves=[];
  const add=(to,kind="move",extra={})=>{
    if(p.t==="p" && y(to)===home(1-side)){
      for(const promote of promotions(s)) moves.push({from,to,kind,promote,...extra});
    }else{
      moves.push({from,to,kind,...extra});
    }
  };
  const walk=(directions,limit)=>{
    for(const [dx,dy] of directions) for(let d=1;d<=limit;d++){
      const to=step(from,dx*d,dy*d);
      if(to<0) break;
      const target=b[to];
      if(!target || (edible(target) && (p.t==="j" || target.c!==side))) add(to);
      if(target) break;
    }
  };

  switch(p.t){
    case "p": {
      const dy=forward(side);
      if(p.group){
        const group=formation(b,side);
        if(from!==group[0]) break;
        for(const dx of [-1,0,1]){
          const to=step(from,dx,dy);
          if(to<0) continue;
          const target=b[to];
          const canEnter=dx===0 ? !target : edible(target) && target.c!==side;
          if(canEnter && formationTarget(b,group,to,dx!==0)) add(to,"formation");
        }
        break;
      }
      const one=step(from,0,dy), two=step(from,0,2*dy);
      if(one>=0 && !b[one]){
        add(one);
        if(p.fresh && y(from)===home(side)+dy && !b[two]) add(two);
      }
      for(const dx of [-1,1]){
        const to=step(from,dx,dy);
        if(to<0) continue;
        if(edible(b[to]) && b[to].c!==side) add(to);
        if(s.ep?.to===to) add(to,"ep",{victim:s.ep.victim});
      }
      if(s.ninja[side]===from){
        for(const to of neighbors(from)) if(!b[to]) add(to,"smoke");
      }
      break;
    }
    case "n": walk(KNIGHT,1); break;
    case "b": walk(DIAGONAL,7); break;
    case "r": walk(ORTHOGONAL,7); break;
    case "q": walk(ADJACENT,7); break;
    case "k": {
      walk(ADJACENT,1);
      const row=home(side);
      if(from!==at(4,row) || check(s)) break;
      for(const flank of [0,1]){
        const mortar=at(flank===0?0:7,row);
        const cols=flank===0?[1,2,3]:[5,6];
        if(!s.rights[side][flank] || !["m","r"].includes(b[mortar]?.t) || b[mortar].c!==side || cols.some(col=>b[at(col,row)])) continue;
        const pass=at(flank===0?3:5,row);
        const transit=b.slice();
        transit[from]=null;
        transit[pass]=p;
        if(!attacked(transit,pass,1-side)) add(at(flank===0?2:6,row),"castle",{mortar,pass});
      }
      break;
    }
    case "j":
      walk(ADJACENT,1);
      for(const to of neighbors(from)){
        if(b[to]) continue;
        for(const create of Object.keys(PRICE)){
          if((create==="r" && s.variant!=="custom") || s.joker[side]<PRICE[create] || (create==="p" && (y(to)===0 || y(to)===7))) continue;
          moves.push({from,to,kind:"create",create});
        }
      }
      break;
    case "m":
      for(let to=0;to<64;to++){
        if(!edible(b[to]) || b[to].c===side) continue;
        const cost=distance(from,to);
        if(cost<=s.bank[side]+s.joker[side]) moves.push({from,to,kind:"fire",cost});
      }
      break;
  }
  return moves;
}

function apply(s,a){
  const {side}=s;
  const n={...s,b:s.b.slice(),side:1-side,rights:s.rights.map(r=>r.slice()),bank:s.bank.slice(),joker:s.joker.slice(),ninja:s.ninja.slice(),ep:null,smoke:null,quiet:s.quiet+1};
  const p=s.b[a.from];
  const victim=a.victim??a.to;
  const captured=s.b[victim];
  n.ninja[side]=null;
  if(p.t==="r") loseRookRights(n,a.from,p.c);
  if(captured?.t==="r") loseRookRights(n,victim,captured.c);
  if(captured && n.ninja[captured.c]===victim) n.ninja[captured.c]=null;
  if(captured?.group){
    for(const i of formation(s.b,captured.c)) n.b[i]=piece("p",captured.c);
  }
  if(a.kind==="fire"){
    const ordinary=Math.min(a.cost,n.bank[side]);
    n.bank[side]-=ordinary;
    n.joker[side]-=a.cost-ordinary;
    n.b[a.to]=null;
  }else if(a.kind==="formation"){
    const group=formation(s.b,side);
    const dx=x(a.to)-x(a.from), dy=forward(side);
    for(const i of group) n.b[i]=null;
    for(const i of group){
      n.b[step(i,dx,dy)]=a.promote ? piece("p",side) : {...piece("p",side),group:true};
    }
    if(a.promote) n.b[a.to]=piece(a.promote,side);
    if(captured) n.bank[side]+=PRICE[captured.t];
  }else if(a.kind==="create"){
    n.joker[side]-=PRICE[a.create];
    n.b[a.to]=piece(a.create,side);
  }else{
    n.b[a.from]=null;
    n.b[victim]=null;
    n.b[a.to]=piece(a.promote??p.t,side);
    if(captured){
      (p.t==="j"?n.joker:n.bank)[side]+=PRICE[captured.t];
      if(p.t==="p" && !a.promote) n.ninja[side]=a.to;
    }
    if(p.t==="p" && Math.abs(y(a.from)-y(a.to))===2){
      n.ep={to:(a.from+a.to)/2,victim:a.to};
    }
    if(a.kind==="smoke") n.smoke={from:a.from};
    if(p.t==="k") n.rights[side]=[false,false];
    if(a.kind==="castle"){
      n.b[a.pass]=s.b[a.mortar];
      n.b[a.mortar]=null;
    }
  }
  if(captured || p.t==="p" || a.kind==="create") n.quiet=0;
  return n;
}

function loseRookRights(s,i,color){
  if(y(i)===home(color) && (x(i)===0 || x(i)===7)) s.rights[color][x(i)===0?0:1]=false;
}

function legal(s,from){
  return candidates(s,from).filter(a=>!check(apply(s,a),s.side));
}

function anyMove(s){
  return s.b.some((p,i)=>p?.c===s.side && legal(s,i).length);
}

function positionKey(s){
  const ep=s.ep && s.b.some((p,i)=>p?.c===s.side && p.t==="p" && legal(s,i).some(a=>a.kind==="ep")) ? s.ep.to : null;
  return JSON.stringify([s.b,s.side,s.rights,s.bank,s.joker,s.ninja,ep,s.smoke]);
}

function moveLabel(s,a,hide){
  const start=square(a.from);
  const end=square(a.to);
  if(a.kind==="castle") return x(a.to)===6?"Рокировка O–O":"Рокировка O–O–O";
  if(a.kind==="fire") return "Мортира "+start+" → "+end+" · −"+a.cost;
  if(a.kind==="create") return NAME[a.create]+" на "+end+" · −"+PRICE[a.create];
  if(a.kind==="smoke") return "Дым "+start+(hide?"":" → "+end+(a.promote?" · "+NAME[a.promote]:""));
  const separator=s.b[a.victim??a.to]?" × ":" → ";
  return (a.kind==="formation"?"Пушка Георгия":NAME[s.b[a.from].t])+" "+start+separator+end+(a.promote?" · "+NAME[a.promote]:"");
}

function gameResult(state,repetitions,drawClaim=false){
  if(!anyMove(state)) return check(state)?["Мат",["Чёрные","Белые"][state.side]+" победили."]:["Пат","Ничья."];
  if(repetitions>=5) return ["Ничья","Пять повторов позиции."];
  if(state.quiet>=150) return ["Ничья","Правило 75 ходов."];
  if(drawClaim) return ["Ничья","Ничья по заявлению игрока."];
  return null;
}
