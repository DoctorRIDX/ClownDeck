// ClownDeck backend (Termux)
// API lokal untuk app ClownDeck: tambah Sender (pairing code) dan kirim file WhatsApp.
//
//   cd backend && npm install && node backend.js
//
// Env opsional:
//   PORT=8787                 port server lokal
//   CLOWNDECK_FOLDER=/path    folder yang dikirim (default Download/DokumenScript)
//   CODE_TTL_SEC=60           lama hitung mundur kode pairing di app
//   WA_LOG=debug              log Baileys (untuk cek error pairing)

'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');
const os = require('os');
const crypto = require('crypto');

// ===== Konfigurasi =====
const VERSION = '1.0.0';
const HOST = '127.0.0.1'; // hanya bisa diakses dari HP ini
const PORT = Number(process.env.PORT || 8787);
const AUTH_ROOT = path.join(__dirname, 'auth');
const CODE_TTL_MS = Number(process.env.CODE_TTL_SEC || 60) * 1000;
const CAPTION = 'from ClownDeck🏴';
const DELAY_BETWEEN_FILES = 1500;
const LOG_LEVEL = process.env.WA_LOG || 'silent';
const FOLDER_CANDIDATES = [
  process.env.CLOWNDECK_FOLDER,
  '/storage/emulated/0/Download/DokumenScript',
  path.join(os.homedir(), 'storage', 'downloads', 'DokumenScript'),
  path.join(os.homedir(), 'storage', 'shared', 'Download', 'DokumenScript'),
  path.join(os.homedir(), 'DokumenScript'),
].filter(Boolean);

const startedAt = Date.now();

// ===== Helper =====
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const log = (...a) => console.log(new Date().toLocaleTimeString('id-ID'), '|', ...a);

function normalizeNumber(input) {
  let n = String(input ?? '').replace(/[^0-9]/g, '');
  if (n.startsWith('0')) n = '62' + n.slice(1);
  return /^62\d{8,13}$/.test(n) ? n : null;
}

const authDir = (num) => path.join(AUTH_ROOT, num);

function hasPairedAuth(num) {
  try {
    const c = JSON.parse(fs.readFileSync(path.join(authDir(num), 'creds.json'), 'utf8'));
    return !!(c.registered || c.me);
  } catch (_) {
    return false;
  }
}

function rmAuth(num) {
  try { fs.rmSync(authDir(num), { recursive: true, force: true }); } catch (_) {}
}

function findFolder() {
  for (const p of FOLDER_CANDIDATES) {
    try {
      if (fs.existsSync(p) && fs.statSync(p).isDirectory()) return p;
    } catch (_) {}
  }
  return null;
}

function walkFiles(dir) {
  let out = [];
  for (const name of fs.readdirSync(dir)) {
    const full = path.join(dir, name);
    let st;
    try { st = fs.statSync(full); } catch (_) { continue; }
    if (st.isDirectory()) out = out.concat(walkFiles(full));
    else if (st.isFile() && st.size > 0) out.push(full);
  }
  return out.sort();
}

function guessMime(ext) {
  const map = {
    '.pdf': 'application/pdf',
    '.doc': 'application/msword',
    '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    '.xls': 'application/vnd.ms-excel',
    '.xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    '.ppt': 'application/vnd.ms-powerpoint',
    '.pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    '.txt': 'text/plain',
    '.js': 'text/javascript',
    '.json': 'application/json',
    '.zip': 'application/zip',
    '.rar': 'application/vnd.rar',
    '.7z': 'application/x-7z-compressed',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
    '.webp': 'image/webp',
    '.gif': 'image/gif',
    '.mp4': 'video/mp4',
    '.mkv': 'video/x-matroska',
    '.mov': 'video/quicktime',
    '.webm': 'video/webm',
    '.mp3': 'audio/mpeg',
    '.ogg': 'audio/ogg',
    '.wav': 'audio/wav',
    '.m4a': 'audio/mp4',
    '.apk': 'application/vnd.android.package-archive',
  };
  return map[ext] || 'application/octet-stream';
}

function sanitizeName(raw) {
  let n = String(raw || '').trim();
  n = n.replace(/[\\/]/g, '_').replace(/\.\./g, '_');
  n = n.replace(/[\x00-\x1f]/g, '');
  if (!n) n = 'File';
  if (n.length > 120) n = n.slice(0, 120);
  return n;
}

