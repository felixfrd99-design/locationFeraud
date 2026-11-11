-- =====================================================================
--  REBOND — fiches détaillées, remises sécurisées, club et parrainage
--  À appliquer après 05a_offre_terminee.sql.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Frais : location 6 % (1 € min), vente 8 % (2 € min),
--    divisés par deux à vie pour les 500 membres fondateurs
-- ---------------------------------------------------------------------
alter table public.platform_settings
  add column sale_commission_rate      numeric(5,4) not null default 0.08 check (sale_commission_rate between 0 and 1),
  add column sale_commission_min_cents int          not null default 200  check (sale_commission_min_cents >= 0),
  add column founder_discount          numeric(3,2) not null default 0.50 check (founder_discount between 0 and 1),
  add column founder_slots             int          not null default 500  check (founder_slots >= 0);
update public.platform_settings set commission_rate = 0.06, commission_min_cents = 100;

alter table public.profiles
  add column is_founder    boolean not null default false,
  add column referral_code text unique,
  add column referred_by   uuid references public.profiles (id);
update public.profiles set referral_code = upper(substr(md5(id::text), 1, 6)) where referral_code is null;
create index profiles_referred_by_idx on public.profiles (referred_by);

create or replace function public.rental_fee(amount_cents int, renter uuid)
returns int language sql stable set search_path = '' as $$
  select round(greatest(round(amount_cents * s.commission_rate), s.commission_min_cents)
               * case when coalesce(p.is_founder, false) then s.founder_discount else 1 end)::int
  from public.platform_settings s
  left join public.profiles p on p.id = renter
  where s.id;
$$;

create or replace function public.sale_fee(amount_cents int, buyer uuid)
returns int language sql stable set search_path = '' as $$
  select round(greatest(round(amount_cents * s.sale_commission_rate), s.sale_commission_min_cents)
               * case when coalesce(p.is_founder, false) then s.founder_discount else 1 end)::int
  from public.platform_settings s
  left join public.profiles p on p.id = buyer
  where s.id;
$$;

-- Inscription : code de parrainage, parrain éventuel, statut fondateur
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  sponsor uuid;
  founders int;
  slots int;
begin
  select id into sponsor from public.profiles
  where referral_code = upper(nullif(trim(new.raw_user_meta_data ->> 'ref'), ''));
  select count(*) into founders from public.profiles where is_founder;
  select founder_slots into slots from public.platform_settings where id;
  insert into public.profiles (id, first_name, referral_code, referred_by, is_founder)
  values (new.id, new.raw_user_meta_data ->> 'first_name',
          upper(substr(md5(new.id::text), 1, 6)), sponsor, founders < coalesce(slots, 0));
  return new;
end $$;

-- Un membre ne peut pas se donner le statut fondateur ni changer de parrain
create or replace function public.profiles_guard()
returns trigger language plpgsql set search_path = '' as $$
begin
  if current_user in ('service_role', 'postgres') then return new; end if;
  if (new.is_founder, new.referral_code, new.referred_by)
     is distinct from (old.is_founder, old.referral_code, old.referred_by) then
    raise exception 'Ces informations ne peuvent pas être modifiées';
  end if;
  return new;
end $$;
create trigger profiles_before_update before update on public.profiles
  for each row execute function public.profiles_guard();

-- ---------------------------------------------------------------------
-- 2. Boutiques partenaires (dépôt et retrait du matériel)
-- ---------------------------------------------------------------------
create table public.partner_shops (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  address       text not null,
  city          text not null,
  opening_hours text not null default '',
  active        boolean not null default true,
  created_at    timestamptz not null default now()
);
alter table public.partner_shops enable row level security;
create policy "Boutiques actives visibles" on public.partner_shops for select using (active);

-- ---------------------------------------------------------------------
-- 3. Fiche objet détaillée + vérification de la marque + modes de remise
-- ---------------------------------------------------------------------
create type public.item_condition as enum ('neuf', 'tres_bon', 'bon', 'correct');

