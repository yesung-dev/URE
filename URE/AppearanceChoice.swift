import SwiftUI

enum AppearanceChoice: String, CaseIterable, Identifiable {
    case light
    case dark
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: "라이트"
        case .dark: "다크"
        case .system: "시스템"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: .light
        case .dark: .dark
        case .system: nil
        }
    }

    /// The system setting, independent of this window's override.
    static var systemScheme: ColorScheme {
        UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark" ? .dark : .light
    }

    /// A concrete scheme. System is resolved immediately so materials are not left on the previous appearance.
    var resolvedColorScheme: ColorScheme {
        colorScheme ?? Self.systemScheme
    }
}
