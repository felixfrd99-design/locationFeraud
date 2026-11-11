-- =====================================================================
--  REBOND — durcissement (appliqué après schema.sql et 02_app.sql)
--  Suite aux recommandations de sécurité et de performance de Supabase.
-- =====================================================================

-- Fonctions de déclencheurs : jamais appelables via l'API (les déclencheurs continuent de fonctionner)
revoke execute on function public.handle_new_user()  from public, anon, authenticated;
revoke execute on function public.bookings_prepare() from public, anon, authenticated;
revoke execute on function public.bookings_guard()   from public, anon, authenticated;
revoke execute on function public.offers_prepare()   from public, anon, authenticated;
revoke execute on function public.offers_guard()     from public, anon, authenticated;
revoke execute on function public.offers_mark_sold() from public, anon, authenticated;
revoke execute on function public.touch_updated_at() from public, anon, authenticated;

-- Index manquants sur les clés étrangères
create index if not exists listings_category_idx       on public.listings (category_id);
create index if not exists messages_sender_idx         on public.messages (sender_id);
create index if not exists messages_recipient_idx      on public.messages (recipient_id);
create index if not exists purchase_offers_listing_idx on public.purchase_offers (listing_id);
create index if not exists reviews_author_idx          on public.reviews (author_id);

-- Une seule règle de lecture des annonces (plus rapide que deux règles cumulées)
drop policy "Annonces visibles" on public.listings;
drop policy "Annonce visible par ses locataires" on public.listings;
create policy "Annonces visibles" on public.listings for select
  using (
    status = 'active'
    or owner_id = (select auth.uid())
    or exists (
      select 1 from public.bookings b
      where b.listing_id = listings.id and b.renter_id = (select auth.uid())
    )
  );
