// Supabase Edge Function: generate-tts
// Turns a hotspot Description into narration audio via ElevenLabs.
// The ElevenLabs API key + voice id live as secrets here — never in the app.
//
// Secrets required (Edge Functions → Secrets):
//   ELEVENLABS_API_KEY   — your ElevenLabs API key (Text-to-Speech access)
//   ELEVENLABS_VOICE_ID  — the voice id to narrate with
//
// Returns: { audio_base64, content_type } — the admin previews it, then
// approves to attach it as the hotspot's audio. Nothing is stored here.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const MAX_CHARS = 5000

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

// ArrayBuffer → base64 (chunked to avoid call-stack limits on large audio).
function toBase64(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer)
  let binary = ''
  const chunk = 0x8000
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunk))
  }
  return btoa(binary)
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

    // --- Read input (per-generation controls from the admin) ---
    const body = await req.json().catch(() => ({}))
    const clean = (body.text ?? '').toString().trim()
    if (!clean) return json({ error: 'No text provided' }, 400)
    if (clean.length > MAX_CHARS) {
      return json(
        { error: `Text too long (${clean.length}/${MAX_CHARS} chars). Trim the description.` },
        400,
      )
    }

    const apiKey = Deno.env.get('ELEVENLABS_API_KEY')
    // Admin can pick a voice per generation; fall back to the default secret.
    const voiceId =
      (typeof body.voice_id === 'string' && body.voice_id.trim()) ||
      Deno.env.get('ELEVENLABS_VOICE_ID')
    if (!apiKey || !voiceId) {
      return json({ error: 'ElevenLabs secrets not configured' }, 500)
    }

    // Fixed in config (changeable via secrets without code edits):
    const modelId = Deno.env.get('ELEVENLABS_MODEL_ID') ?? 'eleven_v3'
    const stability = parseFloat(Deno.env.get('ELEVENLABS_STABILITY') ?? '0.5')

    // Admin-controlled per generation:
    const useSpeakerBoost = body.use_speaker_boost !== false // default on
    const speed = typeof body.speed === 'number' ? body.speed : undefined
    const languageCode =
      typeof body.language_code === 'string' && body.language_code.trim()
        ? body.language_code.trim()
        : undefined

    // Optional per-generation overrides (character voices like "Scary" want
    // low stability + high style to keep their drama).
    const stabilityOverride =
      typeof body.stability === 'number' ? body.stability : undefined
    const style = typeof body.style === 'number' ? body.style : undefined

    const voiceSettings: Record<string, unknown> = {
      stability: stabilityOverride ?? stability,
      use_speaker_boost: useSpeakerBoost,
    }
    if (style !== undefined) voiceSettings.style = style
    if (speed !== undefined) voiceSettings.speed = speed

    const payload: Record<string, unknown> = {
      text: clean,
      model_id: modelId,
      voice_settings: voiceSettings,
    }
    if (languageCode) payload.language_code = languageCode

    // --- ElevenLabs Text-to-Speech ---
    const ttsRes = await fetch(
      `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}?output_format=mp3_44100_128`,
      {
        method: 'POST',
        headers: {
          'xi-api-key': apiKey,
          'Content-Type': 'application/json',
          Accept: 'audio/mpeg',
        },
        body: JSON.stringify(payload),
      },
    )

    if (!ttsRes.ok) {
      const detail = await ttsRes.text()
      return json({ error: `ElevenLabs error (${ttsRes.status}): ${detail}` }, 502)
    }

    const audioBuffer = await ttsRes.arrayBuffer()
    return json({
      audio_base64: toBase64(audioBuffer),
      content_type: 'audio/mpeg',
      chars: clean.length,
    })
  } catch (e) {
    return json({ error: `Unexpected error: ${e}` }, 500)
  }
})
