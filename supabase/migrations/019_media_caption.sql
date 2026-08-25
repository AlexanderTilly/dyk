-- Optional per-image caption, shown when a user taps an image in the app.
alter table public.hotspot_media
  add column if not exists caption text;
