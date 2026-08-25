-- Per-city hero image for the Tours tab header (storage path).
-- The app falls back to the bundled Palma image when unset.
alter table public.citypacks
  add column if not exists header_image text;