alter table public.listings
  add column condition          public.item_condition not null default 'bon',
  add column brand              text check (brand is null or char_length(brand) <= 60),
  add column model              text check (model is null or char_length(model) <= 80),
  add column length_cm          int  check (length_cm is null or length_cm > 0),
  add column width_cm           int  check (width_cm  is null or width_cm  > 0),
  add column height_cm          int  check (height_cm is null or height_cm > 0),
  add column weight_kg          numeric(6,2) check (weight_kg is null or weight_kg > 0),
  add column brand_proof_path   text,
  add column brand_verified     boolean not null default false,
  add column handover_modes     text[] not null default '{hand}',
  add column delivery_fee_cents int check (delivery_fee_cents is null or delivery_fee_cents >= 0),
  add column pickup_shop_id     uuid references public.partner_shops (id),
  add constraint listings_handover_modes_chk check (
    cardinality(handover_modes) > 0 and handover_modes <@ array['hand', 'delivery', 'shop']),
  add constraint listings_shop_chk check (
    not ('shop' = any (handover_modes)) or pickup_shop_id is not null),
  add constraint listings_delivery_chk check (
    not ('delivery' = any (handover_modes)) or delivery_fee_cents is not null);
create index listings_pickup_shop_idx on public.listings (pickup_shop_id);

-- Le badge « marque vérifiée » n'est posé que par l'équipe ; il saute si la marque change
create or replace function public.listings_guard()
returns trigger language plpgsql set search_path = '' as $$
begin
  if current_user in ('service_role', 'postgres') then return new; end if;
  if tg_op = 'INSERT' then
    new.brand_verified := false;
  elsif (new.brand, new.model, new.brand_proof_path) is distinct from (old.brand, old.model, old.brand_proof_path) then
    new.brand_verified := false;
  elsif new.brand_verified is distinct from old.brand_verified then
    raise exception 'La vérification de marque est faite par l''équipe';
  end if;
  return new;
end $$;
create trigger listings_before_write before insert or update on public.listings
  for each row execute function public.listings_guard();

-- ---------------------------------------------------------------------
-- 4. Réservations : mode de remise et nouveaux frais
-- ---------------------------------------------------------------------
alter table public.bookings
  add column handover_mode      text not null default 'hand' check (handover_mode in ('hand', 'delivery', 'shop')),
  add column delivery_fee_cents int  not null default 0;

create or replace function public.bookings_prepare()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  l public.listings;
  rent int;
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
  if not (coalesce(new.handover_mode, 'hand') = any (l.handover_modes)) then
    raise exception 'Ce mode de remise n''est pas proposé pour cette annonce';
  end if;
  rent := l.price_per_day_cents * ((new.end_date - new.start_date) + 1);
  new.owner_id                 := l.owner_id;
  new.price_per_day_cents      := l.price_per_day_cents;
  new.deposit_cents            := l.deposit_cents;
  new.delivery_fee_cents       := case when new.handover_mode = 'delivery' then coalesce(l.delivery_fee_cents, 0) else 0 end;
  new.subtotal_cents           := rent + new.delivery_fee_cents;          -- reversé au propriétaire
  new.fee_cents                := public.rental_fee(rent, new.renter_id); -- frais sur la location seule
  new.total_cents              := new.subtotal_cents + new.fee_cents;
  new.status                   := 'pending';
  new.stripe_payment_intent_id := null;
  return new;
end $$;

create or replace function public.bookings_guard()
returns trigger language plpgsql set search_path = '' as $$
begin
  if current_user in ('service_role', 'postgres') then return new; end if;

  if (new.listing_id, new.renter_id, new.owner_id, new.start_date, new.end_date, new.handover_mode,
      new.delivery_fee_cents, new.subtotal_cents, new.fee_cents, new.total_cents, new.deposit_cents,
      new.stripe_payment_intent_id)
     is distinct from
     (old.listing_id, old.renter_id, old.owner_id, old.start_date, old.end_date, old.handover_mode,
      old.delivery_fee_cents, old.subtotal_cents, old.fee_cents, old.total_cents, old.deposit_cents,
      old.stripe_payment_intent_id) then
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

