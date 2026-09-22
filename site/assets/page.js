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

    // Les maquettes, reconstruites dans la langue courante.
    var transfer = document.getElementById("mock-transfer");
    transfer.innerHTML = "";
    transfer.appendChild(MK.transferWindow(t));
    MK.makeZoomable(document.getElementById("fig-transfer"), t.shotHero);

    var popover = document.getElementById("mock-popover");
    popover.innerHTML = "";
    popover.appendChild(MK.popover(t));
    MK.makeZoomable(document.getElementById("fig-popover"), t.shotPopover);

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
      card.appendChild(el("div", "rule"));
      card.appendChild(el("h3", null, item.title));
      card.appendChild(el("p", null, item.body));
      traits.appendChild(card);
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
