// La page, en deux langues, sans dépendance.
//
// Le choix de langue commande aussi les maquettes d'interface : elles sont redessinées en HTML
// (voir `mockups.js`), donc leurs libellés suivent la langue au lieu de demander un jeu
// d'images par langue.
(function () {
  "use strict";

  var COPY = window.QUIX_COPY;
  var MK = window.QUIX_MOCKUPS;
  var STORAGE = "quix.lang";

  function chosenLang() {
    try {
      var saved = localStorage.getItem(STORAGE);
      if (saved && COPY[saved]) return saved;
    } catch (e) { /* navigation privée : on retombe sur la langue du navigateur */ }
    var url = new URLSearchParams(location.search).get("lang");
    if (url && COPY[url]) return url;
    return (navigator.language || "en").toLowerCase().indexOf("fr") === 0 ? "fr" : "en";
  }

  function el(tag, className, html) {
    var node = document.createElement(tag);
    if (className) node.className = className;
    if (html != null) node.innerHTML = html;
    return node;
  }

  function render(lang) {
    var t = COPY[lang];

    document.documentElement.lang = t.htmlLang;
    document.title = t.title;
    var meta = document.querySelector('meta[name="description"]');
    if (meta) meta.setAttribute("content", t.description);

    document.querySelectorAll("[data-t]").forEach(function (node) {
      var value = t[node.getAttribute("data-t")];
      if (typeof value === "string") node.innerHTML = value;
    });

    document.querySelectorAll(".langs button").forEach(function (button) {
      button.setAttribute("aria-pressed", String(button.dataset.lang === lang));
    });

    // The mockups, rebuilt in the current language.
    //
    // The transfer window is not zoomable: it already spans the page, so enlarging it would not
    // show it any bigger. The small ones — the popover and the three first-launch screens — are.
    window.QUIX_DEMO.mount(document.getElementById("mock-transfer"), t);

    var popover = document.getElementById("mock-popover");
    popover.innerHTML = "";
    popover.appendChild(MK.popover(t));
    MK.makeZoomable(document.getElementById("fig-popover"), t.shotPopover, t.zoomClose);

    var gopro = document.getElementById("gopro");
    gopro.innerHTML = "";
    gopro.appendChild(MK.goproDiagram(t));

    var how = document.getElementById("howSteps");
    how.innerHTML = "";
    t.howSteps.forEach(function (item) {
      var row = el("div", "step");
      row.setAttribute("data-reveal", "");
      row.appendChild(el("span", "no mono", item.no));
      row.appendChild(el("h3", null, item.title));
      row.appendChild(el("p", null, item.body));
      how.appendChild(row);
    });

    var traits = document.getElementById("traits");
    traits.innerHTML = "";
    t.traits.forEach(function (item) {
      var card = el("div", "trait");
      card.setAttribute("data-reveal", "");
      card.appendChild(MK.icon(item.icon, "trait-ic"));
      card.appendChild(el("h3", null, item.title));
      card.appendChild(el("p", null, item.body));
      traits.appendChild(card);
    });

    var onb = document.getElementById("onb");
    onb.innerHTML = "";
    t.onbCards.forEach(function (item, index) {
      var card = el("div", "card");
      card.setAttribute("data-reveal", "");
      var figure = el("figure", "card-shot");
      var frame = el("div", "mock-frame tiny");
      frame.appendChild(MK.onboardingWindow(t, index));
      figure.appendChild(frame);
      figure.appendChild(el("span", "zoom-badge", '<svg viewBox="0 0 24 24"><path d="M10.5 4a6.5 6.5 0 1 0 4.1 11.5l4.7 4.7 1.4-1.4-4.7-4.7A6.5 6.5 0 0 0 10.5 4zm0 2a4.5 4.5 0 1 1 0 9 4.5 4.5 0 0 1 0-9zM9.5 8v1.5H8v2h1.5V13h2v-1.5H13v-2h-1.5V8z" fill="currentColor"/></svg>'));
      card.appendChild(figure);
      MK.makeZoomable(figure, item.title, t.zoomClose);
      var body = el("div", "body");
      var no = el("div", "no");
      no.appendChild(el("span", "dot"));
      no.appendChild(el("span", "mono", item.no));
      body.appendChild(no);
      body.appendChild(el("h3", null, item.title));
      body.appendChild(el("p", null, item.body));
      card.appendChild(body);
      onb.appendChild(card);
    });

    // Le formulaire garde la langue, pour que la page de confirmation réponde dans la même.
    var form = document.getElementById("gate");
    if (form && !form.querySelector('input[name="langue"]')) {
      var hidden = document.createElement("input");
      hidden.type = "hidden";
      hidden.name = "langue";
      form.appendChild(hidden);
    }
    if (form) form.querySelector('input[name="langue"]').value = lang;

    observe();
  }

  var revealed = null;
  function observe() {
    if (!("IntersectionObserver" in window)) {
      document.querySelectorAll("[data-reveal]").forEach(function (n) { n.classList.add("shown"); });
      return;
    }
    if (revealed) revealed.disconnect();
    revealed = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("shown");
        revealed.unobserve(entry.target);
      });
    }, { threshold: 0.1, rootMargin: "0px 0px -6% 0px" });

    document.querySelectorAll("[data-reveal]").forEach(function (node, i) {
      var delay = (i % 3) * 0.07;
      node.style.transition =
        "opacity .8s cubic-bezier(.4,0,.2,1) " + delay + "s, transform .8s cubic-bezier(.4,0,.2,1) " + delay + "s";
      revealed.observe(node);
    });
  }

  document.querySelectorAll(".langs button").forEach(function (button) {
    button.addEventListener("click", function () {
      var lang = button.dataset.lang;
      try { localStorage.setItem(STORAGE, lang); } catch (e) { /* sans importance */ }
      render(lang);
    });
  });

  render(chosenLang());
})();
