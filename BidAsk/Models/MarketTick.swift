//
//  MarketTick.swift
//  BidAsk
//
//  Immutable Sendable ticker snapshot emitted off the main thread.
//

import Foundation

enum TickDirection: Sendable, Equatable {
    case up
    case down
    case neutral
}

/// Normalized ticker quote crossing from background feed actors into the pipeline and UI.
struct MarketTick: Sendable, Equatable {
    let symbol: SymbolID
    let lastPrice: Decimal
    let open24h: Decimal
    let bestBid: Decimal?
    let bestAsk: Decimal?
    let volume24hQuote: Decimal
    let exchangeTimestamp: Date?
    let sequenceID: Int64?

    /// Computes 24h percentage move safely (returns 0 when `open24h <= 0`).
    var changePercent24h: Decimal {
        guard open24h > 0 else { return 0 }
        return ((lastPrice - open24h) / open24h) * 100
    }
}
