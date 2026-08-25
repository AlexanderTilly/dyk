-- Switch pricing to euros, stored as integer cents (499 = €4.99).
-- Cities: €4.99 to unlock. Tours: free (0) or €4.99.

alter table public.citypacks rename column price_sek to price_cents;
update public.citypacks set price_cents = 499 where price_cents > 0;

alter table public.tours rename column price_sek to price_cents;
update public.tours set price_cents = 499 where price_cents > 0;