function uniqueFileName(folder, name) {
  const ext = path.extname(name);
  const base = name.slice(0, name.length - ext.length);
  let candidate = name;
  let i = 1;
  while (fs.existsSync(path.join(folder, candidate))) {
    candidate = `${base} (${i})${ext}`;
    i++;
  }
  return candidate;
}

function ensureFolder() {
  let folder = findFolder();
  if (folder) return folder;
  folder = FOLDER_CANDIDATES[0];
  fs.mkdirSync(folder, { recursive: true });
  return folder;
}

function describeError(e) {
  const msg = String(e && e.message ? e.message : e);
  if (/Cannot find (package|module)|ERR_MODULE_NOT_FOUND/i.test(msg)) {
    return 'Modul Baileys/pino belum terpasang. Jalankan "npm install" di folder backend.';
  }
  return msg;
}

// ===== Baileys (dimuat saat dibutuhkan) =====
let _B = null;
let _version; // cache versi WA
let _versionTried = false;

async function loadBaileys() {
  if (_B) return _B;
  const m = await import('@whiskeysockets/baileys');
  const pick = (k) => m[k] ?? (m.default && m.default[k]);
  const make = [m.default && m.default.default, m.default, m.makeWASocket, m.default && m.default.makeWASocket]
    .find((f) => typeof f === 'function');
  if (!make) throw new Error('makeWASocket tidak ditemukan di modul Baileys.');
  _B = {
    makeWASocket: make,
    useMultiFileAuthState: pick('useMultiFileAuthState'),
    fetchLatestBaileysVersion: pick('fetchLatestBaileysVersion'),
    Browsers: pick('Browsers'),
    DisconnectReason: pick('DisconnectReason'),
  };
  return _B;
}

async function getWaVersion(B) {
  if (_versionTried) return _version;
  _versionTried = true;
  try {
    const r = await B.fetchLatestBaileysVersion();
    _version = r.version;
  } catch (_) {
    _version = undefined; // pakai bawaan library
  }
  return _version;
}

// ===== Sender =====
// status: starting | pairing | connecting | connected | disconnected | error
const senders = new Map();

function newSender(number) {
  return {
    number,
    status: 'starting',
    code: null,
    expiresAt: null,
    error: null,
    sock: null,
    stopped: false,
    pairingRequested: false,
    reconnectTimer: null,
  };
}

function publicSender(s) {
  return {
    number: s.number,
    status: s.status,
    code: s.status === 'pairing' ? s.code : null,
    expiresAt: s.status === 'pairing' ? s.expiresAt : null,
    ttlMs: CODE_TTL_MS,
    error: s.error,
  };
}

function endSock(s) {
  const sock = s.sock;
  s.sock = null; // handler close milik socket lama akan diabaikan
  if (sock) {
    try { sock.end(undefined); } catch (_) {}
  }
}

function scheduleReconnect(s, ms) {
  if (s.stopped) return;
  clearTimeout(s.reconnectTimer);
  s.reconnectTimer = setTimeout(() => {
    connectSender(s).catch((e) => {
      s.status = 'error';
      s.error = describeError(e);
      log('[!] gagal menyambung', s.number, s.error);
    });
  }, ms);
}

