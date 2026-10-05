import AppKit
import SwiftUI

/// Applies the chosen appearance to the window, then asks SwiftUI to rebuild materials.
/// Glass keeps the previous appearance when the scheme returns to the system, so the
/// center plate is recreated only after AppKit has the new appearance.
struct WindowAppearanceSetter: NSViewRepresentable {
    var scheme: ColorScheme
    var onApplied: () -> Void

    func makeNSView(context: Context) -> AppearanceApplyingView {
        let view = AppearanceApplyingView()
        view.onApplied = onApplied
        view.scheme = scheme
        return view
    }

    func updateNSView(_ view: AppearanceApplyingView, context: Context) {
        view.onApplied = onApplied
        view.scheme = scheme
    }
}

final class AppearanceApplyingView: NSView {
    var onApplied: () -> Void = {}
    var scheme: ColorScheme = .light {
        didSet {
            guard scheme != oldValue else { return }
            apply()
        }
    }

    private var applied: ColorScheme?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        apply()
    }

    private func apply() {
        guard let window else { return }
        let name: NSAppearance.Name = scheme == .dark ? .darkAqua : .aqua
        window.appearance = NSAppearance(named: name)
        guard applied != scheme else { return }
        applied = scheme
        Task { @MainActor in
            onApplied()
        }
    }
}
