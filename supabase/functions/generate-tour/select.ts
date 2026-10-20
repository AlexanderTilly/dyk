export type Place = { id: string; lat: number; lng: number; themes: string[]; name: string }
export type Pick = { places: Place[]; reason?: 'too_few' }

const MIN_STOPS = 3
const MAX_STOPS = 10 // below the Mapbox Optimization ceiling of 12
const METRES_PER_STOP = 400 // narrations run minutes; 250 m packed too many stops
const NEAR_EQUAL = 3 // at most this many near-equal candidates are in the seeded draw
const NEAR_FACTOR = 1.5 // 'near-equal' = within 1.5x of the best distance (+ slack)
const NEAR_SLACK_M = 40

// mulberry32: small deterministic PRNG, no Math.random so seeds repeat.
function mulberry32(seed: number): () => number {
  let a = seed >>> 0
  return () => {
    a = (a + 0x6d2b79f5) >>> 0
    let t = a
    t = Math.imul(t ^ (t >>> 15), t | 1)
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

function metres(a: { lat: number; lng: number }, b: { lat: number; lng: number }): number {
  const R = 6371000
  const rad = Math.PI / 180
  const dLat = (b.lat - a.lat) * rad
  const dLng = (b.lng - a.lng) * rad
  const h = Math.sin(dLat / 2) ** 2 +
    Math.cos(a.lat * rad) * Math.cos(b.lat * rad) * Math.sin(dLng / 2) ** 2
  return 2 * R * Math.asin(Math.sqrt(h))
}

export function selectPlaces(
  places: Place[],
  opts: {
    start: { lat: number; lng: number }
    km: number
    theme: string
    exclude: string[]
    seed: number
  },
): Pick {
  // Stops of a loop sit well inside its length, hence a third.
  const radius = (opts.km * 1000) / 3
  const inRadius = places.filter(
    (p) => p.themes.includes(opts.theme) && metres(opts.start, p) <= radius,
  )
  if (inRadius.length < MIN_STOPS) return { places: [], reason: 'too_few' }

  // Prefer fresh places; fall back to excluded ones only to reach the minimum.
  const skip = new Set(opts.exclude)
  const fresh = inRadius.filter((p) => !skip.has(p.id))
  const pool = fresh.length >= MIN_STOPS ? fresh : inRadius

  const target = Math.min(
    MAX_STOPS,
    Math.max(MIN_STOPS, Math.round((opts.km * 1000) / METRES_PER_STOP)),
  )
  // Always leave at least two places unused (unless the pool is genuinely tiny).
  // This slack is what makes repeat pulls differ: with none, the set is forced
  // and no seed can vary it. Do not remove it as redundant.
  const want = Math.min(target, Math.max(MIN_STOPS, pool.length - 2), pool.length)
  const rand = mulberry32(opts.seed)
  const pickFrom = (ranked: { p: Place; d: number }[]) => {
    ranked.sort((x, y) => x.d - y.d || (x.p.id < y.p.id ? -1 : 1))
    // Only genuinely comparable candidates enter the draw, otherwise a far
    // outlier could win just because fewer than three good ones remain.
    const limit = ranked[0].d * NEAR_FACTOR + NEAR_SLACK_M
    const near = ranked.filter((r) => r.d <= limit).slice(0, NEAR_EQUAL)
    return near[Math.floor(rand() * near.length)].p
  }

  // Grow from the set, not from the start: ranking every candidate by distance
  // to the start yields a star of places that are each near the start but far
  // from one another, i.e. a long, dull walk. Adding whichever place is closest
  // to what we already hold yields a compact cluster that is quick to walk.
  const chosen: Place[] = [pickFrom(pool.map((p) => ({ p, d: metres(opts.start, p) })))]
  while (chosen.length < want) {
    const rest = pool.filter((p) => !chosen.includes(p))
    chosen.push(
      pickFrom(rest.map((p) => ({ p, d: Math.min(...chosen.map((c) => metres(c, p))) }))),
    )
  }
  return { places: chosen }
}
