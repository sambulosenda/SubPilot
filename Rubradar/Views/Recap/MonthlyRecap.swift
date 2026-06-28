//
//  MonthlyRecap.swift
//  Rubradar
//

import SwiftUI
import UIKit

/// Snapshot of a month's spend for the shareable recap card. Pure value type so
/// the card renders deterministically (and stays unit-testable).
struct MonthlyRecapData {
    let monthTitle: String
    let activeCount: Int
    let breakdown: SpendBreakdown

    var formattedMonthly: String { breakdown.formattedTotal }
    var formattedYearly: String {
        (breakdown.monthlyTotal * 12).formatted(.currency(code: breakdown.preferredCurrency))
    }
    /// The three biggest spend categories, for the "where it goes" panel.
    var topCategories: [CategorySpend] { Array(breakdown.categories.prefix(3)) }
    var hasSpend: Bool { breakdown.monthlyTotal > 0 && !breakdown.categories.isEmpty }

    static func make(
        from subscriptions: [Subscription],
        preferred: String,
        rates: ExchangeRates,
        now: Date = Date()
    ) -> MonthlyRecapData {
        MonthlyRecapData(
            monthTitle: now.formatted(.dateTime.month(.wide).year()),
            activeCount: subscriptions.filter { !$0.isCancelled }.count,
            breakdown: SpendBreakdown.make(from: subscriptions, preferred: preferred, rates: rates)
        )
    }
}

/// A purpose-built, on-brand "month in review" card sized for sharing (9:16).
/// Self-contained — no environment dependencies — so `ImageRenderer` reproduces
/// it exactly off-screen.
struct MonthlyRecapCard: View {
    let data: MonthlyRecapData

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: Spacing.lg)
            hero
            Spacer(minLength: Spacing.lg)
            categories
            Spacer(minLength: Spacing.lg)
            footer
        }
        .padding(28)
        .frame(width: 360, height: 640)
        .background(
            LinearGradient(
                colors: [.brand, .brandDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .foregroundStyle(.white)
    }

    private var header: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "chart.pie.fill")
                .font(.title3.weight(.bold))
            Text("Recurra")
                .font(.title3.weight(.bold))
            Spacer()
            Text(data.monthTitle.uppercased())
                .font(.caption.weight(.semibold))
                .opacity(0.85)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("I'm spending")
                .font(.title3.weight(.medium))
                .opacity(0.85)
            Text(data.formattedMonthly)
                .font(.system(size: 60, weight: .heavy, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("a month across \(data.activeCount) \(data.activeCount == 1 ? "subscription" : "subscriptions")")
                .font(.title3.weight(.medium))
                .opacity(0.85)
        }
    }

    private var categories: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Where it goes")
                .font(.headline)
                .opacity(0.9)
            ForEach(data.topCategories) { slice in
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(slice.category.tint)
                        .frame(width: 10, height: 10)
                    Text(slice.category.label)
                        .font(.subheadline.weight(.medium))
                    Spacer(minLength: Spacing.sm)
                    Text(data.breakdown.format(slice.monthlyAmount))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.12), in: .rect(cornerRadius: Radius.card))
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("≈ \(data.formattedYearly) a year")
                .font(.headline)
            Text("Tracked privately with Recurra")
                .font(.caption)
                .opacity(0.8)
        }
    }
}

/// Sheet that previews the recap card and shares it as an image. Renders the
/// card off-screen with `ImageRenderer` on appear, then offers a `ShareLink`.
struct RecapShareView: View {
    let data: MonthlyRecapData

    @Environment(\.dismiss) private var dismiss
    @State private var shareURL: URL?
    @State private var previewImage: Image?

    var body: some View {
        NavigationStack {
            ScrollView {
                MonthlyRecapCard(data: data)
                    .clipShape(.rect(cornerRadius: 28))
                    .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
                    .padding(.vertical, Spacing.lg)
            }
            .frame(maxWidth: .infinity)
            .background(Color.appBackground)
            .navigationTitle("Monthly recap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) { shareBar }
            .onAppear(perform: renderCard)
        }
    }

    @ViewBuilder
    private var shareBar: some View {
        VStack {
            if let shareURL {
                ShareLink(
                    item: shareURL,
                    preview: SharePreview(
                        "My Recurra month",
                        image: previewImage ?? Image(systemName: "chart.pie.fill")
                    )
                ) {
                    Label("Share recap", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.extraLarge)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
            }
        }
        .padding()
        .background(.bar)
    }

    /// Renders the card to a PNG in the temp directory for sharing.
    @MainActor
    private func renderCard() {
        let renderer = ImageRenderer(content: MonthlyRecapCard(data: data))
        renderer.scale = 3
        guard let uiImage = renderer.uiImage, let png = uiImage.pngData() else { return }
        previewImage = Image(uiImage: uiImage)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("recurra-recap.png")
        try? png.write(to: url)
        shareURL = url
    }
}

#Preview {
    let breakdown = SpendBreakdown(
        preferredCurrency: "GBP",
        monthlyTotal: 47.98,
        categories: [
            CategorySpend(category: .streaming, monthlyAmount: 25.99, fraction: 0.54),
            CategorySpend(category: .music, monthlyAmount: 12.99, fraction: 0.27),
            CategorySpend(category: .software, monthlyAmount: 9.00, fraction: 0.19)
        ],
        hasUnconvertible: false
    )
    return MonthlyRecapCard(
        data: MonthlyRecapData(monthTitle: "June 2026", activeCount: 6, breakdown: breakdown)
    )
}
