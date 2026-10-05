import Combine
import SwiftUI

struct ContentView: View {
    var model: AppModel
    @AppStorage("appearance") private var appearance = AppearanceChoice.system
    @State private var systemScheme = AppearanceChoice.systemScheme
    @State private var glassEpoch = 0

    private var resolvedScheme: ColorScheme {
        appearance.colorScheme ?? systemScheme
    }

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
        .id(glassEpoch)
        .navigationTitle("유리")
        .navigationSubtitle("URE · Unicode Reunion Engine")
        .preferredColorScheme(resolvedScheme)
        .background {
            WindowAppearanceSetter(scheme: resolvedScheme) {
                glassEpoch += 1
            }
        }
        .onReceive(
            DistributedNotificationCenter.default()
                .publisher(for: Notification.Name("AppleInterfaceThemeChangedNotification"))
                .receive(on: DispatchQueue.main)
        ) { _ in
            systemScheme = AppearanceChoice.systemScheme
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("모양", selection: $appearance) {
                    ForEach(AppearanceChoice.allCases) { choice in
                        Text(choice.title).tag(choice)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .accessibilityLabel("모양")
            }
        }
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
