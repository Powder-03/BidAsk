//
//  FeedModels.swift
//  BidAsk
//
//  Core feed identifiers, connection states, events, and a fixed-capacity ring buffer.
//

import Foundation

/// Supported market data sources. Each mode maintains an isolated paper wallet and order book.
enum FeedMode: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case okxLive
    case binanceLive
    case nseSimulated

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .okxLive:
            return "OKX Live"
        case .binanceLive:
            return "Binance Live"
        case .nseSimulated:
            return "NSE Demo"
        }
    }

    var quoteCurrency: String {
        switch self {
        case .okxLive, .binanceLive:
            return "USDT"
        case .nseSimulated:
            return "INR"
        }
    }

    /// Decimal precision used in internal wallet accounting for this quote currency.
    var quoteScale: Int {
        switch self {
        case .okxLive, .binanceLive:
            return 8
        case .nseSimulated:
            return 2
        }
    }

    var startingCash: Decimal {
        switch self {
        case .okxLive, .binanceLive:
            return Decimal(string: "100000.00", locale: Locale(identifier: "en_US_POSIX")) ?? 100_000
        case .nseSimulated:
            return Decimal(string: "1000000.00", locale: Locale(identifier: "en_US_POSIX")) ?? 1_000_000
        }
    }
}

/// Identifies separate WebSocket channels so sequence/timestamp watermarks never collide.
enum ChannelKind: Hashable, Sendable {
    case ticker
    case orderBookTop5
}

/// Live health state surfaced in the Watchlist and Detail header badges.
enum FeedConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case stale(lastMessageAgeSeconds: Int)
    case reconnecting(attempt: Int, retryDelaySeconds: Int)
    case offlinePaused
    case backgroundPaused
    case simulated

    var statusLabel: String {
        switch self {
        case .disconnected:
            return "OFFLINE"
        case .connecting:
            return "CONNECTING"
        case .connected:
            return "LIVE"
        case .stale(let age):
            return "STALE • \(age)s"
        case .reconnecting(let attempt, _):
            return "RETRY #\(attempt)"
        case .offlinePaused:
            return "NO NETWORK"
        case .backgroundPaused:
            return "PAUSED"
        case .simulated:
            return "NSE DEMO"
        }
    }
}

/// Lightweight Double-backed point used strictly at the Swift Charts rendering boundary.
struct PricePoint: Identifiable, Equatable, Sendable {
    let id: UInt64
    let timestamp: Date
    let price: Double
}

/// Unified events emitted by any `MarketFeedProtocol` adapter.
enum MarketFeedEvent: Sendable {
    case connectionChanged(FeedConnectionState)
    case tick(MarketTick)
    case orderBook(OrderBookSnapshot)
    /// Pre-seeded intraday points (bypasses trade matching so old candles never trigger limit orders).
    case historySeed([SymbolID: [PricePoint]])
    case heartbeatLatency(Duration)
}

/// Fixed-capacity FIFO buffer keeping rolling chart histories bounded in memory (`O(capacity)`).
struct RingBuffer<Element: Sendable>: Sendable, Equatable where Element: Equatable {
    private var storage: [Element]
    let capacity: Int

    init(capacity: Int) {
        self.capacity = max(1, capacity)
        self.storage = []
        self.storage.reserveCapacity(self.capacity)
    }

    var elements: [Element] { storage }
    var isEmpty: Bool { storage.isEmpty }
    var count: Int { storage.count }

    mutating func append(_ element: Element) {
        if storage.count >= capacity {
            storage.removeFirst(storage.count - capacity + 1)
        }
        storage.append(element)
    }

    mutating func append(contentsOf newElements: [Element]) {
        guard !newElements.isEmpty else { return }
        if newElements.count >= capacity {
            storage = Array(newElements.suffix(capacity))
            return
        }
        let overflow = (storage.count + newElements.count) - capacity
        if overflow > 0 {
            storage.removeFirst(overflow)
        }
        storage.append(contentsOf: newElements)
    }

    mutating func removeAll() {
        storage.removeAll(keepingCapacity: true)
    }
}
