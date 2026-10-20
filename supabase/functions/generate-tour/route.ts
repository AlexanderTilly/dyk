import type { Place } from './select.ts'

export type Shape = 'loop' | 'one_way'
export type Routed = { ordered: Place[]; meters: number; geojson: object }

const MAX_WAYPOINTS = 12 // Mapbox Optimization API ceiling
// Deliberately NO `radiuses` parameter. With a numeric radiuses value Mapbox
// rejects the whole trip (HTTP 200, code NoSegment, trips: []) when any one stop
// cannot snap to the walking graph within it. Hotspot coordinates sit inside
// cathedrals, courtyards and a hilltop castle, so they routinely cannot: measured
// against live Mapbox on the real ghost places, 6 of 15 failed individually at
// 40 m, and every numeric value tried (40-500) failed on a full round. This is
// the admin panel's trick (ToursPage.tsx) and it is wrong for generated tours,
// whose stops are not hand-placed on streets. Do not reintroduce it.

export async function buildRoute(
  places: Place[],
  shape: Shape,
  token: string,
  fetchImpl: typeof fetch,
): Promise<Routed | { error: string }> {
  if (places.length < 2) return { error: 'Need at least 2 places to route' }
  if (places.length > MAX_WAYPOINTS) {
    return { error: `At most ${MAX_WAYPOINTS} places can be routed, got ${places.length}` }
  }
  const coords = places.map((p) => `${p.lng},${p.lat}`).join(';')
  const mode = shape === 'loop'
    ? 'roundtrip=true&source=first'
    : 'roundtrip=false&source=first&destination=last'
  const url =
    `https://api.mapbox.com/optimized-trips/v1/mapbox/walking/${coords}?${mode}` +
    `&geometries=geojson&overview=full&access_token=${token}`

  let res: Response
  try {
    res = await fetchImpl(url)
  } catch (_e) {
    // Fixed string: a Deno fetch failure carries the full URL, token included.
    return { error: 'Mapbox request failed' }
  }
  // Never echo the URL: it carries the token.
  if (res.status !== 200) return { error: `Mapbox returned status ${res.status}` }

  const body = await res.json().catch(() => null)
  const trip = body?.trips?.[0]
  const wps: { waypoint_index?: number }[] | undefined = body?.waypoints
  if (!trip || !Array.isArray(wps)) return { error: 'Mapbox reply had no trip' }
  // Mapbox drops waypoints it cannot snap; a short list would silently lose stops.
  if (wps.length !== places.length) {
    return { error: `Mapbox returned ${wps.length} waypoints for ${places.length} places` }
  }
  const ordered: Place[] = new Array(places.length)
  for (let i = 0; i < places.length; i++) {
    const idx = wps[i].waypoint_index
    if (!Number.isInteger(idx) || idx! < 0 || idx! >= places.length || ordered[idx!]) {
      return { error: 'Mapbox returned an invalid waypoint order' }
    }
    ordered[idx!] = places[i]
  }
  return { ordered, meters: Math.round(trip.distance), geojson: trip.geometry }
}
