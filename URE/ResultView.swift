import SwiftUI

struct ResultView: View {
    var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            summary
                .padding(.horizontal, 28)
                .padding(.top, 20)
                .padding(.bottom, 12)

            Table(model.results) {
                TableColumn("이름") { result in
                    VStack(alignment: .leading, spacing: 2) {
                        if case .renamed = result.status {
                            Text("\(FilenameDisplay.decomposed(result.originalName))  →  \(result.proposedName)")
                            Text("\(FilenameDisplay.codePoints(result.originalName)) → \(FilenameDisplay.codePoints(result.proposedName))")
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        } else {
                            Text(result.originalName)
                        }
                        Text(result.relativePath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .help(result.fullPath)
                }
                TableColumn("종류") { result in
                    Text(result.kind.label)
                        .foregroundStyle(.secondary)
                }
                .width(min: 70, ideal: 90)
                TableColumn("상태") { result in
                    Text(result.statusText)
                        .foregroundStyle(color(for: result.status))
                }
                .width(min: 180, ideal: 280)
            }

            Divider()
            footer
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("완료")
                .font(.title2.weight(.semibold))

            if let banner = model.banner {
                Text(banner)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                StatBadge(title: "변경됨", value: model.renamedCount)
                StatBadge(title: "변경할 필요 없음", value: model.unchangedCount)
                StatBadge(title: "실패", value: model.failedCount, emphasizesFailure: model.failedCount > 0)
                if model.skippedCount > 0 {
                    StatBadge(title: "제외", value: model.skippedCount)
                }
            }

            if model.showsPermissionHint {
                Text("권한이 없어 변경하지 못한 항목이 있습니다. 다시 실행한 뒤, 나타나는 창에서 그 파일이 들어 있는 폴더 접근을 허용해 주세요.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        HStack {
            Button("처음으로") {
                model.returnToReady()
            }

            Spacer()

            Button("실행 취소") {
                model.undoLastRun()
            }
            .disabled(!model.canUndo)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func color(for status: RenameStatus) -> Color {
        switch status {
        case .renamed:
            .primary
        case .failed:
            .red
        case .unchanged, .skippedSymlink, .cancelled:
            .secondary
        }
    }
}

private struct StatBadge: View {
    var title: String
    var value: Int
    var emphasizesFailure: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value.grouped)
                .font(.title2.monospacedDigit().weight(.semibold))
                .foregroundStyle(emphasizesFailure ? Color.red : Color.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}
