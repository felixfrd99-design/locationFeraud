/* =====================================================================
   SPOLOC — éléments partagés par le site et l'app
   - pictogrammes des catégories et logo
   - assistant gratuit (base de questions/réponses dans Supabase)
   ===================================================================== */
(function () {
  const SUPABASE_URL = "https://qdnytvevomychpuuxbym.supabase.co";
  const SUPABASE_KEY = "sb_publishable_I5EZVxCYdLCmY-7hP8GRhw_y4ZvBDIo";
  const CONTACT_EMAIL = "[ton-email]"; // ← à remplacer

  /* ---------- Pictogrammes (traits, 24×24) ---------- */
  const ICONS = {
    "velo": '<circle cx="5.5" cy="16.5" r="3.5"/><circle cx="18.5" cy="16.5" r="3.5"/><path d="M5.5 16.5 9 9h6l3.5 7.5M9 9l3 7.5h2.5M8 6.5h3M15 9l-1-2.5h2"/>',
    "glisse-eau": '<path d="M4 15.5c4.5-2.6 11.5-2.6 16 0-4.5 2.6-11.5 2.6-16 0z"/><path d="M15.5 3 11 13.5M14 3h3"/><path d="M2 20.5c1.7 0 1.7-1 3.3-1s1.7 1 3.4 1 1.7-1 3.3-1 1.7 1 3.3 1 1.7-1 3.4-1 1.6 1 3.3 1"/>',
    "kayak": '<path d="M2 14c6 3.2 14 3.2 20 0-6-3.2-14-3.2-20 0z"/><path d="m6 5 12 14M4.5 4l2.5 2.5M17 17.5l2.5 2.5"/>',
    "montagne": '<path d="m2.5 20 6.5-11 4 6 2.5-3.5L21.5 20z"/><path d="m7 11.5 2 1.5 1.8-1.4"/><path d="M17.5 4.5v3M16 6h3"/>',
    "camping": '<path d="M2 20h20M4.5 20 12 5l7.5 15"/><path d="m9 20 3-5.5 3 5.5"/>',
    "raquette": '<circle cx="10" cy="9.5" r="6"/><path d="m14.3 13.8 5.7 5.7M7 6.5l6 6M13 6.5l-6 6"/><circle cx="19" cy="5" r="1.6"/>',
    "fitness": '<path d="M6.5 7v10M17.5 7v10M3.5 9.5v5M20.5 9.5v5M6.5 12h11"/>',
    "escalade": '<path d="M9.5 3.5h5a4 4 0 0 1 4 4v9a4 4 0 0 1-4 4h-5a4 4 0 0 1-4-4v-9a4 4 0 0 1 4-4z"/><path d="M12 3.5V11m-2-2 2 2 2-2"/>',
    "autre": '<circle cx="12" cy="12" r="8"/><path d="M8 12h8M12 8v8"/>',
  };
  const TINTS = {
    "velo": "#DCEEFF", "glisse-eau": "#E8F8C2", "kayak": "#D9F1E8", "montagne": "#E6E9FB",
    "camping": "#F7EAD2", "raquette": "#FFF1C7", "fitness": "#FFE1D8", "escalade": "#ECE3FB", "autre": "#ECEAE3",
  };
  function catIcon(slug, size) {
    const p = ICONS[slug] || ICONS.autre;
    return `<svg viewBox="0 0 24 24" width="${size || 24}" height="${size || 24}" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${p}</svg>`;
  }
  const catTint = slug => TINTS[slug] || TINTS.autre;
  function logo(color, ball) {
    return `<svg viewBox="0 0 64 64" width="34" height="34" aria-hidden="true"><path d="M54 32 A22 22 0 1 1 47.5 16.5" stroke="${color || "#0F1512"}" stroke-width="6" fill="none" stroke-linecap="round"/><path d="M41 9 L50 15 L42 22" stroke="${color || "#0F1512"}" stroke-width="6" fill="none" stroke-linecap="round" stroke-linejoin="round"/><circle class="sl-ball" cx="32" cy="32" r="10" fill="${ball || "#FF6B4A"}"/></svg>`;
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
  .sl-chat{display:flex;flex-direction:column;background:#fff;border:1px solid rgba(15,21,18,.12);border-radius:24px;overflow:hidden;font-family:"Instrument Sans",system-ui,sans-serif;color:#0F1512}
  .sl-chat-h{display:flex;align-items:center;gap:12px;padding:16px 18px;background:#0F1512;color:#F3F1EA}
  .sl-chat-h .av{width:40px;height:40px;border-radius:50%;background:#F3F1EA;display:grid;place-items:center;flex:none}
  .sl-chat-h b{display:block;font-family:"Bricolage Grotesque",system-ui,sans-serif;font-size:17px;letter-spacing:-.02em}
  .sl-chat-h span{font-size:12.5px;color:#B9C0BC;display:flex;align-items:center;gap:6px}
  .sl-chat-h span::before{content:"";width:7px;height:7px;border-radius:50%;background:#C9F23B}
  .sl-chat-h .x{margin-left:auto;width:40px;height:40px;border-radius:50%;border:0;background:rgba(255,255,255,.1);color:#F3F1EA;font-size:18px;cursor:pointer}
  .sl-msgs{flex:1;overflow-y:auto;padding:18px;display:flex;flex-direction:column;gap:10px;background:#F7F6F1;overscroll-behavior:contain}
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
  .sl-form button{width:48px;height:48px;border-radius:50%;border:0;background:#0F1512;color:#C9F23B;cursor:pointer;flex:none;display:grid;place-items:center}
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
      <div class="sl-chat-h"><span class="av">${logo()}</span><div><b>Assistant Spoloc</b><span>Répond tout de suite, 24 h/24</span></div>${opts.closable ? '<button class="x" aria-label="Fermer l\'assistant">✕</button>' : ""}</div>
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
    fab.innerHTML = `<span class="av">${logo()}</span><span class="t">Une question ?</span>`;
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

  window.Spoloc = { catIcon, catTint, logo, maskContacts, mountChat, mountFab, SUPABASE_URL, SUPABASE_KEY, CONTACT_EMAIL };
})();
