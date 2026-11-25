//
//  Instrument.swift
//  BidAsk
//
//  Strongly typed instrument identifiers, metadata, and strict POSIX Decimal parsing.
//

import Foundation

/// Strongly typed canonical symbol identifier (e.g., "BTC-USDT" or "RELIANCE").
struct SymbolID: RawRepresentable, Hashable, Codable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(stringLiteral value: String) {
        self.rawValue = value
    }

    var description: String { rawValue }
}

enum AssetClass: String, Codable, Sendable {
    case crypto
    case indianEquity
}

/// Parses exchange JSON numeric strings directly into `Decimal` without passing through `Double`.
enum DecimalParsing {
    private static let posixLocale = Locale(identifier: "en_US_POSIX")

    static func parseWire(_ raw: String?) -> Decimal? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty,
              let value = Decimal(string: trimmed, locale: posixLocale),
              !value.isNaN else {
            return nil
        }
        return value
    }
}

/// Static trading metadata for a watchlist instrument.
struct Instrument: Identifiable, Hashable, Codable, Sendable {
    let id: SymbolID
    let displayTicker: String
    let name: String
    let assetClass: AssetClass
    let quoteCurrency: String
    let priceScale: Int
    let quantityScale: Int
    let tickSize: Decimal
    let lotSize: Decimal
}
