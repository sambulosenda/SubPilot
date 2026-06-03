//
//  RubradarApp.swift
//  Rubradar
//
//  Created by Sambulo Senda on 03/06/2026.
//

import SwiftUI
import SwiftData

@main
struct RubradarApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(CurrencyService.shared)
        }
        .modelContainer(.app)
    }
}
