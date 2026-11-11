-- =====================================================================
--  REBOND — fonctions pour l'espace /app
--  À exécuter APRÈS schema.sql (SQL Editor › New query › Run).
-- =====================================================================

-- Catalogue : annonces actives, filtrées par catégorie, texte et dates.
-- Une annonce est masquée si une location acceptée / payée / en cours
-- chevauche les dates demandées. Ne renvoie aucune info sur les locataires.
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
    and (p_category is null or c.slug = p_category)
    and (coalesce(p_q, '') = ''
         or l.title ilike '%' || p_q || '%'
         or l.city  ilike '%' || p_q || '%')
    and (p_start is null or p_end is null or not exists (
          select 1 from public.bookings b
          where b.listing_id = l.id
            and b.status in ('accepted', 'paid', 'in_progress')
            and daterange(b.start_date, b.end_date, '[]') && daterange(p_start, p_end, '[]')
        ))
  order by l.created_at desc;
$$;

-- Calendrier d'une annonce : seulement les périodes déjà prises (sans qui ni combien)
create or replace function public.listing_busy_ranges(p_listing uuid)
returns table (start_date date, end_date date)
language sql stable security definer set search_path = '' as $$
  select b.start_date, b.end_date
  from public.bookings b
  join public.listings l on l.id = b.listing_id
  where b.listing_id = p_listing
    and l.status = 'active'
    and b.status in ('accepted', 'paid', 'in_progress')
    and b.end_date >= current_date
  order by b.start_date;
$$;

grant execute on function public.search_listings(text, text, date, date) to anon, authenticated;
grant execute on function public.listing_busy_ranges(uuid)             to anon, authenticated;

-- Un locataire garde l'accès à l'annonce qu'il a louée, même si elle n'est plus en ligne
create policy "Annonce visible par ses locataires" on public.listings for select to authenticated
  using (exists (
    select 1 from public.bookings b
    where b.listing_id = listings.id and b.renter_id = (select auth.uid())
  ));
