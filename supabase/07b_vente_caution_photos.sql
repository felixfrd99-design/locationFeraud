-- =====================================================================
--  SPOLOC — vente sécurisée, double signature, caution = valeur de
--  l'objet, photos obligatoires, délais boutique
--  À appliquer après 07a_etats_vente.sql.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Réglages : droit de retrait et délais en boutique
-- ---------------------------------------------------------------------
alter table public.platform_settings
  add column withdrawal_hours          int not null default 48 check (withdrawal_hours >= 0),
  add column shop_dropoff_hours_before int not null default 24 check (shop_dropoff_hours_before >= 0),
  add column shop_pickup_hours_after   int not null default 72 check (shop_pickup_hours_after >= 0),
  add column max_code_attempts         int not null default 3  check (max_code_attempts between 1 and 10);

-- ---------------------------------------------------------------------
-- 2. Caution = valeur de l'objet (le propriétaire ne choisit pas la caution)
-- ---------------------------------------------------------------------
alter table public.listings
  add column item_value_cents int check (item_value_cents is null or item_value_cents > 0);

create or replace function public.listings_guard()
returns trigger language plpgsql set search_path = '' as $$
begin
  if current_user in ('service_role', 'postgres') then
    if new.item_value_cents is not null then new.deposit_cents := new.item_value_cents; end if;
    return new;
  end if;
  if new.item_value_cents is null and (tg_op = 'INSERT' or old.item_value_cents is not null) then
    raise exception 'Indiquez la valeur actuelle de l''objet : elle sert de caution';
  end if;
  new.deposit_cents := coalesce(new.item_value_cents, old.deposit_cents);
  if tg_op = 'INSERT' then
    new.brand_verified := false;
  elsif (new.brand, new.model, new.brand_proof_path) is distinct from (old.brand, old.model, old.brand_proof_path) then
    new.brand_verified := false;
  elsif new.brand_verified is distinct from old.brand_verified then
    raise exception 'La vérification de marque est faite par l''équipe';
  end if;
  return new;
end $$;

update public.listings set item_value_cents = deposit_cents where deposit_cents > 0;

-- ---------------------------------------------------------------------
-- 3. Catalogue : seules les annonces avec au moins 2 photos apparaissent
-- ---------------------------------------------------------------------
create or replace function public.search_listings(
  p_category text default null,
  p_q        text default null,
  p_start    date default null,
  p_end      date default null
)
returns setof public.listings
language sql stable security definer set search_path = '' as $$
  select l.*
  from public.listings l
  join public.categories c on c.id = l.category_id
  where l.status = 'active'
    and (select count(*) from public.listing_images i where i.listing_id = l.id) >= 2
    and (p_category is null or c.slug = p_category)
    and (coalesce(p_q, '') = ''
         or l.title ilike '%' || p_q || '%'
         or l.city  ilike '%' || p_q || '%'
         or coalesce(l.brand, '') ilike '%' || p_q || '%')
    and (p_start is null or p_end is null or not exists (
          select 1 from public.bookings b
          where b.listing_id = l.id
            and b.status in ('accepted', 'paid', 'in_progress')
            and daterange(b.start_date, b.end_date, '[]') && daterange(p_start, p_end, '[]')
        ))
  order by l.created_at desc;
$$;

-- ---------------------------------------------------------------------
-- 4. Vente : offre seulement pendant ou après une location,
--    double confirmation du vendeur, confirmation de l'acheteur,
--    annulation possible jusqu'à la remise, droit de retrait 48 h
-- ---------------------------------------------------------------------
alter table public.purchase_offers
  add column seller_confirmed_at    timestamptz,
  add column buyer_confirmed_at     timestamptz,
  add column completed_at           timestamptz,
  add column withdrawal_reason      text check (withdrawal_reason is null or char_length(withdrawal_reason) <= 1000),
  add column withdrawal_requested_by uuid references public.profiles (id);
create index purchase_offers_withdrawal_idx on public.purchase_offers (withdrawal_requested_by);

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
  if not exists (
    select 1 from public.bookings b
    where b.listing_id = new.listing_id and b.renter_id = new.buyer_id and b.status in ('in_progress', 'completed')) then
    raise exception 'L''offre d''achat s''ouvre pendant ou après votre location de cet objet';
  end if;
  if exists (
    select 1 from public.purchase_offers o
    where o.listing_id = new.listing_id and o.buyer_id = new.buyer_id and o.status in ('pending', 'accepted', 'confirmed', 'paid')) then
    raise exception 'Vous avez déjà une offre en cours sur cet objet';
  end if;
  new.seller_id                := l.owner_id;
  new.fee_cents                := public.sale_fee(new.amount_cents, new.buyer_id);
  new.total_cents              := new.amount_cents + new.fee_cents;
  new.status                   := 'pending';
  new.stripe_payment_intent_id := null;
  new.seller_confirmed_at      := null;
  new.buyer_confirmed_at       := null;
  new.completed_at             := null;
  new.withdrawal_reason        := null;
  new.withdrawal_requested_by  := null;
  return new;
