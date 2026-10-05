import SwiftUI

struct ContentView: View {
    var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
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
        }
        .frame(minWidth: 760, minHeight: 560)
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("URE")
        .dropDestination(for: URL.self) { urls, _ in
            guard model.acceptsFiles else { return false }
            model.ingest(urls)
            return true
        } isTargeted: { targeted in
            model.setDropTargeted(targeted && model.acceptsFiles)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("URE")
                .font(.largeTitle.weight(.semibold))
            Text("Unicode Reunion Engine")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Decomposed Unicode filenames를 NFC로 정규화합니다.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
        .padding(.vertical, 22)
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
