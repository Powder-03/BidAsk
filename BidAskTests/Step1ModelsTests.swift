//
//  Step1ModelsTests.swift
//  BidAskTests
//
//  Verifies Step 1 milestone: POSIX Decimal parsing, RingBuffer, MarketTick,
//  OrderBookSnapshot hygiene, and feed-isolated PortfolioSnapshot defaults.
//

import Foundation
import Testing
@testable import BidAsk

struct Step1ModelsTests {

    @Test("POSIX wire parsing preserves exact Decimal precision")
    func parseWireDecimals() {
        let tiny = DecimalParsing.parseWire("0.00001234")
        #expect(tiny == Decimal(string: "0.00001234", locale: Locale(identifier: "en_US_POSIX")))

        let btc = DecimalParsing.parseWire(" 68234.55 ")
        #expect(btc == Decimal(string: "68234.55", locale: Locale(identifier: "en_US_POSIX")))

        #expect(DecimalParsing.parseWire("") == nil)
        #expect(DecimalParsing.parseWire("NaN") == nil)
        #expect(DecimalParsing.parseWire(nil) == nil)
    }

    @Test("MarketTick computes 24h percentage safely when open24h is zero")
    func marketTickChangePercent() {
        let tick = MarketTick(
            symbol: "BTC-USDT",
            lastPrice: 105,
            open24h: 100,
            bestBid: 104.9,
            bestAsk: 105.1,
            volume24hQuote: 50_000,
            exchangeTimestamp: nil,
            sequenceID: 1
        )
        #expect(tick.changePercent24h == 5)

        let zeroOpen = MarketTick(
            symbol: "BTC-USDT",
            lastPrice: 105,
            open24h: 0,
            bestBid: nil,
            bestAsk: nil,
            volume24hQuote: 0,
            exchangeTimestamp: nil,
            sequenceID: nil
        )
        #expect(zeroOpen.changePercent24h == 0)
    }

    @Test("OrderBookSnapshot filters invalid sizes, sorts, caps depth, and rejects crossed books")
    func orderBookValidation() {
        let valid = OrderBookSnapshot.validated(
            symbol: "BTC-USDT",
            rawBids: [
                OrderBookLevel(price: 99, size: 1),
                OrderBookLevel(price: 100, size: 2),
                OrderBookLevel(price: 98, size: 0), // Filtered out
                OrderBookLevel(price: 97, size: 3),
                OrderBookLevel(price: 96, size: 4),
                OrderBookLevel(price: 95, size: 5),
                OrderBookLevel(price: 94, size: 6)
            ],
            rawAsks: [
                OrderBookLevel(price: 102, size: 1),
                OrderBookLevel(price: 101, size: 2)
            ],
            maxDepth: 5
        )

        #expect(valid != nil)
        #expect(valid?.bids.count == 5)
        #expect(valid?.bestBid == 100)
        #expect(valid?.bestAsk == 101)
        #expect(valid?.spread == 1)
        #expect(valid?.midPrice == Decimal(string: "100.5", locale: Locale(identifier: "en_US_POSIX")))

        // Crossed book (`bestBid >= bestAsk`) must be rejected
        let crossed = OrderBookSnapshot.validated(
            symbol: "BTC-USDT",
            rawBids: [OrderBookLevel(price: 101, size: 1)],
            rawAsks: [OrderBookLevel(price: 101, size: 1)]
        )
        #expect(crossed == nil)
    }

    @Test("RingBuffer keeps only the newest elements up to capacity")
    func ringBufferCapacity() {
        var buffer = RingBuffer<Int>(capacity: 3)
        buffer.append(contentsOf: [1, 2, 3, 4, 5])
        #expect(buffer.elements == [3, 4, 5])

        buffer.append(6)
        #expect(buffer.elements == [4, 5, 6])
    }

    @Test("PortfolioSnapshot isolates USDT and INR starting accounts per feed")
    func portfolioCurrencyIsolation() {
        let snapshot = PortfolioSnapshot.initial()
        #expect(snapshot.account(for: .okxLive).wallet.quoteCurrency == "USDT")
        #expect(snapshot.account(for: .okxLive).wallet.availableCash == 100_000)
        #expect(snapshot.account(for: .nseSimulated).wallet.quoteCurrency == "INR")
        #expect(snapshot.account(for: .nseSimulated).wallet.availableCash == 1_000_000)
    }
}
