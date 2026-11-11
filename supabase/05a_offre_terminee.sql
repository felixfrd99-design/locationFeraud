-- =====================================================================
--  Nouvel état « completed » pour les ventes (objet remis à l'acheteur).
--  Migration séparée : une nouvelle valeur d'enum ne peut pas être
--  utilisée dans la même transaction que sa création.
-- =====================================================================
alter type public.offer_status add value if not exists 'completed';
