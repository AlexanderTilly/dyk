// Supabase Edge Function: generate-tour
// Tour generator: picks themed places near a start point, routes them on streets
// and writes the result as an unpublished, generated tour with its stops.
//
// Secrets required (Edge Functions -> Secrets):
//   MAPBOX_TOKEN   - Mapbox token for the Optimization API (server-side; not the client token)
//
// Input:  { lat, lng, km, shape: 'loop'|'one_way', theme, exclude?: string[], citypack_id, seed? }
// Output: { tour_id, title, meters, minutes, stops: [...], geojson }

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { buildRoute, type Routed, type Shape } from './route.ts'
import { pickRound } from './plan.ts'
import type { Place } from './select.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

// Same keys as lib/models/themes.dart; English names for the tour title.
const THEME_LABELS: Record<string, string> = {
  food_drink: 'Food & Drink',
  churches: 'Churches',
  ghosts: 'Ghosts',
  walls_gates: 'Walls & Gates',
  palaces: 'Palaces',
  old_shops: 'Old Shops',
  the_sea: 'The Sea',
  modernisme: 'Modernisme',
}

const CANDIDATES = 6
const TOLERANCE = 0.15
const WALK_KMH = 4.8

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405)

  try {
    const body = await req.json().catch(() => ({}))
    const { lat, lng, km, shape, theme, citypack_id } = body
    const exclude = body.exclude ?? []
    if (typeof lat !== 'number' || typeof lng !== 'number' || !(typeof km === 'number' && km > 0)) {
      return json({ error: 'lat, lng and km must be numbers (km > 0)' }, 400)
    }
    if (shape !== 'loop' && shape !== 'one_way') {
      return json({ error: "shape must be 'loop' or 'one_way'" }, 400)
    }
    if (typeof theme !== 'string' || !(theme in THEME_LABELS)) {
      return json({ error: 'Unknown theme' }, 400)
    }
    if (typeof citypack_id !== 'string') return json({ error: 'citypack_id required' }, 400)
    if (!Array.isArray(exclude) || !exclude.every((i: unknown) => typeof i === 'string')) {
      return json({ error: 'exclude must be an array of strings' }, 400)
    }

    const token = Deno.env.get('MAPBOX_TOKEN')
    if (!token) return json({ error: 'MAPBOX_TOKEN secret not configured' }, 500)

    // Hotspots are readable by anyone; writes below use the service role.
    const admin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )
    const { data: rows, error: readErr } = await admin
      .from('hotspots')
      .select('id, name, lat, lng, themes')
      .eq('citypack_id', citypack_id)
    if (readErr) return json({ error: `Read failed: ${readErr.message}` }, 500)
    const places: Place[] = (rows ?? []).map((r) => ({
      id: r.id, name: r.name, lat: r.lat, lng: r.lng, themes: r.themes ?? [],
    }))

    const start = { lat, lng }
    const baseSeed = Number.isInteger(body.seed) ? body.seed : Math.floor(Math.random() * 2 ** 31)
    const askedM = km * 1000
    let best: { routed: Routed; seed: number; dist: number } | null = null
    let lastError: string | null = null

    for (let i = 0; i < CANDIDATES; i++) {
      const seed = baseSeed + i
      const pick = pickRound(places, { start, km, theme, exclude, seed })
      if (pick.reason === 'too_few') {
        return json({
          error: 'too_few',
          message: `Not enough "${THEME_LABELS[theme]}" places within walking range of the start`,
          theme,
        }, 422)
      }
      const routed = await buildRoute(pick.places, shape as Shape, token, fetch)
      if ('error' in routed) {
        lastError = routed.error
        continue
      }
      const dist = Math.abs(routed.meters - askedM) / askedM
      if (!best || dist < best.dist) best = { routed, seed, dist }
      if (dist <= TOLERANCE) break
    }
    if (!best) return json({ error: `Routing failed: ${lastError}` }, 502)

    const { routed, seed } = best
    const minutes = Math.round((routed.meters / 1000 / WALK_KMH) * 60)
    const title = `${THEME_LABELS[theme]} walk, ${km} km`

    const { data: tour, error: tourErr } = await admin
      .from('tours')
      .insert({
        citypack_id,
        type: 'custom', // generated tours are distinguishable; 'custom' always satisfies the CHECK
        title,
        price_sek: 0,
        is_published: false,
        is_generated: true,
        generated_params: { lat, lng, km, shape, theme, exclude, seed },
        distance_meters: routed.meters,
        est_minutes: minutes,
        route_geojson: routed.geojson,
      })
      .select('id')
      .single()
    if (tourErr || !tour) return json({ error: `Tour insert failed: ${tourErr?.message}` }, 500)

    // lat/lng/title are written on the stop itself: the app backfills only name,
    // audio and image from the hotspot, so a stop without coordinates would break
    // the map and arrival detection.
    const stopRows = routed.ordered.map((p, i) => ({
      tour_id: tour.id,
      order_index: i,
      hotspot_id: p.id,
      title: p.name,
      lat: p.lat,
      lng: p.lng,
    }))
    const { error: stopErr } = await admin.from('tour_stops').insert(stopRows)
    if (stopErr) {
      await admin.from('tours').delete().eq('id', tour.id) // no half-written tour
      return json({ error: `Stops insert failed: ${stopErr.message}` }, 500)
    }

    return json({
      tour_id: tour.id,
      title,
      meters: routed.meters,
      minutes,
      stops: stopRows,
      geojson: routed.geojson,
    })
  } catch (e) {
    return json({ error: `Unexpected error: ${e}` }, 500)
  }
})
