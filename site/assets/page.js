// La page, en deux langues, sans dépendance.
//
// Le choix de langue commande **aussi les captures** : montrer une interface anglaise sous un
// texte français donnerait l'impression que l'app n'est traduite qu'à moitié. Les deux jeux
// vivent dans `shots/en/` et `shots/fr/`.
(function () {
  "use strict";

  var COPY = window.QUIX_COPY;
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

    document.getElementById("shot-hero").src = "shots/" + lang + "/transfer.png";
    document.getElementById("shot-popover").src = "shots/" + lang + "/popover.png";

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

    var steps = document.getElementById("hlSteps");
    steps.innerHTML = "";
    t.hlSteps.forEach(function (item) {
      var row = el("div", "step");
      row.setAttribute("data-reveal", "");
      row.appendChild(el("span", "no mono", item.no));
      var body = el("div");
      body.appendChild(el("h3", null, item.title));
      body.appendChild(el("p", null, item.body));
      row.appendChild(body);
      steps.appendChild(row);
    });

    var stats = document.getElementById("stats");
    stats.innerHTML = "";
    t.stats.forEach(function (item) {
      var cell = el("div", "stat");
      var number = el("div", "n", "0");
      number.dataset.count = item.to;
      number.dataset.suffix = item.suffix;
      cell.appendChild(number);
      cell.appendChild(el("div", "l mono", item.label));
      stats.appendChild(cell);
    });

    var onb = document.getElementById("onb");
    onb.innerHTML = "";
    t.onboarding.forEach(function (item) {
      var card = el("div", "card");
      card.setAttribute("data-reveal", "");
      var image = el("img");
      image.src = "shots/" + lang + "/" + item.shot;
      image.alt = item.title;
      image.loading = "lazy";
      card.appendChild(image);
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

    var tabs = document.getElementById("tabs");
    tabs.innerHTML = "";
    t.tabs.forEach(function (item) {
      var row = el("div", "tab");
      row.appendChild(el("span", null, item.name));
      row.appendChild(el("span", "key mono", item.key));
      tabs.appendChild(row);
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

    countUp();
  }

  function countUp() {
    if (!("IntersectionObserver" in window)) return;
    var counters = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        var node = entry.target;
        var to = parseFloat(node.dataset.count) || 0;
        var suffix = node.dataset.suffix || "";
        var start = performance.now();
        (function tick(now) {
          var p = Math.min(1, (now - start) / 1100);
          var eased = 1 - Math.pow(1 - p, 3);
          node.innerHTML = Math.round(to * eased) + suffix;
          if (p < 1) requestAnimationFrame(tick);
        })(start);
        counters.unobserve(node);
      });
    }, { threshold: 0.5 });
    document.querySelectorAll("[data-count]").forEach(function (n) { counters.observe(n); });
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
