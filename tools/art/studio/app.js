// 요괴 하숙집 Asset Studio — 브라우저 앱 (server.py 가 /api 와 /repo 를 준다)
// 네 탭: 서재(에셋 목록·규격/팔레트 검사·업로드), 스프라이트(시트 슬라이스·재생), 화면(실제 게임 수치로 배치·A/B 비교·시간대 색조),
// 매니페스트(art_assets.csv 편집·저장). 저장하면 서버가 CSV 를 쓰고 build_resources.py 를 돌려 게임이 다음 실행에 반영한다.

const VIEW_W = 640, VIEW_H = 360, CELL_W = 64, CELL_H = 48, GRID = 16;
const GROUND_SCREEN_Y = 225;   // 게임 카메라가 1층 바닥·구역 바닥을 놓는 화면 y (플레이스루 스크린샷 기준)
const HOUSE_X0 = 192;          // 4칸 집이 가운데 오는 x (640 - 4*64) / 2
const TIMEBANDS = { morning: 'light_color_morning', day: 'light_color_day', evening: 'light_color_evening', night: 'light_color_night' };

const state = {
  data: null, manifest: [], rows: new Map(), alt: new Map(), useB: false,
  tab: 'library', scale: 2, scene: 'house', camX: 0, band: 'day', showHud: true, showPanel: true,
  images: new Map(), selectedAsset: null, selectedSlot: null, sprite: { file: '', fw: 32, fh: 32, anims: 'idle:0-3:6', anim: 'idle', scale: 4 },
  t0: performance.now(),
};

const $ = (sel, root = document) => root.querySelector(sel);
const el = (tag, attrs = {}, children = []) => {
  const node = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (k === 'class') node.className = v; else if (k === 'text') node.textContent = v; else if (k.startsWith('on')) node.addEventListener(k.slice(2), v); else node.setAttribute(k, v);
  }
  for (const c of children) node.append(c);
  return node;
};
const status = (msg) => { $('#status').textContent = msg; };
const tuning = (key, fallback) => (state.data && state.data.tuning[key] !== undefined ? state.data.tuning[key] : fallback);
const color = (key, fallback) => '#' + tuning(key, fallback);

// ---------------------------------------------------------------- 데이터
async function load() {
  const res = await fetch('/api/state');
  state.data = await res.json();
  state.manifest = state.data.manifest.map(r => ({ ...r }));
  state.rows = new Map(state.manifest.map(r => [r.key, r]));
  for (const key of state.data.wanted_keys) if (!state.rows.has(key)) {
    const row = { key, track: key.startsWith('illust.') ? 'illust' : (key.startsWith('ui.') ? 'ui' : 'pixel'), file: '', frame_w: '0', frame_h: '0', anims: '', parallax: '1.0', repeat: 'false', note: '' };
    state.manifest.push(row); state.rows.set(key, row);
  }
  status(`에셋 ${state.data.assets.length}개 · 매니페스트 ${state.manifest.length}행 · 팔레트 ${state.data.palette.length}색`);
  render();
}

function image(path) {
  if (!path) return null;
  if (state.images.has(path)) return state.images.get(path);
  const img = new Image();
  img.src = '/repo/' + path.replace('res://', '');
  img.onload = () => draw();
  state.images.set(path, img);
  return img;
}

function rowFor(key) {
  const row = state.rows.get(key);
  if (state.useB && state.alt.has(key)) return { ...row, ...state.alt.get(key) };
  return row;
}

function parseAnims(spec) {
  const result = {};
  for (const part of String(spec || '').split(';')) {
    const p = part.trim().split(':');
    if (p.length < 2) continue;
    const [first, last] = p[1].split('-').map(Number);
    result[p[0]] = { first, last: isNaN(last) ? first : last, fps: p[2] ? Number(p[2]) : 6 };
  }
  return result;
}

// 시트에서 프레임 index 의 source rect
function frameRect(img, row, index) {
  const fw = Number(row.frame_w) || img.naturalWidth, fh = Number(row.frame_h) || img.naturalHeight;
  const cols = Math.max(1, Math.floor(img.naturalWidth / fw));
  return { sx: (index % cols) * fw, sy: Math.floor(index / cols) * fh, fw, fh };
}

function animFrame(row, anim, t) {
  const anims = parseAnims(row.anims);
  const a = anims[anim] || anims.idle;
  if (!a) return 0;
  const count = a.last - a.first + 1;
  return a.first + (Math.floor(t * a.fps) % count);
}

// 발이 (x, y) 에 오도록 그린다. 그림이 없으면 자리표시 사각.
function drawKey(ctx, key, x, y, opts = {}) {
  const row = rowFor(key);
  const img = row && row.file ? image(row.file) : null;
  const t = (performance.now() - state.t0) / 1000;
  if (!img || !img.complete || !img.naturalWidth) {
    const size = opts.size || 32;
    ctx.fillStyle = opts.placeholder || '#7a5c8f';
    ctx.fillRect(Math.round(x - size * 0.4), Math.round(y - size), Math.round(size * 0.8), size);
    ctx.fillStyle = '#ede6dc'; ctx.font = '8px monospace'; ctx.textAlign = 'center';
    ctx.fillText(key.split('.').pop().slice(0, 6), Math.round(x), Math.round(y - size * 0.4));
    return;
  }
  const { sx, sy, fw, fh } = frameRect(img, row, opts.frame !== undefined ? opts.frame : animFrame(row, opts.anim || 'idle', t));
  ctx.save();
  ctx.imageSmoothingEnabled = false;
  if (opts.flip) { ctx.translate(Math.round(x), 0); ctx.scale(-1, 1); ctx.translate(-Math.round(x), 0); }
  ctx.drawImage(img, sx, sy, fw, fh, Math.round(x - fw / 2), Math.round(y - fh), fw, fh);
  ctx.restore();
}

