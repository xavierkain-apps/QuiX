// Les deux langues de la page.
//
// Le lecteur visé est celui qui filme : kite, ski, VTT, surf. Il ne sait pas ce qu'est un
// checksum, il n'a pas de compte GitHub, et la notarisation Apple ne lui dit rien. Ce qu'il
// veut savoir tient en trois questions — qu'est-ce que ça fait, comment on s'en sert, est-ce
// que ça risque d'effacer mes vidéos. Tout le reste a été retiré.
//
// Les captures ne sont plus des images : elles sont redessinées en HTML (voir `mockups.js`),
// donc leurs libellés se traduisent comme le reste de la page.
window.QUIX_COPY = {
  en: {
    htmlLang: "en",
    title: "QuiX — your GoPro highlights, sorted the moment you plug in",
    description: "You press the GoPro button when something good happens. QuiX finds those moments and puts the clips in their own folder, automatically. A free GoPro importer for Mac.",

    navGet: "Download",
    h1: "Plug in. Your best moments are already sorted.",
    sub: "You pressed the button when it happened. QuiX finds those clips and keeps them apart, while it imports the rest of your session. Nothing to click.",
    ctaPrimary: "Download for Mac",
    heroFoot: "Free · For Mac · GoPro HERO and MAX",
    shotHero: "Click to take a closer look",

    // Comment ça marche
    howKicker: "How it works",
    howTitle: "Three things, and two of them are already habits.",
    howSteps: [
      { no: "01", title: "You press the button while filming", body: "Something good happens — a jump, a wave, a turn. A short press on the GoPro's front button, and it is marked." },
      { no: "02", title: "Back home, you plug in", body: "The camera over USB-C, switched on. Or the memory card in a reader. QuiX starts on its own." },
      { no: "03", title: "You open the Highlights folder", body: "Your whole session is there, and the moments you marked are already waiting in their own folder." }
    ],

    // Le highlight GoPro
    hlKicker: "The GoPro button",
    hlTitle: "One press. That's the whole trick.",
    hlBody: "While the camera is recording, a short press on the front button — the same one you use to switch it on — marks the moment. The camera writes it inside the video file itself. You can also just say “GoPro, HiLight”, hands free.",
    hlNote: "It only works for presses made while filming. Highlights you add afterwards in the Quik phone app stay in the app, and QuiX cannot see them.",
    hlDiagram: {
      camera: "Your GoPro",
      button: "Front button",
      press: "Short press",
      recording: "Recording",
      result: "Moment marked in the clip"
    },

    // Bénéfices
    traits: [
      { title: "It starts by itself", body: "Plug in and the import is already running. No window to find, no folder to choose again." },
      { title: "Nothing gets lost", body: "Every clip is checked after copying. If something went wrong, QuiX tells you instead of pretending it worked." },
      { title: "Your card is never erased", body: "QuiX only reads it. Emptying the card stays your decision, in the camera, when you are sure." }
    ],

    // Barre de menus
    libTitle: "Check on it without stopping what you're doing.",
    libBody: "QuiX sits in the menu bar. One click tells you where the import is, and what it found. Go make a coffee.",
    shotPopover: "The menu bar, once an import is done",

    // Téléchargement
    dlTitle: "Get QuiX",
    dlBody: "Free, and it stays free. Tell me where to send the link.",
    dlFirstName: "First name",
    dlEmail: "Email",
    dlConsent: "Let me know when a new version is out. One email per release, nothing else, and you can stop whenever you like.",
    dlSubmit: "Send me the link",
    dlFoot: "For macOS 15 and later · Your GoPro over USB-C, or its card in a reader",
    dlPrivacy: "Your address is only used to send you the link, and the release notes if you tick the box. It is never sold, never passed on.",

    footerTag: "a GoPro importer for Mac",

    // Libellés de la maquette d'interface
    ui: {
      tabs: ["Transfer", "Library", "Settings"],
      source: "Source",
      sourceName: "GOPRO",
      sourceMeta: "6 takes — 720.2 MB — <b>3 marked</b>",
      destination: "Destination",
      destMeta: "Highlights / — Clips /",
      progress: "720.2 MB of 720.2 MB",
      colFile: "File",
      colSize: "Size",
      colTags: "Marked",
      colCheck: "Checked",
      checked: "ok",
      note: "Each clip is checked once copied. The card is never modified.",
      openBtn: "Open highlights",
      popTitle: "Import finished",
      popMeta: "6 clips — 720.2 MB — all checked",
      popHighlights: "Highlights",
      popClips: "Clips",
      popNote: "The card was not modified."
    },
    zoomClose: "Close"
  },

  fr: {
    htmlLang: "fr",
    title: "QuiX — vos highlights GoPro triés dès que vous branchez",
    description: "Vous appuyez sur le bouton de la GoPro quand il se passe quelque chose. QuiX retrouve ces moments et range les clips dans leur propre dossier, tout seul. Importeur GoPro gratuit pour Mac.",

    navGet: "Télécharger",
    h1: "Branchez. Vos meilleurs moments sont déjà triés.",
    sub: "Vous avez appuyé sur le bouton au bon moment. QuiX retrouve ces clips et les met à part, pendant qu'il importe le reste de la session. Aucun clic.",
    ctaPrimary: "Télécharger pour Mac",
    heroFoot: "Gratuit · Pour Mac · GoPro HERO et MAX",
    shotHero: "Cliquez pour regarder de plus près",

    howKicker: "Comment ça marche",
    howTitle: "Trois choses, dont deux sont déjà des réflexes.",
    howSteps: [
      { no: "01", title: "Vous appuyez sur le bouton en filmant", body: "Il se passe quelque chose — un saut, une vague, une courbe. Un appui court sur le bouton avant de la GoPro, et c'est marqué." },
      { no: "02", title: "De retour chez vous, vous branchez", body: "La caméra en USB-C, allumée. Ou la carte mémoire dans un lecteur. QuiX démarre tout seul." },
      { no: "03", title: "Vous ouvrez le dossier Highlights", body: "Toute votre session est là, et les moments que vous avez marqués vous attendent déjà dans leur propre dossier." }
    ],

    hlKicker: "Le bouton de la GoPro",
    hlTitle: "Un appui. C'est toute l'astuce.",
    hlBody: "Pendant que la caméra enregistre, un appui court sur le bouton avant — celui-là même qui l'allume — marque l'instant. La caméra l'écrit à l'intérieur du fichier vidéo. Vous pouvez aussi dire « GoPro, HiLight », sans les mains.",
    hlNote: "Ça ne marche que pour les appuis faits pendant le tournage. Les highlights ajoutés après coup dans l'app Quik du téléphone restent dans l'app, et QuiX ne peut pas les voir.",
    hlDiagram: {
      camera: "Votre GoPro",
      button: "Bouton avant",
      press: "Appui court",
      recording: "Enregistrement",
      result: "Moment marqué dans le clip"
    },

    traits: [
      { title: "Ça démarre tout seul", body: "Vous branchez, l'import tourne déjà. Aucune fenêtre à chercher, aucun dossier à rechoisir." },
      { title: "Rien ne se perd", body: "Chaque clip est vérifié après la copie. Si quelque chose s'est mal passé, QuiX vous le dit au lieu de faire comme si de rien n'était." },
      { title: "Votre carte n'est jamais effacée", body: "QuiX ne fait que la lire. La vider reste votre décision, dans la caméra, quand vous êtes sûr." }
    ],

    libTitle: "Jetez un œil sans arrêter ce que vous faites.",
    libBody: "QuiX vit dans la barre de menus. Un clic dit où en est l'import, et ce qu'il a trouvé. Allez vous faire un café.",
    shotPopover: "La barre de menus, une fois l'import terminé",

    dlTitle: "Obtenir QuiX",
    dlBody: "Gratuit, et ça le restera. Dites-moi où envoyer le lien.",
    dlFirstName: "Prénom",
    dlEmail: "E-mail",
    dlConsent: "Prévenez-moi quand une nouvelle version sort. Un e-mail par version, rien d'autre, et vous arrêtez quand vous voulez.",
    dlSubmit: "Envoyez-moi le lien",
    dlFoot: "Pour macOS 15 et plus · Votre GoPro en USB-C, ou sa carte dans un lecteur",
    dlPrivacy: "Votre adresse sert seulement à vous envoyer le lien, et les nouveautés si vous cochez la case. Elle n'est ni vendue ni transmise.",

    footerTag: "importeur GoPro pour Mac",

    ui: {
      tabs: ["Transfert", "Bibliothèque", "Réglages"],
      source: "Source",
      sourceName: "GOPRO",
      sourceMeta: "6 prises — 720,2 Mo — <b>3 marquées</b>",
      destination: "Destination",
      destMeta: "Highlights / — Clips /",
      progress: "720,2 Mo sur 720,2 Mo",
      colFile: "Fichier",
      colSize: "Taille",
      colTags: "Marqué",
      colCheck: "Vérifié",
      checked: "ok",
      note: "Chaque clip est vérifié une fois copié. La carte n'est jamais modifiée.",
      openBtn: "Ouvrir les highlights",
      popTitle: "Import terminé",
      popMeta: "6 clips — 720,2 Mo — tous vérifiés",
      popHighlights: "Highlights",
      popClips: "Clips",
      popNote: "La carte n'a pas été modifiée."
    },
    zoomClose: "Fermer"
  }
};
