-- Creator collab tours: branded presentation, CTA link and a per-tour
-- packing checklist. Revenue split (50/50) is handled business-side.

alter table public.tours
  add column if not exists creator_name text,
  add column if not exists creator_handle text,   -- e.g. kikilicious_83 (no @)
  add column if not exists creator_avatar text,   -- storage path
  add column if not exists creator_intro text,    -- personal intro on the detail page
  add column if not exists cta_text text,         -- e.g. "Book your table"
  add column if not exists cta_url text,
  add column if not exists checklist jsonb,       -- ["Good shoes", "Water bottle", ...]
  add column if not exists is_creator boolean not null default false;

update public.tours set is_creator = true where creator_name is not null;
