-- =====================================================================
--  SPOLOC — demi-journée, messagerie protégée, assistant
--  À appliquer après 05b_club_remises.sql.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Location à la demi-journée (matin 8 h–13 h, après-midi 13 h–20 h)
-- ---------------------------------------------------------------------
alter table public.listings
  add column price_half_day_cents int check (price_half_day_cents is null or price_half_day_cents > 0);

alter table public.bookings
  add column slot text not null default 'full' check (slot in ('full', 'am', 'pm')),
  add constraint bookings_half_day_single_chk check (slot = 'full' or start_date = end_date);

-- Période réelle occupée, à l'heure près, pour empêcher les chevauchements
alter table public.bookings
  add column period tsrange generated always as (
    tsrange(
      start_date + case when slot = 'pm' then time '13:00' else time '00:00' end,
      case when slot = 'am' then start_date + time '13:00' else (end_date + 1) + time '00:00' end,
      '[)')
  ) stored;

alter table public.bookings drop constraint bookings_no_overlap;
alter table public.bookings add constraint bookings_no_overlap exclude using gist (
  listing_id with =,
  period with &&
) where (status in ('accepted', 'paid', 'in_progress'));

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
  if coalesce(new.slot, 'full') in ('am', 'pm') then
    -- demi-journée : prix fixé par le propriétaire, sinon 60 % du prix journée
    rent := coalesce(l.price_half_day_cents, round(l.price_per_day_cents * 0.6)::int);
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

  if (new.listing_id, new.renter_id, new.owner_id, new.start_date, new.end_date, new.slot, new.handover_mode,
      new.delivery_fee_cents, new.subtotal_cents, new.fee_cents, new.total_cents, new.deposit_cents,
      new.stripe_payment_intent_id)
     is distinct from
     (old.listing_id, old.renter_id, old.owner_id, old.start_date, old.end_date, old.slot, old.handover_mode,
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

-- Calendrier : les périodes prises, avec le créneau (sans dire qui)
drop function public.listing_busy_ranges(uuid);
create function public.listing_busy_ranges(p_listing uuid)
returns table (start_date date, end_date date, slot text)
language sql stable security definer set search_path = '' as $$
  select b.start_date, b.end_date, b.slot
  from public.bookings b
  join public.listings l on l.id = b.listing_id
  where b.listing_id = p_listing
    and l.status = 'active'
    and b.status in ('accepted', 'paid', 'in_progress')
    and b.end_date >= current_date
  order by b.start_date;
$$;
grant execute on function public.listing_busy_ranges(uuid) to anon, authenticated;

-- ---------------------------------------------------------------------
-- 2. Messagerie entre particuliers : coordonnées masquées, interlocuteurs contrôlés
-- ---------------------------------------------------------------------
alter table public.messages add column masked boolean not null default false;

create or replace function public.mask_contacts(p text)
returns text language plpgsql immutable set search_path = '' as $$
declare r text := p;
begin
  -- emails, y compris « arobase » et « (at) »
  r := regexp_replace(r, '[A-Za-z0-9._%+-]+\s*(@|\(at\)|\[at\]|\sarobase\s|\sat\s)\s*[A-Za-z0-9-]+(\s*(\.|\(dot\)|\spoint\s)\s*[A-Za-z]{2,})+', '[coordonnées masquées]', 'gi');
  -- liens et noms de domaine
  r := regexp_replace(r, '(https?://|www\.)\S+', '[lien masqué]', 'gi');
  r := regexp_replace(r, '\m[A-Za-z0-9-]+\.(com|fr|net|org|io|me|be|ch|eu|co|app|link|ly)\M\S*', '[lien masqué]', 'gi');
  -- numéros de téléphone français et internationaux, avec ou sans séparateurs
  r := regexp_replace(r, '(\+|00)\s?\d{2}([\s.\-]?\d){8,}', '[numéro masqué]', 'g');
  r := regexp_replace(r, '\m0\d([\s.\-]?\d){8}\M', '[numéro masqué]', 'g');
  -- messageries externes
  r := regexp_replace(r, '\m(whats\s?app|wh?atsap+|telegram|signal|snap(chat)?|insta(gram)?|messenger|facebook|fb|tiktok|linkedin|lydia|paypal|wero|iban|rib|esp[eè]ces|cash)\M', '[hors Spoloc]', 'gi');
  return r;
end $$;

create or replace function public.messages_prepare()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  owner uuid;
  clean text;
begin
  select owner_id into owner from public.listings where id = new.listing_id;
  if owner is null then raise exception 'Annonce introuvable'; end if;
  -- un message concerne toujours le propriétaire de l'annonce
  if new.sender_id <> owner and new.recipient_id <> owner then
    raise exception 'Vous ne pouvez écrire qu''au propriétaire de l''annonce';
  end if;
  -- le propriétaire ne répond qu'aux personnes qui l'ont contacté ou ont réservé
  if new.sender_id = owner and not exists (
       select 1 from public.messages m where m.listing_id = new.listing_id and m.sender_id = new.recipient_id)
     and not exists (
       select 1 from public.bookings b where b.listing_id = new.listing_id and b.renter_id = new.recipient_id)
     and not exists (
       select 1 from public.purchase_offers o where o.listing_id = new.listing_id and o.buyer_id = new.recipient_id) then
    raise exception 'Cette personne ne vous a pas encore contacté';
  end if;
  clean := public.mask_contacts(new.body);
  new.masked := clean is distinct from new.body;
  new.body := clean;
  new.created_at := now();
  return new;
end $$;
create trigger messages_before_insert before insert on public.messages
  for each row execute function public.messages_prepare();
revoke execute on function public.messages_prepare() from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 3. Assistant gratuit : base de questions/réponses que tu enrichis
--    + journal des questions posées (pour voir ce qu'il faut ajouter)
-- ---------------------------------------------------------------------
create table public.assistant_faq (
  id         serial primary key,
  question   text not null,
  answer     text not null,
  keywords   text[] not null default '{}',
  active     boolean not null default true,
  sort_order smallint not null default 0,
  updated_at timestamptz not null default now()
);
alter table public.assistant_faq enable row level security;
create policy "Réponses de l'assistant visibles" on public.assistant_faq for select using (active);

create table public.assistant_questions (
  id         bigserial primary key,
  question   text not null check (char_length(question) between 2 and 500),
  answered   boolean not null default false,
  faq_id     int references public.assistant_faq (id) on delete set null,
  page       text check (page is null or char_length(page) <= 40),
  created_at timestamptz not null default now()
);
create index assistant_questions_faq_idx on public.assistant_questions (faq_id);
alter table public.assistant_questions enable row level security;
create policy "Poser une question à l'assistant" on public.assistant_questions for insert to anon, authenticated
  with check (true);

insert into public.assistant_faq (question, answer, keywords, sort_order) values
('Comment fonctionne Spoloc ?', 'Des particuliers mettent en location le matériel de sport qu''ils utilisent peu. Vous cherchez par sport, dates et quartier, vous envoyez une demande, le propriétaire accepte, vous payez en ligne et récupérez le matériel avec un code.', '{fonctionne,marche,principe,comment,spoloc,quoi}', 1),
('Combien de temps peut-on louer ?', 'D''une demi-journée (matin 8 h–13 h ou après-midi 13 h–20 h) jusqu''à 30 jours.', '{duree,temps,combien,jours,demi,journee,matin,apres-midi,minimum,maximum,30}', 2),
('Comment se passe le paiement ?', 'Vous payez en ligne par carte, sur Spoloc, une fois votre demande acceptée. L''argent est conservé par notre prestataire de paiement et n''est versé au propriétaire que le lendemain de la remise du matériel.', '{paiement,payer,carte,cb,argent,prix,regler}', 3),
('Comment fonctionne la caution ?', 'La caution est une empreinte bancaire : le montant est bloqué sur votre carte la veille du retrait, sans être débité. Elle est libérée au retour. En cas de casse ou de vol, tout ou partie peut être retenu, photos de l''état à l''appui.', '{caution,depot,garantie,empreinte,bloque,debite}', 4),
('Comment récupérer le matériel ?', 'Trois possibilités selon l''annonce : en main propre sur un créneau proposé par le propriétaire, livré près de chez vous s''il le propose, ou dans une boutique partenaire. À chaque remise : photos, code à 4 chiffres et signature.', '{recuperer,retrait,remise,recevoir,livraison,boutique,rendez-vous,chercher}', 5),
('À quoi sert le code à 4 chiffres ?', 'Il prouve que la remise a bien eu lieu. Le locataire donne son code au propriétaire au retrait ; au retour, c''est le propriétaire qui donne le sien. Avec les photos et la signature, personne ne peut contester.', '{code,chiffres,signature,photos,preuve}', 6),
('Que se passe-t-il si le matériel est abîmé ou volé ?', 'Les photos prises au retrait et au retour servent de référence. En cas de dommage ou de vol, la caution est retenue en tout ou partie, après échange entre les deux parties. Écrivez-nous si vous n''arrivez pas à vous mettre d''accord.', '{abime,casse,vol,vole,degat,dommage,perdu,litige,probleme}', 7),
('Puis-je annuler ?', 'Oui, tant que la location n''a pas commencé, depuis « Mes locations ». Rien n''est débité tant que la demande n''est pas acceptée.', '{annuler,annulation,rembourse,remboursement,changer}', 8),
('Combien ça coûte ?', 'Le prix à la journée est fixé par le propriétaire. Le total exact (location, frais de service, livraison éventuelle) est affiché avant de payer. Publier une annonce est gratuit, et les propriétaires ne paient jamais de frais.', '{cout,coute,tarif,frais,cher,gratuit,commission}', 9),
('Comment mettre mon matériel en location ?', 'Créez un compte, cliquez sur « Publier », ajoutez des photos, l''état, la marque, les dimensions, votre prix et vos modes de remise. C''est gratuit et vous gagnez 50 points pour votre première annonce.', '{publier,annonce,mettre,proposer,deposer,louer mon,prêter,preter}', 10),
('Quand suis-je payé quand je loue mon matériel ?', 'Le lendemain de la remise du matériel au locataire, sur votre compte bancaire. Vous touchez 100 % du prix que vous avez fixé.', '{paye,verse,virement,recevoir argent,quand,proprietaire}', 11),
('Peut-on acheter l''objet loué ?', 'Oui, si le propriétaire a activé l''option rachat (badge « Rachetable »). Faites une offre depuis la fiche de l''objet ; s''il accepte, vous payez en ligne et l''objet vous est remis avec photos, code et signature.', '{acheter,achat,rachat,racheter,vendre,vente,offre}', 12),
('Qu''est-ce que le Club et les points ?', 'Vous gagnez 1 point par euro loué, prêté, acheté ou vendu, 50 points pour votre première annonce, 20 par avis et 200 par ami parrainé. Les points s''échangent contre des frais offerts, des réductions et des bons en boutique.', '{club,points,fidelite,recompense,parrainage,parrain,ami,inviter}', 13),
('Que veut dire « Marque vérifiée » ?', 'Le propriétaire nous a envoyé une preuve (étiquette, numéro de série ou facture) que nous avons contrôlée. Le badge disparaît si la marque est modifiée.', '{marque,verifiee,verification,authentique,contrefacon,faux}', 14),
('Puis-je échanger mon numéro avec le propriétaire ?', 'Non : pour que la caution, les photos et l''aide en cas de litige fonctionnent, tout passe par la messagerie Spoloc. Les numéros, emails et liens y sont masqués automatiquement.', '{numero,telephone,email,mail,contact,whatsapp,coordonnees,joindre}', 15),
('Où est disponible Spoloc ?', 'Nous commençons par Paris et la petite couronne, avec du matériel pour partir en week-end : bivouac, paddle, kayak, escalade, vélo.', '{ou,ville,paris,region,disponible,zone,quartier}', 16),
('Vous êtes une boutique ?', 'Devenez point de dépôt et de retrait : des clients du quartier passent chez vous et vous êtes rémunéré à chaque objet géré. Écrivez-nous depuis la page « Qui sommes-nous ».', '{boutique,magasin,partenaire,commercant,point relais}', 17);
