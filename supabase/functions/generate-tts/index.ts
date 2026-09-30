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
  // Without this the browser hides the x-used-* headers from JavaScript.
  // Custom response headers are not readable by default, whatever the
  // server sends — the same rule that makes access-control-allow-origin
  // itself unreadable.
  'Access-Control-Expose-Headers':
    'x-used-voice, x-used-model, x-used-language, x-used-settings, x-chars',
}

// ElevenLabs per-request limit. Must equal TTS_MAX_CHARS in
// dyk-admin/src/lib/limits.ts — the admin's character counter and
// "Generate narration" button are gated on the same number.
const MAX_CHARS = 5000

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
    // eleven_v3 — back to it after a trial of multilingual_v2 sounded worse,
    // especially in Spanish and Catalan. v3 can vary between takes of the same
    // text; what fixes the ACCENT is the voice, not the model: there is no
    // Spain-vs-Latin-America setting (language_code is plain ISO 639-1, 'es'),
    // so Castilian comes from choosing a Castilian voice.
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
    // language_code is silently ignored by models that do not support it —
    // ElevenLabs documents exactly that — so sending it regardless made the
    // admin report a language that was never enforced. Send it only where it
    // changes something, and report honestly below.
    const modelHonoursLanguageCode =
      modelId === 'eleven_v3' ||
      modelId === 'eleven_flash_v2_5' ||
      modelId === 'eleven_turbo_v2_5'
    const sentLanguageCode =
      modelHonoursLanguageCode && languageCode ? languageCode : undefined

    const payload: Record<string, unknown> = {
      text: clean,
      model_id: modelId,
      voice_settings: voiceSettings,
    }
    if (sentLanguageCode) payload.language_code = sentLanguageCode

    // --- ElevenLabs Text-to-Speech ---
    // The STREAMING endpoint, deliberately. Supabase kills a function that
    // has sent nothing after 150 seconds — an idle timeout, not a duration
    // one — and eleven_v3 needs roughly 45ms per character, so anything past
    // ~3,300 characters used to die before it could answer. Measured: 2,790
    // characters took 124 seconds. Streaming puts the first bytes on the wire
    // within a second or two, so the idle clock never runs out; the 400-second
    // wall clock on Pro then covers even a full 5,000-character text.
    const ttsRes = await fetch(
      `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}/stream?output_format=mp3_44100_128`,
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

    // Piped, not buffered: returning the upstream body hands the headers back
    // immediately and the audio follows as it is produced. Buffering it here
    // would reintroduce exactly the wait this change exists to remove.
    //
    // What produced the clip travels in headers now, because the body is the
    // audio. Keeping it matters: a voice that drifts — because a secret
    // changed, or because ElevenLabs silently ignored an unsupported
    // language_code — can otherwise only be diagnosed by reading old commits
    // and guessing. That happened with Spanish in August 2026.
    return new Response(ttsRes.body, {
      headers: {
        ...corsHeaders,
        'Content-Type': 'audio/mpeg',
        'x-used-voice': voiceId,
        'x-used-model': modelId,
        'x-used-language': sentLanguageCode ?? '',
        'x-used-settings': JSON.stringify(voiceSettings),
        'x-chars': String(clean.length),
      },
    })
  } catch (e) {
    return json({ error: `Unexpected error: ${e}` }, 500)
  }
})
