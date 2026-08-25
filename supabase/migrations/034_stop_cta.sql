-- CTA moves from the tour (creator) level to the stop it belongs to:
-- "Book your table" points at a restaurant stop, not at the creator.
alter table public.tour_stops
  add column if not exists cta_text text,
  add column if not exists cta_url text;
