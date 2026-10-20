// Supabase Edge Function: tag-themes
// One-time tagging step for the tour generator: reads a hotspot's own text and
// decides which of the eight fixed themes it is about, so tours can later be
// filtered by theme without calling a model. Admin-only.
//
// Secrets required (Edge Functions → Secrets):
//   ANTHROPIC_API_KEY   — Anthropic API key
//
// Input:  { hotspot_ids: string[] }
// Output: { tagged: { id: string, themes: string[] }[] }

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

// "About" vs "mentions" is spelled out because description text is full of
// incidental detail (a church near the harbour, a palace with a café) and a
// loose tagger would bury every theme under every neighbour.
const PROMPT =
  `You tag places in a walking-tour app with themes. Choose the themes this place is ABOUT, ` +
  `from this fixed list only:\n` +
  `- food_drink: eating, drinking, bars, restaurants, bakeries, markets, food traditions\n` +
  `- churches: churches, chapels, convents, cathedrals, religious life\n` +
  `- ghosts: ghosts, legends, hauntings, curses, murders, eerie or macabre stories\n` +
  `- walls_gates: city walls, gates, bastions, fortifications\n` +
  `- palaces: palaces, noble mansions, patios of the aristocracy, royal or grand residences\n` +
  `- old_shops: historic shops, workshops, crafts, traditional trades\n` +
  `- the_sea: harbour, shoreline, seafaring, fishing, maritime history\n` +
  `- modernisme: Modernista / Art Nouveau architecture and its architects\n\n` +
  `A theme belongs only when the place itself is about it: it is what the place is, or what its ` +
  `story is mainly about. A passing mention does not count; a church whose text says it can be ` +
  `seen from the sea is not a maritime place, and a palace with a café in its courtyard is not ` +
  `about food. Prefer fewer themes: usually one, rarely three. Return an empty list if none fit.\n\n`

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
      .select('id, name, subtitle, description')
      .in('id', ids)
    if (readErr) return json({ error: `Read failed: ${readErr.message}` }, 500)

    const tagged: { id: string; themes: string[] }[] = []
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
                themes: { type: 'array', items: { type: 'string', enum: THEMES } },
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

      // A declined or empty reply skips this place rather than failing the batch.
      if (response.stop_reason === 'refusal') continue
      const textBlock = response.content.find((b) => b.type === 'text')
      if (!textBlock || textBlock.type !== 'text') continue

      const themes = cleanThemes(JSON.parse(textBlock.text).themes, THEMES)
      const { error: writeErr } = await admin
        .from('hotspots')
        .update({ themes })
        .eq('id', row.id)
      if (writeErr) return json({ error: `Write failed: ${writeErr.message}` }, 500)
      tagged.push({ id: row.id, themes })
    }

    return json({ tagged })
  } catch (e) {
    return json({ error: `Unexpected error: ${e}` }, 500)
  }
})
