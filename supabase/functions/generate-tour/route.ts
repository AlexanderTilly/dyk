import type { Place } from './select.ts'

export type Shape = 'loop' | 'one_way'
export type Routed = { ordered: Place[]; meters: number; geojson: object }

const MAX_WAYPOINTS = 12 // Mapbox Optimization API ceiling
// Snap each waypoint to the street within this many metres so stops do not
// spur into dead ends. Same value and floor as dyk-admin ToursPage.tsx.
const SNAP_M = 40
const SNAP_MIN_M = 30

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
  const radiuses = places.map(() => Math.max(SNAP_M, SNAP_MIN_M)).join(';')
  const mode = shape === 'loop'
    ? 'roundtrip=true&source=first'
    : 'roundtrip=false&source=first&destination=last'
  const url =
    `https://api.mapbox.com/optimized-trips/v1/mapbox/walking/${coords}?${mode}` +
    `&geometries=geojson&overview=full&radiuses=${radiuses}&access_token=${token}`

  let res: Response
  try {
    res = await fetchImpl(url)
  } catch (e) {
    return { error: `Mapbox request failed: ${e}` }
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
