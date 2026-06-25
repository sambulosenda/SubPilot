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

    @Query(animation: .default) private var subscriptions: [Subscription]
    @Query(sort: \Profile.sortIndex, animation: .default) private var profiles: [Profile]
    @Environment(CurrencyService.self) private var currency
    @Environment(\.openURL) private var openURL
    @AppStorage("preferredCurrencyCode") private var preferredCurrency =
        Locale.current.currency?.identifier ?? "GBP"
    /// Selected profile's UUID string; empty means "All Profiles".
    @AppStorage("selectedProfileID") private var selectedProfileID = ""
    @State private var sortOption: SortOption = .nextRenewal
    @State private var searchText = ""
    @State private var showManageProfiles = false
    @State private var showInsights = false
    @State private var path: [Subscription] = []
    /// Drives the "Add a Subscription" chooser bottom sheet (CTA + toolbar `+`).
    @State private var showAddChooser = false
    /// Flow chosen in the chooser, presented once the chooser finishes dismissing
    /// so we never present a sheet from a sheet mid-dismiss.
    @State private var pendingAdd: AddSheet?

    /// Subscriptions in the selected profile ("" = All), before search/cancel
    /// filtering. Drives the dashboard totals so they scope to the profile.
    private var profileSubscriptions: [Subscription] {
        subscriptions.filter { $0.belongsToProfile(id: selectedProfileID) }
    }

    private var metrics: HomeMetrics {
        HomeMetrics.make(from: profileSubscriptions, preferred: preferredCurrency, rates: currency.rates)
    }

    private var visibleSubscriptions: [Subscription] {
        let filtered = profileSubscriptions.filter { sub in
            if searchText.isEmpty {
                return !sub.isCancelled // Home lists active subscriptions only.
            }
            // Search spans the profile, so cancelled subs stay reachable to reopen.
            return sub.name.localizedCaseInsensitiveContains(searchText)
                || sub.category.label.localizedCaseInsensitiveContains(searchText)
        }
        return filtered.sorted(by: sortComparator)
    }

    private func sortComparator(_ a: Subscription, _ b: Subscription) -> Bool {
        switch sortOption {
        case .nextRenewal: a.projectedNextRenewal() < b.projectedNextRenewal()
        case .name: a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        case .amount: a.monthlyEquivalent > b.monthlyEquivalent
        case .category: a.category.label.localizedCaseInsensitiveCompare(b.category.label) == .orderedAscending
        }
    }

    /// "Up next" only reads true when the default next-renewal order is in effect.
    private var listSectionTitle: LocalizedStringKey {
        sortOption == .nextRenewal && searchText.isEmpty ? "Up next" : "Your subscriptions"
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if subscriptions.isEmpty {
                    SubscriptionsEmptyState(
                        onScan: { presentAdd(.scan) },
                        onBrowseCatalogue: { presentAdd(.catalogue) },
                        onImportStatement: { presentAdd(.bankImport) },
                        onAddManually: { presentAdd(.manual) }
                    )
                } else {
                    list
                }
            }
            .navigationTitle("")
            // No large title: the "Up next" / empty-state headline owns the screen,
            // so we keep the bar inline rather than stranding a title above the content.
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showManageProfiles) {
                NavigationStack { ManageProfilesView() }
            }
            .sheet(isPresented: $showAddChooser, onDismiss: {
                if let pendingAdd {
                    self.pendingAdd = nil
                    presentAdd(pendingAdd)
                }
            }) {
                AddOptionsSheet { choice in
                    pendingAdd = choice
                    showAddChooser = false
                }
            }
            .onChange(of: profiles.map(\.id)) {
                // A deleted selected profile would otherwise filter to nothing.
                if !selectedProfileID.isEmpty,
                   !profiles.contains(where: { $0.id.uuidString == selectedProfileID }) {
                    selectedProfileID = ""
                }
            }
            #if DEBUG
            // `-StartRoute <name>` pushes the named subscription's detail screen
            // on launch so screenshots of pushed screens need no UI taps (pairs
            // with `-DemoSeed`/`-StartTab`).
            .task {
                let args = ProcessInfo.processInfo.arguments
                guard let i = args.firstIndex(of: "-StartRoute"), i + 1 < args.count,
                      let sub = subscriptions.first(where: {
                          $0.name.localizedCaseInsensitiveContains(args[i + 1])
                      }) else { return }
                path = [sub]
            }
            #endif
        }
    }

    private var list: some View {
        // Filter+sort once per body pass; reused by the rows and the empty overlay.
        let visible = visibleSubscriptions
        return List {
            if searchText.isEmpty {
                Section {
                    DashboardHeader(metrics: metrics, onAdd: { showAddChooser = true })
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }

            if !visible.isEmpty {
                Section {
                    ForEach(visible) { sub in
                        NavigationLink(value: sub) {
                            SubscriptionRow(subscription: sub)
                        }
                        .contextMenu {
                            if let url = sub.providerURL {
                                Button {
                                    openURL(url)
                                } label: {
                                    Label("Open \(sub.name)", systemImage: "arrow.up.forward.app")
                                }
                            }
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
        .navigationDestination(isPresented: $showInsights) {
            InsightsView()
        }
        .searchable(text: $searchText, prompt: "Search subscriptions")
        .searchToolbarBehavior(.minimize)
        .tabBarMinimizeBehavior(.onScrollDown)
        .overlay {
            if !searchText.isEmpty && visible.isEmpty {
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

    private var currentProfileName: String {
        guard !selectedProfileID.isEmpty,
              let profile = profiles.first(where: { $0.id.uuidString == selectedProfileID })
        else { return "All Profiles" }
        return profile.name
    }

    private var profileMenu: some View {
        Menu {
            Picker("Profile", selection: $selectedProfileID) {
                Label("All Profiles", systemImage: "square.stack.3d.up.fill").tag("")
                ForEach(profiles) { profile in
                    Label(profile.name, systemImage: profile.symbolName).tag(profile.id.uuidString)
                }
            }
            Divider()
            Button("Manage Profiles…", systemImage: "slider.horizontal.3") {
                showManageProfiles = true
            }
        } label: {
            HStack(spacing: Spacing.xs) {
                Text(currentProfileName).fontWeight(.semibold)
                Image(systemName: "chevron.down").font(.caption2.weight(.bold))
            }
        }
        .accessibilityLabel("Profile: \(currentProfileName)")
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Trailing edge stays a two-pill capsule: a secondary overflow (Insights
        // + Sort) and the primary Add. Folding Insights and Sort into one ⋯ menu
        // keeps the top from reading as a dense three-segment glass cluster.
        if !subscriptions.isEmpty {
            ToolbarItem(placement: .topBarLeading) { profileMenu }
            ToolbarItem(placement: .topBarTrailing) { overflowMenu }
        }
        ToolbarItem(placement: .topBarTrailing) { addMenu }
    }

    /// Primary action — one tap opens the add chooser (a bottom sheet).
    private var addMenu: some View {
        Button { showAddChooser = true } label: {
            Label("Add subscription", systemImage: "plus")
        }
    }

    /// Secondary, list-only actions: Insights (a push) and Sort (a rarely
    /// changed preference) live here rather than as standalone toolbar buttons.
    private var overflowMenu: some View {
        Menu {
            Button("Insights", systemImage: "chart.pie.fill") { showInsights = true }
            Divider()
            Picker("Sort by", selection: $sortOption) {
                ForEach(SortOption.allCases) { option in
                    Label(option.label, systemImage: option.symbol).tag(option)
                }
            }
        } label: {
            Label("More", systemImage: "ellipsis")
        }
    }
}

#Preview {
    SubscriptionListView(presentAdd: { _ in })
        .modelContainer(.preview)
        .environment(CurrencyService())
}
