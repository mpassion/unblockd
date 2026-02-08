import SwiftUI

// MARK: - Colors
extension Color {
    static let ubPrimary = Color(hex: "008C9E")

    // Adaptive Backgrounds
    static let ubBackground = Color(nsColor: .windowBackgroundColor)
    static let ubCard = Color(nsColor: .controlBackgroundColor)

    // Header/Footer specific backgrounds (subtle contrast)
    static let ubHeaderBg = Color(name: "ubHeaderBg") { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return isDark ? NSColor(white: 0.12, alpha: 1.0) : NSColor(white: 0.98, alpha: 1.0)
    }

    // Status
    static let ubStatusBlue = Color(hex: "3B82F6") // Royal Blue for "Action"
    static let ubStatusGreen = Color(hex: "10B981")
    static let ubStatusOrange = Color(hex: "F59E0B")
    static let ubStatusRed = Color(hex: "EF4444")
    static let ubStatusPurple = Color(hex: "8B5CF6") // Merged

    // Helper init
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// Helper to create adaptive colors with dynamic providers for macOS
    init(name: String, dynamicProvider: @escaping (NSAppearance) -> NSColor) {
        self.init(nsColor: NSColor(name: NSColor.Name(name), dynamicProvider: dynamicProvider))
    }
}

// MARK: - View Modifiers
struct UBBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.ubBackground)
    }
}

struct UBCardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background(Color.ubCard)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.05), radius: 2, x: 0, y: 1)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.05), lineWidth: 1)
            )
    }
}

extension View {
    func ubBackground() -> some View {
        modifier(UBBackground())
    }

    func ubCard() -> some View {
        modifier(UBCardStyle())
    }
}
