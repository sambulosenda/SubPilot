//
//  Theme.swift
//  Rubradar
//

import SwiftUI

/// Spacing scale used across the app.
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

/// Corner radii.
enum Radius {
    static let chip: CGFloat = 10
    static let card: CGFloat = 16
}

extension Color {
    static let appBackground = Color(.systemGroupedBackground)
    static let cardBackground = Color(.secondarySystemGroupedBackground)

    /// Brand teal and a deeper shade for gradients (e.g. the shareable recap
    /// card). Falls back to the asset accent if the hex ever fails to parse.
    static let brand = Color(hex: "0D9488") ?? .accentColor
    static let brandDeep = Color(hex: "0B6E66") ?? .accentColor

    /// The "act now" colour for text. System orange is ~2.2:1 on a white
    /// card — unreadable at caption size — so light mode uses a burnt orange
    /// (~5:1). Dark mode keeps system orange, which is fine on dark cards.
    /// Fills, rings and large icons can stay plain `.orange`.
    static let attention = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? .systemOrange
            : UIColor(red: 0.76, green: 0.25, blue: 0.05, alpha: 1)
    })
}
