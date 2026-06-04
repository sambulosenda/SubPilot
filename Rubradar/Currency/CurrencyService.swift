//
//  CurrencyService.swift
//  Rubradar
//

import Foundation
import Observation

/// Loads and caches daily FX rates (Frankfurter API, base GBP) with a bundled
/// offline fallback. Conversions pivot through the base currency.
@MainActor
@Observable
final class CurrencyService {
    static let shared = CurrencyService()

    private(set) var rates: ExchangeRates
    private(set) var isRefreshing = false

    private let defaultsKey = "cachedExchangeRates"
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let cached = try? JSONDecoder().decode(ExchangeRates.self, from: data) {
            rates = cached
        } else {
            rates = .fallback
        }
    }

    /// True if the cached rates are from a previous day (or are the fallback).
    var isStale: Bool {
        !Calendar.current.isDateInToday(rates.date)
    }

    var lastUpdated: Date { rates.date }

    /// Fetches today's rates if stale. Silently keeps the cache on failure.
    func refreshIfNeeded() async {
        guard isStale else { return }
        await refresh()
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        guard let url = URL(string: "https://api.frankfurter.app/latest?from=\(rates.base)") else { return }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            let decoded = try JSONDecoder().decode(FrankfurterResponse.self, from: data)
            let fresh = decoded.asExchangeRates()
            // Skip the write when nothing changed (e.g. a same-day manual refresh)
            // so currency readers aren't invalidated, and the cache isn't rewritten.
            guard fresh != rates else { return }
            rates = fresh
            if let encoded = try? JSONEncoder().encode(fresh) {
                UserDefaults.standard.set(encoded, forKey: defaultsKey)
            }
        } catch {
            // Keep existing cache / fallback on any failure.
        }
    }

    func convert(_ amount: Decimal, from: String, to: String) -> Decimal? {
        rates.convert(amount, from: from, to: to)
    }
}

// MARK: - Frankfurter response

private struct FrankfurterResponse: Decodable {
    let base: String
    let date: String
    let rates: [String: Double]

    func asExchangeRates() -> ExchangeRates {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let parsed = formatter.date(from: date) ?? Date()
        let decimalRates = rates.mapValues { Decimal($0) }
        return ExchangeRates(base: base, date: parsed, rates: decimalRates)
    }
}