create or replace function public.offers_prepare()
returns trigger language plpgsql security definer set search_path = '' as $$
declare l public.listings;
begin
  select * into l from public.listings where id = new.listing_id;
  if l.id is null or l.status not in ('active', 'paused') then
    raise exception 'Annonce indisponible';
  end if;
  if not l.buyout_enabled then
    raise exception 'Le propriétaire n''a pas ouvert cet objet au rachat';
  end if;
  if l.owner_id = new.buyer_id then
    raise exception 'Impossible d''acheter sa propre annonce';
  end if;
  new.seller_id                := l.owner_id;
  new.fee_cents                := public.sale_fee(new.amount_cents, new.buyer_id);
  new.total_cents              := new.amount_cents + new.fee_cents;
  new.status                   := 'pending';
  new.stripe_payment_intent_id := null;
  return new;
end $$;

-- ---------------------------------------------------------------------
-- 5. Remise sécurisée : code + photos + signature
--    retrait : le propriétaire saisit le code du locataire
--    retour  : le locataire saisit le code du propriétaire
--    vente   : le vendeur saisit le code de l'acheteur
-- ---------------------------------------------------------------------
create type public.handover_kind as enum ('pickup', 'return', 'sale');

create table public.handover_codes (
  id         uuid primary key default gen_random_uuid(),
  booking_id uuid references public.bookings (id) on delete cascade,
  offer_id   uuid references public.purchase_offers (id) on delete cascade,
  kind       public.handover_kind not null,
  holder_id  uuid not null references public.profiles (id),
  code       text not null,
  attempts   smallint not null default 0,
  used_at    timestamptz,
  unique (booking_id, kind),
  unique (offer_id, kind),
  check ((booking_id is null) <> (offer_id is null))
);
create index handover_codes_holder_idx on public.handover_codes (holder_id);
alter table public.handover_codes enable row level security;
create policy "Voir ses codes" on public.handover_codes for select to authenticated
  using (holder_id = (select auth.uid()));

create or replace function public.new_code()
returns text language sql volatile set search_path = '' as $$
  select lpad((floor(random() * 10000))::int::text, 4, '0');
$$;

create or replace function public.bookings_make_codes()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.handover_codes (booking_id, kind, holder_id, code) values
    (new.id, 'pickup', new.renter_id, public.new_code()),
    (new.id, 'return', new.owner_id,  public.new_code());
  return new;
end $$;
create trigger bookings_after_insert after insert on public.bookings
  for each row execute function public.bookings_make_codes();

create or replace function public.offers_make_code()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.handover_codes (offer_id, kind, holder_id, code)
  values (new.id, 'sale', new.buyer_id, public.new_code());
  return new;
end $$;
create trigger offers_after_insert after insert on public.purchase_offers
  for each row execute function public.offers_make_code();

create table public.handovers (
  id             uuid primary key default gen_random_uuid(),
  booking_id     uuid references public.bookings (id) on delete cascade,
  offer_id       uuid references public.purchase_offers (id) on delete cascade,
  kind           public.handover_kind not null,
  condition      public.item_condition not null,
  notes          text not null default '',
  photo_paths    text[] not null check (cardinality(photo_paths) between 2 and 8),
  signature_path text not null,
  confirmed_by   uuid not null references public.profiles (id),
  signed_by      uuid not null references public.profiles (id),
  created_at     timestamptz not null default now(),
  unique (booking_id, kind),
  unique (offer_id, kind),
  check ((booking_id is null) <> (offer_id is null))
);
create index handovers_confirmed_idx on public.handovers (confirmed_by);
create index handovers_signed_idx    on public.handovers (signed_by);
alter table public.handovers enable row level security;
create policy "Voir les remises de ses locations et ventes" on public.handovers for select to authenticated
  using ((select auth.uid()) in (confirmed_by, signed_by));

-- Retourne 'ok' ou un message ; un mauvais code compte un essai (5 maximum)
create or replace function public.confirm_handover(
  p_kind      public.handover_kind,
  p_id        uuid,
  p_code      text,
  p_condition public.item_condition,
  p_photos    text[],
  p_signature text,
  p_notes     text default ''
)
returns text language plpgsql security definer set search_path = '' as $$
declare
  me     uuid := auth.uid();
  b      public.bookings;
  o      public.purchase_offers;
  c      public.handover_codes;
  signer uuid;
