//
//  SubscriptionListView.swift
//  Rubradar
//

import SwiftUI
import SwiftData

enum SortOption: String, CaseIterable, Identifiable {
    case nextRenewal, name, amount, category
    var id: String { rawValue }
    var label: String {
        switch self {
        case .nextRenewal: "Next renewal"
        case .name: "Name"
        case .amount: "Amount"
        case .category: "Category"
        }
    }
    var symbol: String {
        switch self {
        case .nextRenewal: "calendar"
        case .name: "textformat"
        case .amount: "sterlingsign"
        case .category: "square.grid.2x2"
        }
    }
}

/// The Home screen: a spend dashboard above the list of tracked subscriptions.
struct SubscriptionListView: View {
    /// Requests the parent shell to present an add flow.
    var presentAdd: (AddSheet) -> Void
    /// Asks the shell to switch to the Calendar tab ("View all").
    var onViewAllRenewals: () -> Void = {}

    @Query private var subscriptions: [Subscription]
    @Environment(CurrencyService.self) private var currency
    @AppStorage("preferredCurrencyCode") private var preferredCurrency =
        Locale.current.currency?.identifier ?? "GBP"
    @State private var sortOption: SortOption = .nextRenewal
    @State private var searchText = ""

    private var metrics: HomeMetrics {
        HomeMetrics.make(from: subscriptions, preferred: preferredCurrency, rates: currency.rates)
    }

    private var visibleSubscriptions: [Subscription] {
        let filtered = subscriptions.filter { sub in
            if searchText.isEmpty {
                return !sub.isCancelled // Home lists active subscriptions only.
            }
            // Search spans everything, so cancelled subs stay reachable to reopen.
            return sub.name.localizedCaseInsensitiveContains(searchText)
                || sub.category.label.localizedCaseInsensitiveContains(searchText)
        }
        return filtered.sorted(by: sortComparator)
    }

    private func sortComparator(_ a: Subscription, _ b: Subscription) -> Bool {
        switch sortOption {
        case .nextRenewal: a.nextRenewalDate < b.nextRenewalDate
        case .name: a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        case .amount: a.monthlyEquivalent > b.monthlyEquivalent
        case .category: a.category.label.localizedCaseInsensitiveCompare(b.category.label) == .orderedAscending
        }
    }

    /// "Up next" only reads true when the default next-renewal order is in effect.
    private var listSectionTitle: String {
        sortOption == .nextRenewal && searchText.isEmpty ? "Up next" : "Your subscriptions"
    }

    var body: some View {
        NavigationStack {
            Group {
                if subscriptions.isEmpty {
                    SubscriptionsEmptyState(
                        onScan: { presentAdd(.scan) },
                        onBrowseCatalogue: { presentAdd(.catalogue) },
                        onAddManually: { presentAdd(.manual) }
                    )
                } else {
                    list
                }
            }
            .navigationTitle("Home")
            .toolbar { toolbarContent }
        }
    }

    private var list: some View {
        List {
            if searchText.isEmpty {
                Section {
                    DashboardHeader(metrics: metrics, presentAdd: presentAdd)
                        .listRowInsets(EdgeInsets(top: 0, leading: Spacing.md, bottom: 0, trailing: Spacing.md))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }

            if !visibleSubscriptions.isEmpty {
                Section {
                    ForEach(visibleSubscriptions) { sub in
                        NavigationLink(value: sub) {
                            SubscriptionRow(subscription: sub)
                        }
                    }
                } header: {
                    sectionHeader
                }
            }
        }
        .navigationDestination(for: Subscription.self) { sub in
            SubscriptionDetailView(subscription: sub)
        }
        .searchable(text: $searchText, prompt: "Search subscriptions")
        .tabBarMinimizeBehavior(.onScrollDown)
        .overlay {
            if !searchText.isEmpty && visibleSubscriptions.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }

    private var sectionHeader: some View {
        HStack {
            Text(listSectionTitle)
            Spacer()
            Button("View all") { onViewAllRenewals() }
                .font(.subheadline.weight(.semibold))
                .textCase(nil)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Sort by", selection: $sortOption) {
                    ForEach(SortOption.allCases) { option in
                        Label(option.label, systemImage: option.symbol).tag(option)
                    }
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
        }
    }
}

#Preview {
    SubscriptionListView(presentAdd: { _ in })
        .modelContainer(.preview)
        .environment(CurrencyService.shared)
}
