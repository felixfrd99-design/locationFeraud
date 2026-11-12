-- =====================================================================
--  SPOLOC — carte de fidélité à la place des points
--  * Toutes les 5 locations terminées : frais de service offerts sur la
--    location suivante (5 € maximum).
--  * Parrainage : seulement quand le filleul a terminé sa 1re location ;
--    le parrain et le filleul reçoivent chacun la même remise.
--  * La remise s'applique toute seule à la prochaine demande, et revient
--    si la demande est refusée ou annulée.
-- =====================================================================

-- 1. Fin des points ---------------------------------------------------
drop trigger if exists bookings_points on public.bookings;
drop trigger if exists offers_points   on public.purchase_offers;
drop trigger if exists listings_points on public.listings;
drop trigger if exists reviews_points  on public.reviews;
drop function if exists public.points_on_booking();
drop function if exists public.points_on_sale();
drop function if exists public.points_on_listing();
drop function if exists public.points_on_review();
drop function if exists public.my_points();
drop function if exists public.award(uuid, int, text, uuid);
drop table if exists public.points_ledger;

-- 2. Réglages ---------------------------------------------------------
alter table public.platform_settings
  add column loyalty_every     int not null default 5   check (loyalty_every between 1 and 50),
  add column voucher_max_cents int not null default 500 check (voucher_max_cents >= 0);

-- 3. Remises ----------------------------------------------------------
create table public.fee_vouchers (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles (id) on delete cascade,
  reason          text not null check (reason in ('fidelite', 'parrainage', 'filleul')),
  ref_id          uuid,
  max_cents       int  not null check (max_cents >= 0),
  used_booking_id uuid,
  used_at         timestamptz,
  created_at      timestamptz not null default now()
);
create index fee_vouchers_user_idx on public.fee_vouchers (user_id, created_at);
create unique index fee_vouchers_referral_once on public.fee_vouchers (reason, ref_id) where reason in ('parrainage', 'filleul');
alter table public.fee_vouchers enable row level security;
create policy "Voir ses remises" on public.fee_vouchers for select to authenticated
  using (user_id = (select auth.uid()));

alter table public.bookings
  add column voucher_id     uuid references public.fee_vouchers (id) on delete set null,
  add column discount_cents int not null default 0 check (discount_cents >= 0);
create index bookings_voucher_idx on public.bookings (voucher_id);

-- 4. Application à la réservation ------------------------------------
create or replace function public.apply_voucher()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v public.fee_vouchers;
begin
  new.voucher_id := null;
  new.discount_cents := 0;
  select * into v from public.fee_vouchers
   where user_id = new.renter_id and used_booking_id is null
   order by created_at limit 1 for update skip locked;
  if v.id is not null and new.fee_cents > 0 then
    new.discount_cents := least(new.fee_cents, v.max_cents);
    new.fee_cents      := new.fee_cents - new.discount_cents;
    new.total_cents    := new.subtotal_cents + new.fee_cents;
    new.voucher_id     := v.id;
    update public.fee_vouchers set used_booking_id = new.id, used_at = now() where id = v.id;
  end if;
  return new;
end $$;
-- s'exécute après bookings_prepare (ordre alphabétique des déclencheurs)
create trigger bookings_zvoucher before insert on public.bookings
  for each row execute function public.apply_voucher();

create or replace function public.bookings_guard()
returns trigger language plpgsql set search_path = '' as $$
begin
  if current_user in ('service_role', 'postgres') then return new; end if;

  if (new.listing_id, new.renter_id, new.owner_id, new.start_date, new.end_date, new.start_hour, new.end_hour, new.handover_mode,
      new.delivery_fee_cents, new.subtotal_cents, new.fee_cents, new.total_cents, new.deposit_cents,
      new.stripe_payment_intent_id, new.voucher_id, new.discount_cents)
     is distinct from
     (old.listing_id, old.renter_id, old.owner_id, old.start_date, old.end_date, old.start_hour, old.end_hour, old.handover_mode,
      old.delivery_fee_cents, old.subtotal_cents, old.fee_cents, old.total_cents, old.deposit_cents,
      old.stripe_payment_intent_id, old.voucher_id, old.discount_cents) then
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

-- 5. Gagner une remise / la rendre ------------------------------------
create or replace function public.loyalty_on_booking()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  s       public.platform_settings;
  done    int;
  sponsor uuid;
begin
  -- demande refusée ou annulée : la remise revient
  if new.status in ('declined', 'cancelled') and old.status is distinct from new.status and new.voucher_id is not null then
    update public.fee_vouchers set used_booking_id = null, used_at = null where id = new.voucher_id;
  end if;

  if new.status = 'completed' and old.status is distinct from 'completed' then
    select * into s from public.platform_settings where id;
    select count(*) into done from public.bookings where renter_id = new.renter_id and status = 'completed';
    if done % s.loyalty_every = 0 then
      insert into public.fee_vouchers (user_id, reason, ref_id, max_cents) values (new.renter_id, 'fidelite', new.id, s.voucher_max_cents);
    end if;
    if done = 1 then
      select referred_by into sponsor from public.profiles where id = new.renter_id;
      if sponsor is not null then
        insert into public.fee_vouchers (user_id, reason, ref_id, max_cents) values
          (sponsor,        'parrainage', new.renter_id, s.voucher_max_cents),
          (new.renter_id,  'filleul',    new.renter_id, s.voucher_max_cents)
        on conflict do nothing;
      end if;
    end if;
  end if;
  return new;
end $$;
create trigger bookings_loyalty after update on public.bookings
  for each row execute function public.loyalty_on_booking();

revoke execute on function public.apply_voucher()      from public, anon, authenticated;
revoke execute on function public.loyalty_on_booking() from public, anon, authenticated;

-- 6. Ma carte ---------------------------------------------------------
create or replace function public.my_loyalty()
returns json language sql stable set search_path = '' as $$
  select json_build_object(
    'completed', (select count(*) from public.bookings where renter_id = (select auth.uid()) and status = 'completed'),
    'every',     s.loyalty_every,
    'max_cents', s.voucher_max_cents,
    'vouchers',  (select count(*) from public.fee_vouchers where user_id = (select auth.uid()) and used_booking_id is null),
    'referrals', (select count(*) from public.fee_vouchers where user_id = (select auth.uid()) and reason = 'parrainage'))
  from public.platform_settings s where s.id;
$$;
revoke execute on function public.my_loyalty() from public, anon;
grant execute on function public.my_loyalty() to authenticated;

-- 7. Assistant --------------------------------------------------------
update public.assistant_faq
   set question = 'Comment fonctionne la fidélité ?',
       answer = 'Toutes les 5 locations terminées, vos frais de service sont offerts sur la suivante (jusqu''à 5 €). Parrainage : dès que votre ami a terminé sa première location, vous recevez chacun la même remise. Les propriétaires, eux, ne paient jamais rien.',
       keywords = '{club,points,fidelite,fidele,parrainage,parrain,filleul,remise,avantage,recompense}'
 where question ilike '%points%';
update public.assistant_faq
   set answer = 'Partagez votre lien depuis l''onglet Club. Dès que votre ami a terminé sa première location, vous recevez chacun vos frais de service offerts sur une location (jusqu''à 5 €).'
 where question ilike '%parrain%';