begin
  if me is null then raise exception 'Connexion requise'; end if;
  if coalesce(cardinality(p_photos), 0) < 2 then raise exception 'Au moins 2 photos sont nécessaires'; end if;
  if p_signature is null or p_signature = '' then raise exception 'La signature est nécessaire'; end if;
  if exists (select 1 from unnest(p_photos) x where x not like me::text || '/%')
     or p_signature not like me::text || '/%' then
    raise exception 'Photos ou signature invalides';
  end if;

  if p_kind = 'sale' then
    select * into o from public.purchase_offers where id = p_id for update;
    if o.id is null then raise exception 'Offre introuvable'; end if;
    if me <> o.seller_id then raise exception 'Seul le vendeur confirme la remise'; end if;
    if o.status not in ('accepted', 'paid') then raise exception 'Cette vente n''est pas prête pour la remise'; end if;
    signer := o.buyer_id;
    select * into c from public.handover_codes where offer_id = p_id and kind = 'sale' for update;
  else
    select * into b from public.bookings where id = p_id for update;
    if b.id is null then raise exception 'Réservation introuvable'; end if;
    if p_kind = 'pickup' then
      if me <> b.owner_id then raise exception 'Seul le propriétaire confirme le retrait'; end if;
      if b.status not in ('accepted', 'paid') then raise exception 'Cette location n''est pas prête pour le retrait'; end if;
      signer := b.renter_id;
    else
      if me <> b.renter_id then raise exception 'Seul le locataire confirme le retour'; end if;
      if b.status <> 'in_progress' then raise exception 'Cette location n''est pas en cours'; end if;
      signer := b.owner_id;
    end if;
    select * into c from public.handover_codes where booking_id = p_id and kind = p_kind for update;
  end if;

  if c.id is null or c.used_at is not null then return 'Ce code n''est plus valable'; end if;
  if c.attempts >= 5 then return 'Trop d''essais : contactez le support'; end if;
  if c.code <> trim(p_code) then
    update public.handover_codes set attempts = attempts + 1 where id = c.id;
    return format('Code incorrect (%s essai(s) restant(s))', 4 - c.attempts);
  end if;

  update public.handover_codes set used_at = now() where id = c.id;
  insert into public.handovers (booking_id, offer_id, kind, condition, notes, photo_paths, signature_path, confirmed_by, signed_by)
  values (case when p_kind = 'sale' then null else p_id end,
          case when p_kind = 'sale' then p_id else null end,
          p_kind, p_condition, coalesce(p_notes, ''), p_photos, p_signature, me, signer);

  if p_kind = 'pickup' then
    update public.bookings set status = 'in_progress' where id = p_id;
  elsif p_kind = 'return' then
    update public.bookings set status = 'completed' where id = p_id;
  else
    update public.purchase_offers set status = 'completed' where id = p_id;
    update public.listings set status = 'sold' where id = o.listing_id;
  end if;
  return 'ok';
end $$;
revoke execute on function public.confirm_handover(public.handover_kind, uuid, text, public.item_condition, text[], text, text) from public, anon;
grant execute on function public.confirm_handover(public.handover_kind, uuid, text, public.item_condition, text[], text, text) to authenticated;

-- ---------------------------------------------------------------------
-- 6. Points et parrainage
--    1 point par euro loué ou vendu (des deux côtés), 20 points par avis,
--    50 points pour la première annonce, 200 points pour le parrain et
--    le filleul à la première location terminée du filleul
-- ---------------------------------------------------------------------
create table public.points_ledger (
  id         bigserial primary key,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  points     int  not null,
  reason     text not null,
  ref_id     uuid not null,
  created_at timestamptz not null default now(),
  unique (user_id, reason, ref_id)
);
alter table public.points_ledger enable row level security;
create policy "Voir ses points" on public.points_ledger for select to authenticated
  using (user_id = (select auth.uid()));

create or replace function public.award(p_user uuid, p_points int, p_reason text, p_ref uuid)
returns void language sql security definer set search_path = '' as $$
  insert into public.points_ledger (user_id, points, reason, ref_id)
  values (p_user, p_points, p_reason, p_ref)
  on conflict (user_id, reason, ref_id) do nothing;
$$;

