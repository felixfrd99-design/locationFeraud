-- =====================================================================
--  SPOLOC — location à l'heure, 5 h minimum
--  Remplace les créneaux fixes (matin / après-midi) par une heure de
--  début et une heure de fin libres, le même jour, entre 7 h et 22 h.
--  Tarif : demi-journée jusqu'à 6 h, journée au-delà.
-- =====================================================================

alter table public.platform_settings
  add column min_rental_hours      int not null default 5 check (min_rental_hours between 1 and 12),
  add column half_day_max_hours    int not null default 6 check (half_day_max_hours between 1 and 12);

alter table public.bookings
  add column start_hour smallint,
  add column end_hour   smallint;

-- anciens créneaux → heures
update public.bookings set start_hour = 8,  end_hour = 13 where slot = 'am';
update public.bookings set start_hour = 13, end_hour = 20 where slot = 'pm';

alter table public.bookings drop constraint bookings_no_overlap;
alter table public.bookings drop constraint bookings_half_day_single_chk;
alter table public.bookings drop column period;
alter table public.bookings drop column slot;

alter table public.bookings add constraint bookings_hours_chk check (
  (start_hour is null and end_hour is null)
  or (start_date = end_date and start_hour between 7 and 21 and end_hour between 8 and 22 and end_hour - start_hour >= 5)
);

alter table public.bookings
  add column period tsrange generated always as (
    case when start_hour is null
      then tsrange(start_date + interval '0 hour', end_date + interval '1 day', '[)')
      else tsrange(start_date + make_interval(hours => start_hour), start_date + make_interval(hours => end_hour), '[)')
    end
  ) stored;

alter table public.bookings add constraint bookings_no_overlap exclude using gist (
  listing_id with =,
  period with &&
) where (status in ('accepted', 'paid', 'in_progress'));

create or replace function public.bookings_prepare()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  l public.listings;
  s public.platform_settings;
  rent int;
  hours int;
begin
  select * into l from public.listings where id = new.listing_id;
  select * into s from public.platform_settings where id;
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
  if new.start_hour is not null then
    hours := new.end_hour - new.start_hour;
    if new.start_date <> new.end_date or hours < s.min_rental_hours then
      raise exception 'Location de % h minimum, le même jour', s.min_rental_hours;
    end if;
    -- jusqu'à 6 h : prix demi-journée (fixé par le propriétaire, sinon 60 % du prix jour) ; au-delà : prix journée
    rent := case when hours <= s.half_day_max_hours
                 then coalesce(l.price_half_day_cents, round(l.price_per_day_cents * 0.6)::int)
                 else l.price_per_day_cents end;
  else
    rent := l.price_per_day_cents * ((new.end_date - new.start_date) + 1);
  end if;
  new.owner_id                 := l.owner_id;
  new.price_per_day_cents      := l.price_per_day_cents;
  new.deposit_cents            := l.deposit_cents;
  new.delivery_fee_cents       := case when new.handover_mode = 'delivery' then coalesce(l.delivery_fee_cents, 0) else 0 end;
  new.subtotal_cents           := rent + new.delivery_fee_cents;
  new.fee_cents                := public.rental_fee(rent, new.renter_id);
  new.total_cents              := new.subtotal_cents + new.fee_cents;
  new.status                   := 'pending';
  new.stripe_payment_intent_id := null;
  return new;
end $$;

create or replace function public.bookings_guard()
returns trigger language plpgsql set search_path = '' as $$
begin
  if current_user in ('service_role', 'postgres') then return new; end if;

  if (new.listing_id, new.renter_id, new.owner_id, new.start_date, new.end_date, new.start_hour, new.end_hour, new.handover_mode,
      new.delivery_fee_cents, new.subtotal_cents, new.fee_cents, new.total_cents, new.deposit_cents,
      new.stripe_payment_intent_id)
     is distinct from
     (old.listing_id, old.renter_id, old.owner_id, old.start_date, old.end_date, old.start_hour, old.end_hour, old.handover_mode,
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

drop function public.listing_busy_ranges(uuid);
create function public.listing_busy_ranges(p_listing uuid)
returns table (start_date date, end_date date, start_hour smallint, end_hour smallint)
language sql stable security definer set search_path = '' as $$
  select b.start_date, b.end_date, b.start_hour, b.end_hour
  from public.bookings b
  join public.listings l on l.id = b.listing_id
  where b.listing_id = p_listing
    and l.status = 'active'
    and b.status in ('accepted', 'paid', 'in_progress')
    and b.end_date >= current_date
  order by b.start_date, b.start_hour nulls first;
$$;
grant execute on function public.listing_busy_ranges(uuid) to anon, authenticated;

update public.assistant_faq
   set answer = 'De 5 h à 30 jours. Sur une journée, choisissez vos heures entre 7 h et 22 h, 5 h minimum : jusqu''à 6 h, c''est le tarif demi-journée ; au-delà, le tarif journée.'
 where question = 'Combien de temps peut-on louer ?';
