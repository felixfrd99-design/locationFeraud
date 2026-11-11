-- =====================================================================
--  Nouveaux états de vente (migration séparée : une valeur d'enum
--  ne peut pas être utilisée dans la transaction qui la crée)
--    confirmed            : le vendeur a confirmé deux fois, la vente est ferme
--    withdrawal_requested : après la remise, une des deux parties exerce
--                           son droit de retrait (48 h) ; Spoloc arbitre
-- =====================================================================
alter type public.offer_status add value if not exists 'confirmed';
alter type public.offer_status add value if not exists 'withdrawal_requested';
