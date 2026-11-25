//
//  PortfolioModels.swift
//  BidAsk
//
//  Feed-isolated paper wallet ledgers, positions, and persisted portfolio snapshots.
//

import Foundation

struct WalletLedger: Codable, Sendable, Equatable {
    let quoteCurrency: String
    var availableCash: Decimal
    var lockedCash: Decimal

    var totalCash: Decimal {
        availableCash + lockedCash
    }
}

struct Position: Identifiable, Codable, Sendable, Equatable {
    var id: SymbolID { symbol }
    let symbol: SymbolID
    var totalQuantity: Decimal
    var lockedQuantity: Decimal
    var averageCost: Decimal
    var realizedPnL: Decimal

    var availableQuantity: Decimal {
        max(0, totalQuantity - lockedQuantity)
    }
}

/// Isolated paper-trading account state for a single `FeedMode` (`OKX`, `Binance`, or `NSE Demo`).
struct FeedAccountState: Codable, Sendable, Equatable {
    let feedMode: FeedMode
    var wallet: WalletLedger
    var positions: [SymbolID: Position]
    var openOrders: [OpenOrder]
    var orderHistory: [OrderRecord]

    static func initial(for mode: FeedMode) -> FeedAccountState {
        FeedAccountState(
            feedMode: mode,
            wallet: WalletLedger(
                quoteCurrency: mode.quoteCurrency,
                availableCash: mode.startingCash,
                lockedCash: 0
            ),
            positions: [:],
            openOrders: [],
            orderHistory: []
        )
    }
}

/// Versioned snapshot written atomically to Application Support by `PortfolioStorageActor`.
struct PortfolioSnapshot: Codable, Sendable, Equatable {
    var version: UInt64
    var accounts: [FeedMode: FeedAccountState]

    static func initial() -> PortfolioSnapshot {
        var initialAccounts: [FeedMode: FeedAccountState] = [:]
        for mode in FeedMode.allCases {
            initialAccounts[mode] = .initial(for: mode)
        }
        return PortfolioSnapshot(version: 0, accounts: initialAccounts)
    }

    func account(for mode: FeedMode) -> FeedAccountState {
        accounts[mode] ?? .initial(for: mode)
    }
}
