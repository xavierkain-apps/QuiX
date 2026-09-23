// The page in both languages.
//
// The reader is someone who films — kite, ski, mountain bike, surf. They do not know what a
// checksum is, have no GitHub account, and Apple notarization means nothing to them. What they
// want to know fits in three questions: what does it do, how do I use it, and could it wipe my
// footage. And one more, answered in several places on purpose: does it cost anything. It does not.
//
// The screens are not images: they are redrawn in HTML (see `mockups.js`), so their labels
// translate with the rest of the page. The text inside the first-launch screens is the app's own,
// taken from App/Localizable.xcstrings, so the page shows the app as it really is.
window.QUIX_COPY = {
  en: {
    htmlLang: "en",
    title: "QuiX — free GoPro importer for Mac that sorts your highlights",
    description: "Press the button on your GoPro when something good happens. QuiX finds those moments and puts the clips in their own folder, automatically. Free, for Mac.",

    navGet: "Free download",
    h1: "Skip the rushes.<br>Keep the moments.",
    sub: "You pressed the button when it happened. QuiX finds those clips and keeps them apart, while it imports the rest of your session. Nothing to click.",
    ctaPrimary: "Download for free",
    heroFoot: "100% free · No account · No ads · For Mac",
    shotHero: "The end of an import: three marked takes, already waiting in Highlights.",

    howKicker: "How it works",
    howTitle: "Film. Press. Plug in.",
    howSteps: [
      { no: "01", title: "You press the button while filming", body: "Something good happens — a jump, a wave, a turn. A short press on the button on the side of your GoPro, and the moment is marked." },
      { no: "02", title: "Back home, you plug in", body: "The camera over USB-C, switched on. Or the memory card in a reader. QuiX starts on its own." },
      { no: "03", title: "You open the Highlights folder", body: "Your whole session is there, and the moments you marked are already waiting in their own folder." }
    ],

    hlKicker: "The GoPro button",
    hlTitle: "One press. One highlight.",
    hlBody: "While your GoPro is recording, give a short press to the button on its side — the one you use to switch it on. The camera keeps filming and writes the moment inside the video file. You can also just say “GoPro, HighLight”, hands free.",
    hlNote: "It only works for presses made while filming. Highlights added afterwards in the Quik phone app stay in the app, and QuiX cannot see them.",
    hlDiagram: {
      camera: "GoPro HERO12 Black, seen from the front",
      shutter: "Shutter",
      shutterNote: "starts and stops recording",
      side: "Power / Mode",
      sideNote1: "short press while",
      sideNote2: "filming = HighLight",
      timeline: "Your clip",
      marker: "HighLight"
    },

    traits: [
      { icon: "bolt", title: "It starts by itself", body: "Plug in and the import is already running. No window to find, no folder to choose again." },
      { icon: "shield", title: "Nothing gets lost", body: "Every clip is checked after copying. If something went wrong, QuiX tells you instead of pretending it worked." },
      { icon: "hand", title: "Your card is never wiped behind your back", body: "QuiX only empties it when you press the button — and only once every clip is safely on your Mac." },
      { icon: "free", title: "Free, for good", body: "No price, no trial, no subscription, no ads. Download it and it is yours." }
    ],

    onbKicker: "First launch",
    onbTitle: "Ready in under a minute.",
    onbHint: "Click a screen to enlarge it",
    onbCards: [
      { no: "01", title: "What QuiX does", body: "Your GoPro over USB-C, or its card in a reader. Your footage is never modified." },
      { no: "02", title: "Where your clips go", body: "Pick the folder you already use. Each import gets its own dated folder, with Highlights and Clips inside." },
      { no: "03", title: "Say yes to your Mac", body: "Once for the camera, once for the card reader. That is the whole setup." }
    ],
    onb: {
      back: "Back",
      cont: "Continue",
      screens: [
        {
          title: "QuiX sorts your GoPro highlights",
          text: "Plug the camera in over USB-C and switch it on, or put the card into a reader. QuiX reads the tags you pressed while filming and files each take in Highlights or Clips. It never modifies the card.",
          cards: [
            { icon: "bolt", title: "No waiting", body: "Sorting reads 34 KB per clip, not the whole file." },
            { icon: "shield", title: "Verified", body: "Every copy is checksummed, then read back from disk." },
            { icon: "hand", title: "Never erases", body: "The card is only emptied by a button you press." }
          ]
        },
        {
          title: "Where should the clips go?",
          text: "QuiX creates one dated folder per import, with Highlights and Clips inside it. Pick somewhere you already keep footage — QuiX will not invent a folder for you.",
          button: "Choose a folder…"
        },
        {
          title: "Two permissions macOS will ask for",
          text: "Neither is optional, and both fail the same misleading way — QuiX sees the hardware and finds nothing on it.",
          rows: [
            { icon: "globe", title: "Local Network", body: "Over USB-C the GoPro is a network device. macOS asks the first time QuiX talks to it; if you refuse, the camera looks empty." },
            { icon: "card", title: "Removable Volumes", body: "For a card in a reader. macOS asks on the first card; without it, the card looks empty." },
            { icon: "bell", title: "Notifications", body: "So you know when an import is done and the camera can be unplugged.", button: "Allow notifications…" }
          ],
          checkbox: "Open QuiX when the GoPro is plugged in",
          primary: "Plug in and turn on your GoPro"
        }
      ]
    },

    libTitle: "Check on it without stopping what you're doing.",
    libBody: "QuiX sits in the menu bar. One click tells you where the import is, and what it found. Go make a coffee.",
    shotPopover: "The menu bar, once an import is done",

    dlTitle: "Get QuiX. It's free.",
    dlBody: "No price, no trial, no subscription, no ads. Just tell me where to send the link.",
    dlFirstName: "First name",
    dlEmail: "Email",
    dlConsent: "Let me know when a new version is out. One email per release, nothing else, and you can stop whenever you like.",
    dlSubmit: "Send me the free download",
    dlFoot: "For macOS 15 and later · Your GoPro over USB-C, or its card in a reader",
    dlPrivacy: "Your address is only used to send you the link, and the release notes if you tick the box. It is never sold, never passed on.",

    footerTag: "a free GoPro importer for Mac",

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
    // The animated hero: transfer, then the library, then the Finder, then the clip playing.
    // The labels are the app's own (Localizable.xcstrings) and the Finder's.
    demo: {
      progressFmt: "{x} MB of 720.2 MB",
      decimal: ".",
      allHighlights: "All highlights",
      allClips: "All clips",
      sessions: "Sessions",
      importFolder: "Import folder",
      filters: ["Highlights", "Clips", "All"],
      summary: "6 takes — 3 tagged",
      inspector: "Inspector",
      moments: "Moments",
      reveal: "Reveal in Finder",
      quikNote: "Highlights added afterwards in the Quik app stay inside that app.",
      favorites: "Favorites",
      places: ["AirDrop", "Recents", "Applications", "Movies", "Downloads"],
      path: ["Movies", "GoPro", "2026-09-22", "Highlights"],
      items: "3 items",
      highlight: "HighLight"
    },
    zoomClose: "Close"
  },

  fr: {
    htmlLang: "fr",
    title: "QuiX — importeur GoPro gratuit pour Mac qui trie vos highlights",
    description: "Appuyez sur le bouton de votre GoPro quand il se passe quelque chose. QuiX retrouve ces moments et range les clips dans leur propre dossier, tout seul. Gratuit, pour Mac.",

    navGet: "Téléchargement gratuit",
    h1: "Vos meilleures prises,<br>déjà triées.",
    sub: "Vous avez appuyé sur le bouton au bon moment. QuiX retrouve ces clips et les met à part, pendant qu'il importe le reste de la session. Aucun clic.",
    ctaPrimary: "Télécharger gratuitement",
    heroFoot: "100 % gratuit · Sans compte · Sans pub · Pour Mac",
    shotHero: "La fin d'un import : trois prises marquées, qui attendent déjà dans Highlights.",

    howKicker: "Comment ça marche",
    howTitle: "Filmez. Appuyez. Branchez.",
    howSteps: [
      { no: "01", title: "Vous appuyez sur le bouton en filmant", body: "Il se passe quelque chose — un saut, une vague, une courbe. Un appui court sur le bouton sur le côté de votre GoPro, et l'instant est marqué." },
      { no: "02", title: "De retour chez vous, vous branchez", body: "La caméra en USB-C, allumée. Ou la carte mémoire dans un lecteur. QuiX démarre tout seul." },
      { no: "03", title: "Vous ouvrez le dossier Highlights", body: "Toute votre session est là, et les moments que vous avez marqués vous attendent déjà dans leur propre dossier." }
    ],

    hlKicker: "Le bouton de la GoPro",
    hlTitle: "Un appui, un highlight.",
    hlBody: "Pendant que votre GoPro enregistre, donnez un appui court sur le bouton de son côté — celui qui sert à l'allumer. La caméra continue de filmer et écrit l'instant à l'intérieur du fichier vidéo. Vous pouvez aussi dire « GoPro, HighLight », sans les mains.",
    hlNote: "Ça ne marche que pour les appuis faits pendant le tournage. Les highlights ajoutés après coup dans l'app Quik du téléphone restent dans l'app, et QuiX ne peut pas les voir.",
    hlDiagram: {
      camera: "GoPro HERO12 Black, vue de face",
      shutter: "Déclencheur",
      shutterNote: "lance et arrête l'enregistrement",
      side: "Power / Mode",
      sideNote1: "appui court en",
      sideNote2: "filmant = HighLight",
      timeline: "Votre clip",
      marker: "HighLight"
    },

    traits: [
      { icon: "bolt", title: "Ça démarre tout seul", body: "Vous branchez, l'import tourne déjà. Aucune fenêtre à chercher, aucun dossier à rechoisir." },
      { icon: "shield", title: "Rien ne se perd", body: "Chaque clip est vérifié après la copie. Si quelque chose s'est mal passé, QuiX vous le dit au lieu de faire comme si de rien n'était." },
      { icon: "hand", title: "Votre carte n'est jamais vidée dans votre dos", body: "QuiX ne la vide que si vous appuyez sur le bouton — et seulement quand tous les clips sont bien sur votre Mac." },
      { icon: "free", title: "Gratuit, pour de bon", body: "Pas de prix, pas d'essai, pas d'abonnement, pas de pub. Vous le téléchargez, il est à vous." }
    ],

    onbKicker: "Premier lancement",
    onbTitle: "Prêt en moins d'une minute.",
    onbHint: "Cliquez sur un écran pour l'agrandir",
    onbCards: [
      { no: "01", title: "Ce que fait QuiX", body: "Votre GoPro en USB-C, ou sa carte dans un lecteur. Vos vidéos ne sont jamais modifiées." },
      { no: "02", title: "Où vont vos clips", body: "Choisissez le dossier que vous utilisez déjà. Chaque import a son dossier daté, avec Highlights et Clips dedans." },
      { no: "03", title: "Dites oui à votre Mac", body: "Une fois pour la caméra, une fois pour le lecteur de cartes. C'est toute l'installation." }
    ],
    onb: {
      back: "Retour",
      cont: "Continuer",
      screens: [
        {
          title: "QuiX trie les highlights de votre GoPro",
          text: "Branchez la caméra en USB-C et allumez-la, ou mettez la carte dans un lecteur. QuiX lit les tags posés pendant le tournage et range chaque prise dans Highlights ou dans Clips. Il ne modifie jamais la carte.",
          cards: [
            { icon: "bolt", title: "Sans attendre", body: "Le tri lit 34 Ko par clip, pas le fichier entier." },
            { icon: "shield", title: "Vérifié", body: "Chaque copie porte une empreinte, relue ensuite sur le disque." },
            { icon: "hand", title: "N'efface jamais", body: "La carte ne se vide que par un bouton sur lequel vous appuyez." }
          ]
        },
        {
          title: "Où ranger les clips ?",
          text: "QuiX crée un dossier daté par import, avec Highlights et Clips dedans. Choisissez un endroit où vous rangez déjà vos rushes — QuiX n'inventera pas de dossier à votre place.",
          button: "Choisir un dossier…"
        },
        {
          title: "Deux autorisations que macOS va demander",
          text: "Aucune n'est facultative, et les deux échouent de la même façon trompeuse : QuiX voit le matériel et n'y trouve rien.",
          rows: [
            { icon: "globe", title: "Réseau local", body: "En USB-C, la GoPro est un périphérique réseau. macOS la demande la première fois que QuiX lui parle ; en cas de refus, la caméra paraît vide." },
            { icon: "card", title: "Volumes amovibles", body: "Pour une carte dans un lecteur. macOS la demande à la première carte ; sans elle, la carte paraît vide." },
            { icon: "bell", title: "Notifications", body: "Pour savoir quand un import est fini et quand débrancher la caméra.", button: "Autoriser les notifications…" }
          ],
          checkbox: "Ouvrir QuiX quand la GoPro est branchée",
          primary: "Branchez et allumez votre GoPro"
        }
      ]
    },

    libTitle: "Jetez un œil sans arrêter ce que vous faites.",
    libBody: "QuiX vit dans la barre de menus. Un clic dit où en est l'import, et ce qu'il a trouvé. Allez vous faire un café.",
    shotPopover: "La barre de menus, une fois l'import terminé",

    dlTitle: "Obtenez QuiX. C'est gratuit.",
    dlBody: "Pas de prix, pas d'essai, pas d'abonnement, pas de pub. Dites-moi juste où envoyer le lien.",
    dlFirstName: "Prénom",
    dlEmail: "E-mail",
    dlConsent: "Prévenez-moi quand une nouvelle version sort. Un e-mail par version, rien d'autre, et vous arrêtez quand vous voulez.",
    dlSubmit: "Envoyez-moi le lien gratuit",
    dlFoot: "Pour macOS 15 et plus · Votre GoPro en USB-C, ou sa carte dans un lecteur",
    dlPrivacy: "Votre adresse sert seulement à vous envoyer le lien, et les nouveautés si vous cochez la case. Elle n'est ni vendue ni transmise.",

    footerTag: "importeur GoPro gratuit pour Mac",

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
    demo: {
      progressFmt: "{x} Mo sur 720,2 Mo",
      decimal: ",",
      allHighlights: "Tous les highlights",
      allClips: "Tous les clips",
      sessions: "Sessions",
      importFolder: "Dossier d'import",
      filters: ["Highlights", "Clips", "Tout"],
      summary: "6 prises — 3 taguées",
      inspector: "Inspecteur",
      moments: "Moments",
      reveal: "Révéler dans le Finder",
      quikNote: "Les highlights ajoutés après coup dans l'app Quik restent dans l'app.",
      favorites: "Favoris",
      places: ["AirDrop", "Récents", "Applications", "Vidéos", "Téléchargements"],
      path: ["Vidéos", "GoPro", "2026-09-22", "Highlights"],
      items: "3 éléments",
      highlight: "HighLight"
    },
    zoomClose: "Fermer"
  }
};
