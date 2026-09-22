// The app's screens, redrawn in HTML.
//
// Why not PNG screenshots: an interface image blurs as soon as it is resized, distorts when its
// frame does not keep its ratio, weighs a couple of hundred kilobytes, and needs one set per
// language. Redrawn, the same interface stays sharp at any size, translates with the rest of the
// page, and can be enlarged with a click.
//
// Everything is sized in `em`. The frame sets a font size and the whole mockup follows, which is
// what lets the same screen show small in a card and large in the zoom view without distortion.
(function () {
  "use strict";

  function el(tag, className, html) {
    var node = document.createElement(tag);
    if (className) node.className = className;
    if (html != null) node.innerHTML = html;
    return node;
  }

  // SF Symbols–like icons, drawn on a 24-unit grid.
  var ICON = {
    bolt: '<svg viewBox="0 0 24 24"><path d="M13.2 2 4.6 13.4h6.1L9.9 22l8.6-11.6h-6.2z" fill="currentColor"/></svg>',
    shield: '<svg viewBox="0 0 24 24"><path d="M12 2.2 4.4 5.1v5.6c0 5 3.2 9.2 7.6 11 4.4-1.8 7.6-6 7.6-11V5.1z" fill="currentColor"/><path d="m8.4 12.1 2.5 2.5 4.8-5" fill="none" stroke="#1C1C21" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    hand: '<svg viewBox="0 0 24 24"><path d="M7.6 12.2V6a1.5 1.5 0 0 1 3 0v5M10.6 11V4.4a1.5 1.5 0 0 1 3 0V11M13.6 11V5.6a1.5 1.5 0 0 1 3 0V12M16.6 12V8.8a1.5 1.5 0 0 1 3 0v5.4c0 4.4-3.1 7.8-7.4 7.8-2.8 0-4.3-1.1-5.9-3.4l-3-4.3a1.5 1.5 0 0 1 2.4-1.8l2 2.4" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    globe: '<svg viewBox="0 0 24 24"><g fill="none" stroke="currentColor" stroke-width="1.7"><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c2.6 2.6 3.8 5.6 3.8 9s-1.2 6.4-3.8 9c-2.6-2.6-3.8-5.6-3.8-9S9.4 5.6 12 3z"/></g></svg>',
    card: '<svg viewBox="0 0 24 24"><path d="M9 3h7.5A2.5 2.5 0 0 1 19 5.5v13a2.5 2.5 0 0 1-2.5 2.5h-9A2.5 2.5 0 0 1 5 18.5V7zM10 3.5v3.8M13 3.5v3.8M16 3.5v3.8" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/></svg>',
    bell: '<svg viewBox="0 0 24 24"><path d="M6 16.5V11a6 6 0 0 1 9.5-4.9M18 11v5.5l1.5 1.5h-15L6 16.5M10 20.5a2 2 0 0 0 4 0" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/><circle cx="18" cy="6" r="2.6" fill="currentColor"/></svg>',
    arrow: '<svg viewBox="0 0 24 24"><path d="M4 12h15M13 6l6 6-6 6" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    check: '<svg viewBox="0 0 24 24"><path d="m6 12.5 4 4 8-9" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    free: '<svg viewBox="0 0 24 24"><g fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M20.6 13.4 13.4 20.6a2 2 0 0 1-2.8 0L3 13V3h10l7.6 7.6a2 2 0 0 1 0 2.8z"/><circle cx="7.5" cy="7.5" r="1.4" fill="currentColor"/></g></svg>'
  };
  window.QUIX_ICON = ICON;

  function icon(name, className) {
    return el("span", "ic " + (className || ""), ICON[name]);
  }

  // Six clips in the example. Three carry a mark, as the text above the screen says.
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

  // The transfer window, at the end of an import.
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
    route.appendChild(el("div", "mk-arrow", ICON.arrow));
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

  // The three first-launch screens. Their text is the app's own, from Localizable.xcstrings.
  function onboardingWindow(t, index) {
    var o = t.onb;
    var s = o.screens[index];
    var win = el("div", "mk mk-win mk-onb");
    win.appendChild(chrome("QuiX"));

    var body = el("div", "mk-onbBody");
    var logo = el("img", "mk-logo");
    logo.src = "assets/icon-256.png";
    logo.alt = "";
    body.appendChild(logo);
    body.appendChild(el("div", "mk-onbTitle", s.title));
    // A <div>, not a <p>: the page styles `.card p`, and the mockup sits inside a card. A
    // paragraph here picked up the page's 13.5px and ignored the mockup's em scale.
    body.appendChild(el("div", "mk-onbText", s.text));

    if (index === 0) {
      var cards = el("div", "mk-feats");
      s.cards.forEach(function (c) {
        var card = el("div", "mk-feat");
        card.appendChild(icon(c.icon, "mk-featIc"));
        card.appendChild(el("div", "mk-featT", c.title));
        card.appendChild(el("div", "mk-featB", c.body));
        cards.appendChild(card);
      });
      body.appendChild(cards);
    } else if (index === 1) {
      body.appendChild(el("span", "mk-btn mk-choose", s.button));
    } else {
      var list = el("div", "mk-perms");
      s.rows.forEach(function (r) {
        var row = el("div", "mk-perm");
        row.appendChild(icon(r.icon, "mk-permIc"));
        var text = el("div", "mk-permText");
        text.appendChild(el("div", "mk-permT", r.title));
        text.appendChild(el("div", "mk-permB", r.body));
        row.appendChild(text);
        if (r.button) row.appendChild(el("span", "mk-ghostBtn", r.button));
        list.appendChild(row);
      });
      body.appendChild(list);
      var check = el("div", "mk-check");
      check.appendChild(el("span", "mk-box", ICON.check));
      check.appendChild(el("span", null, s.checkbox));
      body.appendChild(check);
    }
    win.appendChild(body);

    var foot = el("div", "mk-onbFoot");
    var pager = el("div", "mk-pager");
    for (var i = 0; i < 3; i++) pager.appendChild(el("i", i === index ? "on" : ""));
    foot.appendChild(pager);
    var actions = el("div", "mk-actions");
    if (index > 0) actions.appendChild(el("span", "mk-ghostBtn", o.back));
    actions.appendChild(el("span", "mk-btn" + (index === 1 ? " dim" : ""), index === 2 ? s.primary : o.cont));
    foot.appendChild(actions);
    win.appendChild(foot);
    return win;
  }

  // The menu bar popover.
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

  // A GoPro HERO12 Black seen from the front: front screen on the left, square lens cover on the
  // right, shutter button on the top edge, Mode/power button on the side edge. The side button is
  // the one that sets a HiLight: a short press while recording. Below, a clip timeline receives
  // the marker at the moment of the press.
  function goproDiagram(t) {
    var d = t.hlDiagram;
    var wrap = el("div", "gp");
    wrap.innerHTML =
      '<svg viewBox="44 0 470 330" role="img" aria-label="' + d.camera + '">' +
        // Shutter label, above
        '<text x="226" y="22" class="gp-lab" text-anchor="middle">' + d.shutter + '</text>' +
        '<text x="226" y="38" class="gp-sub dim" text-anchor="middle">' + d.shutterNote + '</text>' +
        '<path d="M226 46 V66" class="gp-lead"/>' +
        // Shutter button on the top edge
        '<rect x="204" y="64" width="44" height="12" rx="5" class="gp-shutter"/>' +
        '<rect x="216" y="61" width="20" height="6" rx="3" class="gp-shutterRed"/>' +
        // Body
        '<rect x="100" y="74" width="224" height="164" rx="22" class="gp-body"/>' +
        '<rect x="100" y="74" width="224" height="164" rx="22" class="gp-edge"/>' +
        // Mode / power button on the side edge
        '<g class="gp-btnGroup">' +
          '<circle cx="330" cy="120" r="15" class="gp-halo"/>' +
          '<rect x="322" y="104" width="14" height="32" rx="6" class="gp-side"/>' +
        '</g>' +
        '<path d="M342 120 H368" class="gp-lead"/>' +
        '<text x="372" y="112" class="gp-lab">' + d.side + '</text>' +
        '<text x="372" y="128" class="gp-sub">' + d.sideNote1 + '</text>' +
        '<text x="372" y="143" class="gp-sub">' + d.sideNote2 + '</text>' +
        // Front screen, with the recording indicator
        '<rect x="120" y="94" width="78" height="66" rx="8" class="gp-screen"/>' +
        '<circle cx="134" cy="110" r="4.5" class="gp-rec"/>' +
        '<text x="143" y="114" class="gp-recLab">REC</text>' +
        '<text x="159" y="142" class="gp-time" text-anchor="middle">00:42</text>' +
        // Status light and GoPro wordmark
        '<circle cx="124" cy="222" r="3" class="gp-led"/>' +
        '<text x="142" y="225" class="gp-brand">GoPro</text>' +
        // Lens cover
        '<rect x="214" y="92" width="94" height="94" rx="16" class="gp-lensCover"/>' +
        '<circle cx="261" cy="139" r="33" class="gp-lensRing"/>' +
        '<circle cx="261" cy="139" r="22" class="gp-lens"/>' +
        '<circle cx="253" cy="130" r="6" class="gp-glint"/>' +
        // Timeline
        '<text x="100" y="274" class="gp-sub dim">' + d.timeline + '</text>' +
        '<rect x="100" y="284" width="224" height="10" rx="5" class="gp-track"/>' +
        '<rect x="100" y="284" width="224" height="10" rx="5" class="gp-played"/>' +
        '<g class="gp-marker">' +
          // At 50 % of the cycle — the instant the halo peaks — the playhead is at the track's
          // midpoint, x = 100 + 224 / 2 = 212. The marker lands there.
          '<path d="M206 300 l6 -9 l6 9 z" class="gp-flag"/>' +
          '<text x="212" y="318" class="gp-sub" text-anchor="middle">' + d.marker + '</text>' +
        '</g>' +
      '</svg>';
    return wrap;
  }

  // Click to enlarge. The mockup is cloned at a larger font size, and since everything is in
  // `em` it is redrawn sharp rather than being a stretched image.
  //
  // `.mk` is cloned, not the frame: the frame carries its own font size, which would override
  // the zoom view's.
  function makeZoomable(figure, label, closeLabel) {
    figure.setAttribute("aria-label", label);
    if (figure.dataset.zoomBound === "1") return;
    figure.dataset.zoomBound = "1";
    figure.classList.add("zoomable");
    figure.setAttribute("role", "button");
    figure.setAttribute("tabindex", "0");

    function open() {
      var source = figure.querySelector(".mk");
      if (!source) return;
      var overlay = el("div", "zoom");
      overlay.setAttribute("role", "dialog");
      overlay.setAttribute("aria-modal", "true");
      var inner = el("div", "zoom-inner");
      inner.appendChild(source.cloneNode(true));
      overlay.appendChild(inner);
      var close = el("button", "zoom-x", "&times;");
      close.setAttribute("aria-label", closeLabel || "Close");
      overlay.appendChild(close);
      document.body.appendChild(overlay);
      document.body.style.overflow = "hidden";
      requestAnimationFrame(function () { overlay.classList.add("on"); });

      function shut() {
        overlay.classList.remove("on");
        document.body.style.overflow = "";
        setTimeout(function () { overlay.remove(); }, 200);
        document.removeEventListener("keydown", onKey);
        figure.focus();
      }
      function onKey(e) { if (e.key === "Escape") shut(); }
      overlay.addEventListener("click", shut);
      document.addEventListener("keydown", onKey);
      close.focus();
    }

    figure.addEventListener("click", open);
    figure.addEventListener("keydown", function (e) {
      if (e.key === "Enter" || e.key === " ") { e.preventDefault(); open(); }
    });
  }

  window.QUIX_MOCKUPS = {
    transferWindow: transferWindow,
    onboardingWindow: onboardingWindow,
    popover: popover,
    goproDiagram: goproDiagram,
    makeZoomable: makeZoomable,
    icon: icon
  };
})();
