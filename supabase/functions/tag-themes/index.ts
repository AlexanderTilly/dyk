// Supabase Edge Function: tag-themes
// One-time tagging step for the tour generator: reads a hotspot's own text and
// decides which of the eight fixed themes it is about, so tours can later be
// filtered by theme without calling a model. Admin-only.
//
// Secrets required (Edge Functions → Secrets):
//   ANTHROPIC_API_KEY   — Anthropic API key
//
// Input:  { hotspot_ids: string[] }
// Output: { tagged: { id, themes }[], skipped: { id, reason }[] }

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import Anthropic from 'npm:@anthropic-ai/sdk'
import { cleanThemes } from './pick.ts'

// Edge functions cannot import from lib/, so this is a third copy of the keys.
// The other two: lib/models/themes.dart and dyk-admin/src/themes.ts. Change all three.
const THEMES = [
  'food_drink',
  'churches',
  'ghosts',
  'walls_gates',
  'palaces',
  'old_shops',
  'the_sea',
  'modernisme',
]

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

// `ghosts` is the headline category, not a judgement call: the walkable places
// measured for the ghost theme are exactly that category, so the model must not
// widen the set. It is added from `category` below and kept out of the enum.
const MODEL_THEMES = THEMES.filter((t) => t !== 'ghosts')

// Supabase kills a function that has sent nothing for 150 seconds, and the calls
// below are sequential, so the batch size has to be capped in code.
const MAX_IDS = 10

// Keyword matching tagged 126 of 148 places "royal" and 128 "maritime" because
// these descriptions are long and mention everything in passing. The prompt
// names that failure and tells the model where the weight lies.
const PROMPT =
  `You tag places in a walking-tour app with themes. Choose the themes this place is ABOUT, ` +
  `from this fixed list only:
` +
  `- food_drink: eating, drinking, bars, restaurants, bakeries, markets, food traditions
` +
  `- churches: churches, chapels, convents, cathedrals, religious life
` +
  `- walls_gates: city walls, gates, bastions, fortifications
` +
  `- palaces: palaces, noble mansions, patios of the aristocracy, royal or grand residences
` +
  `- old_shops: historic shops, workshops, crafts, traditional trades
` +
  `- the_sea: harbour, shoreline, seafaring, fishing, maritime history
` +
  `- modernisme: Modernista / Art Nouveau architecture and its architects

` +
  `The description is long and will touch several themes in passing: kings, the sea, churches and ` +
  `food come up almost everywhere in this city. Mentioning a theme does not make the place about it. ` +
  `A theme belongs only when it is what the place IS, or what its story is mainly about; a church ` +
  `whose text says it can be seen from the sea is not a maritime place, and a palace with a cafe in ` +
  `its courtyard is not about food. The name and the opening sentence weigh more than later detail. ` +
  `Prefer fewer themes: usually one, rarely three. Return an empty list if none fit.

`

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405)

  try {
    // --- Verify the caller is an admin ---
    const authHeader = req.headers.get('Authorization') ?? ''
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } },
    )
    const { data: isAdmin, error: adminErr } = await supabase.rpc('is_admin')
    if (adminErr) return json({ error: 'Auth check failed' }, 401)
    if (isAdmin !== true) return json({ error: 'Admin access required' }, 403)

    // --- Read input ---
    const body = await req.json().catch(() => ({}))
    const ids = body.hotspot_ids
    if (!Array.isArray(ids) || ids.length === 0 || !ids.every((i) => typeof i === 'string')) {
      return json({ error: 'hotspot_ids must be a non-empty array of strings' }, 400)
    }

    if (ids.length > MAX_IDS) {
      return json({ error: `At most ${MAX_IDS} hotspot_ids per call (150 s idle timeout)` }, 400)
    }

    const apiKey = Deno.env.get('ANTHROPIC_API_KEY')
    if (!apiKey) return json({ error: 'ANTHROPIC_API_KEY secret not configured' }, 500)
    const client = new Anthropic({ apiKey })

    // Writes bypass RLS with the service role; the admin check above is the gate.
    const admin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )
    const { data: rows, error: readErr } = await admin
      .from('hotspots')
      .select('id, name, subtitle, description, category, themes')
      .in('id', ids)
    if (readErr) return json({ error: `Read failed: ${readErr.message}` }, 500)

    const tagged: { id: string; themes: string[] }[] = []
    const skipped: { id: string; reason: string }[] = []
    for (const row of rows ?? []) {
      const response = await client.messages.create({
        model: 'claude-opus-5',
        max_tokens: 1000,
        output_config: {
          format: {
            type: 'json_schema',
            schema: {
              type: 'object',
              properties: {
                themes: { type: 'array', items: { type: 'string', enum: MODEL_THEMES } },
              },
              required: ['themes'],
              additionalProperties: false,
            },
          },
        },
        messages: [
          {
            role: 'user',
            content: PROMPT + JSON.stringify({
              name: row.name ?? null,
              subtitle: row.subtitle ?? null,
              description: row.description ?? null,
            }),
          },
        ],
      })

      // A bad reply skips this place only; the caller sees why in `skipped`.
      if (response.stop_reason === 'refusal') {
        skipped.push({ id: row.id, reason: 'refusal' })
        continue
      }
      const textBlock = response.content.find((b) => b.type === 'text')
      if (!textBlock || textBlock.type !== 'text') {
        skipped.push({ id: row.id, reason: 'no text in reply' })
        continue
      }
      let parsed: { themes?: unknown }
      try {
        parsed = JSON.parse(textBlock.text)
      } catch {
        skipped.push({ id: row.id, reason: 'malformed reply' })
        continue
      }

      // An empty or unusable reply must never erase what is stored, and headline
      // places keep `ghosts` whatever the model says.
      const existing: string[] = row.themes ?? []
      const fromModel = cleanThemes(parsed.themes, MODEL_THEMES)
      const base = fromModel.length > 0 ? fromModel : existing
      const themes = row.category === 'headline'
        ? ['ghosts', ...base.filter((t) => t !== 'ghosts')].slice(0, 3)
        : base
      if (fromModel.length === 0 && themes.length === existing.length) {
        skipped.push({ id: row.id, reason: 'no themes returned, kept existing' })
        continue
      }
      const { error: writeErr } = await admin
        .from('hotspots')
        .update({ themes })
        .eq('id', row.id)
      if (writeErr) return json({ error: `Write failed: ${writeErr.message}` }, 500)
      tagged.push({ id: row.id, themes })
    }

    return json({ tagged, skipped })
  } catch (e) {
    return json({ error: `Unexpected error: ${e}` }, 500)
  }
})
