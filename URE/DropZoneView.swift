import SwiftUI

struct DropZoneView: View {
    var model: AppModel

    var body: some View {
        VStack(spacing: 18) {
            dropArea
            Text("파일 내용은 바꾸지 않고, 이름만 NFC로 정규화합니다.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var dropArea: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(model.isDropTargeted ? Color.accentColor : Color.secondary)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 6) {
                Text("파일 또는 폴더를 여기에 놓으세요")
                    .font(.title3.weight(.medium))
                Text("Drop Files & Folders Here")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button("파일 선택") {
                model.chooseFiles()
            }
            .controlSize(.large)
        }
        .padding(36)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(model.isDropTargeted ? Color.accentColor.opacity(0.08) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    model.isDropTargeted ? Color.accentColor : Color(nsColor: .separatorColor),
                    style: StrokeStyle(lineWidth: model.isDropTargeted ? 2 : 1.5, dash: [8, 6])
                )
        )
        .animation(.easeOut(duration: 0.15), value: model.isDropTargeted)
        .accessibilityLabel("파일 또는 폴더를 여기에 놓으세요")
    }
}
