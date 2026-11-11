-- =====================================================================
--  REBOND — schéma Supabase
--  À coller en une fois dans Supabase › SQL Editor › New query › Run.
--  Montants en centimes (int) pour éviter les erreurs d'arrondi.
-- =====================================================================

create extension if not exists btree_gist;

-- ---------------------------------------------------------------------
-- 1. Types
-- ---------------------------------------------------------------------
create type public.listing_status as enum ('active', 'paused', 'sold', 'archived');
create type public.booking_status as enum ('pending', 'accepted', 'declined', 'cancelled', 'paid', 'in_progress', 'completed');
create type public.offer_status   as enum ('pending', 'accepted', 'declined', 'cancelled', 'paid');

-- ---------------------------------------------------------------------
-- 2. Réglages de la plateforme (une seule ligne) + calcul de commission
-- ---------------------------------------------------------------------
create table public.platform_settings (
  id                   boolean primary key default true check (id),
  commission_rate      numeric(5,4) not null default 0.10 check (commission_rate between 0 and 1),
  commission_min_cents int          not null default 200  check (commission_min_cents >= 0),
  updated_at           timestamptz  not null default now()
);
insert into public.platform_settings default values;

-- 10 % du montant, avec un minimum de 2 € (réglable dans la table ci-dessus)
create or replace function public.compute_fee(amount_cents int)
returns int language sql stable set search_path = '' as $$
  select greatest(round(amount_cents * commission_rate)::int, commission_min_cents)
  from public.platform_settings where id;
$$;

create or replace function public.touch_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at := now(); return new; end $$;

