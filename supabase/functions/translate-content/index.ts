// Supabase Edge Function: translate-content
// Translates hotspot/tour content (name, subtitle, description, facts) into
// Spanish, Catalan or German via the Claude API. Admin-only.
//
// Secrets required (Edge Functions → Secrets):
//   ANTHROPIC_API_KEY   — Anthropic API key
//
// Input:  { target_lang: "es"|"ca"|"de", content: { name?, subtitle?, description?, facts?: string[] } }
// Output: { translated: { ...same keys, translated values... } }

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import Anthropic from 'npm:@anthropic-ai/sdk'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const LANG_NAMES: Record<string, string> = {
  es: 'Spanish (as spoken in Spain)',
  ca: 'Catalan',
  de: 'German',
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

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
    const targetLang = body.target_lang as string
    const content = body.content as Record<string, unknown>
    if (!LANG_NAMES[targetLang]) return json({ error: 'target_lang must be es, ca or de' }, 400)
    if (!content || typeof content !== 'object') return json({ error: 'No content provided' }, 400)

    const apiKey = Deno.env.get('ANTHROPIC_API_KEY')
    if (!apiKey) return json({ error: 'ANTHROPIC_API_KEY secret not configured' }, 500)

    const client = new Anthropic({ apiKey })

    const response = await client.messages.create({
      model: 'claude-opus-5',
      max_tokens: 16000,
      output_config: {
        format: {
          type: 'json_schema',
          schema: {
            type: 'object',
            properties: {
              name: { type: ['string', 'null'] },
              subtitle: { type: ['string', 'null'] },
              description: { type: ['string', 'null'] },
              facts: { type: ['array', 'null'], items: { type: 'string' } },
            },
            required: ['name', 'subtitle', 'description', 'facts'],
            additionalProperties: false,
          },
        },
      },
      messages: [
        {
          role: 'user',
          content:
            `Translate the following tourist-guide content from English to ${LANG_NAMES[targetLang]}. ` +
            `It is spoken-word audio-guide material for the city travel app "Did You Know?" — keep the warm, ` +
            `storytelling tone, keep proper names (places, people, dishes) in their original form, and keep ` +
            `the same paragraph structure. Translate every field that is present; return null for fields that ` +
            `are null or missing. "facts" is an array — translate each entry, keeping the same order and count.\n\n` +
            JSON.stringify({
              name: content.name ?? null,
              subtitle: content.subtitle ?? null,
              description: content.description ?? null,
              facts: content.facts ?? null,
            }),
        },
      ],
    })

    if (response.stop_reason === 'refusal') {
      return json({ error: 'Translation was declined — try adjusting the text.' }, 502)
    }
    const textBlock = response.content.find((b) => b.type === 'text')
    if (!textBlock || textBlock.type !== 'text') {
      return json({ error: 'No translation returned' }, 502)
    }
    const translated = JSON.parse(textBlock.text)
    return json({ translated })
  } catch (e) {
    return json({ error: `Unexpected error: ${e}` }, 500)
  }
})
