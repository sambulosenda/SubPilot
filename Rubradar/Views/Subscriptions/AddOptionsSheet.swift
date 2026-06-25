//
//  AddOptionsSheet.swift
//  Rubradar
//

import SwiftUI

/// The "Add a Subscription" chooser, presented as a fitted bottom sheet from the
/// dashboard CTA and the Home toolbar `+`. Replaces a cramped `Menu` dropdown:
/// each flow gets a full-width row with an icon and a one-line description so the
/// four ways to add (manual, catalogue, scan, import) read distinctly.
///
/// Owns no presentation state — selecting a row reports the chosen `AddSheet` to
/// the host, which dismisses this sheet and presents the real flow on dismissal
/// (sequencing avoids presenting a sheet from a sheet mid-dismiss).
struct AddOptionsSheet: View {
    var onSelect: (AddSheet) -> Void

    private struct Option: Identifiable {
        let flow: AddSheet
        let title: LocalizedStringKey
        let subtitle: LocalizedStringKey
        let symbol: String
        var id: String { flow.id }
    }

    private let options: [Option] = [
        Option(flow: .catalogue, title: "Browse catalogue",
                subtitle: "Pick from popular services", symbol: "magnifyingglass"),
        Option(flow: .scan, title: "Scan a receipt",
                subtitle: "Snap a photo, we'll read it", symbol: "doc.viewfinder"),
        Option(flow: .bankImport, title: "Import bank statement",
                subtitle: "Find subscriptions in your transactions", symbol: "doc.badge.arrow.up"),
        Option(flow: .manual, title: "Add manually",
                subtitle: "Enter the details yourself", symbol: "square.and.pencil"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Add a subscription")
                    .font(.title2.bold())
                    .padding(.top, Spacing.md)

                VStack(spacing: Spacing.sm) {
                    ForEach(options) { option in
                        Button { onSelect(option.flow) } label: {
                            row(option)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.lg)
        }
        .presentationDetents([.height(400)])
        .presentationDragIndicator(.visible)
        .presentationBackground(.thinMaterial)
    }

    private func row(_ option: Option) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: option.symbol)
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
                .frame(width: 44, height: 44)
                .background(.tint.opacity(0.12), in: .rect(cornerRadius: Radius.card * 0.75))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(option.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(option.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: Spacing.sm)

            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(Spacing.md)
        .background(Color.cardBackground, in: .rect(cornerRadius: Radius.card))
        .contentShape(.rect(cornerRadius: Radius.card))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            AddOptionsSheet(onSelect: { _ in })
        }
}
