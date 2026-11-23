import { createServer } from 'node:http';
import { createServer as createHttpsServer } from 'node:https';
import { createHash, randomBytes, randomInt, scryptSync, timingSafeEqual } from 'node:crypto';
import { readFileSync, existsSync, createReadStream, statSync, mkdirSync } from 'node:fs';
import { dirname, resolve, extname, sep } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import vm from 'node:vm';

const database = resolve(process.env.CLUB_DB || 'server/data/club.sqlite');
mkdirSync(dirname(database), { recursive: true });
const db = new DatabaseSync(database);
db.exec(`
  PRAGMA journal_mode=WAL;
  CREATE TABLE IF NOT EXISTS users (name TEXT PRIMARY KEY, salt TEXT NOT NULL, hash TEXT NOT NULL, coins INTEGER NOT NULL DEFAULT 0);
  CREATE TABLE IF NOT EXISTS sessions (token TEXT PRIMARY KEY, name TEXT NOT NULL, expiry INTEGER NOT NULL);
  CREATE TABLE IF NOT EXISTS stamps (name TEXT NOT NULL, id TEXT NOT NULL, PRIMARY KEY (name,id));
  CREATE TABLE IF NOT EXISTS rooms (code TEXT PRIMARY KEY, data TEXT NOT NULL);
`);
const chess = vm.runInNewContext(readFileSync('assets/chess2/rules.js','utf8') +
  '\n({setup,legal,apply,gameResult,positionKey,moveLabel})');
