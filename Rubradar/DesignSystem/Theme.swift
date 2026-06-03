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
}
