import SwiftUI

@main
struct DecryptEditorApp: App {
    @StateObject private var fileService = FileService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(fileService)
                .preferredColorScheme(.dark)
        }
    }
}