// ---------------------------------------------------------------- 검사 (격자·팔레트)
function checkAsset(asset) {
  const badges = [];
  const grid = asset.w % GRID === 0 && asset.h % GRID === 0;
  badges.push({ ok: grid, text: grid ? '16px 격자' : `격자 아님 ${asset.w}×${asset.h}` });
  if (asset.path.includes('/illust/')) badges.push({ ok: asset.w === 1024 && asset.h === 1024, text: '일러스트 1024' });
  return badges;
}

function paletteCheck(asset, callback) {
  const img = image(asset.path);
  const run = () => {
    if (asset.w * asset.h > 512 * 512) return callback(null);
    const c = document.createElement('canvas'); c.width = asset.w; c.height = asset.h;
    const g = c.getContext('2d'); g.drawImage(img, 0, 0);
    const px = g.getImageData(0, 0, asset.w, asset.h).data;
    const pal = new Set(state.data.palette.map(h => h.toLowerCase()));
    const off = new Set();
    for (let i = 0; i < px.length; i += 4) {
      if (px[i + 3] < 1) continue;
      const hex = [px[i], px[i + 1], px[i + 2]].map(v => v.toString(16).padStart(2, '0')).join('');
      if (!pal.has(hex)) off.add(hex);
    }
    callback(off);
  };
  if (img.complete && img.naturalWidth) run(); else img.addEventListener('load', run, { once: true });
}

// ---------------------------------------------------------------- 탭 렌더
function render() {
  const side = $('#side'), view = $('#view');
  side.innerHTML = ''; view.innerHTML = '';
  ({ library: renderLibrary, sprite: renderSprite, composer: renderComposer, manifest: renderManifest })[state.tab](side, view);
}

function renderLibrary(side, view) {
  side.append(el('h2', { text: '업로드 (라이선스 기록 필수)' }));
  const file = el('input', { type: 'file', accept: 'image/png' });
  const folder = el('select', {}, [el('option', { value: 'pixel', text: 'assets/art/pixel (16px 격자)' }), el('option', { value: 'illust', text: 'assets/art/illust (1024)' })]);
  const source = el('input', { type: 'text', placeholder: '출처 (팩 이름·URL·생성 툴)' });
  const license = el('input', { type: 'text', placeholder: '라이선스 (CC0 / 상업 이용 허용 / 구매 약관…)' });
  const ai = el('input', { type: 'checkbox' });
  const note = el('input', { type: 'text', placeholder: '비고' });
  const btn = el('button', { class: 'primary', text: '업로드', onclick: async () => {
    const f = file.files[0]; if (!f) return status('파일을 고르세요');
    if (!/^[a-z0-9_]+\.png$/.test(f.name)) return status('파일명은 소문자 snake_case .png');
    const data = await new Promise(r => { const fr = new FileReader(); fr.onload = () => r(fr.result.split(',')[1]); fr.readAsDataURL(f); });
    const res = await fetch('/api/upload', { method: 'POST', body: JSON.stringify({ name: f.name, folder: folder.value, data, source: source.value, license: license.value, ai: ai.checked, note: note.value, kind: folder.value === 'illust' ? '일러스트' : '픽셀' }) });
    const out = await res.json();
    status(out.error ? out.error : `업로드 ${out.path}`);
    if (!out.error) await load();
  } });
  side.append(file, label('폴더'), folder, label('출처'), source, label('라이선스'), license, el('label', {}, [ai, ' AI 생성 (스토어 공개 표기)']), label('비고'), note, el('div', { class: 'row' }, [btn]));
  side.append(el('h2', { text: '필터' }));
  const filter = el('input', { type: 'text', placeholder: '이름·경로 검색', oninput: () => drawGrid(filter.value) });
  side.append(filter);

  const grid = el('div', { class: 'grid' });
  view.append(el('h2', { text: '에셋 서재 — 클릭하면 스프라이트 탭·화면 슬롯에 쓴다' }), grid);
  function drawGrid(q) {
    grid.innerHTML = '';
    for (const asset of state.data.assets) {
      if (q && !asset.path.includes(q)) continue;
      const card = el('div', { class: 'thumb' + (state.selectedAsset === asset.path ? ' selected' : '') });
      card.append(el('img', { src: '/repo/' + asset.path.replace('res://', ''), alt: asset.name }));
      card.append(el('div', { class: 'name', text: asset.name }));
      card.append(el('div', { class: 'meta', text: `${asset.w}×${asset.h}` }));
      for (const b of checkAsset(asset)) card.append(el('span', { class: 'badge ' + (b.ok ? 'ok' : 'bad'), text: b.text }));
      const palBadge = el('span', { class: 'badge dim', text: '팔레트…' }); card.append(palBadge);
      paletteCheck(asset, off => { if (off === null) { palBadge.textContent = '팔레트 검사 생략'; return; } palBadge.className = 'badge ' + (off.size ? 'bad' : 'ok'); palBadge.textContent = off.size ? `팔레트 밖 ${off.size}색` : '팔레트 OK'; });
      card.onclick = () => { state.selectedAsset = asset.path; state.sprite.file = asset.path; if (state.selectedSlot) assignSlot(state.selectedSlot, asset.path); drawGrid(q); status(`선택: ${asset.path}`); };
      grid.append(card);
    }
  }
  drawGrid('');
}

const label = (text) => el('label', { text });

