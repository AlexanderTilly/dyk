import { assert, assertEquals, assertNotEquals } from 'jsr:@std/assert'
import { type Place, selectPlaces } from './select.ts'

const start = { lat: 39.5696, lng: 2.6502 }
// ~111 m per 0.001 deg latitude
function mk(i: number, dLat: number, dLng: number, themes = ['churches']): Place {
  return { id: `p${i}`, name: `P${i}`, lat: start.lat + dLat, lng: start.lng + dLng, themes }
}
// 30 churches on a grid within ~0.9 km of start
const grid: Place[] = []
for (let i = 0; i < 30; i++) {
  grid.push(mk(i, ((i % 6) - 3) * 0.0022, (Math.floor(i / 6) - 2) * 0.0026))
}
const base = { start, km: 3, theme: 'churches', exclude: [] as string[], seed: 1 }
const ids = (p: Place[]) => p.map((x) => x.id).sort()

Deno.test('returns between 3 and 10 places', () => {
  for (const km of [1, 2, 3, 6, 10, 20]) {
    const r = selectPlaces(grid, { ...base, km })
    assert(r.places.length >= 3 && r.places.length <= 10, `km=${km} got ${r.places.length}`)
  }
  assertEquals(selectPlaces(grid, { ...base, km: 20 }).places.length, 10)
  assertEquals(selectPlaces(grid, { ...base, km: 1 }).places.length, 3)
})
Deno.test('too few in radius gives too_few and no places', () => {
  const few = [mk(1, 0.001, 0), mk(2, 0, 0.001), mk(3, 0.5, 0.5)] // third is far away
  assertEquals(selectPlaces(few, { ...base, km: 3 }), { places: [], reason: 'too_few' })
})
Deno.test('does not widen the radius to rescue', () => {
  const r = selectPlaces([mk(1, 0.001, 0), mk(2, 0, 0.001)], base)
  assertEquals(r.reason, 'too_few')
})
Deno.test('different seeds give different sets', () => {
  const sets = new Set<string>()
  for (let s = 1; s <= 8; s++) sets.add(ids(selectPlaces(grid, { ...base, seed: s }).places).join())
  assert(sets.size > 1)
  assertNotEquals(
    ids(selectPlaces(grid, { ...base, seed: 1 }).places),
    ids(selectPlaces(grid, { ...base, seed: 2 }).places),
  )
})
Deno.test('same seed repeats', () => {
  assertEquals(selectPlaces(grid, base), selectPlaces(grid, base))
})
Deno.test('excluded places are skipped while enough others remain', () => {
  const first = selectPlaces(grid, base).places.map((p) => p.id)
  const r = selectPlaces(grid, { ...base, exclude: first })
  for (const p of r.places) assert(!first.includes(p.id))
})
Deno.test('excluded places are used only when too few others remain', () => {
  const small = grid.slice(0, 4)
  const r = selectPlaces(small, { ...base, exclude: ['p0', 'p1'] })
  assertEquals(r.reason, undefined)
  assertEquals(r.places.length, 3)
  const got = ids(r.places)
  assert(got.includes('p2') && got.includes('p3'), 'fresh places must survive the top-up')
  assertEquals(got.filter((x) => x === 'p0' || x === 'p1').length, 1)
})
Deno.test('every place carries the theme', () => {
  const mixed = grid.map((p, i) => (i % 2 ? { ...p, themes: ['ghosts'] } : p))
  const r = selectPlaces(mixed, base)
  assert(r.places.length >= 3)
  for (const p of r.places) assert(p.themes.includes('churches'))
})
Deno.test('radius grows with km: 1 km ask does not reach 2 km away', () => {
  const far = mk(99, 0.018, 0) // ~2 km north
  const near = [mk(1, 0.001, 0), mk(2, 0, 0.001), mk(3, -0.001, 0), far]
  const inside = [mk(1, 0.001, 0), mk(2, 0, 0.001), mk(3, 0.0027, 0)] // 300 m, inside 333 m
  assertEquals(selectPlaces(inside, { ...base, km: 1 }).reason, undefined)
  assertEquals(selectPlaces(near.slice(0, 2).concat(far), { ...base, km: 1 }).reason, 'too_few')
  // reachable at the larger radius: with only two near places it is needed to reach 3
  const two = [mk(1, 0.001, 0), mk(2, 0, 0.001), far]
  assertEquals(selectPlaces(two, { ...base, km: 1 }).reason, 'too_few')
  assert(selectPlaces(two, { ...base, km: 9 }).places.some((p) => p.id === 'p99'))
})
Deno.test('result is a compact cluster, not a star around start', () => {
  // two clusters equidistant-ish from start; picks should come from one of them
  const a = [0, 1, 2, 3, 4, 5].map((i) => mk(i, 0.0028 + i * 0.0003, 0))
  const b = [6, 7, 8, 9, 10, 11].map((i) => mk(i, -0.0028 - (i - 6) * 0.0003, 0))
  for (let s = 1; s <= 6; s++) {
    const r = selectPlaces([...a, ...b], { ...base, km: 1.5, seed: s })
    const north = r.places.filter((p) => p.lat > start.lat).length
    assert(north === 0 || north === r.places.length, `seed ${s} mixed clusters`)
  }
})
Deno.test('seeds change membership, not just order, over a pool of 12', () => {
  const pool: Place[] = []
  for (let i = 0; i < 12; i++) pool.push(mk(i, ((i % 4) - 1.5) * 0.0018, (Math.floor(i / 4) - 1) * 0.0022))
  const sets: string[][] = []
  for (let s = 1; s <= 10; s++) {
    const r = selectPlaces(pool, { ...base, km: 3, seed: s })
    assertEquals(r.places.length, 8)
    sets.push(ids(r.places))
  }
  assert(new Set(sets.map((x) => x.join())).size > 1, 'all seeds returned the same members')
  assert(sets.some((x) => x.join() !== sets[0].join()))
})