async function connectSender(s) {
  if (s.stopped) return;
  const B = await loadBaileys();
  const pino = require('pino');
  const { state, saveCreds } = await B.useMultiFileAuthState(authDir(s.number));
  const version = await getWaVersion(B);

  const sock = B.makeWASocket({
    version,
    auth: state,
    logger: pino({ level: LOG_LEVEL }),
    printQRInTerminal: false,
    browser: B.Browsers.ubuntu('Chrome'), // wajib valid untuk pairing code
    markOnlineOnConnect: false,
    syncFullHistory: false,
  });
  s.sock = sock;
  sock.ev.on('creds.update', saveCreds);

  // Cek dari dua sumber: status socket yang hidup sekarang, DAN file di disk.
  // File disk jadi jaring pengaman kalau creds baru saja tersimpan tapi socket
  // ini sempat membaca status lama sebelum pembaruan — ini akar masalah
  // "pairing gagal padahal sudah tersambung".
  const paired = () => !!(sock.authState.creds.registered || sock.authState.creds.me) || hasPairedAuth(s.number);

  // Hanya minta kode BARU kalau memang belum ada kode yang masih berlaku.
  // Sebelumnya kode baru diminta setiap kali socket putus-sambung, yang
  // otomatis membatalkan kode lama walau pengguna belum sempat memasukkannya —
  // itulah yang membuat pairing tampak gagal padahal nomornya akhirnya tersambung.
  const needsNewCode = () =>
    !paired() && (!s.code || Date.now() >= (s.expiresAt || 0));

  const requestCode = async () => {
    if (s.stopped || s.sock !== sock) return;
    if (!needsNewCode() || s.pairingRequested) return;
    s.pairingRequested = true;
    try {
      log(`minta pairing code ${s.number}`);
      const code = await sock.requestPairingCode(s.number);
      if (s.stopped || s.sock !== sock) return;
      s.code = code;
      s.expiresAt = Date.now() + CODE_TTL_MS;
      s.status = 'pairing';
      s.error = null;
      log(`pairing code ${s.number}: ${code}`);
    } catch (e) {
      log('[!] gagal minta kode:', e.message);
      if (s.stopped || s.sock !== sock) return;
      // Jangan langsung nyerah: koneksi akan dicoba ulang otomatis dan kode
      // akan diminta lagi pada percobaan berikutnya.
      s.error = 'Gagal meminta pairing code, mencoba lagi...';
    } finally {
      s.pairingRequested = false;
    }
  };

  sock.ev.on('connection.update', async (u) => {
    if (s.stopped || s.sock !== sock) return;
    const { connection, lastDisconnect, qr } = u;

    // qr muncul = socket siap untuk registrasi
    if (qr) await requestCode();

    if (connection === 'open') {
      s.status = 'connected';
      s.code = null;
      s.expiresAt = null;
      s.error = null;
      log('terhubung:', s.number);
    }

    if (connection === 'close') {
      const status = lastDisconnect && lastDisconnect.error && lastDisconnect.error.output
        ? lastDisconnect.error.output.statusCode
        : undefined;
      log(`koneksi tertutup ${s.number} (kode ${status ?? '?'})`);

      if (status === B.DisconnectReason.loggedOut) {
        s.sock = null;
        s.status = 'disconnected';
        s.code = null;
        s.expiresAt = null;
        s.error = 'Sender logout dari WhatsApp. Tambahkan lagi lewat Add Sender.';
        rmAuth(s.number);
        return;
      }

      const wasPaired = paired();
      s.sock = null;

      if (wasPaired) {
        // 515 setelah pairing berhasil itu normal; begitu juga putus biasa.
        // Sudah tertaut — tidak pernah ditampilkan sebagai gagal lagi.
        s.code = null;
        s.expiresAt = null;
        s.status = 'connecting';
        s.error = null;
        scheduleReconnect(s, 1500);
      } else if (s.code && Date.now() < (s.expiresAt || 0)) {
        // Kode masih berlaku: jangan ganti status atau minta kode baru,
        // cukup coba sambung lagi diam-diam di belakang layar supaya
        // kode yang sedang dimasukkan pengguna tidak ikut batal.
        scheduleReconnect(s, 1500);
      } else {
        // Belum tertaut dan tidak ada kode aktif: mulai lagi dari awal,
        // tanpa pernah menyerah secara permanen.
        s.code = null;
        s.expiresAt = null;
        s.status = 'starting';
        scheduleReconnect(s, 1500);
      }
    }
  });

  // Cadangan kalau event qr tidak muncul
  if (!paired()) setTimeout(() => requestCode().catch(() => {}), 8000);
}

async function beginPairing(num) {
  let s = senders.get(num);

  // Sudah tertaut (atau punya session valid): jangan hapus, cukup pastikan menyambung
  if (s && (s.status === 'connected' || hasPairedAuth(num))) {
    if (s.status !== 'connected' && !s.sock) scheduleReconnect(s, 0);
    return s;
  }
  if (!s && hasPairedAuth(num)) {
    s = newSender(num);
    s.status = 'connecting';
    senders.set(num, s);
    scheduleReconnect(s, 0);
    return s;
  }

  // Mulai dari awal
  if (s) {
    s.stopped = true;
    clearTimeout(s.reconnectTimer);
    endSock(s);
  }
  rmAuth(num);
  s = newSender(num);
  senders.set(num, s);
  connectSender(s).catch((e) => {
    s.status = 'error';
    s.error = describeError(e);
    log('[!] gagal memulai sender', num, s.error);
  });
  return s;
}

