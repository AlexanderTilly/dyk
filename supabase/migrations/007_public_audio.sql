-- DYK v1: make the audio bucket public so the app can stream uploaded MP3s
-- via a plain public URL (same as images). Revisit with signed URLs when
-- premium gating needs to protect audio.
update storage.buckets set public = true where id = 'hotspot-audio';