function renderSprite(side, view) {
  const s = state.sprite;
  side.append(el('h2', { text: '시트 규격' }));
  const fileSel = el('select', {}, [el('option', { value: '', text: '(서재에서 고르기)' }), ...state.data.assets.map(a => el('option', { value: a.path, text: a.name }))]);
  fileSel.value = s.file;
  fileSel.onchange = () => { s.file = fileSel.value; draw(); };
  const fw = el('input', { type: 'number', value: s.fw, oninput: () => { s.fw = Number(fw.value) || 0; draw(); } });
  const fh = el('input', { type: 'number', value: s.fh, oninput: () => { s.fh = Number(fh.value) || 0; draw(); } });
  const anims = el('input', { type: 'text', value: s.anims, oninput: () => { s.anims = anims.value; draw(); } });
  const anim = el('input', { type: 'text', value: s.anim, oninput: () => { s.anim = anim.value; } });
  const scale = el('select', {}, [1, 2, 3, 4, 6].map(v => el('option', { value: v, text: `×${v}` })));
  scale.value = s.scale; scale.onchange = () => { s.scale = Number(scale.value); draw(); };
  side.append(label('파일'), fileSel, label('프레임 폭 (0 = 전체)'), fw, label('프레임 높이'), fh, label('애니메이션 구간 name:first-last:fps;…'), anims, label('재생할 구간'), anim, label('배율'), scale);
  side.append(el('h2', { text: '매니페스트 키에 적용' }));
  const keySel = el('select', {}, state.manifest.map(r => el('option', { value: r.key, text: r.key })));
  const applyBtn = el('button', { class: 'ghost', text: '이 규격을 키에 적용', onclick: () => { const row = state.rows.get(keySel.value); Object.assign(row, { file: s.file, frame_w: String(s.fw), frame_h: String(s.fh), anims: s.anims }); status(`${row.key} ← ${s.file} (${s.fw}×${s.fh}, ${s.anims})`); } });
  const loadBtn = el('button', { class: 'ghost', text: '키의 규격 불러오기', onclick: () => { const row = state.rows.get(keySel.value); s.file = row.file; s.fw = Number(row.frame_w) || 0; s.fh = Number(row.frame_h) || 0; s.anims = row.anims; render(); } });
  side.append(keySel, el('div', { class: 'row' }, [loadBtn, applyBtn]));
  side.append(el('p', { class: 'dim', text: '프레임 표준: idle 4 / walk 6 / work 4 / 감정 2×2 (docs/02). 시트는 왼쪽 위부터 가로로 센다.' }));
  const canvas = el('canvas', { class: 'stage', width: 640, height: 360 });
  view.append(el('h2', { text: '시트 (프레임 격자) · 재생 미리보기' }), canvas);
  state.canvas = canvas;
  draw();
}

function drawSprite(ctx) {
  const s = state.sprite;
  ctx.fillStyle = '#1e2a3a'; ctx.fillRect(0, 0, VIEW_W, VIEW_H);
  const img = s.file ? image(s.file) : null;
  if (!img || !img.complete || !img.naturalWidth) { ctx.fillStyle = '#b3adb5'; ctx.fillText('파일을 고르세요', 20, 30); return; }
  const fw = s.fw || img.naturalWidth, fh = s.fh || img.naturalHeight;
  const cols = Math.max(1, Math.floor(img.naturalWidth / fw)), rows = Math.max(1, Math.floor(img.naturalHeight / fh));
  ctx.imageSmoothingEnabled = false;
  const sheetScale = Math.max(1, Math.min(3, Math.floor(400 / img.naturalWidth)));
  ctx.drawImage(img, 10, 10, img.naturalWidth * sheetScale, img.naturalHeight * sheetScale);
  ctx.strokeStyle = 'rgba(242,166,90,.8)'; ctx.font = '9px monospace'; ctx.fillStyle = '#f2a65a';
  for (let r = 0; r < rows; r++) for (let c = 0; c < cols; c++) {
    ctx.strokeRect(10 + c * fw * sheetScale + 0.5, 10 + r * fh * sheetScale + 0.5, fw * sheetScale, fh * sheetScale);
    ctx.fillText(String(r * cols + c), 12 + c * fw * sheetScale, 19 + r * fh * sheetScale);
  }
  const row = { file: s.file, frame_w: String(s.fw), frame_h: String(s.fh), anims: s.anims };
  const t = (performance.now() - state.t0) / 1000;
  const idx = animFrame(row, s.anim, t);
  const { sx, sy } = frameRect(img, row, idx);
  const px = 470, py = 60;
  ctx.fillStyle = '#2e2733'; ctx.fillRect(px - 10, py - 10, fw * s.scale + 20, fh * s.scale + 30);
  ctx.drawImage(img, sx, sy, fw, fh, px, py, fw * s.scale, fh * s.scale);
  ctx.fillStyle = '#ede6dc'; ctx.font = '11px monospace';
  ctx.fillText(`${s.anim} #${idx}  ${fw}×${fh} ×${s.scale}`, px - 6, py + fh * s.scale + 14);
  // 발 위치 기준선 (게임은 발이 원점)
  ctx.strokeStyle = '#7fb2a6'; ctx.beginPath(); ctx.moveTo(px - 10, py + fh * s.scale + 0.5); ctx.lineTo(px + fw * s.scale + 10, py + fh * s.scale + 0.5); ctx.stroke();
}

