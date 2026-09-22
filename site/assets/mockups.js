// Les captures d'écran, redessinées en HTML.
//
// Pourquoi pas des PNG : une image d'interface est floue dès qu'on la redimensionne, elle pèse
// deux cents kilo-octets, elle se déforme si le cadre ne suit pas son rapport, et il en faut un
// jeu par langue. Redessinée, la même interface reste nette à toutes les tailles, se traduit
// avec le reste de la page, et se laisse agrandir d'un clic.
//
// Tout est dimensionné en `em`. Le cadre fixe une taille de police, et la maquette entière suit
// — c'est ce qui permet d'afficher la même sans la déformer dans le flux de la page comme en
// plein écran.
(function () {
  "use strict";

  function el(tag, className, html) {
    var node = document.createElement(tag);
    if (className) node.className = className;
    if (html != null) node.innerHTML = html;
    return node;
  }

  // Les six clips de l'exemple. Trois portent une marque, comme dans le texte au-dessus.
  var FILES = [
    { name: "GX010042.MP4", size: "120 MB", tag: true },
    { name: "GX010043.MP4", size: "120 MB", tag: false },
    { name: "GX010044.MP4", size: "120 MB", tag: true },
    { name: "GX010045.MP4", size: "120 MB", tag: false },
    { name: "GX010046.MP4", size: "120 MB", tag: true },
    { name: "GX010047.MP4", size: "120 MB", tag: false }
  ];

  function chrome(title) {
    var bar = el("div", "mk-bar");
    var dots = el("div", "mk-dots");
    ["r", "y", "g"].forEach(function (c) { dots.appendChild(el("span", "mk-dot mk-" + c)); });
    bar.appendChild(dots);
    bar.appendChild(el("span", "mk-title", title));
    return bar;
  }

  // La fenêtre de transfert, à la fin d'un import.
  function transferWindow(t) {
    var ui = t.ui;
    var win = el("div", "mk mk-win");

    win.appendChild(chrome("QuiX"));

    var tabs = el("div", "mk-tabs");
    ui.tabs.forEach(function (name, i) {
      tabs.appendChild(el("span", "mk-tab" + (i === 0 ? " on" : ""), name));
    });
    win.appendChild(tabs);

    var body = el("div", "mk-body");

    var route = el("div", "mk-route");
    var src = el("div", "mk-card");
    src.appendChild(el("div", "mk-lab", ui.source));
    src.appendChild(el("div", "mk-big", ui.sourceName));
    src.appendChild(el("div", "mk-meta", ui.sourceMeta));
    src.appendChild(el("div", "mk-path", "/Volumes/GOPRO/DCIM"));
    route.appendChild(src);

    route.appendChild(el("div", "mk-arrow",
      '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 12h15M13 6l6 6-6 6" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></svg>'));

    var dst = el("div", "mk-card");
    dst.appendChild(el("div", "mk-lab", ui.destination));
    dst.appendChild(el("div", "mk-big", "2026-09-22"));
    dst.appendChild(el("div", "mk-meta", ui.destMeta));
    dst.appendChild(el("div", "mk-path", "~/Movies/GoPro"));
    route.appendChild(dst);
    body.appendChild(route);

    var prog = el("div", "mk-prog");
    prog.appendChild(el("div", "mk-track", '<span class="mk-fill"></span>'));
    prog.appendChild(el("div", "mk-progLab", ui.progress));
    body.appendChild(prog);

    var table = el("div", "mk-table");
    var head = el("div", "mk-row mk-head");
    head.appendChild(el("span", "mk-c1", '<i class="mk-bullet"></i>' + ui.colFile));
    head.appendChild(el("span", "mk-c2", ui.colSize));
    head.appendChild(el("span", "mk-c3", ui.colTags));
    head.appendChild(el("span", "mk-c4", ui.colCheck));
    table.appendChild(head);

    FILES.forEach(function (f) {
      var row = el("div", "mk-row");
      row.appendChild(el("span", "mk-c1", '<i class="mk-bullet"></i>' + f.name));
      row.appendChild(el("span", "mk-c2", f.size));
      row.appendChild(el("span", "mk-c3", f.tag ? '<b class="mk-badge">1</b>' : ""));
      row.appendChild(el("span", "mk-c4 mk-ok", ui.checked));
      table.appendChild(row);
    });
    body.appendChild(table);
    win.appendChild(body);

    var foot = el("div", "mk-foot");
    foot.appendChild(el("p", "mk-note", ui.note));
    foot.appendChild(el("span", "mk-btn", ui.openBtn));
    win.appendChild(foot);

    return win;
  }

  // Le popover de la barre de menus.
  function popover(t) {
    var ui = t.ui;
    var pop = el("div", "mk mk-pop");
    pop.appendChild(el("div", "mk-popTitle", ui.popTitle));
    pop.appendChild(el("div", "mk-popMeta", ui.popMeta));

    var tiles = el("div", "mk-tiles");
    [[3, ui.popHighlights, true], [3, ui.popClips, false]].forEach(function (pair) {
      var tile = el("div", "mk-tile");
      tile.appendChild(el("div", "mk-n" + (pair[2] ? " blue" : ""), String(pair[0])));
      tile.appendChild(el("div", "mk-tl", pair[1]));
      tiles.appendChild(tile);
    });
    pop.appendChild(tiles);

    pop.appendChild(el("span", "mk-btn mk-wide", ui.openBtn));
    pop.appendChild(el("div", "mk-popNote", ui.popNote));
    return pop;
  }

  // Le schéma du bouton : ce que le lecteur doit retenir de toute la page.
  function goproDiagram(t) {
    var d = t.hlDiagram;
    var wrap = el("div", "gp");
    wrap.innerHTML =
      '<svg viewBox="0 0 320 200" role="img" aria-label="' + d.camera + '">' +
        '<rect x="74" y="34" width="150" height="132" rx="26" class="gp-body"/>' +
        '<rect x="224" y="74" width="12" height="52" rx="5" class="gp-side"/>' +
        '<circle cx="163" cy="104" r="36" class="gp-lensRing"/>' +
        '<circle cx="163" cy="104" r="25" class="gp-lens"/>' +
        '<circle cx="155" cy="95" r="7" class="gp-glint"/>' +
        '<rect x="88" y="48" width="42" height="12" rx="6" class="gp-screen"/>' +
        '<circle cx="98" cy="150" r="5" class="gp-rec"/>' +
        '<text x="110" y="154" class="gp-recLab">' + d.recording + '</text>' +
        '<g class="gp-btnGroup">' +
          '<circle cx="99" cy="104" r="13" class="gp-halo"/>' +
          '<circle cx="99" cy="104" r="9" class="gp-btn"/>' +
        '</g>' +
        '<path d="M99 104 L34 104" class="gp-lead"/>' +
        '<text x="30" y="99" class="gp-lab" text-anchor="end">' + d.button + '</text>' +
        '<text x="30" y="115" class="gp-sub" text-anchor="end">' + d.press + '</text>' +
        '<path d="M224 104 L288 104" class="gp-lead"/>' +
        '<circle cx="292" cy="104" r="5" class="gp-mark"/>' +
      '</svg>' +
      '<p class="gp-result">' + d.result + '</p>';
    return wrap;
  }

  // Agrandissement au clic. Le nœud est recloné à une plus grande taille de police, et comme
  // tout est en `em`, il se redessine net au lieu d'être un agrandissement d'image.
  //
  // On clone `.mk`, pas le cadre : le cadre porte sa propre taille de police, qui écraserait
  // celle du plein écran.
  function makeZoomable(figure, label) {
    figure.classList.add("zoomable");
    figure.setAttribute("role", "button");
    figure.setAttribute("tabindex", "0");
    figure.setAttribute("aria-label", label);
    if (figure.dataset.zoomBound === "1") return;
    figure.dataset.zoomBound = "1";

    function open() {
      var source = figure.querySelector(".mk");
      if (!source) return;
      var overlay = el("div", "zoom");
      var inner = el("div", "zoom-inner");
      inner.appendChild(source.cloneNode(true));
      overlay.appendChild(inner);
      overlay.appendChild(el("button", "zoom-x", "&times;"));
      document.body.appendChild(overlay);
      document.body.style.overflow = "hidden";
      requestAnimationFrame(function () { overlay.classList.add("on"); });

      function close() {
        overlay.classList.remove("on");
        document.body.style.overflow = "";
        setTimeout(function () { overlay.remove(); }, 200);
        document.removeEventListener("keydown", onKey);
      }
      function onKey(e) { if (e.key === "Escape") close(); }
      overlay.addEventListener("click", close);
      document.addEventListener("keydown", onKey);
      overlay.querySelector(".zoom-x").focus();
    }

    figure.addEventListener("click", open);
    figure.addEventListener("keydown", function (e) {
      if (e.key === "Enter" || e.key === " ") { e.preventDefault(); open(); }
    });
  }

  window.QUIX_MOCKUPS = {
    transferWindow: transferWindow,
    popover: popover,
    goproDiagram: goproDiagram,
    makeZoomable: makeZoomable
  };
})();
