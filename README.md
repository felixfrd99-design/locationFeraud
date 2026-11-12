# Spoloc

*Le sport, en location.*

Spoloc (ex-Rebond, ex-Location Ferro) est une marketplace de location d'équipements sportifs entre particuliers : une personne met en location un équipement dont elle se sert peu, une autre le loue, et peut aussi proposer de l'acheter.

## Contenu

- `index.html` : le site public en onglets (Louer, Publier, Qui sommes-nous, Aide avec l'assistant)
- `app/index.html` : l'espace connecté (réservation, remises, messagerie, club)
- `assets/spoloc.js` : pictogrammes, logo et assistant gratuit (réponses dans la table `assistant_faq`)

## Commission

Réglée dans le bloc `CONFIG` en haut du script de `index.html` :

- `COMMISSION_RATE` : 10 % appliqués à chaque location et à chaque vente
- `COMMISSION_MIN` : plancher en € par transaction (2 € par défaut)

## Prochaines étapes

- Base de données : Supabase, projet `qdnytvevomychpuuxbym` (région eu-west-1). Migrations dans `supabase/`, à appliquer dans l'ordre : `schema.sql`, `02_app.sql`, `03_hardening.sql`, `04_rachat_30j.sql`, `05a_offre_terminee.sql`, `05b_club_remises.sql`, `06_demi_journee_messages_assistant.sql`, `07a_etats_vente.sql`, `07b_vente_caution_photos.sql`, `08_location_heures.sql` (les fichiers « a » seuls, avant les « b »). Toutes déjà appliquées sur le projet.
- Paiements et reversement aux propriétaires : Stripe
- Mise en ligne : Vercel, branché sur ce dépôt

## Lancer en local

Ouvrir `index.html` dans un navigateur.
