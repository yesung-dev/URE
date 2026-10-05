import SwiftUI

struct ContentView: View {
    var model: AppModel

    var body: some View {
        Group {
            switch model.phase {
            case .ready:
                DropZoneView(model: model)
            case .scanning:
                WorkingView(
                    title: "탐색 중...",
                    completed: model.progressCompleted,
                    total: nil,
                    detail: "\(model.progressCompleted.grouped)개 발견"
                ) {
                    model.cancel()
                }
            case .preview:
                PreviewView(model: model)
            case .renaming:
                WorkingView(
                    title: "처리 중...",
                    completed: model.progressCompleted,
                    total: model.progressTotal,
                    detail: progressDetail
                ) {
                    model.cancel()
                }
            case .undoing:
                WorkingView(
                    title: "실행 취소 중...",
                    completed: model.progressCompleted,
                    total: model.progressTotal,
                    detail: progressDetail,
                    allowsCancel: false,
                    cancel: {}
                )
            case .result:
                ResultView(model: model)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minWidth: 760, minHeight: 560)
        .navigationTitle("URE")
        .navigationSubtitle("Unicode Reunion Engine")
        .dropDestination(for: URL.self) { urls, _ in
            guard model.acceptsFiles else { return false }
            model.ingest(urls)
            return true
        } isTargeted: { targeted in
            model.setDropTargeted(targeted && model.acceptsFiles)
        }
    }

    private var progressDetail: String {
        "\(model.progressCompleted.grouped) / \(model.progressTotal.grouped)"
    }
}

extension Int {
    var grouped: String {
        formatted(.number.grouping(.automatic))
    }
}

#Preview {
    ContentView(model: AppModel())
}
