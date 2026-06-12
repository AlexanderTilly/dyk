# Palma Explorer — Plan 1: Supabase Backend

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Skapa Supabase-projektet med databas-schema, storage-buckets och RLS-regler som driver hela Palma Explorer-plattformen.

**Architecture:** Supabase (Postgres) håller alla hotspots, CityPacks, Hot Deals och köp. Row Level Security styr vad gratis- vs premium-användare får se. Supabase Storage lagrar MP3-filer och bilder. Allt byggs med SQL-migrationer versionshanterade i `supabase/migrations/`.

**Tech Stack:** Supabase CLI, PostgreSQL, Supabase Storage, Supabase Auth

---

## Filstruktur

```
supabase/
  migrations/
    001_schema.sql          — alla tabeller
    002_rls.sql             — Row Level Security policies
    003_storage.sql         — storage buckets + policies
    004_seed.sql            — testdata (Palma-hotspots)
```

---

### Task 1: Installera Supabase CLI och initiera projekt

**Files:**
- Create: `supabase/config.toml` (genereras av CLI)

- [ ] **Steg 1: Installera Supabase CLI**

```powershell
winget install Supabase.CLI
# Verifiera:
supabase --version
# Förväntat: supabase version X.X.X
```

- [ ] **Steg 2: Logga in**

```powershell
supabase login
# Öppnar webbläsaren — logga in med ditt Supabase-konto
```

- [ ] **Steg 3: Skapa nytt Supabase-projekt på supabase.com**

Gå till https://supabase.com/dashboard → New project
- Name: `palma-explorer`
- Password: (spara i 1Password)
- Region: `eu-central-1` (Frankfurt — närmast Spanien)

Notera: `Project URL` och `anon key` — behövs senare.

- [ ] **Steg 4: Initiera lokalt**

```powershell
cd C:\Users\tilly\palma_app
supabase init
supabase link --project-ref <din-project-ref>
# project-ref hittas i Supabase dashboard URL: supabase.com/dashboard/project/<REF>
```

- [ ] **Steg 5: Commit**

```bash
git add supabase/
git commit -m "chore: initialize supabase project

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 2: Databas-schema (migration 001)

**Files:**
- Create: `supabase/migrations/001_schema.sql`

- [ ] **Steg 1: Skapa migrations-fil**

Skapa `supabase/migrations/001_schema.sql`:

```sql
-- CityPacks: en stad = ett pack (t.ex. "Palma de Mallorca")
create table public.citypacks (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  city text not null,
  country text not null,
  description text,
  price_sek integer not null default 49,
  is_published boolean not null default false,
  created_at timestamptz not null default now()
);