end $$;

-- Transitions autorisées depuis le site :
--   vendeur  : pending → accepted (1re confirmation) → confirmed (2e confirmation, vente ferme)
--   acheteur : confirme son achat (buyer_confirmed_at) une fois la vente ferme
--   les deux : annulation possible jusqu'à la remise (pending, accepted, confirmed)
create or replace function public.offers_guard()
returns trigger language plpgsql set search_path = '' as $$
begin
  if current_user in ('service_role', 'postgres') then return new; end if;

  if (new.listing_id, new.buyer_id, new.seller_id, new.amount_cents, new.fee_cents, new.total_cents,
      new.stripe_payment_intent_id, new.seller_confirmed_at, new.completed_at, new.withdrawal_reason, new.withdrawal_requested_by)
     is distinct from
     (old.listing_id, old.buyer_id, old.seller_id, old.amount_cents, old.fee_cents, old.total_cents,
      old.stripe_payment_intent_id, old.seller_confirmed_at, old.completed_at, old.withdrawal_reason, old.withdrawal_requested_by) then
    raise exception 'Cette information ne peut pas être modifiée';
  end if;

  -- confirmation de l'acheteur : une seule fois, après la confirmation ferme du vendeur
  if new.buyer_confirmed_at is distinct from old.buyer_confirmed_at then
    if auth.uid() <> old.buyer_id or old.buyer_confirmed_at is not null or old.status not in ('confirmed', 'paid') then
      raise exception 'Confirmation d''achat impossible à ce stade';
    end if;
    new.buyer_confirmed_at := now();
  end if;

  if new.status is distinct from old.status then
    if auth.uid() = old.seller_id and old.status = 'pending' and new.status in ('accepted', 'declined') then
      null;
    elsif auth.uid() = old.seller_id and old.status = 'accepted' and new.status = 'confirmed' then
      new.seller_confirmed_at := now();
    elsif auth.uid() = old.seller_id and old.status = 'accepted' and new.status = 'declined' then
      null;
    elsif auth.uid() in (old.buyer_id, old.seller_id) and old.status in ('pending', 'accepted', 'confirmed') and new.status = 'cancelled' then
      null;
    else
      raise exception 'Changement de statut non autorisé';
    end if;
  end if;
  return new;
end $$;

-- Droit de retrait : dans les 48 h après la remise, acheteur ou vendeur
create or replace function public.request_sale_withdrawal(p_offer uuid, p_reason text)
returns text language plpgsql security definer set search_path = '' as $$
declare
  o public.purchase_offers;
  hours int;
begin
  select * into o from public.purchase_offers where id = p_offer for update;
  if o.id is null then raise exception 'Vente introuvable'; end if;
  if auth.uid() is null or auth.uid() not in (o.buyer_id, o.seller_id) then raise exception 'Vente introuvable'; end if;
  if o.status <> 'completed' then raise exception 'Le droit de retrait s''exerce après la remise'; end if;
  select withdrawal_hours into hours from public.platform_settings where id;
  if o.completed_at < now() - make_interval(hours => hours) then
    return format('Le délai de %s h est dépassé : écrivez-nous si besoin', hours);
  end if;
  if coalesce(trim(p_reason), '') = '' then raise exception 'Expliquez le problème en quelques mots'; end if;
  update public.purchase_offers
     set status = 'withdrawal_requested', withdrawal_reason = left(trim(p_reason), 1000), withdrawal_requested_by = auth.uid()
   where id = p_offer;
  return 'ok';
end $$;
revoke execute on function public.request_sale_withdrawal(uuid, text) from public, anon;
grant execute on function public.request_sale_withdrawal(uuid, text) to authenticated;

-- ---------------------------------------------------------------------
-- 5. Remise : 3 essais, signature des DEUX personnes
-- ---------------------------------------------------------------------
alter table public.handovers add column confirmer_signature_path text;

drop function public.confirm_handover(public.handover_kind, uuid, text, public.item_condition, text[], text, text);
create function public.confirm_handover(
  p_kind                public.handover_kind,
  p_id                  uuid,
  p_code                text,
  p_condition           public.item_condition,
  p_photos              text[],
  p_signature           text,   -- signature de la personne qui donne son code
  p_confirmer_signature text,   -- signature de la personne qui valide
  p_notes               text default ''
)
returns text language plpgsql security definer set search_path = '' as $$
declare
  me     uuid := auth.uid();
  b      public.bookings;
  o      public.purchase_offers;
  c      public.handover_codes;
  signer uuid;
  maxtry int;
