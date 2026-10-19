/* Freeze Palma's places into a file the website can serve.
 *
 * The site could query Supabase from the browser — the anon key is public and
 * RLS protects the rest — but a marketing page should not go blank because the
 * database is having an afternoon, and 149 pins change about once a month. So
 * the data is baked and committed, and this script regenerates it.
 *
 *   node tool/build_web_places.js            (reads ../dyk-admin/.env.local)
 *
 * Writes web/data/palma.json: the places with a story, their coordinates,
 * their first photograph and their English narration.
 */
const fs = require('fs')
const path = require('path')

const ENV = path.join(__dirname, '..', '..', 'dyk-admin', '.env.local')
const OUT = path.join(__dirname, '..', 'web', 'data', 'palma.json')

const env = Object.fromEntries(
  fs.readFileSync(ENV, 'utf8').split(/\r?\n/).filter((l) => l.includes('='))
    .map((l) => [l.slice(0, l.indexOf('=')).trim(), l.slice(l.indexOf('=') + 1).trim()]),
)
const URL = env.VITE_SUPABASE_URL
const KEY = env.VITE_SUPABASE_PUBLISHABLE_KEY || env.VITE_SUPABASE_ANON_KEY
const H = { apikey: KEY, Authorization: 'Bearer ' + KEY }

/** PostgREST caps a page at 1000 rows and says nothing about it. */
async function all(query) {
  const out = []
  for (let from = 0; ; from += 1000) {
    const res = await fetch(`${URL}/rest/v1/${query}`, {
      headers: { ...H, Range: `${from}-${from + 999}` },
    })
    const page = await res.json()
    if (!Array.isArray(page)) throw new Error(JSON.stringify(page).slice(0, 200))
    out.push(...page)
    if (page.length < 1000) return out
  }
}

const publicUrl = (storagePath) => {
  const [bucket, ...rest] = storagePath.split('/')
  if (!rest.length) return null
  return `${URL}/storage/v1/object/public/${bucket}/${rest.map(encodeURIComponent).join('/')}`
}

;(async () => {
  const packs = await all('citypacks?select=id,city')
  const palma = packs.find((p) => (p.city || '').trim().toLowerCase() === 'palma')
  if (!palma) throw new Error('no Palma citypack')

  const hotspots = await all(
    `hotspots?select=id,name,subtitle,category,subcategory,lat,lng&citypack_id=eq.${palma.id}`,
  )
  const media = await all('hotspot_media?select=hotspot_id,media_type,storage_path,sort_order,lang')

  const image = {}
  const audio = {}
  for (const m of media) {
    if (m.media_type === 'image' && !image[m.hotspot_id]) {
      image[m.hotspot_id] = publicUrl(m.storage_path)
    }
    if (m.media_type === 'audio' && (m.lang ?? 'en') === 'en' && !audio[m.hotspot_id]) {
      audio[m.hotspot_id] = publicUrl(m.storage_path)
    }
  }

  // Only places that actually have something to hear. A pin that opens to
  // silence is worse than no pin: the map is the promise, and 149 is the
  // number the page prints next to it.
  const places = hotspots
    .filter((h) => h.lat && h.lng && audio[h.id])
    .map((h) => ({
      n: h.name,
      s: h.subtitle || '',
      c: h.category || 'history',
      lat: Number(h.lat.toFixed(6)),
      lng: Number(h.lng.toFixed(6)),
      img: image[h.id] || null,
      a: audio[h.id],
    }))
    .sort((a, b) => a.n.localeCompare(b.n))

  fs.mkdirSync(path.dirname(OUT), { recursive: true })
  fs.writeFileSync(OUT, JSON.stringify({ city: 'Palma', places }))

  const byCat = {}
  for (const p of places) byCat[p.c] = (byCat[p.c] || 0) + 1
  console.log(`${places.length} places → web/data/palma.json`)
  console.log('  ' + Object.entries(byCat).map(([c, n]) => `${c}: ${n}`).join('  '))
  console.log('  ' + Math.round(fs.statSync(OUT).size / 1024) + ' kB')
})()
