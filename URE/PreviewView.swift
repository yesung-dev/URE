import SwiftUI

struct PreviewView: View {
    var model: AppModel
    @State private var showsPendingOnly = false

    private var pendingItems: [ScanItem] {
        model.items.filter(\.willRename)
    }

    private var visibleItems: [ScanItem] {
        showsPendingOnly ? pendingItems : model.items
    }

    var body: some View {
        VStack(spacing: 0) {
            summary
                .padding(.horizontal, 28)
                .padding(.top, 8)
                .padding(.bottom, 12)

            Table(visibleItems) {
                TableColumn("현재 이름") { item in
                    NameCell(name: item.originalName, showScalars: item.needsNormalization, emphasizeDecomposed: true)
                }
                TableColumn("변경 후") { item in
                    NameCell(name: item.proposedName, showScalars: item.needsNormalization, emphasizeDecomposed: false)
                }
                TableColumn("상태") { item in
                    Text(item.previewStatus)
                        .foregroundStyle(item.willRename ? Color.primary : Color.secondary)
                }
                .width(min: 140, ideal: 180)
                TableColumn("종류") { item in
                    Text(item.kind.label)
                        .foregroundStyle(.secondary)
                }
                .width(min: 70, ideal: 90)
                TableColumn("경로") { item in
                    Text(item.relativePath)
                        .foregroundStyle(.secondary)
                        .help(item.fullPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .safeAreaBar(edge: .bottom) {
            footer
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(summaryTitle)
                .font(.title2.weight(.semibold))
            Text("변경 예정 \(pendingItems.count.grouped) · 전체 \(model.items.count.grouped)")
                .font(.callout)
                .foregroundStyle(.secondary)

            if !pendingItems.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(pendingItems.prefix(3))) { item in
                        Text("\(FilenameDisplay.decomposed(item.originalName))  →  \(item.proposedName)")
                            .font(.body)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .padding(.top, 2)
            }

            if model.appBundleCount > 0 {
                Text("앱 패키지(.app) 내부는 변경하지 않습니다.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Toggle("변경 예정만 보기", isOn: $showsPendingOnly)
                .toggleStyle(.checkbox)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summaryTitle: String {
        if pendingItems.isEmpty {
            return "변경이 필요한 항목이 없습니다."
        }
        return "\(pendingItems.count.grouped)개의 항목을 정규화할 수 있습니다."
    }

    private var footer: some View {
        HStack {
            Button("취소") {
                model.cancel()
            }
            .buttonStyle(.glass)
            .keyboardShortcut(.cancelAction)

            Spacer()

            Text("기존 파일은 덮어쓰지 않습니다.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()

            if pendingItems.isEmpty {
                Button("닫기") {
                    model.returnToReady()
                }
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.defaultAction)
            } else {
                Button("정규화 실행") {
                    model.renameSelected()
                }
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

struct NameCell: View {
    var name: String
    var showScalars: Bool
    var emphasizeDecomposed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(emphasizeDecomposed && showScalars ? FilenameDisplay.decomposed(name) : name)
                .lineLimit(1)
                .truncationMode(.middle)
            if showScalars {
                Text(FilenameDisplay.codePoints(name))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .help(name)
    }
}

enum FilenameDisplay {
    static func decomposed(_ name: String) -> String {
        var scalars: [Unicode.Scalar] = []
        for scalar in name.unicodeScalars {
            if let last = scalars.last, shouldSeparate(last, scalar) {
                scalars.append("\u{200C}")
            }
            scalars.append(scalar)
        }
        return String(String.UnicodeScalarView(scalars))
    }

    static func codePoints(_ name: String, limit: Int = 6) -> String {
        let points = name.unicodeScalars.map { String(format: "U+%04X", $0.value) }
        if points.count <= limit {
            return points.joined(separator: " ")
        }
        return points.prefix(limit).joined(separator: " ") + " …"
    }

    private static func shouldSeparate(_ previous: Unicode.Scalar, _ next: Unicode.Scalar) -> Bool {
        isHangulJamo(previous) && isHangulJamo(next) || next.properties.isGraphemeExtend
    }

    private static func isHangulJamo(_ scalar: Unicode.Scalar) -> Bool {
        let value = scalar.value
        return (0x1100...0x11FF).contains(value)
            || (0xA960...0xA97F).contains(value)
            || (0xD7B0...0xD7FF).contains(value)
    }
}
