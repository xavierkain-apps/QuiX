import SwiftUI

@main
struct QuiXApp: App {

    @State private var model = ImportModel()

    var body: some Scene {
        Window("QuiX", id: "quix") {
            ContentView(model: model)
        }
        .commands {
            // L'app fait une chose : il n'y a rien à créer, rien à ouvrir.
            CommandGroup(replacing: .newItem) {}
        }
    }
}
