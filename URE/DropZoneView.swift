import SwiftUI

struct DropZoneView: View {
    var model: AppModel

    var body: some View {
        VStack(spacing: 22) {
            dropArea
                .frame(maxWidth: 520, maxHeight: 340)

            VStack(spacing: 4) {
                Text("Decomposed Unicode filenames를 NFC로 정규화합니다.")
                Text("파일 내용은 바꾸지 않고, 이름만 NFC로 정규화합니다.")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var dropArea: some View {
        VStack(spacing: 18) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 28, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(model.isDropTargeted ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .frame(width: 64, height: 64)
                .background(
                    model.isDropTargeted ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.06),
                    in: Circle()
                )

            VStack(spacing: 6) {
                Text("파일 또는 폴더를 여기에 놓으세요")
                    .font(.title3.weight(.semibold))
                Text("Drop Files & Folders Here")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button("파일 선택") {
                model.chooseFiles()
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassEffect(dropGlass, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .animation(.smooth(duration: 0.22), value: model.isDropTargeted)
        .accessibilityLabel("파일 또는 폴더를 여기에 놓으세요")
    }

    private var dropGlass: Glass {
        if model.isDropTargeted {
            .regular.tint(.accentColor).interactive()
        } else {
            .regular
        }
    }
}
