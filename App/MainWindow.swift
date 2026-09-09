import SwiftUI

/// La fenêtre unique, et ses deux onglets.
///
/// Le handoff dessinait deux fenêtres séparées. Les réunir change une chose qui compte : « Ouvrir
/// les highlights » ne fait plus surgir une seconde fenêtre par-dessus la première, il bascule
/// d'onglet — on reste au même endroit.
struct MainWindow: View {

    let model: ImportModel
    let router: AppRouter

    var body: some View {
        VStack(spacing: 0) {
            tabs
            Group {
                switch router.tab {
                case .transfer: TransferWindow(model: model)
                case .library: LibraryWindow(model: model, router: router)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(minWidth: 900, minHeight: 600)
        .background(Ink.window)
        .foregroundStyle(Ink.primary)
    }

    /// La barre d'onglets, au même gabarit que l'en-tête de la Bibliothèque : 46 pt, fond de
    /// panneau, filet en bas.
    private var tabs: some View {
        HStack {
            Segmented(selection: Binding(get: { router.tab }, set: { router.tab = $0 }),
                      options: AppRouter.Tab.allCases, label: \.rawValue)
            Spacer()
            if model.stageKind == .importing {
                HStack(spacing: 7) {
                    PulsingDot(size: 6)
                    Text("Import en cours").font(Type.caption).foregroundStyle(Ink.blueText)
                }
            }
        }
        .padding(.horizontal, 20)
        .frame(height: Metrics.headerHeight)
        .background(Ink.titleBar)
        .overlay(alignment: .bottom) { Rule() }
    }
}
