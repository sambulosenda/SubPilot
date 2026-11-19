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
        case .nextRenewal: String(localized: "Next renewal")
        case .name: String(localized: "Name")
        case .amount: String(localized: "Amount")
        case .category: String(localized: "Category")
        }
    }
    var symbol: String {
        switch self {
        case .nextRenewal: "calendar"
        case .name: "textformat"
        case .amount: "banknote"   // currency-neutral, unlike sterlingsign
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
    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.openURL) private var openURL
    @AppStorage("preferredCurrencyCode") private var preferredCurrency =
        Locale.current.currency?.identifier ?? "GBP"
    /// Selected profile's UUID string; empty means "All Profiles".
    @AppStorage("selectedProfileID") private var selectedProfileID = ""
    /// Persisted — resetting to "next renewal" every launch reads as a bug to
    /// users who sort by amount.
    @AppStorage("subscriptionSortOption") private var sortOption: SortOption = .nextRenewal
    @State private var searchText = ""
    @State private var showManageProfiles = false
    @State private var showAssistant = false
    @State private var showCutList = false
    /// `dismissToken`s of attention items the user chose to keep
    /// (comma-joined), so they stop asking for a decision.
    @AppStorage("keptAttentionTokens") private var keptAttentionRaw = ""
    /// `UsageCheckIn.monthKey` of the month the check-in was last done (or
    /// skipped) in.
    @AppStorage("lastUsageCheckInMonth") private var lastUsageCheckInMonth = ""
    @State private var showUsageCheckIn = false
    @State private var path: [Subscription] = []
    /// Shared namespace so a tapped row zooms into its detail screen and back.
    @Namespace private var detailTransition
    /// Drives the "Add a Subscription" chooser bottom sheet (toolbar `+`).
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

    private var keptAttentionTokens: Set<String> {
        Set(keptAttentionRaw.split(separator: ",").map(String.init))
    }

    private func keep(_ token: String) {
        // Carry over only tokens that could still be flagged, so this never
        // grows past the handful of items inside their windows.
        let live = Set(AttentionRadar.items(in: subscriptions).compactMap(\.dismissToken))
        let kept = keptAttentionTokens.intersection(live).union([token])
        withAnimation {
            keptAttentionRaw = kept.sorted().joined(separator: ",")
        }
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
        return sorted(filtered)
    }

    private func sorted(_ subs: [Subscription]) -> [Subscription] {
        switch sortOption {
        case .nextRenewal:
            // Decorate-sort-undecorate: projecting the next renewal walks the
            // calendar, so compute it once per row — not once per comparison
            // on every body evaluation (this re-sorts on each search keystroke).
            return subs.map { (sub: $0, next: $0.projectedNextRenewal()) }
                .sorted { $0.next < $1.next }
                .map(\.sub)
        case .name:
            return subs.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .amount:
            return subs.sorted { $0.monthlyEquivalent > $1.monthlyEquivalent }
        case .category:
            return subs.sorted { $0.category.label.localizedCaseInsensitiveCompare($1.category.label) == .orderedAscending }
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
                    .background(alignment: .top) { HomeAmbience() }
                } else {
                    list
                }
            }
            .navigationTitle("")
            // No large title: the "Up next" / empty-state headline owns the screen,
            // so we keep the bar inline rather than stranding a title above the content.
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showUsageCheckIn) {
                let candidates = sorted(UsageCheckIn.candidates(in: profileSubscriptions))
                UsageCheckInView(subscriptions: candidates,
                                 month: UsageCheckIn.reviewedMonth()) { unused in
                    if let unused {
                        UsageCheckIn.record(unused: unused, among: candidates)
                    }
                    withAnimation { lastUsageCheckInMonth = UsageCheckIn.monthKey(for: Date()) }
                }
            }
            .sheet(isPresented: $showAssistant) {
                AssistantView(showsClose: true)
            }
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
            // `-StartTab assistant` predates the assistant leaving the tab bar;
            // keep it working for the screenshot scripts.
            .task {
                let args = ProcessInfo.processInfo.arguments
                if let i = args.firstIndex(of: "-StartTab"), i + 1 < args.count, args[i + 1] == "assistant" {
                    showAssistant = true
                }
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
                    DashboardHeader(metrics: metrics,
                                    onOpenCalendar: onViewAllRenewals,
                                    onOpenCut: { showCutList = true })
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                if UsageCheckIn.isDue(lastDoneMonthKey: lastUsageCheckInMonth,
                                      subscriptions: profileSubscriptions) {
                    Section {
                        Button { showUsageCheckIn = true } label: {
                            UsageCheckInRow(month: UsageCheckIn.reviewedMonth())
                        }
                        .buttonStyle(.plain)
                    }
                }

                let attention = AttentionRadar.items(in: profileSubscriptions,
                                                     dismissed: keptAttentionTokens)
                if !attention.isEmpty {
                    AttentionSection(items: attention, onKeep: keep)
                }
            }

            if !visible.isEmpty {
                Section {
                    ForEach(visible) { sub in
                        NavigationLink(value: sub) {
                            SubscriptionRow(subscription: sub)
                        }
                        .matchedTransitionSource(id: sub.id, in: detailTransition)
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
            SubscriptionDetailView(subscription: sub,
                                   transitionID: sub.id,
                                   transitionNamespace: detailTransition)
        }
        .navigationDestination(isPresented: $showCutList) {
            CutListView(subscriptions: sorted(profileSubscriptions.filter(\.isCancelled)),
                        summary: metrics.cut)
        }
        // A soft brand glow behind the total, the same light the onboarding
        // and paywall sit in, so Home doesn't drop to a flat black after them.
        .scrollContentBackground(.hidden)
        .background(alignment: .top) { HomeAmbience() }
        .background(Color.appBackground.ignoresSafeArea())
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
            // Named for where it goes. It was "View all", which promised the
            // full list and opened the Calendar tab.
            Button("Calendar") { onViewAllRenewals() }
                .font(.subheadline.weight(.semibold))
                .textCase(nil)
                // The text is ~18pt tall; pad the tappable area out to 44
                // without letting it push the header's layout.
                .padding(.vertical, 13)
                .padding(.leading, Spacing.md)
                .contentShape(.rect)
                .padding(.vertical, -13)
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
        // Trailing edge stays a two-pill capsule: a secondary overflow (Assistant
        // + Sort) and the primary Add. Folding both into one ⋯ menu
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

    /// The assistant is Pro-only. A free user goes straight to the paywall:
    /// it is presented by the app shell, which can't show a sheet over one
    /// already up from here, so the locked screen's own "Unlock" would do
    /// nothing inside our sheet.
    private func openAssistant() {
        if purchases.isPro {
            showAssistant = true
        } else {
            purchases.paywallContext = .assistant
        }
    }

    /// Secondary, list-only actions: the Assistant (a sheet) and Sort (a rarely
    /// changed preference) live here rather than as standalone toolbar buttons.
    private var overflowMenu: some View {
        Menu {
            Button("Assistant", systemImage: "sparkles") { openAssistant() }
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

/// Ambient backdrop for Home: a teal glow falling from the top-leading corner,
/// where the monthly total sits. Decoration only, and fixed, so the list
/// scrolls over it.
private struct HomeAmbience: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        RadialGradient(
            colors: [.brand.opacity(colorScheme == .dark ? 0.30 : 0.14), .brand.opacity(0)],
            center: UnitPoint(x: 0.15, y: 0),
            startRadius: 0,
            endRadius: 420
        )
        .frame(height: 460)
        .frame(maxWidth: .infinity)
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview {
    SubscriptionListView(presentAdd: { _ in })
        .modelContainer(.preview)
        .environment(CurrencyService())
}
