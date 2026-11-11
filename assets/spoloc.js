/* =====================================================================
   SPOLOC — éléments partagés par le site et l'app
   - pictogrammes des catégories et logo
   - assistant gratuit (base de questions/réponses dans Supabase)
   ===================================================================== */
(function () {
  const SUPABASE_URL = "https://qdnytvevomychpuuxbym.supabase.co";
  const SUPABASE_KEY = "sb_publishable_I5EZVxCYdLCmY-7hP8GRhw_y4ZvBDIo";
  const CONTACT_EMAIL = "spoloc@outlook.com";

  /* ---------- Pictogrammes (traits, 24×24) ---------- */
  /* Pictogrammes Material Symbols (Google, licence Apache 2.0) */
  const ICONS = {
    "velo": "M195.43-158.57q-81.71 0-138.57-57.35Q0-273.28 0-355q0-81.24 57.48-138.34 57.48-57.09 138.95-57.09 70.29 0 124.5 45.5 54.22 45.5 65.7 115.5h47.89l-81.04-229.14h-42.05q-13.47 0-22.45-8.85Q280-636.28 280-650q0-13.72 8.86-22.58 8.86-8.85 22.57-8.85H439.2q13.47 0 22.45 9.09 8.98 9.1 8.98 23.54 0 13.23-8.5 21.73t-21.5 8.5h-21.28l25.28 68.14h216.26l-70.28-188.14H518q-13.48 0-22.46-8.85-8.97-8.86-8.97-22.58 0-13.72 8.85-22.58 8.86-8.85 22.58-8.85h67.57q24.47 0 41.45 11.23Q644-778.96 652-756.48l75.52 206.05h37.05q81.71 0 138.57 56.35Q960-437.72 960-357q0 81.72-56.86 139.84-56.86 58.12-138.57 58.12-72.24 0-126.48-47.76-54.24-47.77-66.48-119.77H386.63q-11.48 72-65.1 120-53.62 48-126.1 48Zm128.85-168v-62.86h-86.85q-13.47 0-22.45 8.85Q206-371.72 206-358q0 13.72 8.86 22.58 8.86 8.85 22.57 8.85h86.85Zm175.68-62.86h72.65q3.76-22.29 15.02-49.45 11.26-27.16 30.3-48.69H466.35l33.61 98.14Zm188.13-77.18 32.52 84.09q5 11.72 15.98 16.84 10.98 5.11 23.45.88 12.72-4 17.84-15.98 5.12-11.98 1.12-23.7l-28.04-82.85-62.87 20.72Z",
    "glisse-eau": "M120-34.5h-10q-14.03 0-23.33-9.34-9.3-9.33-9.3-23.41t9.3-23.42Q95.97-100 110-100h10q25.29 0 49.69-7t48.4-24.76q8.61-7.24 21.86-7.24t21.96 7.24q24 17.76 48.4 24.76t49.69 7q24.28 0 49.3-7.38 25.03-7.38 49.03-24.38Q467.8-138 480.5-138q12.7 0 21.41 6.24 24 17.76 48.4 24.64 24.4 6.88 49.69 6.88 24.29 0 49.31-7.26 25.02-7.26 48.78-24.26 8.71-6.24 21.76-6.24t22.06 6.24q23.76 17 48.82 24.38Q815.8-100 840-100h10q14.03 0 23.33 9.33 9.3 9.34 9.3 23.42 0 14.08-9.3 23.41-9.3 9.34-23.33 9.34h-10q-29 0-59.54-8.5T720-74.26Q690.08-51.5 659.54-43T600-34.5q-29 0-59.54-8.5T480-74.26Q450.08-51.5 419.54-43T360-34.5q-29 0-59.54-8.5T240-74.26Q210.08-51.5 179.54-43T120-34.5Zm354.78-536.13L632.63-446.3v161q17.24 12.23 32.72 24.09t31.95 25.1q-21.19 17.91-45.89 28.89-24.69 10.98-51.41 10.98-33.76 0-64.76-17.4-31-17.4-55.24-46.16-24.24 28.76-55.24 46.16-31 17.4-64.76 17.4h-4.94q-2.69 0-5.02-1.24-103.95-72.48-163.31-132.58-59.36-60.11-59.36-101.81 0-26.57 21.88-35.1 21.89-8.53 44.75-8.53 28.28 0 68.07 9.52 39.78 9.52 89.58 27.05L330.13-570.2q-4.24-23.94 1.76-43.9 6-19.97 24.68-32.16l100.26-67.17q-6.76-1-20.57-3.77-13.8-2.76-29.49-5.52-15.68-2.76-29.61-6.02-13.92-3.26-20.68-4.26l-83.05 56.28q-10.95 7.72-24.01 5.92-13.06-1.79-20.54-13.69-7.75-11.9-5.51-24.86 2.24-12.95 13.96-20.67l93-63.76q5.67-3.28 11.95-5 6.28-1.72 12.92-.72l205.25 37.99q11.75 2.25 23.72 9.99 11.98 7.74 20.22 22.22l35 62q22.28 38.8 59.31 65.82 37.02 27.02 83.54 35.26 13.02 2.42 21.71 12.76 8.68 10.33 8.68 23.69 0 13.1-9.05 22.31-9.05 9.22-21.1 6.98-63.72-10-116.84-47.14-53.12-37.14-86.6-93.42l-104.26 70.41Zm-66.95 57.46 15.8 105.39q37.76 17.76 72.87 37.06 35.11 19.31 70.87 41.07v-73.78L407.83-513.17ZM684.07-758.3q-31.04 0-53.34-22.33-22.3-22.33-22.3-53.41 0-31.09 22.33-53.43 22.33-22.33 53.42-22.33 31.08 0 53.42 22.36 22.33 22.37 22.33 53.51 0 31.04-22.36 53.33-22.37 22.3-53.5 22.3Z",
    "kayak": "M120-34.5h-10q-14.03 0-23.33-9.34-9.3-9.33-9.3-23.41t9.3-23.42Q95.97-100 110-100h10q25.29 0 49.69-7t48.4-24.76q8.61-7.24 21.86-7.24t21.96 7.24q24 17.76 48.4 24.76t49.69 7q24.28 0 49.3-7.38 25.03-7.38 49.03-24.38Q467.8-138 480.5-138q12.7 0 21.41 6.24 24 17.76 48.4 24.64 24.4 6.88 49.69 6.88 24.29 0 49.31-7.26 25.02-7.26 48.78-24.26 8.71-6.24 21.76-6.24t22.06 6.24q23.76 17 48.82 24.38Q815.8-100 840-100h10q14.03 0 23.33 9.33 9.3 9.34 9.3 23.42 0 14.08-9.3 23.41-9.3 9.34-23.33 9.34h-10q-29 0-59.54-8.5T720-74.26Q690.08-51.5 659.54-43T600-34.5q-29 0-59.54-8.5T480-74.26Q450.08-51.5 419.54-43T360-34.5q-29 0-59.54-8.5T240-74.26Q210.08-51.5 179.54-43T120-34.5Zm360-565q-31.2 0-53.41-22.37-22.22-22.36-22.22-53.5 0-31.04 22.22-53.34Q448.8-751 480-751q31.2 0 53.41 22.33 22.22 22.32 22.22 53.41 0 31.09-22.22 53.42Q511.2-599.5 480-599.5ZM360.05-196.24q-23.81 0-46.92-9.03-23.1-9.04-43.17-25.53-14.48-10.77-30.96-11.27t-29.72 9.5q-8.76 6.77-17.31 12.79-8.56 6.02-16.77 11.02-15.2-3.24-32.13-7.22-16.94-3.98-34.61-9.69-43.87-12.2-43.87-37.2 0-25 43.87-36.96 45.95-12.47 93.67-22.83 47.72-10.36 88.96-17.6l55.28-177.33q8.33-29 35.36-40.57 27.03-11.58 53.47 1.9L540-500.98l118.85-62.8 69.04-160.09-15.28-39.24q-2.48-6.8-1.98-13.76t3.02-12.72l30.24-65.04q5.48-12.67 18.65-17.65 13.18-4.98 25.85.5l52.37 24.04q12.67 5.72 17.77 18.65 5.1 12.94-.62 25.61l-29.26 65.25q-2.5 5.8-7.98 10.39-5.47 4.6-11.19 6.84l-39.57 15.52-153.84 358.43q56.52 7.27 118.26 20.13 61.74 12.85 117.21 27.09 41.87 11.96 41.87 37.08 0 25.12-41.87 37.32-17.67 5.47-34.72 9.45-17.06 3.98-32.02 7.22-8.77-5-17.17-11.14-8.39-6.14-16.91-12.67-13.24-10-29.72-9.5-16.48.5-30.96 11.27-20.04 16.49-43.1 25.53-23.07 9.03-46.89 9.03-23.81 0-46.95-9.02-23.14-9.02-43.06-25.46-13.44-10.85-30.1-10.85-16.66 0-29.9 10.77-20.04 16.49-43.1 25.53-23.07 9.03-46.89 9.03ZM567.33-352.5l48.41-115.87L540-429.24l-74.33-36.56-33.84 110.3h50.26q21.39 0 41.81.5 20.43.5 43.43 2.5Z",
    "montagne": "M741.48-35.93q-24.72 0-49.32-4-24.59-4-47.59-11.24L96.13-250.41q-8.48-3.24-12.34-11.34-3.86-8.1-.62-16.58 3.24-8.47 11.22-12.33 7.98-3.86 16.7-.62l268.8 97.52 68.81-175.5-157.33-163.85q-24.91-27.43-20.39-62.71 4.52-35.27 35.67-53.94l154.52-90q14.72-8.24 31.44-9.22 16.72-.98 31.19 3.78 14.48 4.53 26.34 15.41Q562-718.91 567-703.67l13.48 44.19q16.52 53.28 48.9 85.33 32.38 32.04 78.9 47.32l14.76-45.28q2.48-8.24 10.08-12.1 7.6-3.86 15.84-1.62 8.47 2.24 12.59 10.22 4.12 7.98 1.88 16.46L729-453.33q-69.67-14.47-119.6-52.2-49.92-37.73-78.12-103.58l-128.17 73.37 109.61 128.61q5.95 6.96 8.07 16.77 2.12 9.82-1.59 18.77l-78.05 199.98 137.74 49.85 94-289.61q10.24 3.24 19.96 5.86t19.43 4.62L618.52-106.8l41 14.23q18.76 7 39.12 10.5 20.36 3.5 42.84 3.5 23.76 0 46-3.5t43.48-11.5q8.71-3 17.07-.26t10.6 11.22q3.24 9.48-1.5 17.96t-14.22 11.48q-24.71 8.24-50.07 12.74t-51.36 4.5ZM673.98-714q-31.2 0-53.41-22.34-22.22-22.33-22.22-53.29 0-31.2 22.22-53.53 22.21-22.34 53.41-22.34 30.95 0 53.29 22.34 22.34 22.33 22.34 53.53 0 30.96-22.34 53.29Q704.93-714 673.98-714Z",
    "camping": "M77.61-110v-129.89q0-11.44 3.48-21.63 3.48-10.2 10.19-19.39l346.46-469.02-47.33-63.09q-2.48-3.48 4.29-15.82 6.76-12.33 13-23.17 6.23-10.84 6.59-15.94.36-5.09-15.68 6.19 11.19-8.96 24.87-6.1 13.67 2.86 22.87 14.06L480-806.87l34.89-47.7q8.96-11.19 22.63-13.55 13.68-2.36 25.11 6.6 11.2 8.95 13.44 22.75 2.23 13.79-6.72 24.99l-46.09 63.85 345.46 469.02q6.71 9.19 10.19 19.39 3.48 10.19 3.48 21.63V-110q0 14.67-9.69 24.37-9.7 9.7-24.37 9.7H111.91q-14.91 0-24.61-9.7-9.69-9.7-9.69-24.37Zm247.26-34.07h310.02L480-361 324.87-144.07Z",
    "raquette": "M516.17-389.37q-85.17 0-136.15 13.6-50.98 13.6-83.98 46.6L144.96-178.09q-9.96 9.96-23.04 9.46-13.07-.5-22.79-10.46-9.72-9.71-9.72-23.41t9.72-23.41L249.46-376q33-33.24 47.36-82.86 14.35-49.62 14.35-135.51 0-58.91 25.36-115.23 25.36-56.31 76.84-107.31 88.48-88.72 194.67-100.72 106.2-12 175.16 56.72 68.47 68.48 56.47 175.67-12 107.2-100.47 196.15-51.24 51.24-107.56 75.48-56.31 24.24-115.47 24.24ZM414.2-492.91q48.04 48.04 131.08 35.42 83.05-12.62 149.09-78.66 65.8-66.05 78.8-147.47t-34.8-129.71q-47.8-47.8-130.59-35.18Q525-835.89 459.2-770.09q-66.05 66.05-79.55 147.59t34.55 129.59ZM739.35-35.93q-60.96 0-103.2-42.36t-42.24-103.08q0-60.72 42.24-102.96 42.24-42.24 103.2-42.24 60.72 0 103.07 42.24 42.36 42.24 42.36 102.96 0 60.72-42.36 103.08-42.35 42.36-103.07 42.36Z",
    "fitness": "M269.2-643.3 150.11-524.22q-9.96 9.96-23.03 9.84-13.08-.12-23.04-10.08-8.95-8.95-9.33-22.53-.38-13.58 8.57-23.53l33.61-34.37L105-637.02q-10.2-10.2-10.2-23.99T105-685l61.37-61.37-17.89-17.65q-10.44-10.2-10.44-23.99t10.2-23.75q9.19-9.44 23.37-9.82 14.17-.38 24.37 8.82l18.65 18.13L275-855q10.2-10.2 23.99-10.2t24.23 10.2l31.89 31.89 34.61-33.85q9.95-8.95 23.15-8.95t22.91 9.71q9.96 10.2 9.96 23.28 0 13.07-9.96 23.03L316.93-691.04l374.11 374.11 118.85-118.85q9.96-9.96 23.15-9.96 13.2 0 23.16 9.96 8.95 8.95 9.33 22.65.38 13.7-8.57 23.41l-33.85 34.61L855-323.22q10.2 10.44 10.2 24.23 0 13.79-10.2 23.99l-62.37 62.37 18.13 17.65q10.2 10.2 10.2 23.99t-10.2 23.75q-10.19 10.2-23.87 10.2-13.67 0-23.87-10.44l-17.65-17.89L685-105q-10.2 10.2-23.99 10.2T637.02-105l-32.13-31.89-34.61 33.85q-9.95 8.95-23.03 8.83-13.08-.12-22.79-9.83-10.2-9.96-10.2-23.04 0-13.07 10.2-23.27L643.3-269.2 269.2-643.3Z",
    "escalade": "m75.52-292.07 177.37-236.41q4.98-6.72 12.19-10.07 7.21-3.36 14.92-3.36t14.92 3.36q7.21 3.35 12.43 10.07L465.52-317.5q4.29 6 10.44 9 6.16 3 13.7 3 18.86 0 26.86-16.38t-3-31.38L412.91-487.15q-6.95-9.52-6.95-20.68 0-11.15 6.95-20.34l119.98-160.31q4.98-6.72 12.19-10.07 7.21-3.36 14.92-3.36t14.92 3.36q7.21 3.35 12.43 10.07l297.13 396.41q12.67 17.4 3.29 36.05-9.39 18.65-30.4 18.65H102.63q-21.01 0-30.4-18.65-9.38-18.65 3.29-36.05Z",
    "autre": "m282.3-571.76 170.11-272.5q5.48-7.96 12.56-11.94 7.07-3.97 16.03-3.97t16.03 3.97q7.08 3.98 12.56 11.94l170.34 272.5q5.48 9.19 4.98 18.27t-4.98 17.03q-4.23 7.96-11.91 12.56-7.68 4.6-17.67 4.6h-338.7q-10.11 0-17.87-4.73-7.76-4.72-11.71-12.43-4.48-7.95-4.98-17.03-.5-9.08 5.21-18.27ZM711.02-69q-75.13 0-127.55-52.42-52.43-52.43-52.43-127.56t52.43-127.67q52.42-52.55 127.55-52.55t127.56 52.55Q891-324.11 891-248.98t-52.42 127.56Q786.15-69 711.02-69Zm-604.89-59.3v-247.59q0-14.43 9.82-24.37 9.82-9.94 24.48-9.94h247.83q14.42 0 24.25 9.94 9.82 9.94 9.82 24.37v247.59q0 14.66-9.82 24.48Q402.68-94 388.26-94H140.43q-14.66 0-24.48-9.82t-9.82-24.48Z",
  };
  const TINTS = {};  // une seule teinte neutre pour toutes les catégories
  function catIcon(slug, size) {
    const d = ICONS[slug] || ICONS.autre;
    return `<svg viewBox="0 -960 960 960" width="${size || 24}" height="${size || 24}" fill="currentColor" aria-hidden="true"><path d="${d}"/></svg>`;
  }
  const TINT = {};
  const catTint = () => "#ECE4D6";
  /* Logo : le mot « spoloc », le premier « o » devient un point vert (une balle) */
  const ACCENT = "#D35F2A";
  function logo(color) {
    return `<span class="sl-wm" style="color:${color || "#0F1512"}">sp<i class="sl-o"></i>loc</span>`;
  }
  /* Petite marque carrée pour l'icône d'onglet et l'avatar de l'assistant */
  function mark(size) {
    const s = size || 40;
    return `<svg viewBox="0 0 64 64" width="${s}" height="${s}" aria-hidden="true"><rect width="64" height="64" rx="18" fill="#0F1512"/><circle cx="32" cy="32" r="11" fill="${ACCENT}"/><circle cx="32" cy="32" r="11" fill="none" stroke="#F3F1EA" stroke-width="3"/></svg>`;
  }

  /* ---------- Masquage des coordonnées (aperçu côté navigateur ; la base fait foi) ---------- */
  function maskContacts(t) {
    return String(t)
      .replace(/[A-Za-z0-9._%+-]+\s*(@|\(at\)|\[at\]|\sarobase\s|\sat\s)\s*[A-Za-z0-9-]+(\s*(\.|\(dot\)|\spoint\s)\s*[A-Za-z]{2,})+/gi, "[coordonnées masquées]")
      .replace(/(https?:\/\/|www\.)\S+/gi, "[lien masqué]")
      .replace(/\b[A-Za-z0-9-]+\.(com|fr|net|org|io|me|be|ch|eu|co|app|link|ly)\b\S*/gi, "[lien masqué]")
      .replace(/(\+|00)\s?\d{2}([\s.\-]?\d){8,}/g, "[numéro masqué]")
      .replace(/\b0\d([\s.\-]?\d){8}\b/g, "[numéro masqué]")
      .replace(/\b(whats\s?app|wh?atsap+|telegram|signal|snap(chat)?|insta(gram)?|messenger|facebook|fb|tiktok|linkedin|lydia|paypal|wero|iban|rib|esp[eè]ces|cash)\b/gi, "[hors Spoloc]");
  }

  /* ---------- Assistant ---------- */
  const FALLBACK = [
    ["Comment fonctionne Spoloc ?", "Des particuliers mettent en location le matériel de sport qu'ils utilisent peu. Vous cherchez par sport, dates et quartier, vous envoyez une demande, le propriétaire accepte, vous payez en ligne et récupérez le matériel avec un code.", ["fonctionne", "principe", "spoloc"]],
    ["Combien de temps peut-on louer ?", "D'une demi-journée (matin 8 h–13 h ou après-midi 13 h–20 h) jusqu'à 30 jours.", ["duree", "temps", "jours", "demi", "journee", "matin", "apres-midi", "minimum", "maximum"]],
    ["Comment se passe le paiement ?", "Vous payez en ligne par carte, sur Spoloc, une fois votre demande acceptée. L'argent est conservé par notre prestataire de paiement et n'est versé au propriétaire que le lendemain de la remise du matériel.", ["paiement", "payer", "carte", "argent", "regler"]],
    ["Comment fonctionne la caution ?", "La caution est une empreinte bancaire : le montant est bloqué sur votre carte la veille du retrait, sans être débité. Elle est libérée au retour. En cas de casse ou de vol, tout ou partie peut être retenu, photos de l'état à l'appui.", ["caution", "depot", "garantie", "empreinte", "bloque", "debite"]],
    ["Comment récupérer le matériel ?", "Selon l'annonce : en main propre sur un créneau proposé par le propriétaire, livré près de chez vous, ou dans une boutique partenaire. À chaque remise : photos, code à 4 chiffres et signature.", ["recuperer", "retrait", "remise", "livraison", "boutique", "chercher"]],
    ["À quoi sert le code à 4 chiffres ?", "Il prouve que la remise a bien eu lieu. Le locataire donne son code au propriétaire au retrait ; au retour, c'est le propriétaire qui donne le sien. Avec les photos et la signature, personne ne peut contester.", ["code", "chiffres", "signature", "photos", "preuve"]],
    ["Que se passe-t-il si le matériel est abîmé ou volé ?", "Les photos prises au retrait et au retour servent de référence. En cas de dommage ou de vol, la caution est retenue en tout ou partie, après échange entre les deux parties.", ["abime", "casse", "vol", "vole", "degat", "dommage", "perdu", "litige"]],
    ["Puis-je annuler ?", "Oui, tant que la location n'a pas commencé, depuis « Mes locations ». Rien n'est débité tant que la demande n'est pas acceptée.", ["annuler", "annulation", "rembourse", "remboursement"]],
    ["Combien ça coûte ?", "Le prix est fixé par le propriétaire. Le total exact (location, frais de service, livraison éventuelle) est affiché avant de payer. Publier une annonce est gratuit, et les propriétaires ne paient jamais de frais.", ["cout", "coute", "tarif", "frais", "cher", "gratuit"]],
    ["Comment mettre mon matériel en location ?", "Créez un compte, cliquez sur « Publier », ajoutez des photos, l'état, la marque, les dimensions, votre prix et vos modes de remise. C'est gratuit, et 50 points vous attendent pour la première annonce.", ["publier", "annonce", "mettre", "proposer", "deposer", "preter"]],
    ["Peut-on acheter l'objet loué ?", "Oui, si le propriétaire a activé l'option rachat (badge « Rachetable »). Faites une offre depuis la fiche de l'objet.", ["acheter", "achat", "rachat", "racheter", "vendre", "vente", "offre"]],
    ["Puis-je échanger mon numéro avec le propriétaire ?", "Non : pour que la caution, les photos et l'aide en cas de litige fonctionnent, tout passe par la messagerie Spoloc. Les numéros, emails et liens y sont masqués automatiquement.", ["numero", "telephone", "email", "mail", "contact", "whatsapp", "coordonnees"]],
  ].map(([question, answer, keywords], i) => ({ id: null, question, answer, keywords, sort_order: i }));

  const STOP = new Set("le la les l de des du d un une et ou a au aux en pour par sur est ce cet cette ces que qu qui quoi comment je j tu il elle on vous nous mon ma mes votre vos ton ta tes se s sa son ses y ne n pas plus moins avec dans sans si quand combien ca c est etre avoir faire peut peux puis-je dois il-y-a bonjour salut merci svp stp".split(" "));
  const norm = s => String(s || "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/[^a-z0-9\- ]+/g, " ").replace(/\s+/g, " ").trim();
  const toks = s => norm(s).split(" ").filter(w => w.length > 1 && !STOP.has(w));
  const stem = w => w.length > 5 ? w.slice(0, w.length - 2) : w;

  let KB = null;
  async function loadKB() {
    if (KB) return KB;
    try {
      const r = await fetch(`${SUPABASE_URL}/rest/v1/assistant_faq?select=id,question,answer,keywords,sort_order&order=sort_order`, { headers: { apikey: SUPABASE_KEY, Authorization: `Bearer ${SUPABASE_KEY}` } });
      if (!r.ok) throw 0;
      const data = await r.json();
      KB = data.length ? data : FALLBACK;
    } catch { KB = FALLBACK; }
    return KB;
  }
  function rank(q) {
    const qn = " " + norm(q) + " ", qt = toks(q), qs = qt.map(stem);
    return (KB || FALLBACK).map(f => {
      let score = 0;
      (f.keywords || []).forEach(k => {
        const kn = norm(k); if (!kn || STOP.has(kn)) return;
        if (qn.includes(" " + kn + " ") || qn.includes(" " + kn)) score += 3;
        else if (qs.some(w => w.length > 3 && stem(kn).startsWith(w))) score += 2;
      });
      const ft = new Set(toks(f.question).map(stem));
      qs.forEach(w => { if (ft.has(w)) score += 1; });
      return { f, score };
    }).sort((a, b) => b.score - a.score);
  }
  function logQuestion(question, faq, page) {
    try {
      fetch(`${SUPABASE_URL}/rest/v1/assistant_questions`, {
        method: "POST",
        headers: { apikey: SUPABASE_KEY, Authorization: `Bearer ${SUPABASE_KEY}`, "Content-Type": "application/json", Prefer: "return=minimal" },
        body: JSON.stringify({ question: question.slice(0, 500), answered: !!faq, faq_id: faq?.id || null, page: (page || "").slice(0, 40) }),
      }).catch(() => {});
    } catch {}
  }

  const CSS = `
  .sl-wm{display:inline-flex;align-items:baseline;font-family:"Bricolage Grotesque",system-ui,sans-serif;font-weight:800;letter-spacing:-.05em;line-height:1}
  .sl-wm .sl-o{display:inline-block;width:.52em;height:.52em;border-radius:50%;background:#D35F2A;margin:0 .035em;align-self:center;transform:translateY(.12em)}
  .sl-chat{display:flex;flex-direction:column;background:#fff;border:1px solid rgba(15,21,18,.12);border-radius:24px;overflow:hidden;font-family:"Instrument Sans",system-ui,sans-serif;color:#0F1512}
  .sl-chat-h{display:flex;align-items:center;gap:12px;padding:16px 18px;background:#0F1512;color:#F3F1EA}
  .sl-chat-h .av{width:40px;height:40px;border-radius:50%;background:#F3F1EA;display:grid;place-items:center;flex:none}
  .sl-chat-h b{display:block;font-family:"Bricolage Grotesque",system-ui,sans-serif;font-size:17px;letter-spacing:-.02em}
  .sl-chat-h span{font-size:12.5px;color:#B9C0BC;display:flex;align-items:center;gap:6px}
  .sl-chat-h span::before{content:"";width:7px;height:7px;border-radius:50%;background:#F2A57C}
  .sl-chat-h .x{margin-left:auto;width:40px;height:40px;border-radius:50%;border:0;background:rgba(255,255,255,.1);color:#F3F1EA;font-size:18px;cursor:pointer}
  .sl-msgs{flex:1;overflow-y:auto;padding:18px;display:flex;flex-direction:column;gap:10px;background:#F8F4EC;overscroll-behavior:contain}
  .sl-b{max-width:86%;padding:11px 14px;border-radius:18px;font-size:14.5px;line-height:1.5;animation:slIn .3s cubic-bezier(.2,.8,.2,1)}
  .sl-b.bot{align-self:flex-start;background:#fff;border:1px solid rgba(15,21,18,.08);border-bottom-left-radius:6px}
  .sl-b.me{align-self:flex-end;background:#0F1512;color:#F3F1EA;border-bottom-right-radius:6px}
  .sl-b .q{display:block;font-weight:600;margin-bottom:4px}
  .sl-typing{display:inline-flex;gap:4px;padding:14px}
  .sl-typing i{width:7px;height:7px;border-radius:50%;background:#9AA39E;animation:slDot 1s infinite}
  .sl-typing i:nth-child(2){animation-delay:.15s}.sl-typing i:nth-child(3){animation-delay:.3s}
  .sl-sugg{display:flex;flex-wrap:wrap;gap:6px;margin-top:2px}
  .sl-sugg button{border:1.5px solid rgba(15,21,18,.14);background:#fff;border-radius:999px;padding:8px 12px;font:inherit;font-size:13px;cursor:pointer;min-height:40px;text-align:left;color:#0F1512}
  .sl-sugg button:hover{border-color:#0F1512}
  .sl-form{display:flex;gap:8px;padding:12px;border-top:1px solid rgba(15,21,18,.08);background:#fff}
  .sl-form input{flex:1;min-width:0;border:1.5px solid rgba(15,21,18,.14);border-radius:999px;padding:0 16px;min-height:48px;font:inherit;outline:none;color:#0F1512;background:#fff}
  .sl-form input:focus{border-color:#0F1512}
  .sl-form button{width:48px;height:48px;border-radius:50%;border:0;background:#0F1512;color:#F3F1EA;cursor:pointer;flex:none;display:grid;place-items:center}
  .sl-foot{font-size:11.5px;color:#5A615C;text-align:center;padding:0 12px 10px;background:#fff}
  .sl-fab{position:fixed;right:20px;bottom:calc(20px + env(safe-area-inset-bottom));z-index:80;display:flex;align-items:center;gap:10px;border:0;border-radius:999px;background:#0F1512;color:#F3F1EA;padding:0 18px 0 8px;min-height:56px;font:600 15px "Instrument Sans",system-ui,sans-serif;cursor:pointer;box-shadow:0 18px 40px -16px rgba(15,21,18,.6);transition:transform .3s cubic-bezier(.2,.8,.2,1)}
  .sl-fab:hover{transform:translateY(-3px)}
  .sl-fab .av{width:40px;height:40px;border-radius:50%;background:#F3F1EA;display:grid;place-items:center}
  .sl-pop{position:fixed;right:20px;bottom:calc(88px + env(safe-area-inset-bottom));z-index:81;width:min(390px,calc(100vw - 32px));height:min(580px,calc(100vh - 120px));opacity:0;transform:translateY(16px) scale(.98);pointer-events:none;transition:opacity .25s,transform .3s cubic-bezier(.2,.8,.2,1);box-shadow:0 30px 70px -30px rgba(15,21,18,.55)}
  .sl-pop.open{opacity:1;transform:none;pointer-events:auto}
  .sl-pop .sl-chat{height:100%}
  @keyframes slIn{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:none}}
  @keyframes slDot{0%,100%{opacity:.3}50%{opacity:1}}
  @media (max-width:860px){.sl-fab{bottom:calc(84px + env(safe-area-inset-bottom));right:14px;padding:0 8px}.sl-fab .t{display:none}.sl-pop{right:16px;bottom:calc(150px + env(safe-area-inset-bottom));height:min(540px,calc(100vh - 180px))}}
  `;
  function injectCSS() { if (document.getElementById("sl-css")) return; const s = document.createElement("style"); s.id = "sl-css"; s.textContent = CSS; document.head.appendChild(s); }

  function mountChat(container, opts) {
    opts = opts || {};
    injectCSS();
    const esc = s => String(s ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
    container.innerHTML = `<div class="sl-chat" style="${opts.height ? `height:${opts.height}` : "height:100%"}">
      <div class="sl-chat-h"><span class="av">${mark(30)}</span><div><b>Assistant Spoloc</b><span>Répond tout de suite, 24 h/24</span></div>${opts.closable ? '<button class="x" aria-label="Fermer l\'assistant">✕</button>' : ""}</div>
      <div class="sl-msgs" aria-live="polite"></div>
      <form class="sl-form"><label class="sr" style="position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0)" for="sl-in-${opts.id || "x"}">Votre question</label><input id="sl-in-${opts.id || "x"}" placeholder="Posez votre question…" autocomplete="off" maxlength="300"><button type="submit" aria-label="Envoyer"><svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14M13 6l6 6-6 6"/></svg></button></form>
      <div class="sl-foot">Réponses automatiques. Pour un cas particulier : ${esc(CONTACT_EMAIL)}</div>
    </div>`;
    const msgs = container.querySelector(".sl-msgs"), form = container.querySelector(".sl-form"), input = form.querySelector("input");
    const scroll = () => { msgs.scrollTop = msgs.scrollHeight; };
    const add = (html, who) => { const d = document.createElement("div"); d.className = "sl-b " + who; d.innerHTML = html; msgs.appendChild(d); scroll(); return d; };
    const suggest = list => `<div class="sl-sugg">${list.map(f => `<button type="button" data-q="${esc(f.question)}">${esc(f.question)}</button>`).join("")}</div>`;
    async function answer(q) {
      add(esc(q), "me");
      const typing = add('<span class="sl-typing"><i></i><i></i><i></i></span>', "bot");
      await loadKB();
      await new Promise(r => setTimeout(r, 450 + Math.random() * 350));
      typing.remove();
      const ranked = rank(q), best = ranked[0];
      if (best && best.score >= 3) {
        const more = ranked.slice(1, 3).filter(x => x.score >= 3).map(x => x.f);
        add(`<span class="q">${esc(best.f.question)}</span>${esc(best.f.answer)}${more.length ? `<div style="margin-top:10px;font-size:13px;color:#5A615C">Ça peut aussi vous aider :</div>${suggest(more)}` : ""}`, "bot");
        logQuestion(q, best.f, opts.page);
      } else {
        add(`Je n'ai pas encore la réponse à cette question, je l'ai transmise à l'équipe pour l'ajouter. En attendant, écrivez-nous à <b>${esc(CONTACT_EMAIL)}</b>.${suggest((KB || FALLBACK).slice(0, 3))}`, "bot");
        logQuestion(q, null, opts.page);
      }
    }
    msgs.addEventListener("click", e => { const b = e.target.closest("[data-q]"); if (b) answer(b.dataset.q); });
    form.addEventListener("submit", e => { e.preventDefault(); const q = input.value.trim(); if (q.length < 2) return; input.value = ""; answer(q); });
    (async () => {
      await loadKB();
      add(`Bonjour ! Je réponds à vos questions sur la location, le paiement, la caution ou la remise du matériel.${suggest((KB || FALLBACK).slice(0, opts.suggestions || 4))}`, "bot");
    })();
    return { close: container.querySelector(".x"), focus: () => input.focus(), ask: answer };
  }

  function mountFab(opts) {
    injectCSS();
    const fab = document.createElement("button");
    fab.className = "sl-fab"; fab.setAttribute("aria-label", "Ouvrir l'assistant"); fab.setAttribute("aria-expanded", "false");
    fab.innerHTML = `<span class="av">${mark(30)}</span><span class="t">Une question ?</span>`;
    const pop = document.createElement("div"); pop.className = "sl-pop"; pop.setAttribute("role", "dialog"); pop.setAttribute("aria-label", "Assistant Spoloc");
    document.body.append(pop, fab);
    let chat = null;
    const toggle = open => {
      if (open && !chat) { chat = mountChat(pop, { closable: true, id: "pop", page: (opts && opts.page) || location.hash.slice(1) || "site" }); chat.close.addEventListener("click", () => toggle(false)); }
      pop.classList.toggle("open", open); fab.setAttribute("aria-expanded", open);
      if (open) setTimeout(() => chat.focus(), 250);
    };
    fab.addEventListener("click", () => toggle(!pop.classList.contains("open")));
    addEventListener("keydown", e => { if (e.key === "Escape" && pop.classList.contains("open")) toggle(false); });
    return { fab, open: () => toggle(true), hide: h => { fab.style.display = h ? "none" : ""; if (h) toggle(false); } };
  }

  window.Spoloc = { catIcon, catTint, logo, mark, maskContacts, mountChat, mountFab, SUPABASE_URL, SUPABASE_KEY, CONTACT_EMAIL };
})();