-- Hotspots: platser inom ett CityPack
create table public.hotspots (
  id uuid primary key default gen_random_uuid(),
  citypack_id uuid not null references public.citypacks(id) on delete cascade,
  slug text not null unique,  -- t.ex. "catedral", "placa_major"
  name text not null,
  subtitle text,
  description text,
  lat double precision not null,
  lng double precision not null,
  radius_meters integer not null default 50,
  year integer,
  is_free boolean not null default false,  -- syns för gratis-användare
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

-- Media kopplat till hotspot (ljud + bilder)
create table public.hotspot_media (
  id uuid primary key default gen_random_uuid(),
  hotspot_id uuid not null references public.hotspots(id) on delete cascade,
  media_type text not null check (media_type in ('audio', 'image')),
  storage_path text not null,  -- t.ex. "hotspot-audio/catedral.mp3"
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

-- Hot Deals: erbjudanden för gratis-användare
create table public.hot_deals (
  id uuid primary key default gen_random_uuid(),
  citypack_id uuid not null references public.citypacks(id) on delete cascade,
  business_name text not null,
  offer_text text not null,  -- t.ex. "15% rabatt på lunch idag"
  lat double precision not null,
  lng double precision not null,
  radius_meters integer not null default 80,
  is_active boolean not null default true,
  valid_from timestamptz,
  valid_to timestamptz,
  created_at timestamptz not null default now()
);

-- Köp: vilka users har köpt vilket CityPack
create table public.user_purchases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  citypack_id uuid not null references public.citypacks(id) on delete cascade,
  purchased_at timestamptz not null default now(),
  platform text not null check (platform in ('ios', 'android', 'web')),
  unique(user_id, citypack_id)
);

-- Index för geo-lookups
create index hotspots_citypack_id_idx on public.hotspots(citypack_id);
create index hot_deals_citypack_id_idx on public.hot_deals(citypack_id);
create index user_purchases_user_id_idx on public.user_purchases(user_id);
```

- [ ] **Steg 2: Kör migration lokalt**

```powershell
supabase db reset
# Förväntat: "Database reset successful"
```

- [ ] **Steg 3: Pusha till Supabase**

```powershell
supabase db push
# Förväntat: "Applying migration 001_schema.sql... Done"
```

- [ ] **Steg 4: Commit**

```bash
git add supabase/migrations/001_schema.sql
git commit -m "feat: add database schema for citypacks, hotspots, deals, purchases

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 3: Row Level Security (migration 002)

**Files:**
- Create: `supabase/migrations/002_rls.sql`

- [ ] **Steg 1: Skapa RLS-migration**

Skapa `supabase/migrations/002_rls.sql`:

```sql
-- Aktivera RLS på alla tabeller
alter table public.citypacks enable row level security;
alter table public.hotspots enable row level security;
alter table public.hotspot_media enable row level security;
alter table public.hot_deals enable row level security;
alter table public.user_purchases enable row level security;

-- Helper: har användaren köpt detta CityPack?
create or replace function public.has_purchased(p_citypack_id uuid)
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 from public.user_purchases
    where user_id = auth.uid()
    and citypack_id = p_citypack_id
  );
$$;

-- CITYPACKS: alla ser publicerade packs
create policy "citypacks_public_read"
  on public.citypacks for select
  using (is_published = true);

-- HOTSPOTS: gratis-hotspots syns för alla
--           premium-hotspots syns om man köpt CityPacket
create policy "hotspots_free_read"
  on public.hotspots for select
  using (
    is_free = true
    or public.has_purchased(citypack_id)
  );

-- HOTSPOT_MEDIA: samma logik som hotspot
create policy "hotspot_media_read"
  on public.hotspot_media for select
  using (
    exists (
      select 1 from public.hotspots h
      where h.id = hotspot_id
      and (h.is_free = true or public.has_purchased(h.citypack_id))
    )
  );

-- HOT DEALS: visas bara för användare SOM INTE har köpt packen (gratis-users)
create policy "hot_deals_free_users_read"
  on public.hot_deals for select
  using (
    is_active = true
    and (valid_from is null or valid_from <= now())
    and (valid_to is null or valid_to >= now())
    and not public.has_purchased(citypack_id)
  );

-- USER_PURCHASES: varje user ser bara sina egna köp
create policy "user_purchases_own"
  on public.user_purchases for select
  using (user_id = auth.uid());

create policy "user_purchases_insert"
  on public.user_purchases for insert
  with check (user_id = auth.uid());
```

- [ ] **Steg 2: Kör och pusha**

```powershell
supabase db push
# Förväntat: "Applying migration 002_rls.sql... Done"
```

- [ ] **Steg 3: Commit**

```bash
git add supabase/migrations/002_rls.sql
git commit -m "feat: add row level security — free vs premium access control

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 4: Storage buckets (migration 003)

**Files:**
- Create: `supabase/migrations/003_storage.sql`

- [ ] **Steg 1: Skapa storage-migration**

Skapa `supabase/migrations/003_storage.sql`:

```sql
-- Bucket för audio-filer (MP3)
insert into storage.buckets (id, name, public)
values ('hotspot-audio', 'hotspot-audio', false);

-- Bucket för bilder
insert into storage.buckets (id, name, public)
values ('hotspot-images', 'hotspot-images', true);

-- Audio: autentiserade users med köp kan ladda ned
create policy "audio_download_purchased"
  on storage.objects for select
  using (
    bucket_id = 'hotspot-audio'
    and auth.role() = 'authenticated'
  );

-- Images: publikt läsbara
create policy "images_public_read"
  on storage.objects for select
  using (bucket_id = 'hotspot-images');

-- Admin kan ladda upp (service_role via admin-panelen)
create policy "audio_admin_upload"
  on storage.objects for insert
  with check (bucket_id = 'hotspot-audio' and auth.role() = 'service_role');

create policy "images_admin_upload"
  on storage.objects for insert
  with check (bucket_id = 'hotspot-images' and auth.role() = 'service_role');
```

- [ ] **Steg 2: Kör och pusha**

```powershell
supabase db push
# Förväntat: "Applying migration 003_storage.sql... Done"
```

- [ ] **Steg 3: Commit**

```bash
git add supabase/migrations/003_storage.sql
git commit -m "feat: add storage buckets for audio and images

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 5: Seed-data (Palmas tre hotspots)

**Files:**
- Create: `supabase/migrations/004_seed.sql`

- [ ] **Steg 1: Skapa seed-data**

Skapa `supabase/migrations/004_seed.sql`:

```sql
-- Skapa Palma CityPack
insert into public.citypacks (id, name, city, country, description, price_sek, is_published)
values (
  'a1b2c3d4-0000-0000-0000-000000000001',
  'Palma de Mallorca',
  'Palma',
  'Spanien',
  'Utforska Palmas historiska gamla stad med audio-guider och lokala tips.',
  49,
  true
);

-- Hotspots
insert into public.hotspots (citypack_id, slug, name, subtitle, description, lat, lng, radius_meters, year, is_free, sort_order)
values
(
  'a1b2c3d4-0000-0000-0000-000000000001',
  'catedral',
  'Catedral de Mallorca',
  'La Seu • Grundad 1229',
  'Katedralen byggdes på order av Jaime I efter att han besegrade morerna 1229. Det tog över 400 år att färdigställa den gotiska mästerverket vid vattnet.',
  39.5671, 2.6498, 60, 1229,
  true,  -- gratis-hotspot
  1
),
(
  'a1b2c3d4-0000-0000-0000-000000000001',
  'placa_major',
  'Plaça Major',
  'Stadens hjärta • 1800-tal',
  'Plaça Major är Palmas centrala torg, omgiven av eleganta arkader och gatukafeer.',
  39.5697, 2.6500, 50, 1803,
  true,  -- gratis-hotspot
  2
),
(
  'a1b2c3d4-0000-0000-0000-000000000001',
  'placa_cort',
  'Plaça de Cort',
  'Rådhustorget • 1400-tal',
  'Plaça de Cort är hem till Palmas rådhus från 1600-talet och det berömda gamla olivträdet.',
  39.5694, 2.6503, 40, 1400,
  false,  -- premium-hotspot
  3
);

-- Ett test-deal
insert into public.hot_deals (citypack_id, business_name, offer_text, lat, lng, radius_meters, is_active)
values (
  'a1b2c3d4-0000-0000-0000-000000000001',
  'Restaurang La Bóveda',
  '15% rabatt på lunch — visa denna notis',
  39.5675, 2.6495, 80,
  true
);
```

- [ ] **Steg 2: Kör och pusha**

```powershell
supabase db push
# Förväntat: "Applying migration 004_seed.sql... Done"
```

- [ ] **Steg 3: Verifiera i Supabase Dashboard**

Gå till https://supabase.com/dashboard → ditt projekt → Table Editor
Kontrollera att `citypacks`, `hotspots` och `hot_deals` har data.

- [ ] **Steg 4: Commit**

```bash
git add supabase/migrations/004_seed.sql
git commit -m "feat: add Palma seed data — 3 hotspots + 1 test deal

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Klar!

Backend-fundamentet är på plats. Nästa steg: **Plan 2 (Admin-panel)** för att kunna lägga till innehåll via webbläsaren.
