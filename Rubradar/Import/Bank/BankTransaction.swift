//
//  BankTransaction.swift
//  Rubradar
//

import Foundation

/// A single charge parsed from an imported bank / card statement.
///
/// `amount` is always the positive magnitude of a debit (money out) — credits
/// (money in) are dropped during parsing, since only outgoing charges can be a
/// subscription. Currency is often absent in bank CSVs, so it's optional and
/// resolved to the user's preferred currency downstream.
struct BankTransaction: Equatable {
    var date: Date
    var description: String
    var amount: Decimal
    var currencyCode: String?
}