begin
  if me is null then raise exception 'Connexion requise'; end if;
  if coalesce(cardinality(p_photos), 0) < 2 then raise exception 'Au moins 2 photos sont nécessaires'; end if;
  if coalesce(p_signature, '') = '' or coalesce(p_confirmer_signature, '') = '' then
    raise exception 'Les deux signatures sont nécessaires';
  end if;
  if exists (select 1 from unnest(p_photos) x where x not like me::text || '/%')
     or p_signature not like me::text || '/%' or p_confirmer_signature not like me::text || '/%' then
    raise exception 'Photos ou signatures invalides';
  end if;
  select max_code_attempts into maxtry from public.platform_settings where id;

  if p_kind = 'sale' then
    select * into o from public.purchase_offers where id = p_id for update;
    if o.id is null then raise exception 'Vente introuvable'; end if;
    if me <> o.seller_id then raise exception 'Seul le vendeur confirme la remise'; end if;
    if o.status not in ('confirmed', 'paid') then raise exception 'La vente doit d''abord être confirmée par le vendeur'; end if;
    if o.buyer_confirmed_at is null then raise exception 'L''acheteur doit d''abord confirmer son achat'; end if;
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
  if c.attempts >= maxtry then return 'Code bloqué après 3 essais : contactez le support'; end if;
  if c.code <> trim(p_code) then
    update public.handover_codes set attempts = attempts + 1 where id = c.id;
    if c.attempts + 1 >= maxtry then return 'Code incorrect : code bloqué, contactez le support'; end if;
    return format('Code incorrect (%s essai(s) restant(s))', maxtry - c.attempts - 1);
  end if;

  update public.handover_codes set used_at = now() where id = c.id;
  insert into public.handovers (booking_id, offer_id, kind, condition, notes, photo_paths, signature_path, confirmer_signature_path, confirmed_by, signed_by)
  values (case when p_kind = 'sale' then null else p_id end,
          case when p_kind = 'sale' then p_id else null end,
          p_kind, p_condition, coalesce(p_notes, ''), p_photos, p_signature, p_confirmer_signature, me, signer);

  if p_kind = 'pickup' then
    update public.bookings set status = 'in_progress' where id = p_id;
  elsif p_kind = 'return' then
    update public.bookings set status = 'completed' where id = p_id;
  else
    update public.purchase_offers set status = 'completed', completed_at = now() where id = p_id;
    update public.listings set status = 'sold' where id = o.listing_id;
    -- l'acheteur avait l'objet en location : la location se termine avec la vente
    update public.bookings set status = 'completed' where listing_id = o.listing_id and renter_id = o.buyer_id and status = 'in_progress';
  end if;
  return 'ok';
end $$;
revoke execute on function public.confirm_handover(public.handover_kind, uuid, text, public.item_condition, text[], text, text, text) from public, anon;
grant execute on function public.confirm_handover(public.handover_kind, uuid, text, public.item_condition, text[], text, text, text) to authenticated;

create or replace function public.can_see_handover_file(p_path text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.handovers h
    where (p_path = any (h.photo_paths) or p_path = h.signature_path or p_path = h.confirmer_signature_path)
      and auth.uid() in (h.confirmed_by, h.signed_by)
  );
$$;

-- ---------------------------------------------------------------------
-- 6. Réponses de l'assistant mises à jour
-- ---------------------------------------------------------------------
update public.assistant_faq set answer = 'La caution correspond à la valeur de l''objet déclarée par le propriétaire. C''est une empreinte bancaire : le montant est bloqué sur votre carte la veille du retrait, sans être débité, puis libéré au retour. En cas de casse ou de vol, tout ou partie peut être retenu, photos de l''état à l''appui.'
 where question = 'Comment fonctionne la caution ?';
update public.assistant_faq set answer = 'Il prouve que la remise a bien eu lieu. Le locataire donne son code au propriétaire au retrait ; au retour, c''est le propriétaire qui donne le sien. 3 essais maximum. Avec les photos et les signatures des deux personnes, personne ne peut contester.'
 where question = 'À quoi sert le code à 4 chiffres ?';
update public.assistant_faq set answer = 'Oui, si le propriétaire a activé l''option rachat (badge « Rachetable »), pendant ou après votre location de l''objet. Le vendeur confirme deux fois, vous confirmez votre achat, puis l''objet est remis avec photos, code et deux signatures. La vente est définitive, mais chacun dispose de 48 h pour signaler un problème.'
 where question = 'Peut-on acheter l''objet loué ?';
insert into public.assistant_faq (question, answer, keywords, sort_order) values
('Puis-je revenir sur un achat ?', 'La vente est définitive une fois l''objet remis. Avant la remise, l''acheteur comme le vendeur peuvent annuler. Après la remise, chacun dispose de 48 h pour signaler un problème depuis « Mes locations » ou « Mon matériel » : Spoloc étudie la demande et peut annuler la vente.', '{retractation,retrait,annuler achat,revenir,rembourser,probleme,defaut}', 18),
('Les photos sont-elles obligatoires ?', 'Oui : au moins 2 photos pour publier une annonce, et au moins 2 photos à chaque remise et à chaque retour. C''est ce qui protège les deux parties.', '{photo,photos,obligatoire,image}', 19);
