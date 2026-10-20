import { assert, assertEquals } from 'jsr:@std/assert'
import { buildRoute } from './route.ts'
import type { Place } from './select.ts'

const mk = (i: number): Place => ({
  id: `p${i}`, name: `P${i}`, lat: 39.57 + i * 0.001, lng: 2.65 + i * 0.001, themes: ['ghosts'],
})
const places = [0, 1, 2, 3].map(mk)

function stub(status: number, body: unknown, calls: string[] = []) {
  return (url: string | URL | Request) => {
    calls.push(String(url))
    return Promise.resolve(new Response(JSON.stringify(body), { status }))
  }
}

Deno.test('reorders places by waypoint_index and returns trip distance', async () => {
  const body = {
    code: 'Ok',
    trips: [{ distance: 2100.4, geometry: { type: 'LineString', coordinates: [[2.65, 39.57]] } }],
    waypoints: [
      { waypoint_index: 0 }, { waypoint_index: 2 }, { waypoint_index: 3 }, { waypoint_index: 1 },
    ],
  }
  const calls: string[] = []
  const r = await buildRoute(places, 'loop', 'tok', stub(200, body, calls) as typeof fetch)
  assert(!('error' in r))
  assertEquals(r.ordered.map((p) => p.id), ['p0', 'p3', 'p1', 'p2'])
  assertEquals(r.meters, 2100)
  assertEquals((r.geojson as { type: string }).type, 'LineString')
  assert(calls[0].includes('roundtrip=true&source=first'))
  assert(!calls[0].includes('radiuses'))
  assert(calls[0].includes('/2.65,39.57;')) // lng,lat order
})

Deno.test('one_way uses destination=last', async () => {
  const calls: string[] = []
  const body = {
    trips: [{ distance: 10, geometry: {} }],
    waypoints: places.map((_, i) => ({ waypoint_index: i })),
  }
  await buildRoute(places, 'one_way', 'tok', stub(200, body, calls) as typeof fetch)
  assert(calls[0].includes('roundtrip=false&source=first&destination=last'))
})

Deno.test('fewer waypoints than places is an error with no ordering', async () => {
  const body = {
    trips: [{ distance: 10, geometry: {} }],
    waypoints: [{ waypoint_index: 0 }, { waypoint_index: 1 }],
  }
  const r = await buildRoute(places, 'loop', 'tok', stub(200, body) as typeof fetch)
  assert('error' in r)
  assert(r.error.includes('2 waypoints for 4 places'))
  assertEquals(Object.keys(r), ['error'])
})

Deno.test('non-200 reply returns an error carrying the status', async () => {
  const r = await buildRoute(places, 'loop', 'tok', stub(422, { message: 'x' }) as typeof fetch)
  assert('error' in r)
  assert(r.error.includes('422'))
})

Deno.test('more than 12 places is rejected before any call', async () => {
  const calls: string[] = []
  const many = Array.from({ length: 13 }, (_, i) => mk(i))
  const r = await buildRoute(many, 'loop', 'tok', stub(200, {}, calls) as typeof fetch)
  assert('error' in r)
  assertEquals(calls.length, 0)
})

Deno.test('a failing fetch never leaks the token', async () => {
  const boom = (url: string | URL | Request) => Promise.reject(new Error(`failed ${url}`))
  const r = await buildRoute(places, 'loop', 'SECRET', boom as unknown as typeof fetch)
  assert('error' in r)
  assert(!r.error.includes('SECRET'))
})
