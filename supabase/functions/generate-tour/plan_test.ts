import { assert, assertEquals } from 'jsr:@std/assert'
import { MAX_EXCLUDE, pickRound } from './plan.ts'
import { type Place, selectPlaces } from './select.ts'

const start = { lat: 39.5696, lng: 2.6502 }
// 11 themed places within ~0.9 km: small enough that unbounded excludes starve it.
const pool: Place[] = Array.from({ length: 11 }, (_, i) => ({
  id: `g${i}`, name: `G${i}`, themes: ['ghosts'],
  lat: start.lat + ((i % 4) - 1.5) * 0.002, lng: start.lng + (Math.floor(i / 4) - 1) * 0.0025,
}))
const base = { start, km: 3, theme: 'ghosts' }

Deno.test('unbounded exclude starves the pool (documents the failure)', () => {
  let ex: string[] = []
  const sizes: number[] = []
  for (let seed = 1; seed <= 4; seed++) {
    const r = selectPlaces(pool, { ...base, exclude: ex, seed })
    sizes.push(r.places.length)
    ex = [...ex, ...r.places.map((p) => p.id)]
  }
  assert(sizes[3] < sizes[0], `expected shrink, got ${sizes}`)
})

Deno.test('repeated pulls keep returning a full-sized round', () => {
  const full = selectPlaces(pool, { ...base, exclude: [], seed: 1 }).places.length
  let ex: string[] = []
  for (let seed = 1; seed <= 6; seed++) {
    const r = pickRound(pool, { ...base, exclude: ex, seed })
    assertEquals(r.reason, undefined)
    assert(r.places.length >= full, `pull ${seed}: ${r.places.length} < ${full}`)
    ex = [...ex, ...r.places.map((p) => p.id)] // client feeds picks back, unbounded
  }
})

Deno.test('ids older than MAX_EXCLUDE are discarded (pick equals the no-exclude pick)', () => {
  const old = pool.slice(0, 5).map((p) => p.id)
  const filler = Array.from({ length: MAX_EXCLUDE }, (_, i) => `none${i}`)
  const r = pickRound(pool, { ...base, exclude: [...old, ...filler], seed: 2 })
  const plain = selectPlaces(pool, { ...base, exclude: [], seed: 2 })
  assertEquals(r.places.map((p) => p.id), plain.places.map((p) => p.id))
})
