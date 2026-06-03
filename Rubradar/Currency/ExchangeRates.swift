//
//  ExchangeRates.swift
//  Rubradar
//

import Foundation

/// A set of FX rates expressed as units of each currency per 1 unit of `base`.
/// All app conversions pivot through the base currency (GBP).
struct ExchangeRates: Codable, Equatable {
    let base: String
    var date: Date
    var rates: [String: Decimal]

    /// Converts an amount between two currencies via the base pivot.
    /// Returns nil if either currency is unknown.
    func convert(_ amount: Decimal, from: String, to: String) -> Decimal? {
        guard amount != 0 else { return 0 }
        guard let fromRate = rate(for: from), let toRate = rate(for: to), fromRate != 0 else { return nil }
        let inBase = amount / fromRate
        return inBase * toRate
    }

    func rate(for code: String) -> Decimal? {
        if code == base { return 1 }
        return rates[code]
    }

    /// Currencies we can convert to/from (base included), sorted.
    var supportedCodes: [String] {
        ([base] + rates.keys).sorted()
    }
}

extension ExchangeRates {
    /// Offline fallback, base GBP. Approximate, bundled so the app always works
    /// without a network. Refreshed daily from the FX API when online.
    static let fallback = ExchangeRates(
        base: "GBP",
        date: Date(timeIntervalSince1970: 0),
        rates: [
            "USD": 1.27, "EUR": 1.17, "CAD": 1.72, "AUD": 1.92, "JPY": 190.0,
            "CHF": 1.12, "INR": 106.0, "CNY": 9.15, "BRL": 6.30, "ZAR": 23.5,
            "SEK": 13.3, "NOK": 13.6, "DKK": 8.72, "PLN": 5.05, "NZD": 2.08,
            "SGD": 1.71, "HKD": 9.90, "MXN": 22.0, "AED": 4.66, "TRY": 41.0
        ]
    )
}
