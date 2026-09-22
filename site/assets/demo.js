// The hero, animated: what happens after you plug in, told in one loop.
//
//   1. Transfer — the progress bar fills, each clip is checked as the copy passes it.
//   2. Library  — the session opens, the takes appear, a tagged one is selected.
//   3. Finder   — "Reveal in Finder" opens the Highlights folder.
//   4. Player   — the clip opens and plays, its HighLight marked on the timeline.
//
// Everything is drawn in HTML and sized in `em`, like the other mockups. A cursor moves to the
// real position of each target — measured from the layout, not hard-coded — so the story stays
// right whatever the size of the window on the page.
//
// The loop only runs while the hero is on screen, and not at all when the visitor asks for
// reduced motion: they get the finished transfer, still.
(function () {
  "use strict";

  function el(tag, className, html) {
    var node = document.createElement(tag);
    if (className) node.className = className;
    if (html != null) node.innerHTML = html;
    return node;
  }

  var CLIPS = [
    { name: "GX010042.MP4", mb: 120, tags: 1, dur: "0:42", scene: 1 },
    { name: "GX010043.MP4", mb: 120, tags: 0, dur: "1:08", scene: 2 },
    { name: "GX010044.MP4", mb: 120, tags: 1, dur: "0:37", scene: 3 },
    { name: "GX010045.MP4", mb: 120, tags: 0, dur: "0:55", scene: 4 },
    { name: "GX010046.MP4", mb: 120, tags: 1, dur: "1:21", scene: 5 },
    { name: "GX010047.MP4", mb: 120, tags: 0, dur: "0:29", scene: 6 }
  ];
  var TOTAL_MB = 720.2;

  // A stylised frame of footage — sky, horizon, ground, a rider — drawn in CSS. Six scenes: sea,
  // snow, sunset surf, forest trail, wave, dusk.
  function poster(scene) {
    return el("div", "pv pv-" + scene,
      '<i class="pv-sun"></i><i class="pv-far"></i><i class="pv-near"></i><i class="pv-rider"></i>');
  }

  function chrome(title, small) {
    var bar = el("div", "mk-bar" + (small ? " mk-bar-sm" : ""));
    var dots = el("div", "mk-dots");
    ["r", "y", "g"].forEach(function (c) { dots.appendChild(el("span", "mk-dot mk-" + c)); });
    bar.appendChild(dots);
    bar.appendChild(el("span", "mk-title", title));
    return bar;
  }

  function build(t) {
    var ui = t.ui, d = t.demo, refs = { rows: [], thumbs: [] };
    var win = el("div", "mk mk-win mk-demo");
    win.appendChild(chrome("QuiX"));

    var tabs = el("div", "mk-tabs");
    refs.tabs = ui.tabs.map(function (name, i) {
      var tab = el("span", "mk-tab" + (i === 0 ? " on" : ""), name);
      tabs.appendChild(tab);
      return tab;
    });
    win.appendChild(tabs);

    var stage = el("div", "mk-stage");
    win.appendChild(stage);

    // ── 1. Transfer ──────────────────────────────────────────────────────────
    var transfer = el("div", "scene scene-transfer on");
    var body = el("div", "mk-body");
    var route = el("div", "mk-route");
    var src = el("div", "mk-card");
    src.appendChild(el("div", "mk-lab", ui.source));
    src.appendChild(el("div", "mk-big", ui.sourceName));
    src.appendChild(el("div", "mk-meta", ui.sourceMeta));
    src.appendChild(el("div", "mk-path", "/Volumes/GOPRO/DCIM"));
    route.appendChild(src);
    refs.arrow = el("div", "mk-arrow", window.QUIX_ICON.arrow);
    route.appendChild(refs.arrow);
    var dst = el("div", "mk-card");
    dst.appendChild(el("div", "mk-lab", ui.destination));
    dst.appendChild(el("div", "mk-big", "2026-09-22"));
    dst.appendChild(el("div", "mk-meta", ui.destMeta));
    dst.appendChild(el("div", "mk-path", "~/Movies/GoPro"));
    route.appendChild(dst);
    body.appendChild(route);

    var prog = el("div", "mk-prog");
    var track = el("div", "mk-track");
    refs.fill = el("span", "mk-fill");
    track.appendChild(refs.fill);
    prog.appendChild(track);
    refs.progLab = el("div", "mk-progLab");
    prog.appendChild(refs.progLab);
    body.appendChild(prog);

    var table = el("div", "mk-table");
    var head = el("div", "mk-row mk-head");
    head.appendChild(el("span", "mk-c1", '<i class="mk-bullet"></i>' + ui.colFile));
    head.appendChild(el("span", "mk-c2", ui.colSize));
    head.appendChild(el("span", "mk-c3", ui.colTags));
    head.appendChild(el("span", "mk-c4", ui.colCheck));
    table.appendChild(head);
    CLIPS.forEach(function (c) {
      var row = el("div", "mk-row pending");
      row.appendChild(el("span", "mk-c1", '<i class="mk-bullet"></i>' + c.name));
      row.appendChild(el("span", "mk-c2", c.mb + " MB"));
      row.appendChild(el("span", "mk-c3", c.tags ? '<b class="mk-badge">' + c.tags + "</b>" : ""));
      row.appendChild(el("span", "mk-c4 mk-ok", '<span class="wait">…</span><span class="done">' + ui.checked + "</span>"));
      table.appendChild(row);
      refs.rows.push(row);
    });
    body.appendChild(table);
    transfer.appendChild(body);
    var foot = el("div", "mk-foot");
    foot.appendChild(el("p", "mk-note", ui.note));
    refs.openBtn = el("span", "mk-btn", ui.openBtn);
    foot.appendChild(refs.openBtn);
    transfer.appendChild(foot);
    stage.appendChild(transfer);
    refs.transfer = transfer;

    // ── 2. Library ───────────────────────────────────────────────────────────
    var library = el("div", "scene scene-library");
    var side = el("div", "lb-side");
    side.appendChild(el("div", "lb-global on", '<i class="lb-dot blue"></i><span>' + d.allHighlights + "</span><em>3</em>"));
    side.appendChild(el("div", "lb-global", '<i class="lb-dot"></i><span>' + d.allClips + "</span><em>6</em>"));
    side.appendChild(el("div", "lb-colHead", d.sessions));
    side.appendChild(el("div", "lb-session on", '<span class="mono">2026-09-22</span><em>6</em>'));
    side.appendChild(el("div", "lb-session", '<span class="mono">2026-09-14</span><em>11</em>'));
    side.appendChild(el("div", "lb-session", '<span class="mono">2026-09-07</span><em>8</em>'));
    var folder = el("div", "lb-folder");
    folder.appendChild(el("div", "lb-folderLab", d.importFolder));
    folder.appendChild(el("div", "lb-folderPath mono", "~/Movies/GoPro"));
    side.appendChild(folder);
    library.appendChild(side);

    var shelf = el("div", "lb-shelf");
    var shelfHead = el("div", "lb-head");
    shelfHead.appendChild(el("div", "lb-headTitle", '<b class="mono">2026-09-22</b><span>' + d.summary + "</span>"));
    var seg = el("div", "lb-seg");
    d.filters.forEach(function (f, i) { seg.appendChild(el("span", i === 2 ? "on" : "", f)); });
    shelfHead.appendChild(seg);
    shelf.appendChild(shelfHead);
    var grid = el("div", "lb-grid");
    CLIPS.forEach(function (c) {
      var thumb = el("div", "lb-thumb");
      var frame = el("div", "lb-poster");
      frame.appendChild(poster(c.scene));
      if (c.tags) frame.appendChild(el("b", "lb-tag", "★ " + c.tags));
      thumb.appendChild(frame);
      thumb.appendChild(el("div", "lb-cap", '<span class="mono">' + c.name + "</span><em>" + c.dur + "</em>"));
      grid.appendChild(thumb);
      refs.thumbs.push(thumb);
    });
    shelf.appendChild(grid);
    library.appendChild(shelf);

    var insp = el("div", "lb-insp");
    insp.appendChild(el("div", "lb-inspHead", d.inspector));
    var inspBody = el("div", "lb-inspBody");
    var inspPoster = el("div", "lb-poster");
    inspPoster.appendChild(poster(CLIPS[0].scene));
    inspBody.appendChild(inspPoster);
    inspBody.appendChild(el("div", "lb-inspName mono", CLIPS[0].name));
    inspBody.appendChild(el("div", "lb-inspSub", "0:42 — 120 MB — 5.3K"));
    inspBody.appendChild(el("div", "lb-colHead", d.moments));
    inspBody.appendChild(el("div", "lb-moments", '<i class="lb-mTrack"></i><i class="lb-mMark" style="left:58%"></i>'));
    refs.reveal = el("span", "mk-ghostBtn lb-reveal", d.reveal);
    inspBody.appendChild(refs.reveal);
    inspBody.appendChild(el("div", "lb-quik", d.quikNote));
    insp.appendChild(inspBody);
    library.appendChild(insp);
    stage.appendChild(library);
    refs.library = library;
    refs.inspBody = inspBody;

    // ── 3. Finder ────────────────────────────────────────────────────────────
    var finder = el("div", "os-win os-finder");
    var fBar = el("div", "fd-bar");
    var fDots = el("div", "mk-dots");
    ["r", "y", "g"].forEach(function (c) { fDots.appendChild(el("span", "mk-dot mk-" + c)); });
    fBar.appendChild(fDots);
    fBar.appendChild(el("span", "fd-nav", "‹ ›"));
    fBar.appendChild(el("span", "fd-title", d.path[d.path.length - 1]));
    finder.appendChild(fBar);
    var fMain = el("div", "fd-main");
    var fSide = el("div", "fd-side");
    fSide.appendChild(el("div", "fd-sideHead", d.favorites));
    d.places.forEach(function (p, i) { fSide.appendChild(el("div", "fd-place" + (i === 3 ? " on" : ""), p)); });
    fMain.appendChild(fSide);
    var fGrid = el("div", "fd-grid");
    refs.files = CLIPS.filter(function (c) { return c.tags; }).map(function (c) {
      var file = el("div", "fd-file");
      var icon = el("div", "fd-icon");
      icon.appendChild(poster(c.scene));
      file.appendChild(icon);
      file.appendChild(el("div", "fd-name", c.name));
      fGrid.appendChild(file);
      return file;
    });
    fMain.appendChild(fGrid);
    finder.appendChild(fMain);
    finder.appendChild(el("div", "fd-path", d.path.join('<span>›</span>') + '<em>' + d.items + "</em>"));
    win.appendChild(finder);
    refs.finder = finder;

    // ── 4. Player ────────────────────────────────────────────────────────────
    var player = el("div", "os-win os-player");
    player.appendChild(chrome(CLIPS[0].name, true));
    var screen = el("div", "pl-screen");
    screen.appendChild(poster(CLIPS[0].scene));
    refs.hlFlash = el("div", "pl-flash", "★ " + d.highlight);
    screen.appendChild(refs.hlFlash);
    player.appendChild(screen);
    var ctrl = el("div", "pl-ctrl");
    ctrl.appendChild(el("span", "pl-play", '<svg viewBox="0 0 24 24"><path d="M7 5v14l12-7z" fill="currentColor"/></svg>'));
    var scrub = el("div", "pl-scrub");
    refs.played = el("i", "pl-played");
    scrub.appendChild(refs.played);
    scrub.appendChild(el("i", "pl-mark"));
    ctrl.appendChild(scrub);
    refs.time = el("span", "pl-time mono", "0:00 / 0:42");
    ctrl.appendChild(refs.time);
    player.appendChild(ctrl);
    win.appendChild(player);
    refs.player = player;

    refs.cursor = el("div", "os-cursor",
      '<svg viewBox="0 0 24 24"><path d="M5 2.5v17.2l4.3-4.1 2.6 6 3-1.3-2.6-5.9h6z" fill="#fff" stroke="#000" stroke-width="1.2" stroke-linejoin="round"/></svg>');
    win.appendChild(refs.cursor);
    refs.win = win;
    return refs;
  }

  // ── The timeline ─────────────────────────────────────────────────────────────
  function Demo(t, refs) {
    var timers = [], frame = null, stopped = false, d = t.demo;

    function later(ms, fn) { timers.push(setTimeout(function () { if (!stopped) fn(); }, ms)); }

    function label(mb) {
      var x = mb.toFixed(1).replace(".", d.decimal);
      return d.progressFmt.replace("{x}", x);
    }

    function setProgress(f) {
      refs.fill.style.transform = "scaleX(" + f + ")";
      refs.progLab.textContent = label(TOTAL_MB * f);
      refs.rows.forEach(function (row, i) {
        row.classList.toggle("pending", f < (i + 1) / refs.rows.length - 0.001);
        row.classList.toggle("active", f >= i / refs.rows.length && f < (i + 1) / refs.rows.length);
      });
    }

    // Moves the cursor to the centre of `target`, in the window's coordinate space.
    function pointAt(target, dx, dy) {
      var w = refs.win.getBoundingClientRect(), r = target.getBoundingClientRect();
      var scale = w.width / refs.win.offsetWidth || 1;
      var x = (r.left - w.left + r.width * (dx == null ? .5 : dx)) / scale;
      var y = (r.top - w.top + r.height * (dy == null ? .5 : dy)) / scale;
      refs.cursor.style.transform = "translate(" + x + "px," + y + "px)";
    }
    function click(target) {
      refs.cursor.classList.remove("click");
      void refs.cursor.offsetWidth;
      refs.cursor.classList.add("click");
      if (target) {
        target.classList.add("pressed");
        later(220, function () { target.classList.remove("pressed"); });
      }
    }

    function reset() {
      refs.win.classList.remove("fade");
      refs.transfer.classList.add("on");
      refs.library.classList.remove("on");
      refs.tabs.forEach(function (tab, i) { tab.classList.toggle("on", i === 0); });
      refs.finder.classList.remove("on");
      refs.player.classList.remove("on", "playing", "flash");
      refs.thumbs.forEach(function (th) { th.classList.remove("in", "sel"); });
      refs.inspBody.classList.remove("on");
      refs.files.forEach(function (f) { f.classList.remove("sel"); });
      refs.openBtn.classList.remove("ready");
      refs.cursor.classList.remove("on", "click");
      refs.cursor.style.transition = "none";
      pointAt(refs.arrow);
      void refs.cursor.offsetWidth;
      refs.cursor.style.transition = "";
      refs.played.style.transform = "scaleX(0)";
      refs.time.textContent = "0:00 / 0:42";
      setProgress(0);
    }

    function animate(duration, step, done) {
      var start = null;
      function tick(now) {
        if (stopped) return;
        if (start === null) start = now;
        var p = Math.min(1, (now - start) / duration);
        step(p);
        if (p < 1) frame = requestAnimationFrame(tick); else if (done) done();
      }
      frame = requestAnimationFrame(tick);
    }

    function loop() {
      if (stopped) return;
      reset();

      // 1. Transfer: 5.4 s of copy, eased so it starts and settles softly.
      later(500, function () {
        animate(5400, function (p) {
          setProgress(p < .5 ? 2 * p * p : 1 - Math.pow(-2 * p + 2, 2) / 2);
        }, function () { refs.openBtn.classList.add("ready"); });
      });

      // 2. To the library.
      later(6600, function () { refs.cursor.classList.add("on"); pointAt(refs.tabs[1]); });
      later(7500, function () {
        click(refs.tabs[1]);
        refs.tabs.forEach(function (tab, i) { tab.classList.toggle("on", i === 1); });
        refs.transfer.classList.remove("on");
        refs.library.classList.add("on");
        refs.thumbs.forEach(function (th, i) { later(250 + i * 110, function () { th.classList.add("in"); }); });
      });
      later(9000, function () { pointAt(refs.thumbs[0], .5, .4); });
      later(9800, function () {
        click();
        refs.thumbs[0].classList.add("sel");
        refs.inspBody.classList.add("on");
      });

      // 3. Reveal in Finder.
      later(10900, function () { pointAt(refs.reveal); });
      later(11700, function () { click(refs.reveal); });
      later(11950, function () { refs.finder.classList.add("on"); });
      later(12900, function () { pointAt(refs.files[0], .5, .45); });
      later(13700, function () { click(); refs.files[0].classList.add("sel"); });
      later(13950, function () { click(); });

      // 4. The clip plays; its HighLight lights up as the playhead passes it.
      later(14200, function () {
        refs.player.classList.add("on", "playing");
        refs.cursor.classList.remove("on");
        var flashed = false;
        animate(4200, function (p) {
          var f = .12 + p * .72;
          refs.played.style.transform = "scaleX(" + f + ")";
          var s = Math.round(f * 42);
          refs.time.textContent = "0:" + (s < 10 ? "0" : "") + s + " / 0:42";
          if (!flashed && f >= .58) { flashed = true; refs.player.classList.add("flash"); }
        });
      });

      later(19000, function () { refs.win.classList.add("fade"); });
      later(19700, loop);
    }

    this.start = function () { loop(); };
    this.freeze = function () { setProgress(1); refs.openBtn.classList.add("ready"); };
    this.stop = function () {
      stopped = true;
      timers.forEach(clearTimeout);
      if (frame) cancelAnimationFrame(frame);
    };
  }

  var current = null, observer = null;

  // Builds the demo into `container` in the language of `t`, and starts it when it is visible.
  function mount(container, t) {
    if (current) current.stop();
    if (observer) observer.disconnect();
    container.innerHTML = "";
    var refs = build(t);
    container.appendChild(refs.win);
    var demo = current = new Demo(t, refs);

    var still = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (still || !("IntersectionObserver" in window)) { demo.freeze(); return; }

    demo.freeze();
    var running = false;
    observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting && !running) { running = true; demo.start(); }
        else if (!entry.isIntersecting && running) {
          // Off screen: stop, and start again from the beginning when it comes back.
          running = false;
          demo.stop();
          refs = build(t);
          container.innerHTML = "";
          container.appendChild(refs.win);
          demo = current = new Demo(t, refs);
          demo.freeze();
        }
      });
    }, { threshold: 0.25 });
    observer.observe(container);
  }

  window.QUIX_DEMO = { mount: mount };
})();
