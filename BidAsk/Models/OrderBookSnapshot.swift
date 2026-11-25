//
//  OrderBookSnapshot.swift
//  BidAsk
//
//  Level-2 top-of-book depth snapshot with hygiene validation and spread helpers.
//

import Foundation

struct OrderBookLevel: Identifiable, Sendable, Equatable {
    var id: Decimal { price }
    let price: Decimal
    let size: Decimal
}

/// Normalized top-5 Level-2 order book snapshot for a single symbol.
struct OrderBookSnapshot: Sendable, Equatable {
    let symbol: SymbolID
    /// Sorted descending by price (highest bid first).
    let bids: [OrderBookLevel]
    /// Sorted ascending by price (lowest ask first).
    let asks: [OrderBookLevel]
    let exchangeTimestamp: Date?
    let sequenceID: Int64?

    var bestBid: Decimal? { bids.first?.price }
    var bestAsk: Decimal? { asks.first?.price }

    var spread: Decimal? {
        guard let bestBid, let bestAsk else { return nil }
        return bestAsk - bestBid
    }

    var midPrice: Decimal? {
        guard let bestBid, let bestAsk else { return nil }
        return (bestBid + bestAsk) / 2
    }

    var spreadBasisPoints: Decimal? {
        guard let spread, let midPrice, midPrice > 0 else { return nil }
        return (spread / midPrice) * 10_000
    }

    var totalBidDepth: Decimal {
        bids.reduce(0) { $0 + $1.size }
    }

    var totalAskDepth: Decimal {
        asks.reduce(0) { $0 + $1.size }
    }

    /// Normalizes raw levels: filters `size <= 0`, deduplicates by price, sorts, caps depth, and rejects crossed books.
    static func validated(
        symbol: SymbolID,
        rawBids: [OrderBookLevel],
        rawAsks: [OrderBookLevel],
        maxDepth: Int = 5,
        exchangeTimestamp: Date? = nil,
        sequenceID: Int64? = nil
    ) -> OrderBookSnapshot? {
        let dedupBids = Dictionary(
            rawBids.filter { $0.price > 0 && $0.size > 0 }.map { ($0.price, $0) },
            uniquingKeysWith: { _, latest in latest }
        ).values

        let dedupAsks = Dictionary(
            rawAsks.filter { $0.price > 0 && $0.size > 0 }.map { ($0.price, $0) },
            uniquingKeysWith: { _, latest in latest }
        ).values

        let bidsArray = Array(dedupBids.sorted { $0.price > $1.price }.prefix(maxDepth))
        let asksArray = Array(dedupAsks.sorted { $0.price < $1.price }.prefix(maxDepth))

        // Discard empty books or transient crossed books (`bestBid >= bestAsk`)
        if let topBid = bidsArray.first?.price,
           let topAsk = asksArray.first?.price,
           topBid >= topAsk {
            return nil
        }

        guard !bidsArray.isEmpty || !asksArray.isEmpty else {
            return nil
        }

        return OrderBookSnapshot(
            symbol: symbol,
            bids: bidsArray,
            asks: asksArray,
            exchangeTimestamp: exchangeTimestamp,
            sequenceID: sequenceID
        )
    }
}
