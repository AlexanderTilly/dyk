-- Country layer: ISO code on citypacks for grouping, flags and filtering.
alter table public.citypacks
  add column if not exists country_code text;

-- Backfill the seeded cities from their country names.
update public.citypacks set country_code = c.code
from (values
  ('Spain', 'ES'), ('United Kingdom', 'GB'), ('France', 'FR'),
  ('Italy', 'IT'), ('Germany', 'DE'), ('Netherlands', 'NL'),
  ('Portugal', 'PT'), ('Austria', 'AT'), ('Czech Republic', 'CZ'),
  ('Czechia', 'CZ'), ('Greece', 'GR'), ('Sweden', 'SE'), ('UK', 'GB')
) as c(name, code)
where citypacks.country_code is null
  and lower(citypacks.country) = lower(c.name);
