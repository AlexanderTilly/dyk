-- DYK: video support for hotspots
-- Run in Supabase SQL Editor

-- Allow 'video' as a media type
alter table public.hotspot_media drop constraint if exists hotspot_media_media_type_check;
alter table public.hotspot_media add constraint hotspot_media_media_type_check
  check (media_type in ('audio', 'image', 'video'));

-- Public video bucket
insert into storage.buckets (id, name, public)
values ('hotspot-video', 'hotspot-video', true)
on conflict (id) do nothing;

-- Public read, admin write
create policy "video_public_read" on storage.objects
  for select using (bucket_id = 'hotspot-video');
create policy "video_admin_write" on storage.objects
  for all
  using (bucket_id = 'hotspot-video' and public.is_admin())
  with check (bucket_id = 'hotspot-video' and public.is_admin());
