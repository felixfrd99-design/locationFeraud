-- =====================================================================
--  REBOND — option de rachat et durée maximale de 30 jours
--  À appliquer après 03_hardening.sql.
-- =====================================================================

-- Le propriétaire choisit si son objet peut être racheté, avec un prix indicatif facultatif
alter table public.listings
  add column buyout_enabled     boolean not null default false,
  add column buyout_price_cents int check (buyout_price_cents is null or buyout_price_cents > 0);

-- Une location dure 30 jours au maximum
alter table public.bookings
  add constraint bookings_max_30_days check (end_date - start_date + 1 <= 30);

-- Une offre d'achat n'est possible que si le propriétaire a activé le rachat
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
  new.fee_cents                := public.compute_fee(new.amount_cents);
  new.total_cents              := new.amount_cents + new.fee_cents;
  new.status                   := 'pending';
  new.stripe_payment_intent_id := null;
  return new;
end $$;
revoke execute on function public.offers_prepare() from public, anon, authenticated;
