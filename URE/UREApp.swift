import SwiftUI

@main
struct UREApp: App {
    @State private var model = AppModel()
    private let appUpdater = AppUpdater()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
        .defaultSize(width: 860, height: 700)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            AppUpdaterCommands(appUpdater: appUpdater)
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .pasteboard) {
                Button("파일 선택") {
                    model.chooseFiles()
                }
                .keyboardShortcut("o", modifiers: .command)
                .disabled(!model.acceptsFiles)

                Button("정규화 실행") {
                    model.renameSelected()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(model.phase != .preview || model.pendingCount == 0)
            }
            CommandGroup(replacing: .undoRedo) {
                Button("실행 취소") {
                    model.undoLastRun()
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!model.canUndo)
            }
        }
    }
}
