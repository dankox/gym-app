import SwiftUI

// MARK: - App Appearance Modes

enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    case oledDark = "OLED Black"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark, .oledDark:
            return .dark
        }
    }

    var iconName: String {
        switch self {
        case .system: return "gearshape.fill"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .oledDark: return "moon.stars.fill"
        }
    }
}

// MARK: - Preset Theme Colors

struct PresetThemeColor: Identifiable, Hashable {
    let id: String
    let name: String
    let hex: String

    var color: Color {
        Color(hex: hex) ?? .blue
    }

    static let presets: [PresetThemeColor] = [
        PresetThemeColor(id: "blue", name: "Gym Blue", hex: "#007AFF"),
        PresetThemeColor(id: "green", name: "Emerald", hex: "#34C759"),
        PresetThemeColor(id: "orange", name: "Sunset", hex: "#FF9500"),
        PresetThemeColor(id: "red", name: "Crimson", hex: "#FF3B30"),
        PresetThemeColor(id: "purple", name: "Royal Purple", hex: "#AF52DE"),
        PresetThemeColor(id: "gold", name: "Neon Gold", hex: "#FFCC00"),
        PresetThemeColor(id: "pink", name: "Hot Pink", hex: "#FF2D55"),
        PresetThemeColor(id: "cyan", name: "Cyan Ice", hex: "#32ADE6")
    ]
}

// MARK: - Theme Manager

@Observable
final class ThemeManager {
    static let shared = ThemeManager()

    var appearance: AppAppearance {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: "app_appearance")
        }
    }

    var accentColorHex: String {
        didSet {
            UserDefaults.standard.set(accentColorHex, forKey: "app_accent_color_hex")
        }
    }

    init() {
        let savedAppearanceStr = UserDefaults.standard.string(forKey: "app_appearance") ?? AppAppearance.system.rawValue
        self.appearance = AppAppearance(rawValue: savedAppearanceStr) ?? .system

        let savedHex = UserDefaults.standard.string(forKey: "app_accent_color_hex") ?? "#007AFF"
        self.accentColorHex = savedHex
    }

    var accentColor: Color {
        get {
            Color(hex: accentColorHex) ?? .blue
        }
        set {
            accentColorHex = newValue.toHex()
        }
    }

    func resetToDefaults() {
        appearance = .system
        accentColorHex = "#007AFF"
    }
}

// MARK: - Color Hex Extensions

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let length = hexSanitized.count
        let r, g, b, a: Double
        if length == 6 {
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double((rgb & 0x0000FF)) / 255.0
            a = 1.0
        } else if length == 8 {
            r = Double((rgb & 0xFF000000) >> 24) / 255.0
            g = Double((rgb & 0x00FF0000) >> 16) / 255.0
            b = Double((rgb & 0x000000FF) >> 8) / 255.0
            a = Double((rgb & 0x000000FF)) / 255.0
        } else {
            return nil
        }

        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    func toHex() -> String {
        let uic = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uic.getRed(&r, green: &g, blue: &b, alpha: &a)

        let rgb: Int = (Int)(r * 255) << 16 | (Int)(g * 255) << 8 | (Int)(b * 255)
        return String(format: "#%06X", rgb)
    }
}
