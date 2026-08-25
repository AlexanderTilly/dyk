-- Allow free-text "year founded" (e.g. "1229", "12th century", "1100 century").
alter table public.hotspots
  alter column year type text using year::text;