create or replace function public.points_on_booking()
returns trigger language plpgsql security definer set search_path = '' as $$
declare sponsor uuid;
begin
  if new.status = 'completed' and old.status is distinct from 'completed' then
    perform public.award(new.renter_id, new.subtotal_cents / 100, 'location', new.id);
    perform public.award(new.owner_id,  new.subtotal_cents / 100, 'location_proprietaire', new.id);
    select referred_by into sponsor from public.profiles where id = new.renter_id;
    if sponsor is not null and not exists (
      select 1 from public.bookings where renter_id = new.renter_id and status = 'completed' and id <> new.id) then
      perform public.award(sponsor,        200, 'parrainage', new.renter_id);
      perform public.award(new.renter_id, 200, 'filleul',    new.renter_id);
    end if;
  end if;
  return new;
end $$;
create trigger bookings_points after update on public.bookings
  for each row execute function public.points_on_booking();

create or replace function public.points_on_sale()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.status = 'completed' and old.status is distinct from 'completed' then
    perform public.award(new.buyer_id,  new.amount_cents / 100, 'achat', new.id);
    perform public.award(new.seller_id, new.amount_cents / 100, 'vente', new.id);
  end if;
  return new;
end $$;
create trigger offers_points after update on public.purchase_offers
  for each row execute function public.points_on_sale();

create or replace function public.points_on_listing()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform public.award(new.owner_id, 50, 'premiere_annonce', new.owner_id);
  return new;
end $$;
create trigger listings_points after insert on public.listings
  for each row execute function public.points_on_listing();

create or replace function public.points_on_review()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform public.award(new.author_id, 20, 'avis', new.id);
  return new;
end $$;
create trigger reviews_points after insert on public.reviews
  for each row execute function public.points_on_review();

create or replace function public.my_points()
returns int language sql stable security definer set search_path = '' as $$
  select coalesce(sum(points), 0)::int from public.points_ledger where user_id = auth.uid();
$$;
revoke execute on function public.my_points() from public, anon;
grant execute on function public.my_points() to authenticated;

-- ---------------------------------------------------------------------
-- 7. Fonctions internes : jamais appelables via l'API
-- ---------------------------------------------------------------------
revoke execute on function public.handle_new_user()      from public, anon, authenticated;
revoke execute on function public.profiles_guard()       from public, anon, authenticated;
revoke execute on function public.listings_guard()       from public, anon, authenticated;
revoke execute on function public.bookings_prepare()     from public, anon, authenticated;
revoke execute on function public.bookings_guard()       from public, anon, authenticated;
revoke execute on function public.offers_prepare()       from public, anon, authenticated;
revoke execute on function public.bookings_make_codes()  from public, anon, authenticated;
revoke execute on function public.offers_make_code()     from public, anon, authenticated;
revoke execute on function public.award(uuid, int, text, uuid) from public, anon, authenticated;
revoke execute on function public.points_on_booking()    from public, anon, authenticated;
revoke execute on function public.points_on_sale()       from public, anon, authenticated;
revoke execute on function public.points_on_listing()    from public, anon, authenticated;
revoke execute on function public.points_on_review()     from public, anon, authenticated;
revoke execute on function public.new_code()             from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 8. Stockage privé : photos de remise, signatures, preuves de marque
--    Chaque fichier est rangé dans le dossier de son auteur : <user_id>/...
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('handover-photos', 'handover-photos', false, 10485760, array['image/jpeg', 'image/png', 'image/webp']),
  ('brand-proofs',    'brand-proofs',    false, 10485760, array['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])
on conflict (id) do nothing;

create or replace function public.can_see_handover_file(p_path text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.handovers h
    where (p_path = any (h.photo_paths) or p_path = h.signature_path)
      and auth.uid() in (h.confirmed_by, h.signed_by)
  );
$$;
revoke execute on function public.can_see_handover_file(text) from public, anon;
grant execute on function public.can_see_handover_file(text) to authenticated;

create policy "Déposer ses photos de remise" on storage.objects for insert to authenticated
  with check (bucket_id = 'handover-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "Voir les photos de ses remises" on storage.objects for select to authenticated
  using (bucket_id = 'handover-photos'
         and ((storage.foldername(name))[1] = (select auth.uid())::text or public.can_see_handover_file(name)));
create policy "Déposer ses preuves de marque" on storage.objects for insert to authenticated
  with check (bucket_id = 'brand-proofs' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "Voir ses preuves de marque" on storage.objects for select to authenticated
  using (bucket_id = 'brand-proofs' and (storage.foldername(name))[1] = (select auth.uid())::text);
