//
//  MonthlyRecap.swift
//  Rubradar
//

import SwiftUI
import UIKit

/// A recent price movement flattened for the recap card. Pure value type so the
/// card stays deterministic and unit-testable without SwiftData.
struct RecapPriceChange: Identifiable, Equatable {
    let id: UUID
    let name: String
    /// "£10.99 → £12.99"
    let transition: String
    let isRise: Bool
}

/// Snapshot of a month's spend for the shareable recap card. Pure value type so
/// the card renders deterministically (and stays unit-testable).
struct MonthlyRecapData {
    /// How far back the "price changes" panel looks. ~One recap period.
    static let priceChangeWindowDays = 30

    let monthTitle: String
    let activeCount: Int
    let breakdown: SpendBreakdown
    /// Price movements recorded in the last `priceChangeWindowDays`, newest first.
    var priceChanges: [RecapPriceChange] = []

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
            breakdown: SpendBreakdown.make(from: subscriptions, preferred: preferred, rates: rates),
            priceChanges: recentPriceChanges(in: subscriptions, now: now)
        )
    }

    /// Price changes recorded within the window on non-cancelled subscriptions,
    /// newest first.
    static func recentPriceChanges(in subscriptions: [Subscription], now: Date = Date()) -> [RecapPriceChange] {
        let cutoff = now.addingTimeInterval(-Double(priceChangeWindowDays) * 86_400)
        return subscriptions
            .filter { !$0.isCancelled }
            .flatMap { sub in
                sub.priceHistory
                    .filter { $0.changedAt >= cutoff && $0.changedAt <= now }
                    .map { (date: $0.changedAt,
                            change: RecapPriceChange(id: $0.id, name: sub.name,
                                                     transition: $0.transitionLabel,
                                                     isRise: $0.newAmount > $0.oldAmount)) }
            }
            .sorted { $0.date > $1.date }
            .map(\.change)
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
            if !data.priceChanges.isEmpty {
                Spacer(minLength: Spacing.md)
                priceChangesPanel
            }
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
            Text("SubHelm")
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
            Text("a month across ^[\(data.activeCount) subscription](inflect: true)")
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

    /// Recent price movements, capped at two rows so the fixed-size card never
    /// overflows; anything beyond folds into a "+N more" line.
    private var priceChangesPanel: some View {
        let shown = Array(data.priceChanges.prefix(2))
        let overflow = data.priceChanges.count - shown.count
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Price changes")
                .font(.headline)
                .opacity(0.9)
            ForEach(shown) { change in
                HStack(spacing: Spacing.sm) {
                    Image(systemName: change.isRise ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption.weight(.bold))
                        .opacity(0.9)
                    Text(change.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Spacer(minLength: Spacing.sm)
                    Text(change.transition)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
            if overflow > 0 {
                Text("+ ^[\(overflow) more change](inflect: true)")
                    .font(.caption)
                    .opacity(0.8)
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
            Text("Tracked privately with SubHelm")
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
                        "My SubHelm month",
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
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("subhelm-recap.png")
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
