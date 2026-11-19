//
//  AdaptiveRow.swift
//  Rubradar
//

import SwiftUI

/// A list row's logo, title column and value column: side by side normally,
/// stacked top to bottom at accessibility text sizes. Side by side, the
/// fixed-width value column takes the whole row at those sizes and the title
/// is crushed to a letter per line.
struct RowStack<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ViewBuilder var content: Content

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.sm))
            : AnyLayout(HStackLayout(spacing: Spacing.md))
        layout { content }
    }
}

private struct RowTitleLines: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            content.lineLimit(3)
        } else {
            content.lineLimit(1).minimumScaleFactor(0.8)
        }
    }
}

private struct RowValueSizing: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            content.lineLimit(nil)
        } else {
            content.lineLimit(1).fixedSize(horizontal: true, vertical: false)
        }
    }
}

extension View {
    /// A row's name: one line that shrinks slightly before truncating — or,
    /// at accessibility text sizes, up to three lines at full size.
    func rowTitle() -> some View { modifier(RowTitleLines()) }

    /// A row's price/date: never truncated or wrapped, so the title gives way
    /// instead — until accessibility text sizes, where it wraps like any text.
    func rowValue() -> some View { modifier(RowValueSizing()) }
}
