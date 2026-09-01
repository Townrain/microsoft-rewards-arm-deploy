// migrate-v3-session.js — 把 v3 JSON 会话迁移进 v4 sessions.db
// 用法（容器内）：node /usr/src/microsoft-rewards-script/sessions/migrate.js
// v3 格式: session_mobile.json / session_desktop.json = cookies 数组（playwright cookies 序列化）
//          session_fingerprint_desktop.json = { fingerprint, headers }（BrowserFingerprintWithHeaders）
// v4 格式: sessions.db 表 sessions(email, platform, storage_state=StorageState JSON, fingerprint, updated_at)
const fs = require('fs')
const path = require('path')
const { DatabaseSync } = require('node:sqlite')

const SESSIONS_DIR = '/usr/src/microsoft-rewards-script/sessions'
const EMAIL = process.argv[2] || '<ACCOUNT-EMAIL>'
const emailDir = path.join(SESSIONS_DIR, EMAIL)

if (!fs.existsSync(emailDir)) {
    console.error(`[migrate] 会话目录不存在: ${emailDir}`)
    process.exit(1)
}

function loadJson(name) {
    const p = path.join(emailDir, name)
    if (!fs.existsSync(p)) return null
    try {
        return JSON.parse(fs.readFileSync(p, 'utf8'))
    } catch (e) {
        console.warn(`[migrate] 解析失败 ${name}: ${e.message}`)
        return null
    }
}

const db = new DatabaseSync(path.join(SESSIONS_DIR, 'sessions.db'))
db.exec('PRAGMA journal_mode = WAL')
db.exec(`CREATE TABLE IF NOT EXISTS sessions (
    email TEXT NOT NULL, platform TEXT NOT NULL, storage_state TEXT,
    fingerprint TEXT, updated_at INTEGER NOT NULL, PRIMARY KEY (email, platform))`)

const mobileCookies = loadJson('session_mobile.json')
const desktopCookies = loadJson('session_desktop.json')
const desktopFp = loadJson('session_fingerprint_desktop.json')

const now = Date.now()
const upsert = db.prepare(`INSERT INTO sessions (email, platform, storage_state, fingerprint, updated_at)
    VALUES (?, ?, ?, ?, ?)
    ON CONFLICT(email, platform) DO UPDATE SET
      storage_state = excluded.storage_state,
      fingerprint = COALESCE(excluded.fingerprint, sessions.fingerprint),
      updated_at = excluded.updated_at`)

let n = 0
if (Array.isArray(mobileCookies)) {
    const ss = JSON.stringify({ cookies: mobileCookies, origins: [] })
    upsert.run(EMAIL, 'mobile', ss, null, now)
    console.log(`[migrate] mobile: ${mobileCookies.length} cookies -> ${ss.length} bytes`)
    n++
}
if (Array.isArray(desktopCookies)) {
    const ss = JSON.stringify({ cookies: desktopCookies, origins: [] })
    const fp = desktopFp ? JSON.stringify(desktopFp) : null
    upsert.run(EMAIL, 'desktop', ss, fp, now)
    console.log(`[migrate] desktop: ${desktopCookies.length} cookies -> ${ss.length} bytes, fingerprint: ${fp ? 'yes' : 'no'}`)
    n++
}

if (n === 0) {
    console.error('[migrate] 没有可迁移的会话文件')
    process.exit(1)
}

console.log('[migrate] 迁移后 sessions 表:')
for (const r of db.prepare('SELECT email, platform, length(storage_state) as ss, length(fingerprint) as fp, updated_at FROM sessions').all()) {
    console.log(`  ${r.email} | ${r.platform} | storage=${r.ss}B | fp=${r.fp}B | updated=${new Date(r.updated_at).toISOString()}`)
}
db.close()
console.log('[migrate] DONE')
