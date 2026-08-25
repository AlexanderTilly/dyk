-- Fas 3: one narration per language. Audio rows in hotspot_media get a lang;
-- existing audio is English. The app picks the narration matching the user's
-- app language and falls back to English.

alter table public.hotspot_media
  add column if not exists lang text not null default 'en'
  check (lang in ('en', 'es', 'ca', 'de'));