// ---------------------------------------------------------------- 화면 컴포저
function sceneSlots() {
  const d = state.data;
  if (state.scene === 'house') {
    const layout = String(tuning('start_layout_floor0', 'gate,guest_room,kitchen,empty_lot')).replace(/"/g, '').split(',').map(s => s.trim());
    const slots = layout.map(id => `room.${id}`);
    for (const y of d.csv.yokai.filter(y => y.join_mode === 'start' && y.in_slice === 'true')) slots.push(`char.${y.id}`);
    slots.push('char.player', 'ui.panel', 'ui.chip', 'ui.button');
    return [...new Set(slots)];
  }
  const region = d.csv.regions.find(r => r.id === state.scene);
  if (!region) return [];
  const slots = [`region.${region.id}.sky`, `region.${region.id}.far`, `region.${region.id}.ground`, 'prop.door', 'char.player', 'ui.panel', 'ui.chip'];
  if (Number(region.gather_point_count) > 0) slots.push('prop.gather_point');
  if (region.kind === 'yard') slots.push('prop.farm_plot');
  if (Number(region.fishing_x) > 0) slots.push('prop.water');
  for (const npc of String(region.npcs || '').split(';').filter(Boolean)) slots.push(`npc.${npc.split(':')[0]}`);
  for (const e of String(region.enemy_pool || '').split(';').filter(Boolean)) slots.push(`enemy.${e}`);
  if (region.boss_id) slots.push(`enemy.${region.boss_id}`);
  if (region.kind === 'expedition') for (const y of d.csv.yokai.filter(y => y.join_mode === 'start')) slots.push(`char.${y.id}`);
  return [...new Set(slots)];
}

function assignSlot(key, path) {
  const row = state.rows.get(key);
  if (state.useB) state.alt.set(key, { ...(state.alt.get(key) || {}), file: path });
  else row.file = path;
  draw();
}

function renderComposer(side, view) {
  side.append(el('h2', { text: '장면' }));
  const scenes = [['house', '하숙집 단면'], ...state.data.csv.regions.filter(r => r.kind !== 'house').map(r => [r.id, r.name_ko])];
  const sceneSel = el('select', {}, scenes.map(([v, t]) => el('option', { value: v, text: t })));
  sceneSel.value = state.scene; sceneSel.onchange = () => { state.scene = sceneSel.value; state.camX = 0; state.selectedSlot = null; render(); };
  const bandSel = el('select', {}, Object.keys(TIMEBANDS).map(b => el('option', { value: b, text: { morning: '아침', day: '낮', evening: '저녁', night: '밤' }[b] })));
  bandSel.value = state.band; bandSel.onchange = () => { state.band = bandSel.value; draw(); };
  const hud = el('input', { type: 'checkbox', checked: state.showHud ? 'checked' : null, onchange: () => { state.showHud = hud.checked; draw(); } });
  const panel = el('input', { type: 'checkbox', checked: state.showPanel ? 'checked' : null, onchange: () => { state.showPanel = panel.checked; draw(); } });
  const scaleSel = el('select', {}, [1, 2, 3].map(v => el('option', { value: v, text: `창 ×${v}` })));
  scaleSel.value = state.scale; scaleSel.onchange = () => { state.scale = Number(scaleSel.value); render(); };
  const cam = el('input', { type: 'range', min: 0, max: 1000, value: state.camX, oninput: () => { state.camX = Number(cam.value); draw(); } });
  side.append(sceneSel, label('시간대 색조'), bandSel, el('label', {}, [hud, ' HUD 겹쳐 보기']), el('label', {}, [panel, ' 아침 배치 패널 (하숙집)']), label('배율'), scaleSel, label('카메라 x'), cam);

  side.append(el('h2', { text: 'A/B 비교' }));
  const abBtn = el('button', { class: 'ghost', text: state.useB ? 'B 후보 보는 중 → A' : 'A(저장본) 보는 중 → B', onclick: () => { state.useB = !state.useB; render(); } });
  side.append(el('div', { class: 'row' }, [abBtn, el('span', { class: 'dim', text: `B 후보 ${state.alt.size}개 · 키 ${''}` })]));
  side.append(el('p', { class: 'dim', text: '슬롯을 고른 뒤 서재에서 에셋을 클릭하면 그 슬롯에 들어간다. B 모드에서 넣으면 B 후보. "B 를 A 로" 로 확정.' }));
  side.append(el('button', { class: 'ghost', text: 'B 후보를 전부 A 로 확정', onclick: () => { for (const [k, v] of state.alt) Object.assign(state.rows.get(k), v); state.alt.clear(); state.useB = false; render(); } }));

  side.append(el('h2', { text: '이 장면의 슬롯' }));
  const slots = el('div', { class: 'slots' });
  for (const key of sceneSlots()) {
    const row = rowFor(key) || {};
    const item = el('div', { class: 'slot' + (state.selectedSlot === key ? ' selected' : '') }, [
      el('span', { class: 'key', text: key }), el('span', { class: 'file', text: row.file ? row.file.split('/').pop() : '(없음)' }),
      el('span', { class: 'ab', text: state.alt.has(key) ? 'B' : '' }),
    ]);
    item.onclick = () => { state.selectedSlot = key; status(`슬롯 ${key} — 서재에서 에셋을 클릭`); render(); };
    slots.append(item);
  }
  side.append(slots);
  if (state.selectedSlot) {
    const row = rowFor(state.selectedSlot) || {};
    side.append(el('h2', { text: `${state.selectedSlot} 규격` }));
    const pick = el('select', {}, [el('option', { value: '', text: '(없음)' }), ...state.data.assets.map(a => el('option', { value: a.path, text: a.name }))]);
    pick.value = row.file || ''; pick.onchange = () => assignSlot(state.selectedSlot, pick.value);
    side.append(pick);
    side.append(el('button', { class: 'ghost', text: '스프라이트 탭에서 규격 편집', onclick: () => { const r = state.rows.get(state.selectedSlot); state.sprite.file = r.file; state.sprite.fw = Number(r.frame_w) || 0; state.sprite.fh = Number(r.frame_h) || 0; state.sprite.anims = r.anims; state.tab = 'sprite'; setTab(); } }));
  }
  const canvas = el('canvas', { class: 'stage', width: VIEW_W * state.scale, height: VIEW_H * state.scale });
  view.append(el('h2', { text: `화면 640×360 (게임 수치: 방 64×48 · 16px 격자 · 바닥 y=${GROUND_SCREEN_Y})` }), canvas);
  state.canvas = canvas;
  draw();
}

function drawComposer(ctx) {
  const d = state.data;
  if (state.scene === 'house') drawHouse(ctx); else drawRegion(ctx, d.csv.regions.find(r => r.id === state.scene));
  if (state.showHud) drawHud(ctx);
  // 시간대 색조 (게임의 CanvasModulate 근사 — 곱하기)
  const tint = color(TIMEBANDS[state.band], 'ffffff');
  if (tint.toLowerCase() !== '#ffffff') { ctx.save(); ctx.globalCompositeOperation = 'multiply'; ctx.fillStyle = tint; ctx.fillRect(0, 0, VIEW_W, VIEW_H); ctx.restore(); }
}

function drawHouse(ctx) {
  ctx.fillStyle = '#' + (state.data.csv.regions.find(r => r.id === 'r_house') || { sky_color: '2b3f55' }).sky_color; ctx.fillRect(0, 0, VIEW_W, VIEW_H);
  const cols = Number(tuning('grid_columns', 4)), floors = Number(tuning('grid_floors', 3));
  const layout = String(tuning('start_layout_floor0', 'gate,guest_room,kitchen,empty_lot')).replace(/"/g, '').split(',').map(s => s.trim());
  for (let f = 0; f < floors; f++) for (let c = 0; c < cols; c++) {
    const x = HOUSE_X0 + c * CELL_W, y = GROUND_SCREEN_Y - (f + 1) * CELL_H;
    if (f === 0) {
      const key = `room.${layout[c]}`, row = rowFor(key), img = row && row.file ? image(row.file) : null;
      if (img && img.complete && img.naturalWidth) { ctx.imageSmoothingEnabled = false; ctx.drawImage(img, x, y, CELL_W, CELL_H); }
      else { ctx.fillStyle = '#5c4033'; ctx.fillRect(x, y, CELL_W, CELL_H); }
    } else { ctx.setLineDash([4, 4]); ctx.strokeStyle = 'rgba(255,255,255,.35)'; ctx.strokeRect(x + 0.5, y + 0.5, CELL_W - 1, CELL_H - 1); ctx.setLineDash([]); }
  }
  ctx.strokeStyle = 'rgba(255,255,255,.35)'; ctx.beginPath(); ctx.moveTo(HOUSE_X0, GROUND_SCREEN_Y - floors * CELL_H + 0.5); ctx.lineTo(HOUSE_X0 + cols * CELL_W, GROUND_SCREEN_Y - floors * CELL_H + 0.5); ctx.stroke();
  // 하숙생: 휴식처(첫 객실) 앞, 슬롯 간격 tuning
  const spacing = Number(tuning('yokai_slot_spacing_px', 16));
  const restCol = Math.max(0, layout.indexOf('guest_room'));
  const residents = state.data.csv.yokai.filter(y => y.join_mode === 'start' && y.in_slice === 'true');
  residents.forEach((y, i) => drawKey(ctx, `char.${y.id}`, HOUSE_X0 + restCol * CELL_W + CELL_W / 2 + (i - 1) * spacing, GROUND_SCREEN_Y, { anim: 'idle' }));
  drawKey(ctx, 'char.player', HOUSE_X0 + Number(tuning('player_start_x', 32)), GROUND_SCREEN_Y, { anim: 'idle', placeholder: '#e8734a' });
}

function groundProfile(region) {
  const segs = String(region.ground || '0:480:0').split(';').map(s => s.split(':').map(Number));
  const ramp = Number(tuning('ramp_width_px', 32));
  const pts = [];
  for (const [x0, x1, y] of segs) { pts.push([x0, y]); pts.push([x1, y]); }
  // 게임과 같이 단차는 경사로(ramp)로 잇는다: 인접 세그먼트 경계에서 ramp 폭만큼
  const profile = [pts[0]];
  for (let i = 1; i < pts.length; i++) {
    const [px, py] = profile[profile.length - 1], [x, y] = pts[i];
    if (x === px && y !== py) { profile[profile.length - 1] = [px - ramp / 2, py]; profile.push([x + ramp / 2, y]); }
    else profile.push([x, y]);
  }
  return profile;
}
const yAt = (profile, x) => { for (let i = 1; i < profile.length; i++) { const [ax, ay] = profile[i - 1], [bx, by] = profile[i]; if (x >= ax && x <= bx) return bx === ax ? ay : ay + (by - ay) * (x - ax) / (bx - ax); } return profile[profile.length - 1][1]; };

function drawRegion(ctx, region) {
  if (!region) return;
  const width = Number(region.width_px) || VIEW_W;
  const cam = Math.min(state.camX, Math.max(0, width - VIEW_W));
  const X = (x) => Math.round(x - cam), Y = (yOff) => GROUND_SCREEN_Y + yOff;
  ctx.fillStyle = '#' + (region.sky_color || '8fb0b8'); ctx.fillRect(0, 0, VIEW_W, VIEW_H);
  const sky = rowFor(`region.${region.id}.sky`), skyImg = sky && sky.file ? image(sky.file) : null;
  if (skyImg && skyImg.complete && skyImg.naturalWidth) { ctx.imageSmoothingEnabled = false; ctx.drawImage(skyImg, 0, 0, VIEW_W, VIEW_H); }
  const profile = groundProfile(region);
  const far = rowFor(`region.${region.id}.far`), farImg = far && far.file ? image(far.file) : null;
  if (farImg && farImg.complete && farImg.naturalWidth) {
    const top = Y(Math.min(...profile.map(p => p[1]))) - farImg.naturalHeight;
    for (let x = -cam * Number(far.parallax || 0.3) % farImg.naturalWidth - farImg.naturalWidth; x < VIEW_W; x += farImg.naturalWidth) ctx.drawImage(farImg, Math.round(x), top);
  }
  const demon = region.realm === 'demon';
  ctx.fillStyle = color(demon ? 'region_demon_dirt_color' : 'region_dirt_color', '5c4033');
  ctx.beginPath(); ctx.moveTo(X(profile[0][0]) - 200, Y(profile[0][1]));
  for (const [x, y] of profile) ctx.lineTo(X(x), Y(y));
  ctx.lineTo(X(profile[profile.length - 1][0]) + 200, Y(profile[profile.length - 1][1])); ctx.lineTo(VIEW_W + 200, VIEW_H); ctx.lineTo(-200, VIEW_H); ctx.closePath(); ctx.fill();
  ctx.strokeStyle = color(demon ? 'region_demon_ground_color' : 'region_ground_color', '6b8e5a'); ctx.lineWidth = 4; ctx.beginPath();
  ctx.moveTo(X(profile[0][0]) - 200, Y(profile[0][1])); for (const [x, y] of profile) ctx.lineTo(X(x), Y(y)); ctx.lineTo(X(profile[profile.length - 1][0]) + 200, Y(profile[profile.length - 1][1])); ctx.stroke(); ctx.lineWidth = 1;
  const ground = rowFor(`region.${region.id}.ground`), gImg = ground && ground.file ? image(ground.file) : null;
  if (gImg && gImg.complete && gImg.naturalWidth) for (let i = 1; i < profile.length; i++) { const [ax, ay] = profile[i - 1], [bx, by] = profile[i]; if (ay !== by) continue; for (let x = ax; x + gImg.naturalWidth <= bx + 0.5; x += gImg.naturalWidth) ctx.drawImage(gImg, X(x), Y(ay) - gImg.naturalHeight / 2); }
  // 문
  for (const door of String(region.doors || '').split(';').filter(Boolean)) {
    const x = Number(door.split(':')[1]);
    if (rowFor('prop.door') && rowFor('prop.door').file) drawKey(ctx, 'prop.door', X(x), Y(yAt(profile, x)), { frame: 0 });
    else { ctx.fillStyle = color('door_color', 'd9b384'); ctx.fillRect(X(x) - 8, Y(yAt(profile, x)) - 24, 16, 24); }
  }
  // 채집 포인트
  const count = Number(region.gather_point_count || 0);
  if (count > 0 && region.gather_span) { const [s0, s1] = region.gather_span.split(':').map(Number); for (let i = 0; i < count; i++) { const x = s0 + (s1 - s0) * (i + 0.5) / count; if (rowFor('prop.gather_point').file) drawKey(ctx, 'prop.gather_point', X(x), Y(yAt(profile, x)), { frame: 0, size: 12 }); else { ctx.fillStyle = '#9bb572'; ctx.beginPath(); ctx.arc(X(x), Y(yAt(profile, x)) - 6, 6, 0, Math.PI * 2); ctx.fill(); } } }
  // 텃밭
  if (region.kind === 'yard') { const n = Number(tuning('farm_plots_initial', 6)), w = Number(tuning('farm_plot_width_px', 16)); for (let i = 0; i < n; i++) { const x = Number(region.farm_x) + i * w; if (rowFor('prop.farm_plot').file) drawKey(ctx, 'prop.farm_plot', X(x) + w / 2, Y(0), { frame: i % 4, size: 16 }); else { ctx.fillStyle = color('farm_plot_color_empty', '8c6247'); ctx.fillRect(X(x), Y(0) - 6, w, 6); ctx.strokeStyle = '#1a1620'; ctx.strokeRect(X(x) + 0.5, Y(0) - 5.5, w - 1, 5); } } }
  // 낚시 자리
  if (Number(region.fishing_x) > 0) { const x = Number(region.fishing_x); if (rowFor('prop.water').file) drawKey(ctx, 'prop.water', X(x), Y(yAt(profile, x)), { frame: 0 }); else { ctx.fillStyle = color('region_water_color', '5f8090'); ctx.fillRect(X(x) - 20, Y(yAt(profile, x)) - 3, 40, 6); } }
  // NPC
  for (const npc of String(region.npcs || '').split(';').filter(Boolean)) { const [id, , x] = npc.split(':'); drawKey(ctx, `npc.${id}`, X(Number(x)), Y(yAt(profile, Number(x))), { placeholder: color('merchant_color', 'd4a5c4') }); }
  // 적 (탐험지): enemy_count 마리를 구역 35~85% 사이에
  const enemies = String(region.enemy_pool || '').split(';').filter(Boolean);
  const enemyCount = Number(region.enemy_count || 0);
  for (let i = 0; i < enemyCount && enemies.length; i++) { const x = width * (0.35 + 0.5 * i / Math.max(1, enemyCount - 1)); drawKey(ctx, `enemy.${enemies[i % enemies.length]}`, X(x), Y(yAt(profile, x)), { flip: true, placeholder: '#7a5c8f', size: 32 }); }
  if (region.boss_id) { const x = width * Number(tuning('boss_spawn_x', 0.85)); drawKey(ctx, `enemy.${region.boss_id}`, X(x), Y(yAt(profile, x)), { flip: true, placeholder: '#a883b0', size: 32 }); }
  // 플레이어 + 동료
  const px = 96; drawKey(ctx, 'char.player', X(px), Y(yAt(profile, px)), { anim: 'walk', placeholder: '#e8734a' });
  if (region.kind === 'expedition') state.data.csv.yokai.filter(y => y.join_mode === 'start').forEach((y, i) => drawKey(ctx, `char.${y.id}`, X(px - 24 * (i + 1)), Y(yAt(profile, px - 24 * (i + 1))), { anim: 'walk' }));
}

// 9-patch 또는 색 상자
function panelRect(ctx, key, x, y, w, h, fallback) {
  const row = rowFor(key), img = row && row.file ? image(row.file) : null;
  if (img && img.complete && img.naturalWidth) {
    const mx = Math.floor(img.naturalWidth / 3), my = Math.floor(img.naturalHeight / 3); const W = img.naturalWidth, H = img.naturalHeight;
    const parts = [[0, 0, mx, my, x, y, mx, my], [mx, 0, W - 2 * mx, my, x + mx, y, w - 2 * mx, my], [W - mx, 0, mx, my, x + w - mx, y, mx, my],
      [0, my, mx, H - 2 * my, x, y + my, mx, h - 2 * my], [mx, my, W - 2 * mx, H - 2 * my, x + mx, y + my, w - 2 * mx, h - 2 * my], [W - mx, my, mx, H - 2 * my, x + w - mx, y + my, mx, h - 2 * my],
      [0, H - my, mx, my, x, y + h - my, mx, my], [mx, H - my, W - 2 * mx, my, x + mx, y + h - my, w - 2 * mx, my], [W - mx, H - my, mx, my, x + w - mx, y + h - my, mx, my]];
    ctx.imageSmoothingEnabled = false; for (const p of parts) ctx.drawImage(img, ...p); return;
  }
  ctx.fillStyle = fallback; ctx.fillRect(x, y, w, h); ctx.strokeStyle = color('ui_panel_border_color', '7a7180'); ctx.strokeRect(x + 0.5, y + 0.5, w - 1, h - 1);
}

function drawHud(ctx) {
  const pad = Number(tuning('ui_panel_padding_px', 6)), fs = Number(tuning('ui_font_size', 13)), hfs = Number(tuning('ui_header_font_size', 15));
  const panelColor = color('ui_panel_color', '2e2733'), chipColor = color('ui_chip_color', '1a1620'), accent = color('ui_accent_color', 'f2a65a');
  const regionName = state.scene === 'house' ? '하숙집' : (state.data.csv.regions.find(r => r.id === state.scene) || {}).name_ko;
  // 시계 카드
  panelRect(ctx, 'ui.panel', 4, 4, 178, 62, panelColor);
  ctx.fillStyle = accent; ctx.font = `600 ${hfs}px system-ui`; ctx.textAlign = 'left'; ctx.fillText('09:01 낮 · 봄 2일', 4 + pad, 4 + pad + hfs - 2);
  ctx.fillStyle = '#b3adb5'; ctx.font = `${fs}px system-ui`; ctx.fillText(`맑음 · 음기 ●○○ · ${regionName}`, 4 + pad, 4 + pad + hfs + fs + 2);
  ctx.fillStyle = chipColor; ctx.fillRect(4 + pad, 58, 166, 3); ctx.fillStyle = accent; ctx.fillRect(4 + pad, 58, 60, 3);
  // 칩 줄
  const chips = ['할 일 1/5', '돈 8750', '평판 33', '침대 3/4']; let cx = VIEW_W - 4;
  ctx.font = `${fs}px system-ui`;
  for (const text of chips.reverse()) { const w = ctx.measureText(text).width + pad * 2; cx -= w + 4; panelRect(ctx, 'ui.chip', cx, 6, w, fs + pad + 2, chipColor); ctx.fillStyle = '#ede6dc'; ctx.fillText(text, cx + pad, 6 + fs + 1); }
  // 버튼
  const buttons = ['메뉴  [Tab]', '취침  [Z]']; let bx = VIEW_W - 4;
  for (const text of buttons) { const w = ctx.measureText(text).width + pad * 2; bx -= w + 4; panelRect(ctx, 'ui.button', bx, 34, w, fs + pad + 4, color('ui_button_color', '4a4352')); ctx.fillStyle = '#ede6dc'; ctx.fillText(text, bx + pad, 34 + fs + 2); }
  // 안내 줄
  const guide = '성주 영감: 낮에는 배치된 요괴가 일합니다. 저녁(17:00)이 되면 정산하고 손님이 옵니다.';
  const gw = Math.min(VIEW_W * 0.6, ctx.measureText(guide).width + pad * 2);
  panelRect(ctx, 'ui.panel', (VIEW_W - gw) / 2, 74, gw, fs * 2 + pad * 2 + 4, panelColor);
  ctx.fillStyle = '#ede6dc'; wrapText(ctx, guide, (VIEW_W - gw) / 2 + pad, 74 + pad + fs, gw - pad * 2, fs + 2);
  // 체력 바 · 프롬프트
  panelRect(ctx, 'ui.chip', 4, VIEW_H - (state.showPanel && state.scene === 'house' ? 148 : 30), 156, 22, chipColor);
  ctx.fillStyle = '#b3adb5'; ctx.fillText('체력', 10, VIEW_H - (state.showPanel && state.scene === 'house' ? 148 : 30) + 15);
  ctx.fillStyle = chipColor; ctx.fillRect(44, VIEW_H - (state.showPanel && state.scene === 'house' ? 148 : 30) + 8, 110, 6); ctx.fillStyle = color('drop_ok_color', '7fb2a6'); ctx.fillRect(44, VIEW_H - (state.showPanel && state.scene === 'house' ? 148 : 30) + 8, 80, 6);
  const prompt = 'E: 마당(으)로'; const pw = ctx.measureText(prompt).width + pad * 2;
  panelRect(ctx, 'ui.chip', VIEW_W - 4 - pw, VIEW_H - (state.showPanel && state.scene === 'house' ? 148 : 30), pw, 22, chipColor); ctx.fillStyle = accent; ctx.fillText(prompt, VIEW_W - 4 - pw + pad, VIEW_H - (state.showPanel && state.scene === 'house' ? 148 : 30) + 15);
  // 아침 배치 패널 (하숙집)
  if (state.showPanel && state.scene === 'house') {
    const top = VIEW_H - 122;
    panelRect(ctx, 'ui.panel', 0, top, VIEW_W, 122, panelColor);
    ctx.fillStyle = accent; ctx.font = `600 ${hfs}px system-ui`; ctx.fillText('아침 배치 — 카드를 방으로 끌어 놓으세요', pad, top + pad + hfs - 2);
    const residents = state.data.csv.yokai.filter(y => y.join_mode === 'start' && y.in_slice === 'true');
    residents.forEach((y, i) => { const x = pad + i * 150; panelRect(ctx, 'ui.chip', x, top + 30, 142, 46, chipColor); drawKey(ctx, `char.${y.id}`, x + 22, top + 30 + 42, { frame: 0 }); ctx.fillStyle = '#ede6dc'; ctx.font = `${fs}px system-ui`; ctx.fillText(y.name_ko, x + 46, top + 30 + 18); ctx.fillStyle = '#b3adb5'; ctx.fillText('휴식 · 컨디션 100', x + 46, top + 30 + 36); });
    ctx.fillStyle = '#b3adb5'; ctx.font = `${fs}px system-ui`; ctx.textAlign = 'center';
    ['휴식 (여기에 놓기)', '텃밭 (여기에 놓기)', '동행 (여기에 놓기)'].forEach((t, i) => ctx.fillText(t, VIEW_W / 6 + i * VIEW_W / 3, top + 96));
    ['채집 (여기에 놓기)', '낚시 (여기에 놓기)', '판매 (여기에 놓기)'].forEach((t, i) => ctx.fillText(t, VIEW_W / 6 + i * VIEW_W / 3, top + 114));
    ctx.textAlign = 'left';
  }
}

function wrapText(ctx, text, x, y, maxWidth, lineHeight) {
  const words = text.split(' '); let line = '';
  for (const w of words) { const test = line ? line + ' ' + w : w; if (ctx.measureText(test).width > maxWidth && line) { ctx.fillText(line, x, y); line = w; y += lineHeight; } else line = test; }
  ctx.fillText(line, x, y);
}

// ---------------------------------------------------------------- 매니페스트 표
function renderManifest(side, view) {
  side.append(el('h2', { text: '매니페스트 (data/csv/art_assets.csv)' }));
  side.append(el('p', { class: 'dim', text: '키 규칙: char.<하숙생> / guest.<종족> / enemy.<적> / npc.<가택신·NPC> / room.<방> / illust.<id> / region.<구역>.sky|far|ground / prop.* / ui.*. 파일이 비면 자리표시·코드 그림.' }));
  const filter = el('input', { type: 'text', placeholder: '키 검색', oninput: () => table(filter.value) });
  side.append(filter);
  side.append(el('button', { class: 'ghost', text: '다시 불러오기 (저장 안 한 변경 버림)', onclick: load }));
  const log = el('pre', { class: 'log', id: 'log', text: '' });
  side.append(el('h2', { text: '서버 로그' }), log);
  const box = el('div');
  view.append(el('h2', { text: '행 편집 — 저장하면 서버가 빌드까지 돌린다' }), box);
  function table(q) {
    box.innerHTML = '';
    const t = el('table', { class: 'manifest' });
    t.append(el('tr', {}, ['key', 'track', 'file', 'frame_w', 'frame_h', 'anims', 'parallax', 'repeat', 'note'].map(h => el('th', { text: h }))));
    for (const row of state.manifest) {
      if (q && !row.key.includes(q)) continue;
      const tr = el('tr');
      tr.append(el('td', { text: row.key }));
      const track = el('select', {}, ['pixel', 'illust', 'ui'].map(v => el('option', { value: v, text: v }))); track.value = row.track; track.onchange = () => row.track = track.value;
      tr.append(el('td', {}, [track]));
      const file = el('select', {}, [el('option', { value: '', text: '(없음)' }), ...state.data.assets.map(a => el('option', { value: a.path, text: a.path.replace('res://assets/', '') }))]);
      file.value = row.file; file.onchange = () => row.file = file.value; tr.append(el('td', {}, [file]));
      for (const k of ['frame_w', 'frame_h', 'anims', 'parallax']) { const inp = el('input', { type: 'text', value: row[k] ?? '' }); inp.oninput = () => row[k] = inp.value; tr.append(el('td', {}, [inp])); }
      const rep = el('input', { type: 'checkbox' }); rep.checked = String(row.repeat) === 'true'; rep.onchange = () => row.repeat = rep.checked ? 'true' : 'false'; tr.append(el('td', {}, [rep]));
      const note = el('input', { type: 'text', value: row.note ?? '' }); note.oninput = () => row.note = note.value; tr.append(el('td', {}, [note]));
      t.append(tr);
    }
    box.append(t);
  }
  table('');
}

// ---------------------------------------------------------------- 저장·검증·루프
async function save() {
  status('저장 중…');
  const res = await fetch('/api/manifest', { method: 'POST', body: JSON.stringify({ rows: state.manifest }) });
  const out = await res.json();
  const log = $('#log'); if (log) log.textContent = (out.build.stdout || '') + (out.build.stderr || '');
  status(out.build.code === 0 ? `저장 ${out.saved}행 · 빌드 통과 — 게임을 다시 실행하면 반영` : `저장했지만 빌드 실패 — 매니페스트 탭 로그 확인`);
  if (out.build.code !== 0) { state.tab = 'manifest'; setTab(); const l = $('#log'); if (l) l.textContent = (out.build.stdout || '') + (out.build.stderr || ''); }
}
async function validate() {
  status('규격 검증 중…');
  const out = await (await fetch('/api/validate', { method: 'POST', body: '{}' })).json();
  status((out.code === 0 ? '규격 통과: ' : '규격 위반: ') + (out.stdout || out.stderr).trim().split('\n').pop());
}

function setTab() {
  for (const b of document.querySelectorAll('button.tab')) b.classList.toggle('active', b.dataset.tab === state.tab);
  render();
}

function draw() {
  const canvas = state.canvas; if (!canvas || !canvas.isConnected) return;
  const ctx = canvas.getContext('2d');
  ctx.save(); ctx.setTransform(state.tab === 'composer' ? state.scale : 1, 0, 0, state.tab === 'composer' ? state.scale : 1, 0, 0);
  ctx.imageSmoothingEnabled = false;
  if (state.tab === 'sprite') drawSprite(ctx); else if (state.tab === 'composer') drawComposer(ctx);
  ctx.restore();
}

for (const b of document.querySelectorAll('button.tab')) b.onclick = () => { state.tab = b.dataset.tab; setTab(); };
$('#btn-save').onclick = save;
$('#btn-validate').onclick = validate;
document.addEventListener('keydown', (e) => { if (e.key === 'b' && state.tab === 'composer' && !(e.target instanceof HTMLInputElement)) { state.useB = !state.useB; render(); } });
(function loop() { draw(); requestAnimationFrame(loop); })();
load().catch(err => status('불러오기 실패: ' + err));
