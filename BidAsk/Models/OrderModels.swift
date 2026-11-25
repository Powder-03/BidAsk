//
//  OrderModels.swift
//  BidAsk
//
//  Order types, resting open orders, execution legs, and trading events.
//

import Foundation

enum OrderSide: String, Codable, Sendable, CaseIterable {
    case buy = "BUY"
    case sell = "SELL"
}

enum OrderType: String, Codable, Sendable, CaseIterable {
    case market = "Market"
    case limit = "Limit"
}

enum OrderStatus: String, Codable, Sendable {
    case open = "OPEN"
    case partiallyFilled = "PARTIAL"
    case filled = "FILLED"
    case cancelled = "CANCELLED"
    case rejected = "REJECTED"
}

struct OrderRequest: Sendable, Equatable {
    let feedMode: FeedMode
    let symbol: SymbolID
    let side: OrderSide
    let type: OrderType
    let quantity: Decimal
    let limitPrice: Decimal?
}

struct FillLeg: Codable, Sendable, Equatable {
    let price: Decimal
    let quantity: Decimal
}

/// Active resting limit order managed exclusively inside `TradingEngineActor`.
struct OpenOrder: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let feedMode: FeedMode
    let symbol: SymbolID
    let side: OrderSide
    let limitPrice: Decimal
    let originalQuantity: Decimal
    var remainingQuantity: Decimal
    /// Tracks exact remaining quote reservation for Buys so partial fills never leave penny dust.
    var remainingLockedCash: Decimal
    let createdAt: Date
}

/// Immutable history entry shown in Orders & Execution Log.
struct OrderRecord: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let feedMode: FeedMode
    let symbol: SymbolID
    let side: OrderSide
    let type: OrderType
    var status: OrderStatus
    let requestedQuantity: Decimal
    var filledQuantity: Decimal
    let limitPrice: Decimal?
    var averageFillPrice: Decimal?
    var slippagePercent: Decimal?
    var rejectionReason: String?
    let createdAt: Date
    var updatedAt: Date
}

/// Non-conflated events emitted by `TradingEngineActor` directly to `MarketCoordinator`.
enum TradingEvent: Sendable {
    case snapshotUpdated(FeedMode, PortfolioSnapshot)
    case orderExecuted(OrderRecord)
    case orderRejected(OrderRecord)
    case orderCancelled(OrderRecord)
}