const web = resolve(process.env.CLUB_WEB || 'build/web');
const token = () => randomBytes(32).toString('hex');
const hash = value => createHash('sha256').update(value).digest('hex');
const query = (sql, ...args) => db.prepare(sql).get(...args);
const run = (sql, ...args) => db.prepare(sql).run(...args);
const fail = (status, message) => { throw Object.assign(new Error(message), {status}); };
const attempts = new Map();
const chessTickets = new Map();
function throttle(key) {
  const now = Date.now();
  for (const [ip, window] of attempts) if (window.until <= now) attempts.delete(ip);
  const window = attempts.get(key) ?? {count:0, until:now + 60000};
  attempts.set(key, window);
  if (++window.count > 12) fail(429, 'Слишком много попыток. Подождите минуту.');
}
function identity(req) {
  const raw = req.headers.authorization?.match(/^Bearer ([a-f0-9]{64})$/)?.[1] ??
    req.headers.cookie?.match(/(?:^|;\s*)club_session=([a-f0-9]{64})(?:;|$)/)?.[1];
  const session = raw && query('SELECT name FROM sessions WHERE token=? AND expiry>?',hash(raw),Date.now());
  return {raw, name:session?.name};
}
function profile(name) { return query('SELECT name,coins FROM users WHERE name=?',name); }
async function body(req) {
  const chunks = [];
  let length = 0;
  for await (const chunk of req) {
    length += chunk.length;
    if (length > 8192) fail(413,'Запрос слишком большой.');
    chunks.push(chunk);
  }
  try {
    const data = JSON.parse(Buffer.concat(chunks).toString());
    if (!data || Array.isArray(data) || typeof data !== 'object') fail(400,'Некорректный запрос.');
    return data;
  } catch { fail(400,'Некорректный запрос.'); }
}
function nardySetup() {
  const points = Array(24).fill(0);
  for (const [i,count] of [[23,2],[12,5],[7,3],[5,5],[0,-2],[11,-5],[16,-3],[18,-5]]) points[i]=count;
  return {points,bar:[0,0],off:[0,0]};
}
const sideIndex = side => side === 1 ? 0 : 1;
function nardyMoves(p,side,die) {
  const onBar = p.bar[sideIndex(side)] > 0;
  const own = p.points.flatMap((count,i) => count*side > 0 ? [i] : []);
  const home = !onBar && own.every(i => side === 1 ? i <= 5 : i >= 18);
  return (onBar ? [-1] : own).flatMap(from => {
    const to = from === -1 ? (side === 1 ? 24-die : die-1) : from-side*die;
    if (to >= 0 && to < 24) return p.points[to]*side >= -1 ? [{from,to,die}] : [];
    const distance = side === 1 ? from+1 : 24-from;
    const farther = own.some(i => side === 1 ? i > from : i < from);
    return home && (die === distance || !farther) ? [{from,to:24,die}] : [];
  });
}
function nardyPlay(p,side,{from,to}) {
  const next = structuredClone(p);
  const index = sideIndex(side);
  if (from === -1) next.bar[index]--; else next.points[from]-=side;
  if (to===24) next.off[index]++;
  else {
    if (next.points[to]===-side) { next.points[to]=0; next.bar[1-index]++; }
    next.points[to]+=side;
  }
  return next;
}
function nardyOptions(p,side,dice) {
  if (!dice.length || p.off[sideIndex(side)]===15) return {length:0, options:[]};
  const paths = [];
  for (const die of new Set(dice)) {
    const rest=dice.slice();
    rest.splice(rest.indexOf(die),1);
    for (const move of nardyMoves(p,side,die)) {
      paths.push({move,length:1+nardyOptions(nardyPlay(p,side,move),side,rest).length});
    }
  }
  const length = Math.max(0,...paths.map(path=>path.length));
  const best = paths.filter(path=>path.length===length).map(path=>path.move);
  return {length,options:length===1 ? best.filter(move=>move.die===Math.max(...best.map(item=>item.die))) : best};
}
function roomView(room,name) {
  const i=room.players.indexOf(name);
  if (i<0) fail(403,'Сначала войдите в комнату.');
  const playable=room.players.length===2 && room.turn===i && !room.ending;
  const actions=playable
    ? room.game==='chess'
      ? room.position.b.flatMap((_,from)=>chess.legal(room.position,from))
      : nardyOptions(room.position,i===0?1:-1,room.dice).options
    : [];
  const position = structuredClone(room.position);
  if (room.game === 'chess' && position.smoke && playable) {
    // Room state and player action lists stay on the server under smoke.
    const {from} = position.smoke;
    position.b = position.b.map((piece, index) =>
      piece && piece.c !== i && piece.t !== 'k' &&
      Math.max(Math.abs((index % 8)-(from % 8)),Math.abs((index >> 3)-(from >> 3))) <= 1 ? null : piece);
    actions.length = 0;
  }
  return {...room, id:room.code, repetition:undefined, position, actions, color:i, playable, ready:room.players.length===2};
}
function roomAction(room,name,data) {
  const view=roomView(room,name);
  if (!view.playable || data.revision !== room.revision) fail(409,'Позиция изменилась.');
  if (room.game==='chess') {
    const action=room.position.b.flatMap((_,from)=>chess.legal(room.position,from)).find(a=>
      a.from===data.from && a.to===data.to && a.kind===data.kind &&
      a.create===data.create && a.promote===data.promote);
    if (!action) fail(422,'Недопустимый ход.');
    const key=chess.positionKey(room.position);
    room.repetition.push(key);
    room.log.push(chess.moveLabel(room.position,action,action.kind==='smoke'));
    room.position=chess.apply(room.position,action);
    room.last=action.kind==='smoke'?null:action;
    room.turn=room.position.side;
    const count=1+room.repetition.filter(key=>key===chess.positionKey(room.position)).length;
    room.ending=chess.gameResult(room.position,count);
    return;
  }
  if (data.action==='roll' && !room.dice.length) {
    const a=randomInt(1,7);
    let b=randomInt(1,7);
    if (!room.started) {
      while (a===b) b=randomInt(1,7);
      room.turn=a>b?0:1;
      room.started=true;
    }
    room.dice=a===b?[a,a,a,a]:[a,b];
    room.rolled=[a,b];
  } else {
    const move=view.actions.find(m=>m.from===data.from && m.to===data.to && m.die===data.die);
    if (!move) fail(422,'Недопустимый ход.');
    room.position=nardyPlay(room.position,room.turn===0?1:-1,move);
    room.dice.splice(room.dice.indexOf(move.die),1);
    if (room.position.off[room.turn]===15) room.ending=[`Победа: ${name}`];
  }
  if (!room.ending && !nardyOptions(room.position,room.turn===0?1:-1,room.dice).length) {
    room.dice=[];
    room.turn=1-room.turn;
  }
}
function getRoom(code) {
  const row=query('SELECT data FROM rooms WHERE code=?',code);
  if (!row) fail(404,'Комната не найдена.');
  return JSON.parse(row.data);
}
function saveRoom(room) {
  run('INSERT INTO rooms VALUES(?,?) ON CONFLICT(code) DO UPDATE SET data=excluded.data',room.code,JSON.stringify(room));
}
const types={'.html':'text/html; charset=utf-8','.js':'application/javascript','.css':'text/css','.json':'application/json','.wasm':'application/wasm','.png':'image/png','.otf':'font/otf','.svg':'image/svg+xml'};
const handleRequest=async (req,res)=>{
  const url=new URL(req.url,'http://localhost');
  const {pathname:path}=url;
  const json=(status,data)=>{res.writeHead(status,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'});res.end(JSON.stringify(data));};
  try {
    if (path === '/chess-entry' && req.method === 'POST') {
      let encoded = '';
      for await (const chunk of req) {
        encoded += chunk;
        if (encoded.length > 256) fail(400,'Неверный запрос.');
      }
      const ticket = new URLSearchParams(encoded).get('ticket');
      const entry = chessTickets.get(ticket);
      chessTickets.delete(ticket);
      if (!entry || entry.expiry < Date.now() ||
        !query('SELECT 1 FROM sessions WHERE token=? AND expiry>?',hash(entry.raw),Date.now()))
        fail(401,'Откройте шахматы заново из меню приложения.');
      res.writeHead(303, {
        'Set-Cookie': `club_session=${entry.raw}; HttpOnly; SameSite=Strict; Path=/; Max-Age=2592000; Secure`,
        'Location':'/assets/assets/chess2/index.html',
        'Cache-Control':'no-store',
      });
      return res.end();
    }
    if (!path.startsWith('/api/')) {
      const file=resolve(web,'.'+decodeURIComponent(path));
      if (!file.startsWith(web+sep) && file!==web) fail(404,'Страница не найдена.');
      const actual=existsSync(file) && statSync(file).isDirectory()?resolve(file,'index.html'):file;
      if (!existsSync(actual) || !statSync(actual).isFile()) fail(404,'Страница не найдена.');
      res.writeHead(200,{'Content-Type':types[extname(actual)]||'application/octet-stream','Cache-Control':'no-cache'});
      createReadStream(actual).pipe(res);return;
    }
    const {name,raw}=identity(req);
    // Cookie-authenticated writes are same-origin. Native requests use a bearer session.
    if (req.method==='POST' && ['cross-site','same-site'].includes(req.headers['sec-fetch-site'])) fail(403,'Недоступно.');
    if (req.method==='POST' && (path==='/api/register' || path==='/api/login')) {
      throttle(req.socket.remoteAddress);
      const data=await body(req);
      const login=typeof data.name==='string'?data.name.trim().toLowerCase():'';
      const password=data.password;
      if (!/^[\p{L}\p{N}_-]{3,24}$/u.test(login) || typeof password!=='string' || password.length<8 || password.length>128)
        fail(400,'Имя: 3–24 буквы или цифры. Пароль: 8–128 символов.');
      const existing=query('SELECT * FROM users WHERE name=?',login);
      const salt=existing?.salt??token();
      const passwordHash=scryptSync(password,salt,64);
      if (path==='/api/register') {
        if (existing) fail(409,'Имя уже занято.');
        run('INSERT INTO users(name,salt,hash) VALUES(?,?,?)',login,salt,passwordHash.toString('hex'));
      } else if (!existing || !timingSafeEqual(passwordHash,Buffer.from(existing.hash,'hex'))) {
        fail(401,'Неверное имя или пароль.');
      }
      const session=token();
      run('INSERT INTO sessions VALUES(?,?,?)',hash(session),login,Date.now()+30*86400000);
      const secure=process.env.CLUB_SECURE_COOKIE==='1'?'; Secure':'';
      res.setHeader('Set-Cookie',`club_session=${session}; HttpOnly; SameSite=Strict; Path=/; Max-Age=2592000${secure}`);
      return json(200,{...profile(login), ...(data.native===true?{token:session}:{})});
    }
    if (!name) fail(401,'Войдите в общий аккаунт.');
    if (path==='/api/chess-ticket' && req.method==='POST') {
      const now=Date.now();
      for (const [key,entry] of chessTickets) if (entry.expiry <= now) chessTickets.delete(key);
      const ticket=token();
      chessTickets.set(ticket,{raw,expiry:now+30000});
      return json(200,{ticket});
    }
    if (path==='/api/me' && req.method==='GET') return json(200,profile(name));
    if (path==='/api/logout' && req.method==='POST') {
      run('DELETE FROM sessions WHERE token=?',hash(raw));
      res.setHeader('Set-Cookie','club_session=; HttpOnly; SameSite=Strict; Path=/; Max-Age=0');
      return json(200,{});
    }
    if (path==='/api/stamps' && req.method==='POST') {
      const {id}=await body(req);
      if (typeof id!=='string' || !/^[a-f0-9]{32}$/.test(id)) fail(400,'Некорректный идентификатор фигуры.');
      db.exec('BEGIN IMMEDIATE');
      try {
        if (run('INSERT OR IGNORE INTO stamps VALUES(?,?)',name,id).changes) run('UPDATE users SET coins=coins+1 WHERE name=?',name);
        db.exec('COMMIT');
      } catch (error) { db.exec('ROLLBACK'); throw error; }
      return json(200,profile(name));
    }
    if (path==='/api/rooms' && req.method==='POST') {
      const {game,variant}=await body(req);
      if (!['chess','nardy'].includes(game)) fail(400,'Неизвестная игра.');
      let code;
      do {code=randomBytes(4).toString('hex');} while(query('SELECT code FROM rooms WHERE code=?',code));
      const room={code,game,players:[name],turn:0,revision:0,dice:[],rolled:[],ending:null,log:[],repetition:[],
        position:game==='chess'?chess.setup(variant==='georgy'?'georgy':'standard'):nardySetup()};
      saveRoom(room);return json(201,roomView(room,name));
    }
    const match=path.match(/^\/api\/rooms\/([a-f0-9]{8})(?:\/(join|move))?$/);
    if (match) {
      const [,code,operation]=match;
      if (req.method==='GET' && !operation) return json(200,roomView(getRoom(code),name));
      if (req.method==='POST' && operation) {
        const data=await body(req);
        const room=getRoom(code);
        if (operation==='join') {
          if (data.game!==room.game) fail(400,'Код относится к другой игре.');
          if (!room.players.includes(name)) {
            if (room.players.length===2) fail(409,'Комната заполнена.');
            room.players.push(name);room.revision++;
          }
        } else { roomAction(room,name,data);room.revision++; }
        saveRoom(room);
        return json(200,roomView(room,name));
      }
    }
    fail(404,'Запрос не найден.');
  } catch (error) {
    if (!error.status) console.error(error);
    json(error.status??500,{error:error.status?error.message:'Ошибка сервера.'});
  }
};
const credentials=process.env.CREDENTIALS_DIRECTORY;
const server=credentials
  ? createHttpsServer({
      cert:readFileSync(resolve(credentials,'tls.crt')),
      key:readFileSync(resolve(credentials,'tls.key')),
      minVersion:'TLSv1.2',
    },handleRequest)
  : createServer(handleRequest);
server.listen(Number(process.env.PORT ?? 4185),process.env.CLUB_BIND ?? '127.0.0.1',()=>console.log('Club server listening'));
