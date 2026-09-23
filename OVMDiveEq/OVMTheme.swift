import SwiftUI

enum OVMTheme {
    static let accent = Color(red: 91.0 / 255.0, green: 206.0 / 255.0, blue: 250.0 / 255.0)
    static let background = Color(red: 18.0 / 255.0, green: 31.0 / 255.0, blue: 52.0 / 255.0)
    static let card = Color(red: 27.0 / 255.0, green: 43.0 / 255.0, blue: 69.0 / 255.0)
    static let border = Color(red: 48.0 / 255.0, green: 70.0 / 255.0, blue: 106.0 / 255.0)
    static let textPrimary = Color(red: 212.0 / 255.0, green: 220.0 / 255.0, blue: 232.0 / 255.0)
    static let textSecondary = Color(red: 158.0 / 255.0, green: 178.0 / 255.0, blue: 202.0 / 255.0)
    static let textTertiary = Color(red: 112.0 / 255.0, green: 132.0 / 255.0, blue: 160.0 / 255.0)
    static let danger = Color(red: 244.0 / 255.0, green: 91.0 / 255.0, blue: 105.0 / 255.0)
    static let dangerBackground = danger.opacity(0.16)
    static let warning = Color.orange
    static let warningBackground = Color(red: 42.0 / 255.0, green: 21.0 / 255.0, blue: 32.0 / 255.0)
    static let success = Color.green
    static let successBackground = success.opacity(0.16)
    static let modalSurface = Color(red: 10.0 / 255.0, green: 16.0 / 255.0, blue: 28.0 / 255.0)
    static let modalBorder = border.opacity(0.7)
    static let modalHighlight = Color(red: 226.0 / 255.0, green: 165.0 / 255.0, blue: 47.0 / 255.0)

    static let cornerRadius: CGFloat = 18
}

struct OVMCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: OVMTheme.cornerRadius, style: .continuous)
                    .fill(OVMTheme.card.opacity(0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: OVMTheme.cornerRadius, style: .continuous)
                    .stroke(OVMTheme.border.opacity(0.9), lineWidth: 1)
            )
    }
}

extension View {
    func ovmCardStyle() -> some View {
        modifier(OVMCardModifier())
    }
}