-- ---------------------------------------------------------------------
-- 3. Profils (créés automatiquement à l'inscription)
-- ---------------------------------------------------------------------
create table public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  first_name text,
  city       text,
  avatar_url text,
  created_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, first_name)
  values (new.id, new.raw_user_meta_data ->> 'first_name');
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Compte Stripe Connect du propriétaire : privé, écrit uniquement par le serveur
create table public.payout_accounts (
  user_id           uuid primary key references public.profiles (id) on delete cascade,
  stripe_account_id text not null,
  charges_enabled   boolean not null default false,
  updated_at        timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 4. Catégories
-- ---------------------------------------------------------------------
create table public.categories (
  id         serial primary key,
  slug       text unique not null,
  label      text not null,
  sort_order smallint not null default 0
);
insert into public.categories (slug, label, sort_order) values
  ('velo',       'Vélo',          1),
  ('glisse-eau', 'Paddle & surf', 2),
  ('kayak',      'Kayak',         3),
  ('montagne',   'Ski & snow',    4),
  ('camping',    'Camping',       5),
  ('raquette',   'Raquettes',     6),
  ('fitness',    'Fitness',       7),
  ('escalade',   'Escalade',      8);

-- ---------------------------------------------------------------------
-- 5. Annonces + photos
-- ---------------------------------------------------------------------
create table public.listings (
  id                  uuid primary key default gen_random_uuid(),
  owner_id            uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  category_id         int  not null references public.categories (id),
  title               text not null check (char_length(title) between 3 and 80),
  description         text not null default '',
  city                text not null,
  price_per_day_cents int  not null check (price_per_day_cents > 0),
  deposit_cents       int  not null default 0 check (deposit_cents >= 0),
  status              public.listing_status not null default 'active',
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
create index listings_browse_idx on public.listings (status, category_id, created_at desc);
create index listings_city_idx   on public.listings (lower(city));
create index listings_owner_idx  on public.listings (owner_id);
create trigger listings_touch before update on public.listings
  for each row execute function public.touch_updated_at();

create table public.listing_images (
  id         uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings (id) on delete cascade,
  path       text not null,            -- chemin dans le bucket listing-images
  position   smallint not null default 0,
  created_at timestamptz not null default now()
);
create index listing_images_listing_idx on public.listing_images (listing_id, position);

-- ---------------------------------------------------------------------
-- 6. Réservations (prix et commission figés par le serveur)
-- ---------------------------------------------------------------------
create table public.bookings (
  id                       uuid primary key default gen_random_uuid(),
  listing_id               uuid not null references public.listings (id) on delete restrict,
  renter_id                uuid not null default auth.uid() references public.profiles (id),
  owner_id                 uuid not null references public.profiles (id),
  start_date               date not null,
  end_date                 date not null,
  days                     int generated always as ((end_date - start_date) + 1) stored,
  price_per_day_cents      int not null,
  subtotal_cents           int not null,   -- reversé au propriétaire
  fee_cents                int not null,   -- commission Rebond
  total_cents              int not null,   -- payé par le locataire
  deposit_cents            int not null,   -- caution bloquée, non débitée
  status                   public.booking_status not null default 'pending',
  stripe_payment_intent_id text,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now(),
  constraint bookings_dates_chk check (end_date >= start_date),
  -- deux locations confirmées ne peuvent pas se chevaucher
  constraint bookings_no_overlap exclude using gist (
    listing_id with =,
    daterange(start_date, end_date, '[]') with &&
  ) where (status in ('accepted', 'paid', 'in_progress'))
);
create index bookings_renter_idx on public.bookings (renter_id);
create index bookings_owner_idx  on public.bookings (owner_id);

-- À la création : on ignore les montants envoyés par le navigateur et on recalcule
create or replace function public.bookings_prepare()
returns trigger language plpgsql security definer set search_path = '' as $$
declare l public.listings;
begin
  select * into l from public.listings where id = new.listing_id;
  if l.id is null or l.status <> 'active' then
    raise exception 'Annonce indisponible';
  end if;
  if l.owner_id = new.renter_id then
    raise exception 'Impossible de louer sa propre annonce';
  end if;
  if new.start_date < current_date then
    raise exception 'La date de début est passée';
  end if;
  new.owner_id                 := l.owner_id;
  new.price_per_day_cents      := l.price_per_day_cents;
  new.deposit_cents            := l.deposit_cents;
  new.subtotal_cents           := l.price_per_day_cents * ((new.end_date - new.start_date) + 1);
  new.fee_cents                := public.compute_fee(new.subtotal_cents);
  new.total_cents              := new.subtotal_cents + new.fee_cents;
  new.status                   := 'pending';
  new.stripe_payment_intent_id := null;
  return new;
end $$;
create trigger bookings_before_insert before insert on public.bookings
  for each row execute function public.bookings_prepare();

-- À la modification : montants figés, et seuls certains changements de statut
-- sont permis depuis le site. « paid », « in_progress », « completed » : serveur uniquement.
create or replace function public.bookings_guard()
returns trigger language plpgsql set search_path = '' as $$
begin
  if current_user in ('service_role', 'postgres') then return new; end if;

  if (new.listing_id, new.renter_id, new.owner_id, new.start_date, new.end_date,
      new.subtotal_cents, new.fee_cents, new.total_cents, new.deposit_cents, new.stripe_payment_intent_id)
     is distinct from
     (old.listing_id, old.renter_id, old.owner_id, old.start_date, old.end_date,
      old.subtotal_cents, old.fee_cents, old.total_cents, old.deposit_cents, old.stripe_payment_intent_id) then
    raise exception 'Seul le statut d''une réservation peut être modifié';
  end if;

  if new.status is distinct from old.status then
    if auth.uid() = old.owner_id and old.status = 'pending' and new.status in ('accepted', 'declined') then
      null;
    elsif auth.uid() = old.renter_id and old.status in ('pending', 'accepted') and new.status = 'cancelled' then
      null;
    else
      raise exception 'Changement de statut non autorisé';
    end if;
  end if;
  return new;
end $$;
create trigger bookings_before_update before update on public.bookings
  for each row execute function public.bookings_guard();
create trigger bookings_touch before update on public.bookings
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------
-- 7. Offres d'achat
-- ---------------------------------------------------------------------
create table public.purchase_offers (
  id                       uuid primary key default gen_random_uuid(),
  listing_id               uuid not null references public.listings (id) on delete cascade,
  buyer_id                 uuid not null default auth.uid() references public.profiles (id),
  seller_id                uuid not null references public.profiles (id),
  amount_cents             int  not null check (amount_cents > 0),  -- reversé au vendeur
  fee_cents                int  not null,                          -- commission Rebond
  total_cents              int  not null,                          -- payé par l'acheteur
  status                   public.offer_status not null default 'pending',
  stripe_payment_intent_id text,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now()
);
create index purchase_offers_buyer_idx  on public.purchase_offers (buyer_id);
create index purchase_offers_seller_idx on public.purchase_offers (seller_id);

create or replace function public.offers_prepare()
returns trigger language plpgsql security definer set search_path = '' as $$
declare l public.listings;
begin
  select * into l from public.listings where id = new.listing_id;
  if l.id is null or l.status not in ('active', 'paused') then
    raise exception 'Annonce indisponible';
  end if;
  if l.owner_id = new.buyer_id then
    raise exception 'Impossible d''acheter sa propre annonce';
  end if;
  new.seller_id                := l.owner_id;
  new.fee_cents                := public.compute_fee(new.amount_cents);
  new.total_cents              := new.amount_cents + new.fee_cents;
  new.status                   := 'pending';
  new.stripe_payment_intent_id := null;
  return new;
end $$;
create trigger offers_before_insert before insert on public.purchase_offers
  for each row execute function public.offers_prepare();

create or replace function public.offers_guard()
returns trigger language plpgsql set search_path = '' as $$
begin
  if current_user in ('service_role', 'postgres') then return new; end if;

  if (new.listing_id, new.buyer_id, new.seller_id, new.amount_cents, new.fee_cents,
      new.total_cents, new.stripe_payment_intent_id)
     is distinct from
     (old.listing_id, old.buyer_id, old.seller_id, old.amount_cents, old.fee_cents,
      old.total_cents, old.stripe_payment_intent_id) then
    raise exception 'Seul le statut d''une offre peut être modifié';
  end if;

  if new.status is distinct from old.status then
    if auth.uid() = old.seller_id and old.status = 'pending' and new.status in ('accepted', 'declined') then
      null;
    elsif auth.uid() = old.buyer_id and old.status in ('pending', 'accepted') and new.status = 'cancelled' then
      null;
    else
      raise exception 'Changement de statut non autorisé';
    end if;
  end if;
  return new;
end $$;
create trigger offers_before_update before update on public.purchase_offers
  for each row execute function public.offers_guard();
create trigger offers_touch before update on public.purchase_offers
  for each row execute function public.touch_updated_at();

-- Quand le paiement d'une offre est confirmé (par le serveur), l'annonce passe en « vendu »
create or replace function public.offers_mark_sold()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.status = 'paid' and old.status is distinct from 'paid' then
    update public.listings set status = 'sold' where id = new.listing_id;
  end if;
  return new;
end $$;
create trigger offers_after_update after update on public.purchase_offers
  for each row execute function public.offers_mark_sold();

-- ---------------------------------------------------------------------
-- 8. Messagerie et avis
-- ---------------------------------------------------------------------
create table public.messages (
  id           uuid primary key default gen_random_uuid(),
  listing_id   uuid not null references public.listings (id) on delete cascade,
  sender_id    uuid not null default auth.uid() references public.profiles (id),
  recipient_id uuid not null references public.profiles (id),
  body         text not null check (char_length(body) between 1 and 2000),
  created_at   timestamptz not null default now(),
  constraint messages_not_self check (sender_id <> recipient_id)
);
create index messages_thread_idx on public.messages (listing_id, created_at);

create table public.reviews (
  id         uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings (id) on delete cascade,
  author_id  uuid not null default auth.uid() references public.profiles (id),
  target_id  uuid not null references public.profiles (id),
  rating     smallint not null check (rating between 1 and 5),
  comment    text not null default '',
  created_at timestamptz not null default now(),
  unique (booking_id, author_id)
);
create index reviews_target_idx on public.reviews (target_id);

-- ---------------------------------------------------------------------
-- 9. Sécurité : Row Level Security (qui peut lire / écrire quoi)
-- ---------------------------------------------------------------------
alter table public.platform_settings enable row level security;
alter table public.profiles          enable row level security;
alter table public.payout_accounts   enable row level security;
alter table public.categories        enable row level security;
alter table public.listings          enable row level security;
alter table public.listing_images    enable row level security;
alter table public.bookings          enable row level security;
alter table public.purchase_offers   enable row level security;
alter table public.messages          enable row level security;
alter table public.reviews           enable row level security;

-- Réglages et catégories : lecture publique
create policy "Réglages lisibles" on public.platform_settings for select using (true);
create policy "Catégories lisibles" on public.categories for select using (true);

-- Profils : publics en lecture, chacun modifie le sien
create policy "Profils lisibles" on public.profiles for select using (true);
create policy "Modifier son profil" on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- Compte de versement : visible par son titulaire seulement (écrit par le serveur)
create policy "Voir son compte de versement" on public.payout_accounts for select to authenticated
  using (user_id = (select auth.uid()));

-- Annonces : les actives sont publiques, le propriétaire voit et gère les siennes
create policy "Annonces visibles" on public.listings for select
  using (status = 'active' or owner_id = (select auth.uid()));
create policy "Créer une annonce" on public.listings for insert to authenticated
  with check (owner_id = (select auth.uid()));
create policy "Modifier son annonce" on public.listings for update to authenticated
  using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
create policy "Supprimer son annonce" on public.listings for delete to authenticated
  using (owner_id = (select auth.uid()));

-- Photos : visibles avec l'annonce, gérées par le propriétaire
create policy "Photos visibles" on public.listing_images for select
  using (exists (select 1 from public.listings l where l.id = listing_id));
create policy "Ajouter une photo" on public.listing_images for insert to authenticated
  with check (exists (select 1 from public.listings l where l.id = listing_id and l.owner_id = (select auth.uid())));
create policy "Supprimer une photo" on public.listing_images for delete to authenticated
  using (exists (select 1 from public.listings l where l.id = listing_id and l.owner_id = (select auth.uid())));

-- Réservations : visibles par le locataire et le propriétaire
create policy "Voir ses réservations" on public.bookings for select to authenticated
  using ((select auth.uid()) in (renter_id, owner_id));
create policy "Demander une réservation" on public.bookings for insert to authenticated
  with check (renter_id = (select auth.uid()));
create policy "Répondre ou annuler" on public.bookings for update to authenticated
  using ((select auth.uid()) in (renter_id, owner_id));

-- Offres d'achat : visibles par l'acheteur et le vendeur
create policy "Voir ses offres" on public.purchase_offers for select to authenticated
  using ((select auth.uid()) in (buyer_id, seller_id));
create policy "Faire une offre" on public.purchase_offers for insert to authenticated
  with check (buyer_id = (select auth.uid()));
create policy "Répondre ou retirer une offre" on public.purchase_offers for update to authenticated
  using ((select auth.uid()) in (buyer_id, seller_id));

-- Messages : visibles par l'expéditeur et le destinataire
create policy "Voir ses messages" on public.messages for select to authenticated
  using ((select auth.uid()) in (sender_id, recipient_id));
create policy "Envoyer un message" on public.messages for insert to authenticated
  with check (sender_id = (select auth.uid()));

-- Avis : publics, uniquement après une location terminée, entre les deux parties
create policy "Avis lisibles" on public.reviews for select using (true);
create policy "Laisser un avis" on public.reviews for insert to authenticated
  with check (
    author_id = (select auth.uid())
    and exists (
      select 1 from public.bookings b
      where b.id = booking_id and b.status = 'completed'
        and ((b.renter_id = (select auth.uid()) and target_id = b.owner_id)
          or (b.owner_id  = (select auth.uid()) and target_id = b.renter_id))
    )
  );

-- ---------------------------------------------------------------------
-- 10. Stockage des photos
--     Chaque utilisateur range ses photos dans un dossier à son id :
--     listing-images/<user_id>/<fichier>.jpg
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('listing-images', 'listing-images', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy "Envoyer ses photos" on storage.objects for insert to authenticated
  with check (bucket_id = 'listing-images' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "Remplacer ses photos" on storage.objects for update to authenticated
  using (bucket_id = 'listing-images' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "Supprimer ses photos" on storage.objects for delete to authenticated
  using (bucket_id = 'listing-images' and (storage.foldername(name))[1] = (select auth.uid())::text);
