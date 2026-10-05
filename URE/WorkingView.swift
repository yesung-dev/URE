import SwiftUI

struct WorkingView: View {
    var title: String
    var completed: Int
    var total: Int?
    var detail: String
    var allowsCancel: Bool = true
    var cancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text(title)
                .font(.title3.weight(.medium))
            Text(detail)
                .font(.title2.monospacedDigit())
                .foregroundStyle(.secondary)
            if let total, total > 0 {
                ProgressView(value: Double(completed), total: Double(max(total, 1)))
                    .frame(width: 280)
            }
            if allowsCancel {
                Button("취소", action: cancel)
                    .keyboardShortcut(.cancelAction)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