async function removeSender(num) {
  const s = senders.get(num);
  if (!s) {
    rmAuth(num);
    return;
  }
  s.stopped = true;
  clearTimeout(s.reconnectTimer);
  if (s.sock && s.status === 'connected') {
    try { await Promise.race([s.sock.logout(), sleep(5000)]); } catch (_) {}
  }
  endSock(s);
  rmAuth(num);
  senders.delete(num);
}

function loadExistingSenders() {
  if (!fs.existsSync(AUTH_ROOT)) return;
  for (const name of fs.readdirSync(AUTH_ROOT)) {
    if (!/^62\d{8,13}$/.test(name)) continue;
    if (hasPairedAuth(name)) {
      const s = newSender(name);
      s.status = 'connecting';
      senders.set(name, s);
      scheduleReconnect(s, 0);
      log('memuat sender tersimpan:', name);
    } else {
      rmAuth(name); // sisa pairing yang gagal
    }
  }
}

// ===== Kirim file =====
const jobs = new Map();

function publicJob(j) {
  return {
    id: j.id,
    status: j.status, // running | done | error
    total: j.total,
    done: j.done,
    failed: j.failed,
    current: j.current,
    error: j.error,
    log: j.log.slice(-5),
  };
}

function runningJob() {
  for (const j of jobs.values()) if (j.status === 'running') return j;
  return null;
}

async function waitConnected(s, ms = 90000) {
  const t0 = Date.now();
  while (Date.now() - t0 < ms) {
    if (s.status === 'connected' && s.sock) return;
    await sleep(500);
  }
  throw new Error('Sender terputus dan belum tersambung kembali');
}

async function sendOne(s, jid, filePath) {
  const ext = path.extname(filePath).toLowerCase();
  const mimetype = guessMime(ext);
  const fileName = path.basename(filePath);
  const source = { url: filePath }; // stream dari disk, hemat RAM

  const isImage = ['.jpg', '.jpeg', '.png', '.webp'].includes(ext);
  const isVideo = ['.mp4', '.mkv', '.mov', '.webm'].includes(ext);
  const isAudio = ['.mp3', '.ogg', '.wav', '.m4a'].includes(ext);

  if (isImage) {
    await s.sock.sendMessage(jid, { image: source, caption: CAPTION, mimetype });
  } else if (isVideo) {
    await s.sock.sendMessage(jid, { video: source, caption: CAPTION, mimetype });
  } else if (isAudio) {
    await s.sock.sendMessage(jid, { audio: source, mimetype });
    await s.sock.sendMessage(jid, { text: `${CAPTION}\n${fileName}` });
  } else {
    await s.sock.sendMessage(jid, { document: source, mimetype, fileName, caption: CAPTION });
  }
}

async function sendWithRetry(s, jid, filePath) {
  for (let attempt = 1; attempt <= 2; attempt++) {
    try {
      await waitConnected(s);
      await sendOne(s, jid, filePath);
      return;
    } catch (e) {
      if (attempt === 2) throw e;
      await sleep(3000);
    }
  }
}

async function runJob(job, s, target, folder, files) {
  const jid = target + '@s.whatsapp.net';
  try {
    try {
      const r = await s.sock.onWhatsApp(jid);
      if (r && r[0] && r[0].exists === false) {
        throw new Error('Nomor target tidak terdaftar di WhatsApp.');
      }
    } catch (e) {
      if (/tidak terdaftar/.test(e.message)) throw e;
    }

    for (const f of files) {
      job.current = path.relative(folder, f);
      log(`kirim [${job.done + job.failed + 1}/${job.total}] ${job.current}`);
      try {
        await sendWithRetry(s, jid, f);
        job.done += 1;
      } catch (e) {
        job.failed += 1;
        job.log.push(`Gagal: ${job.current} (${e.message})`);
        log('[!] gagal kirim', job.current, e.message);
      }
      await sleep(DELAY_BETWEEN_FILES);
    }
    job.status = 'done';
  } catch (e) {
    job.status = 'error';
    job.error = describeError(e);
  }
  job.current = '';
  log(`job ${job.id} selesai: ${job.done} sukses, ${job.failed} gagal`);

  // simpan 20 job terakhir saja
  if (jobs.size > 20) {
    const oldest = [...jobs.keys()].slice(0, jobs.size - 20);
    oldest.forEach((k) => { if (jobs.get(k).status !== 'running') jobs.delete(k); });
  }
}

// ===== HTTP =====
function reply(res, code, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(code, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
    'Cache-Control': 'no-store',
  });
  res.end(body);
}

