import type { Place } from './select.ts'

export type Shape = 'loop' | 'one_way'
export type Routed = { ordered: Place[]; meters: number; geojson: object }
// `structural` errors fail identically for every seed, so callers must not retry them.
export type RouteError = { error: string; structural?: true }

const MAX_WAYPOINTS = 12 // Mapbox Optimization API ceiling
// Deliberately NO `radiuses` parameter. With a numeric radiuses value Mapbox
// rejects the whole trip (HTTP 200, code NoSegment, trips: []) when any one stop
// cannot snap to the walking graph within it. Hotspot coordinates sit inside
// cathedrals, courtyards and a hilltop castle, so they routinely cannot: measured
// against live Mapbox on the real ghost places, 6 of 15 failed individually at
// 40 m, and every numeric value tried (40-500) failed on a full round. This is
// the admin panel's trick (ToursPage.tsx) and it is wrong for generated tours,
// whose stops are not hand-placed on streets. Do not reintroduce it.

// `start` is the person's position. It is sent as the FIRST coordinate (pinned by
// source=first) so a loop really returns to the person, a one-way really begins
// there, and the approach leg counts in the distance. Without it a loop closed on
// stop 1 and the stored distance missed the walk to it (measured live: 3 km loop
// from Placa d'Espanya, 1.54 km stops-only vs 3.05 km with start). The start is
// never part of `ordered`.
export async function buildRoute(
  places: Place[],
  shape: Shape,
  token: string,
  fetchImpl: typeof fetch,
  start?: { lat: number; lng: number },
): Promise<Routed | RouteError> {
  if (places.length < 2) return { error: 'Need at least 2 places to route', structural: true }
  const points: { lat: number; lng: number }[] = start ? [start, ...places] : places
  if (points.length > MAX_WAYPOINTS) {
    return {
      error: `At most ${MAX_WAYPOINTS} waypoints can be routed, got ${points.length}`,
      structural: true,
    }
  }
  const coords = points.map((p) => `${p.lng},${p.lat}`).join(';')
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
  if (wps.length !== points.length) {
    return {
      error: `Mapbox returned ${wps.length} waypoints for ${points.length} places`,
      structural: true,
    }
  }
  const slots: (typeof points[number] | undefined)[] = new Array(points.length)
  for (let i = 0; i < points.length; i++) {
    const idx = wps[i].waypoint_index
    if (!Number.isInteger(idx) || idx! < 0 || idx! >= points.length || slots[idx!]) {
      return { error: 'Mapbox returned an invalid waypoint order', structural: true }
    }
    slots[idx!] = points[i]
  }
  const all = slots as Place[]
  // source=first keeps the start at index 0; drop it from the stop list.
  const ordered = start ? all.slice(1) : all
  return { ordered, meters: Math.round(trip.distance), geojson: trip.geometry }
}
