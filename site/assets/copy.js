// Les deux langues de la page. Reprises telles quelles du handoff de design, à deux
// exceptions près : la GoPro doit être **allumée**, et le téléchargement passe par un
// formulaire. Les captures suivent la langue — voir `shots/en/` et `shots/fr/`.
window.QUIX_COPY = {
  en: {
    htmlLang: "en",
    title: "QuiX — plug in, every clip lands sorted",
    description: "QuiX imports your GoPro session on its own and keeps the takes you tagged while filming in their own Highlights folder. macOS 15+, signed and notarized.",
    navGet: "Download",
    h1: "Plug in. Every clip lands sorted.",
    sub: "QuiX imports your whole session on its own and puts the takes you tagged on the camera in their own Highlights folder. No clicking, no sorting, no waiting.",
    ctaPrimary: "Download for macOS",
    ctaSecondary: "View source",
    heroFoot: "macOS 15+ · universal · signed &amp; notarized",
    shotHero: "The Transfer tab at the end of an import",
    hlKicker: "What a highlight is",
    hlTitle: "The tag you press while filming.",
    hlBody: "While the camera is recording, a short press on the power button marks the moment. Back home you see straight away which takes are worth keeping, instead of rewatching the whole session.",
    hlNote: "Only tags set while filming live inside the file. Highlights added afterwards in the Quik mobile app stay in the app.",
    hlSteps: [
      { no: "01", title: "You are recording", body: "Kitesurf, ski, ride — the camera is rolling." },
      { no: "02", title: "Short press on the power button", body: "Or say “GoPro, HiLight”. The moment is written into the clip itself." },
      { no: "03", title: "QuiX keeps those takes apart", body: "Every take carrying a tag goes into Highlights/, the rest into Clips/." }
    ],
    onbKicker: "First launch",
    onbTitle: "Three screens, then you plug in.",
    libTitle: "Lives in the menu bar.",
    libBody: "One click tells you where the import stands, and what it found. The window opens on its own when an import starts.",
    dlTitle: "No editing. No cloud.",
    dlBody: "A universal, Developer ID signed, notarized bundle. Nothing to compile, and Gatekeeper says nothing at all.",
    dlFirstName: "First name",
    dlEmail: "Email",
    dlConsent: "Let me know when a new version is out. One email per release, nothing else, and you can stop at any time.",
    dlSubmit: "Get the download link",
    dlFoot: "HERO12 Black over USB-C · any GoPro card in a reader",
    dlPrivacy: "Your address is used to send you the link and, if you tick the box, the release notes. It is never sold, never shared.",
    shotPopover: "The menu bar popover after an import",
    footerTag: "a GoPro importer for macOS",
    traits: [
      { title: "No waiting", body: "Sorting reads 34 KB per clip, not the whole file." },
      { title: "Verified", body: "Every copy is checksummed, then read back from disk." },
      { title: "Never erases", body: "The card is only emptied by a button you press." }
    ],
    stats: [
      { to: 34, suffix: " KB", label: "read per clip" },
      { to: 3, suffix: "", label: "seeks per clip" },
      { to: 2, suffix: "", label: "sources: card &amp; USB-C" },
      { to: 109, suffix: "", label: "engine tests" }
    ],
    onboarding: [
      { no: "01", shot: "onb-1.png", title: "QuiX sorts your GoPro highlights", body: "Camera over USB-C, or the card in a reader. It never modifies the card." },
      { no: "02", shot: "onb-2.png", title: "Where should the clips go?", body: "One dated folder per import, with Highlights and Clips inside." },
      { no: "03", shot: "onb-3.png", title: "Two permissions macOS will ask for", body: "Local Network for the camera, Removable Volumes for the card." }
    ],
    tabs: [
      { name: "Transfer", key: "⌘1" },
      { name: "Library", key: "⌘2" },
      { name: "Settings", key: "⌘3" }
    ]
  },
  fr: {
    htmlLang: "fr",
    title: "QuiX — branchez, tout arrive déjà trié",
    description: "QuiX importe votre session GoPro tout seul et garde les prises taguées pendant le tournage dans leur propre dossier Highlights. macOS 15+, signé et notarisé.",
    navGet: "Télécharger",
    h1: "Branchez. Tout arrive déjà trié.",
    sub: "QuiX importe toute votre session tout seul et range les prises taguées sur la caméra dans leur propre dossier Highlights. Aucun clic, aucun tri, aucune attente.",
    ctaPrimary: "Télécharger pour macOS",
    ctaSecondary: "Voir le code",
    heroFoot: "macOS 15+ · universel · signé et notarisé",
    shotHero: "L'onglet Transfert à la fin d'un import",
    hlKicker: "Un highlight, c'est quoi",
    hlTitle: "Le tag posé pendant le tournage.",
    hlBody: "Pendant que la caméra enregistre, un appui court sur le bouton power marque l'instant. De retour chez vous, vous voyez tout de suite quelles prises valent le coup, au lieu de revisionner toute la session.",
    hlNote: "Seuls les tags posés pendant le tournage vivent dans le fichier. Ceux ajoutés après coup dans l'app mobile Quik restent dans l'app.",
    hlSteps: [
      { no: "01", title: "Vous filmez", body: "Kitesurf, ski, ride — la caméra tourne." },
      { no: "02", title: "Appui court sur le bouton power", body: "Ou « GoPro, HiLight » à la voix. L'instant est écrit dans le clip lui-même." },
      { no: "03", title: "QuiX met ces prises à part", body: "Chaque prise qui porte un tag va dans Highlights/, le reste dans Clips/." }
    ],
    onbKicker: "Premier lancement",
    onbTitle: "Trois écrans, puis vous branchez.",
    libTitle: "Vit dans la barre de menus.",
    libBody: "Un clic dit où en est l'import, et ce qu'il a trouvé. La fenêtre s'ouvre d'elle-même quand un import démarre.",
    dlTitle: "Pas de montage. Pas de cloud.",
    dlBody: "Un bundle universel, signé Developer ID et notarisé. Rien à compiler, et Gatekeeper ne dit rien du tout.",
    dlFirstName: "Prénom",
    dlEmail: "E-mail",
    dlConsent: "Prévenez-moi quand une nouvelle version sort. Un e-mail par version, rien d'autre, et vous pouvez arrêter quand vous voulez.",
    dlSubmit: "Recevoir le lien de téléchargement",
    dlFoot: "HERO12 Black en USB-C · toute carte GoPro dans un lecteur",
    dlPrivacy: "Votre adresse sert à vous envoyer le lien et, si vous cochez la case, les nouveautés. Elle n'est ni vendue ni transmise.",
    shotPopover: "Le popover de la barre de menus après un import",
    footerTag: "importeur GoPro pour macOS",
    traits: [
      { title: "Pas d'attente", body: "Le tri lit 34 Ko par clip, pas le fichier entier." },
      { title: "Vérifié", body: "Chaque copie est empreintée, puis relue sur le disque." },
      { title: "N'efface jamais", body: "La carte n'est vidée que sur un bouton que vous pressez." }
    ],
    stats: [
      { to: 34, suffix: " Ko", label: "lus par clip" },
      { to: 3, suffix: "", label: "seek par clip" },
      { to: 2, suffix: "", label: "sources : carte &amp; USB-C" },
      { to: 109, suffix: "", label: "tests du moteur" }
    ],
    onboarding: [
      { no: "01", shot: "onb-1.png", title: "QuiX trie vos highlights GoPro", body: "La caméra en USB-C, ou la carte dans un lecteur. Elle ne modifie jamais la carte." },
      { no: "02", shot: "onb-2.png", title: "Où ranger les clips ?", body: "Un dossier daté par import, avec Highlights et Clips à l'intérieur." },
      { no: "03", shot: "onb-3.png", title: "Deux autorisations demandées par macOS", body: "Réseau local pour la caméra, Volumes amovibles pour la carte." }
    ],
    tabs: [
      { name: "Transfert", key: "⌘1" },
      { name: "Bibliothèque", key: "⌘2" },
      { name: "Réglages", key: "⌘3" }
    ]
  }
};