const fail = (res, code, message, errCode) => reply(res, code, { error: message, code: errCode || 'error' });

function readBody(req) {
  return new Promise((resolve, reject) => {
    let raw = '';
    req.on('data', (c) => {
      raw += c;
      if (raw.length > 65536) {
        reject(new Error('Body terlalu besar'));
        req.destroy();
      }
    });
    req.on('end', () => {
      if (!raw) return resolve({});
      try { resolve(JSON.parse(raw)); } catch (_) { reject(new Error('JSON tidak valid')); }
    });
    req.on('error', reject);
  });
}

const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url, 'http://localhost');
    const p = url.pathname.replace(/\/+$/, '') || '/';
    const m = req.method;
    let match;

    if (m === 'GET' && p === '/api/ping') {
      return reply(res, 200, {
        ok: true,
        version: VERSION,
        uptime: Math.round((Date.now() - startedAt) / 1000),
        senders: senders.size,
      });
    }

    if (m === 'GET' && p === '/api/senders') {
      return reply(res, 200, { senders: [...senders.values()].map(publicSender) });
    }

    if (m === 'POST' && p === '/api/senders') {
      const body = await readBody(req);
      const num = normalizeNumber(body.number);
      if (!num) return fail(res, 400, 'Nomor tidak valid. Pakai format 08xx atau 62xx.', 'bad_number');
      const s = await beginPairing(num);
      return reply(res, 200, { sender: publicSender(s) });
    }

    if ((match = p.match(/^\/api\/senders\/(\d+)$/))) {
      const num = match[1];
      if (m === 'GET') {
        const s = senders.get(num);
        if (!s) return fail(res, 404, 'Sender tidak ditemukan.', 'not_found');
        return reply(res, 200, { sender: publicSender(s) });
      }
      if (m === 'DELETE') {
        await removeSender(num);
        return reply(res, 200, { ok: true });
      }
    }

    if (m === 'GET' && p === '/api/files') {
      const folder = findFolder();
      if (!folder) {
        return reply(res, 200, { folder: FOLDER_CANDIDATES[0] || null, exists: false, count: 0 });
      }
      return reply(res, 200, { folder, exists: true, count: walkFiles(folder).length });
    }

    if (m === 'GET' && p === '/api/files/list') {
      const folder = findFolder();
      if (!folder) return reply(res, 200, { folder: FOLDER_CANDIDATES[0] || null, files: [] });
      const files = walkFiles(folder).map((f) => ({
        name: path.relative(folder, f),
        size: fs.statSync(f).size,
      }));
      return reply(res, 200, { folder, files });
    }

    if (m === 'POST' && p === '/api/files') {
      const body = await readBody(req);
      const name = sanitizeName(body.name);
      const bytes = Math.floor(Number(body.bytes));
      if (!Number.isFinite(bytes) || bytes <= 0) {
        return fail(res, 400, 'Ukuran file tidak valid.', 'bad_size');
      }
      const MAX_BYTES = 20 * 1024 * 1024 * 1024; // pengaman 20 GB
      if (bytes > MAX_BYTES) {
        return fail(res, 400, 'Ukuran file terlalu besar (maksimal 20 GB).', 'too_large');
      }
      const folder = ensureFolder();
      const finalName = uniqueFileName(folder, name);
      const full = path.join(folder, finalName);
      try {
        const fd = fs.openSync(full, 'w');
        fs.ftruncateSync(fd, bytes);
        fs.closeSync(fd);
      } catch (e) {
        return fail(res, 500, 'Gagal membuat file: ' + e.message, 'write_failed');
      }
      log('file dibuat:', finalName, bytes, 'bytes');
      return reply(res, 200, { file: { name: finalName, size: bytes } });
    }

    if (m === 'DELETE' && (match = p.match(/^\/api\/files\/(.+)$/))) {
      const name = sanitizeName(decodeURIComponent(match[1]));
      const folder = findFolder();
      if (!folder) return fail(res, 404, 'Folder tidak ditemukan.', 'not_found');
      const full = path.join(folder, name);
      if (!full.startsWith(folder)) return fail(res, 400, 'Nama file tidak valid.', 'bad_name');
      try {
        fs.unlinkSync(full);
      } catch (_) {
        return fail(res, 404, 'File tidak ditemukan.', 'not_found');
      }
      log('file dihapus:', name);
      return reply(res, 200, { ok: true });
    }

    if (m === 'POST' && p === '/api/send') {
      const body = await readBody(req);
      const target = normalizeNumber(body.target);
      if (!target) return fail(res, 400, 'Nomor target tidak valid. Pakai format 08xx atau 62xx.', 'bad_target');

      let s = null;
      if (body.sender) {
        const sn = normalizeNumber(body.sender);
        s = sn ? senders.get(sn) : null;
      } else {
        s = [...senders.values()].find((x) => x.status === 'connected') || null;
      }
      if (!s || s.status !== 'connected' || !s.sock) {
        return fail(res, 400, 'Belum ada Sender yang terhubung. Tambahkan Sender dulu.', 'no_sender');
      }
      if (runningJob()) return fail(res, 409, 'Masih ada proses kirim yang berjalan.', 'busy');

      const folder = findFolder();
      if (!folder) {
        return fail(res, 400, `Folder DokumenScript tidak ditemukan di ${FOLDER_CANDIDATES[0] || 'Download'}.`, 'no_folder');
      }
      const files = walkFiles(folder);
      if (files.length === 0) return fail(res, 400, 'Folder DokumenScript kosong.', 'no_files');

      const job = {
        id: crypto.randomBytes(6).toString('hex'),
        status: 'running',
        total: files.length,
        done: 0,
        failed: 0,
        current: '',
        error: null,
        log: [],
        target,
        sender: s.number,
        startedAt: Date.now(),
      };
      jobs.set(job.id, job);
      runJob(job, s, target, folder, files).catch((e) => {
        job.status = 'error';
        job.error = describeError(e);
      });
      return reply(res, 200, { jobId: job.id });
    }

    if (m === 'GET' && p === '/api/jobs') {
      const list = [...jobs.values()]
        .sort((a, b) => b.startedAt - a.startedAt)
        .slice(0, 20)
        .map((j) => ({
          id: j.id,
          status: j.status,
          total: j.total,
          done: j.done,
          failed: j.failed,
          target: j.target,
          sender: j.sender,
          startedAt: j.startedAt,
        }));
      return reply(res, 200, { jobs: list });
    }

    if (m === 'POST' && p === '/api/check-number') {
      const body = await readBody(req);
      const num = normalizeNumber(body.number);
      if (!num) return fail(res, 400, 'Nomor tidak valid.', 'bad_number');
      const s = [...senders.values()].find((x) => x.status === 'connected' && x.sock);
      if (!s) return fail(res, 400, 'Tidak ada Sender yang terhubung.', 'no_sender');
      try {
        const r = await s.sock.onWhatsApp(`${num}@s.whatsapp.net`);
        const exists = Array.isArray(r) && r.length > 0 && r[0].exists !== false;
        return reply(res, 200, { number: num, exists });
      } catch (e) {
        return fail(res, 500, 'Gagal memeriksa nomor: ' + e.message, 'check_failed');
      }
    }

    if (m === 'GET' && (match = p.match(/^\/api\/jobs\/([a-f0-9]+)$/))) {
      const j = jobs.get(match[1]);
      if (!j) return fail(res, 404, 'Job tidak ditemukan.', 'not_found');
      return reply(res, 200, { job: publicJob(j) });
    }

    return fail(res, 404, 'Endpoint tidak ada.', 'not_found');
  } catch (e) {
    return fail(res, 500, describeError(e), 'server_error');
  }
});

server.on('error', (e) => {
  if (e.code === 'EADDRINUSE') {
    console.error(`[FATAL] Port ${PORT} sudah dipakai. Backend mungkin sudah jalan (pkill -f backend.js untuk menghentikan).`);
  } else {
    console.error('[FATAL]', e);
  }
  process.exit(1);
});

server.listen(PORT, HOST, () => {
  const folder = findFolder();
  console.log('========================================');
  console.log('  ClownDeck backend aktif');
  console.log(`  Alamat : http://${HOST}:${PORT}`);
  console.log(`  Folder : ${folder || 'BELUM ADA (jalankan termux-setup-storage & buat folder DokumenScript)'}`);
  console.log('========================================');
  loadExistingSenders();
});

// Jaga server tetap hidup kalau Baileys melempar error liar
process.on('uncaughtException', (e) => log('[uncaughtException]', e && e.message));
process.on('unhandledRejection', (e) => log('[unhandledRejection]', e && e.message ? e.message : e));

function shutdown() {
  for (const s of senders.values()) {
    s.stopped = true;
    endSock(s);
  }
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(0), 1500);
}
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
