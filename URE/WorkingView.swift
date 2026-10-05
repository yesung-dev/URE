import SwiftUI

struct WorkingView: View {
    var title: String
    var completed: Int
    var total: Int?
    var detail: String
    var allowsCancel: Bool = true
    var cancel: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(detail)
                    .font(.title2.monospacedDigit())
                    .foregroundStyle(.secondary)
                if let total, total > 0 {
                    ProgressView(value: Double(completed), total: Double(max(total, 1)))
                        .frame(maxWidth: 260)
                }
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 36)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28, style: .continuous))

            if allowsCancel {
                Button("취소", action: cancel)
                    .buttonStyle(.glass)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
