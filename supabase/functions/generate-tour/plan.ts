import { type Pick, type Place, selectPlaces } from './select.ts'

// Why the exclude list is bounded: fed back unbounded, picks from earlier pulls
// drain the themed pool inside the radius. Measured on the real ghost places,
// 3 km rounds came back 8, 3, 3 stops and 2 km rounds 5, 5, 3, so a tourist who
// asked for 3 km was handed a 3-stop stub. Size for the asked distance comes
// first; variety is second. So (1) only the most recent ids count, and (2) if
// excluding still yields a smaller round than the same pull would without any
// exclusion, the exclusion is dropped for this pull.
export const MAX_EXCLUDE = 8

type Opts = {
  start: { lat: number; lng: number }
  km: number
  theme: string
  exclude: string[]
  seed: number
}

export function pickRound(places: Place[], opts: Opts): Pick {
  const recent = opts.exclude.slice(-MAX_EXCLUDE)
  const varied = selectPlaces(places, { ...opts, exclude: recent })
  if (varied.reason || recent.length === 0) return varied
  const full = selectPlaces(places, { ...opts, exclude: [] })
  return varied.places.length < full.places.length ? full : varied
}
