//
//  SupportView.swift
//  SubPilot
//

import SwiftUI
import StoreKit
import UIKit

/// Help & Support hub, pushed from Settings. Contact is email-based — it routes
/// to the same inbox we triage from — with app/device diagnostics pre-filled so
/// reports are actionable. Also surfaces a short FAQ and an in-app rate prompt.
/// No live chat: email is the support channel.
struct SupportView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview

    @State private var expandedQuestion: String?

    var body: some View {
        List {
            Section {
                Button {
                    if let url = SupportContact.mailtoURL() { openURL(url) }
                } label: {
                    Label("Email support", systemImage: "envelope.fill")
                }
                Button {
                    requestReview()
                } label: {
                    Label("Rate SubPilot", systemImage: "star.fill")
                }
            } header: {
                Text("Get in touch")
            } footer: {
                Text("Found a bug, stuck on something, or want a service added to the catalogue? Email us — your app version and device are attached automatically so we can help faster.")
            }

            Section("Frequently asked") {
                ForEach(SupportFAQ.items) { item in
                    DisclosureGroup(
                        item.question,
                        isExpanded: Binding(
                            get: { expandedQuestion == item.id },
                            set: { expandedQuestion = $0 ? item.id : nil }
                        )
                    ) {
                        Text(item.answer)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, Spacing.xs)
                    }
                }
            }

            Section {
                LabeledContent("Version", value: AppInfo.versionString)
            } footer: {
                Text("Your subscriptions stay on your device and sync privately across your own devices via iCloud. Nothing is shared with us unless you email it.")
            }
        }
        .navigationTitle("Support")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Contact

/// Builds the support mailto link with diagnostics appended below the cursor, so
/// the user types their message at the top and we still receive version/device.
enum SupportContact {
    static let address = "sambulosendas@gmail.com"

    static func mailtoURL() -> URL? {
        let device = UIDevice.current
        let body = """


        —
        SubPilot \(AppInfo.versionString)
        iOS \(device.systemVersion) · \(device.model)
        """
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        components.queryItems = [
            URLQueryItem(name: "subject", value: "SubPilot support"),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url
    }
}

// MARK: - App info

enum AppInfo {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
    static var versionString: String { "\(version) (\(build))" }
}

// MARK: - FAQ

struct SupportFAQItem: Identifiable {
    let question: String
    let answer: String
    var id: String { question }
}

/// Answers describe only what the app actually does today (reminders, on-device
/// storage + iCloud sync, catalogue/scan add, multi-currency totals).
enum SupportFAQ {
    static let items: [SupportFAQItem] = [
        SupportFAQItem(
            question: "How do renewal reminders work?",
            answer: "SubPilot schedules a local notification at 9 AM, a set number of days before each renewal or free-trial conversion. Set the default timing in Settings → Reminders, or override it per subscription when editing one."
        ),
        SupportFAQItem(
            question: "Where is my data stored?",
            answer: "On your device. If you're signed into iCloud it also syncs and backs up privately across your own devices — there's no account and nothing is sent to us."
        ),
        SupportFAQItem(
            question: "What's the fastest way to add a subscription?",
            answer: "Tap + on Home and pick from the catalogue of popular services, or scan a receipt — SubPilot reads it on your device and fills in the details for you."
        ),
        SupportFAQItem(
            question: "Can I track services billed in other currencies?",
            answer: "Yes. Each subscription keeps its own currency, and your monthly and yearly totals convert to your preferred currency using daily exchange rates. Choose your preferred currency in Settings."
        ),
        SupportFAQItem(
            question: "My reminder didn't show up — why?",
            answer: "Check that reminders are enabled in Settings → Reminders, and that notifications are allowed for SubPilot in iOS Settings. Reminders only fire for future renewals."
        ),
    ]
}

#Preview {
    NavigationStack { SupportView() }
}
