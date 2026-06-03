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

struct SubscriptionListView: View {
    /// Requests the parent shell to present an add flow.
    var presentAdd: (AddSheet) -> Void

    @Query private var subscriptions: [Subscription]
    @Environment(CurrencyService.self) private var currency
    @AppStorage("preferredCurrencyCode") private var preferredCurrency =
        Locale.current.currency?.identifier ?? "GBP"
    @State private var sortOption: SortOption = .nextRenewal
    @State private var searchText = ""

    private var summary: SpendSummary {
        SpendSummary.make(from: subscriptions, preferred: preferredCurrency, rates: currency.rates)
    }

    private var visibleSubscriptions: [Subscription] {
        let filtered = subscriptions.filter { sub in
            searchText.isEmpty
                || sub.name.localizedCaseInsensitiveContains(searchText)
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

    var body: some View {
        NavigationStack {
            Group {
                if subscriptions.isEmpty {
                    SubscriptionsEmptyState(
                        onBrowseCatalogue: { presentAdd(.catalogue) },
                        onAddManually: { presentAdd(.manual) }
                    )
                } else {
                    list
                }
            }
            .navigationTitle("Subscriptions")
            .toolbar { toolbarContent }
        }
    }

    private var list: some View {
        List {
            if searchText.isEmpty {
                Section {
                    SpendSummaryCard(summary: summary, isStale: currency.isStale)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }
            ForEach(visibleSubscriptions) { sub in
                NavigationLink(value: sub) {
                    SubscriptionRow(subscription: sub)
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
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button { presentAdd(.catalogue) } label: {
                    Label("Browse catalogue", systemImage: "magnifyingglass")
                }
                Button { presentAdd(.manual) } label: {
                    Label("Add manually", systemImage: "square.and.pencil")
                }
            } label: {
                Label("Add", systemImage: "plus")
            }
        }
    }
}

#Preview {
    SubscriptionListView(presentAdd: { _ in })
        .modelContainer(.preview)
        .environment(CurrencyService.shared)
}
