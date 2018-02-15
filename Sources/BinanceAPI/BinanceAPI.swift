//
//  BinanceAPI.swift
//  BinanceAPI
//
//  Created by Sumant Manne on 10/19/17.
//

import Alamofire
import Foundation

// MARK: General endpoints

/// Test connectivity to the REST API.
public struct BinancePingRequest: BinanceRequest, Codable {
  public static let endpoint = "v1/ping"
  public static let method: HTTPMethod = .get

  public struct Response: Codable {}
  public init() {}
}

/// Test connectivity to the REST API and get the current server time.
public struct BinanceTimeRequest: BinanceRequest {
  public static let endpoint = "v1/time"
  public static let method: HTTPMethod = .get

  public init() {}

  public struct Response: Decodable {
    public let localTime = Date()
    public let serverTime: Date

    public var delta: TimeInterval {
      return self.serverTime.timeIntervalSince(self.localTime)
    }
  }
}

// MARK: Market Data endpoints

public struct BinanceExchangeInfoRequest: BinanceRequest, Codable {
  public static let endpoint = "v1/exchangeInfo"
  public static let method: HTTPMethod = .get

  public init() {}

  public struct Response: Decodable {

    public struct Symbol: Decodable {
      public struct Filter: Decodable {
        public let filterType: String
        public let minQuantity: Decimal?
        public let maxQuantity: Decimal?
        public let stepSize: Decimal?
        public let minPrice: Decimal?
        public let maxPrice: Decimal?
        public let tickSize: Decimal?

        enum CodingKeys: String, CodingKey {
          case filterType
          case minQuantity = "minQty"
          case maxQuantity = "maxQty"
          case stepSize
          case minPrice, maxPrice, tickSize
        }

        public init(from decoder: Decoder) throws {
          let values = try decoder.container(keyedBy: CodingKeys.self)
          self.filterType = try values.decode(String.self, forKey: .filterType)
          self.minQuantity = try? values.decode(Decimal.self, forKey: .minQuantity)
          self.maxQuantity = try? values.decode(Decimal.self, forKey: .maxQuantity)
          self.stepSize = try? values.decode(Decimal.self, forKey: .stepSize)
          self.minPrice = try? values.decode(Decimal.self, forKey: .minPrice)
          self.maxPrice = try? values.decode(Decimal.self, forKey: .maxPrice)
          self.tickSize = try? values.decode(Decimal.self, forKey: .tickSize)
        }
      }

      public let symbol: String
      public let status: String
      public let baseAsset: String
      public let baseAssetPrecision: Int
      public let quoteAsset: String
      public let quotePrecision: Int
      public let orderTypes: [String]
      public let icebergAllowed: Bool
      public let minQuantity: Decimal
      public let maxQuantity: Decimal
      public let stepSize: Decimal
      public let minPrice: Decimal
      public let maxPrice: Decimal
      public let tickSize: Decimal

      enum CodingKeys: String, CodingKey {
        case symbol
        case status
        case baseAsset
        case baseAssetPrecision
        case quoteAsset
        case quotePrecision
        case orderTypes
        case icebergAllowed
        case filters
      }

      public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.symbol = try values.decode(String.self, forKey: .symbol)
        self.status = try values.decode(String.self, forKey: .status)
        self.baseAsset = try values.decode(String.self, forKey: .baseAsset)
        self.baseAssetPrecision = try values.decode(Int.self, forKey: .baseAssetPrecision)
        self.quoteAsset = try values.decode(String.self, forKey: .quoteAsset)
        self.quotePrecision = try values.decode(Int.self, forKey: .quotePrecision)
        self.orderTypes = try values.decode([String].self, forKey: .orderTypes)
        self.icebergAllowed = try values.decode(Bool.self, forKey: .icebergAllowed)

        var filters = try values.nestedUnkeyedContainer(forKey: .filters)
        var decodedQuantityFilter: (minQuantity: Decimal, maxQuantity: Decimal, stepSize: Decimal)? = nil
        var decodedPriceFilter: (minPrice: Decimal, maxPrice: Decimal, tickSize: Decimal)? = nil
        while(!filters.isAtEnd || (decodedQuantityFilter == nil && decodedPriceFilter == nil)) {
          let filter = try filters.decode(Filter.self)
          if let minQty = filter.minQuantity,
            let maxQty = filter.maxQuantity,
            let stepSize = filter.stepSize
          {
            decodedQuantityFilter = (minQty, maxQty, stepSize)
          }
          if let minPrice = filter.minPrice,
            let maxPrice = filter.maxPrice,
            let tickSize = filter.tickSize
          {
            decodedPriceFilter = (minPrice, maxPrice, tickSize)
          }
        }
        self.minQuantity = decodedQuantityFilter?.minQuantity ?? 0
        self.maxQuantity = decodedQuantityFilter?.maxQuantity ?? 0
        self.stepSize = decodedQuantityFilter?.stepSize ?? 0

        self.minPrice = decodedPriceFilter?.minPrice ?? 0
        self.maxPrice = decodedPriceFilter?.maxPrice ?? 0
        self.tickSize = decodedPriceFilter?.tickSize ?? 0
      }
    }

    public let symbols: [Symbol]

    public init(from decoder: Decoder) throws {
      let dict = try decoder.container(keyedBy: CodingKeys.self)
      var symbols = try dict.nestedUnkeyedContainer(forKey: .symbols)
      var decodedSymbols = [Symbol]()
      while (!symbols.isAtEnd) {
        let symbol = try symbols.decode(Symbol.self)
        decodedSymbols.append(symbol)
      }
      self.symbols = decodedSymbols
    }

    enum CodingKeys: String, CodingKey {
      case symbols
    }

  }
}

public struct BinanceDepthRequest: BinanceRequest {
  public static let endpoint = "v1/depth"
  public static let method: HTTPMethod = .get

  public let symbol: String
  /// Default = 100; Max = 100.
  public let limit: Int32?

  public init(symbol: String, limit: Int32? = nil) {
    self.symbol = symbol
    self.limit = limit != 0 ? limit : nil
  }

  public struct Response: Decodable {
    public struct DepthOrder: Decodable {
      public let price: Decimal
      public let quantity: Decimal

      public init(from decoder: Decoder) throws {
        var values = try decoder.unkeyedContainer()
        self.price = try values.decode(Decimal.self)
        self.quantity = try values.decode(Decimal.self)
      }
    }

    public let lastUpdateId: UInt64
    public let bids: [DepthOrder]
    public let asks: [DepthOrder]
  }
}

/// Get compressed, aggregate trades.
/// Trades that fill at the time, from the same order, with the same price will have the quantity aggregated.
/// When both `startTime` and `endTime` are set limit should not be sent AND the distance between `startTime` and `endTime` must be less than 24 hours.
/// If `fromId`, `startTime`, and `endTime` are not set the most recent aggregate trades will be returned.
public struct BinanceAggregateTradesRequest: BinanceRequest, Codable  {
  public static let endpoint = "v1/aggTrades"
  public static let method: HTTPMethod = .get

  public let symbol: String
  /// ID to get aggregate trades from INCLUSIVE.
  public var fromId: UInt64?
  /// Timestamp to get aggregate trades from INCLUSIVE.
  public let startTime: Date?
  /// Timestamp to get aggregate trades until INCLUSIVE.
  public let endTime: Date?
  /// Default = 500; Max = 500.
  public let limit: Int32?

  public init(symbol: String, fromId: UInt64? = nil, startTime: Date? = nil, endTime: Date? = nil, limit: Int32? = nil) {
    self.symbol = symbol
    self.fromId = fromId != 0 ? fromId : nil
    self.startTime = startTime
    self.endTime = endTime
    self.limit = limit != 0 ? limit : nil
  }

  public struct Element: Codable {
    public let aggregateTradeId: UInt64
    public let price: Decimal
    public let quantity: Decimal
    public let firstTradeId: UInt64
    public let lastTradeId: UInt64
    public let timestamp: Date
    public let makerIsBuyer: Bool
    public let matchIsBest: Bool

    enum CodingKeys: String, CodingKey {
      case aggregateTradeId = "a"
      case price = "p"
      case quantity = "q"
      case firstTradeId = "f"
      case lastTradeId = "l"
      case timestamp = "T"
      case makerIsBuyer = "m"
      case matchIsBest = "M"
    }
  }

  public typealias Response = [Element]
}

/// Kline/candlestick bars for a `symbol`. Klines are uniquely identified by their open time.
/// If `startTime` and `endTime` are not set the most recent klines are returned.
public struct BinanceCandlesticksRequest: BinanceRequest {
  public static let endpoint = "v1/klines"
  public static let method: HTTPMethod = .get

  public let symbol: String
  public let interval: BinanceCandlesticksInterval
  /// Default = 500; Max = 500.
  public let limit: Int32?
  public let startTime: Date?
  public let endTime: Date?

  public init(symbol: String, interval: BinanceCandlesticksInterval, limit: Int32? = nil, startTime: Date? = nil, endTime: Date? = nil) {
    self.symbol = symbol
    self.interval = interval
    self.limit = limit != 0 ? limit : nil
    self.startTime = startTime
    self.endTime = endTime
  }

  public struct Element: Decodable {
    public let openTime: Date
    public let open: Decimal
    public let high: Decimal
    public let low: Decimal
    public let close: Decimal
    public let assetVolume: Decimal
    public let closeTime: Date
    public let quoteVolume: Decimal
    public let trades: UInt64
    public let buyAssetVolume: Decimal
    public let buyQuoteVolume: Decimal
    public let ignored: String?

    public init(from decoder: Decoder) throws {
      var values = try decoder.unkeyedContainer()
      self.openTime = try values.decode(Date.self)
      self.open = try values.decode(Decimal.self)
      self.high = try values.decode(Decimal.self)
      self.low = try values.decode(Decimal.self)
      self.close = try values.decode(Decimal.self)
      self.assetVolume = try values.decode(Decimal.self)
      self.closeTime = try values.decode(Date.self)
      self.quoteVolume = try values.decode(Decimal.self)
      self.trades = try values.decode(UInt64.self)
      self.buyAssetVolume = try values.decode(Decimal.self)
      self.buyQuoteVolume = try values.decode(Decimal.self)
      self.ignored = try values.decodeIfPresent(String.self)
    }
  }

  public typealias Response = [Element]
}

/// 24 hour price change statistics for a `symbol`.
public struct Binance24HourTickerRequest: BinanceRequest, Codable {
  public static let endpoint = "v1/ticker/24hr"
  public static let method: HTTPMethod = .get

  public let symbol: String

  public struct Response: Codable {
    public let priceChange: Decimal
    public let priceChangePercent: Decimal
    public let weightedAvgPrice: Decimal
    public let prevClosePrice: Decimal
    public let lastPrice: Decimal
    public let bidPrice: Decimal
    public let askPrice: Decimal
    public let openPrice: Decimal
    public let highPrice: Decimal
    public let lowPrice: Decimal
    public let openTime: Date
    public let closeTime: Date
    public let firstId: UInt64
    public let lastId: UInt64
    public let count: UInt64
  }
}

/// Latest `price` for all `symbol`s.
public struct BinanceAllPricesRequest: BinanceRequest, Codable {
  public static let endpoint = "v1/ticker/allPrices"
  public static let method: HTTPMethod = .get

  public struct Response: Decodable {
    public let elements: [String: Decimal]

    public init(from decoder: Decoder) throws {
      var dict = [String: Decimal]()
      var container = try decoder.unkeyedContainer()
      if let count = container.count {
        dict.reserveCapacity(count)
      }
      while !container.isAtEnd {
        let e = try container.decode(ResponseElement.self)
        dict[e.symbol] = e.price
      }
      self.elements = dict
    }

    private struct ResponseElement: Codable {
      public let symbol: String
      public let price: Decimal
    }
  }

  public init() {}
}

/// Best price/quantity on the order book for all `symbol`s.
public struct BinanceBookTickersRequest: BinanceRequest, Codable {
  public static let endpoint = "v3/ticker/bookTicker"
  public static let method: HTTPMethod = .get

  public struct Asset {
    private static let markets: [String] = ["BTC", "ETH", "USDT", "BNB"]
    internal static func parse(symbol: String) -> Asset? {
      guard let quote = Asset.markets.filter(symbol.hasSuffix).first else { return nil }
      let index = symbol.index(symbol.endIndex, offsetBy: -quote.count)
      let base = String(symbol[..<index])
      return Asset(base: base, quote: quote)
    }

    public let base: String
    public let quote: String
  }

  public struct Order: Decodable {
    public let symbol: String
    public let base: String
    public let quote: String
    public let bidPrice: Decimal
    public let bidQuantity: Decimal
    public let askPrice: Decimal
    public let askQuantity: Decimal

    enum CodingKeys: String, CodingKey {
      case symbol
      case bidPrice
      case bidQuantity = "bidQty"
      case askPrice
      case askQuantity = "askQty"
    }

    public init(from decoder: Decoder) throws {
      let dict = try decoder.container(keyedBy: CodingKeys.self)
      self.symbol = try dict.decode(type(of: self.symbol), forKey: .symbol)

      guard let asset = Asset.parse(symbol: self.symbol) else { throw BinanceApiError.unknown }
      self.base = asset.base
      self.quote = asset.quote
      self.bidPrice = try dict.decode(type(of: self.bidPrice), forKey: .bidPrice)
      self.bidQuantity = try dict.decode(type(of: self.bidQuantity), forKey: .bidQuantity)
      self.askPrice = try dict.decode(type(of: self.askPrice), forKey: .askPrice)
      self.askQuantity = try dict.decode(type(of: self.askQuantity), forKey: .askQuantity)
    }
  }

  public struct Response: Decodable {
    public let orders: [String: Order]

    public init(from decoder: Decoder) throws {
      var dict = [String: Order]()
      var container = try decoder.unkeyedContainer()
      if let count = container.count {
        dict.reserveCapacity(count)
      }
      while !container.isAtEnd {
        guard let order = try? container.decode(Order.self) else { continue }
        dict[order.symbol] = order
      }
      self.orders = dict
    }
  }

  public init() {}
}

// MARK: Account endpoints

/// Send in a new order.
public struct BinanceNewOrderRequest: BinanceSignedRequest, Codable {
  public static let endpoint = "v3/order"
  public static let method = HTTPMethod.post

  public let symbol: String
  public let side: BinanceOrderSide
  public let orderType: BinanceOrderType
  /// Should not be sent for a market order.
  public let timeInForce: BinanceOrderTime?
  public let quantity: Decimal
  /// Should not be sent for a market order.
  public let price: Decimal?
  /// A unique id for the order. Automatically generated if not sent.
  public let newClientOrderId: String?
  /// Used with stop orders.
  public let stopPrice: Decimal?
  /// Used with iceberg orders.
  public let icebergQuantity: Decimal?
  public let newOrderResponseType: BinanceOrderResponseType?
  public let recvWindow: TimeInterval?
  public let timestamp: Date

  public init(symbol: String, side: BinanceOrderSide, orderType: BinanceOrderType, quantity: Decimal,
              price: Decimal? = nil, timeInForce: BinanceOrderTime? = nil, newClientOrderId: String? = nil,
              stopPrice: Decimal? = nil, icebergQuantity: Decimal? = nil, newOrderResponseType: BinanceOrderResponseType? = .result,
              recvWindow: TimeInterval? = nil, timestamp: Date = Date()) {
    self.symbol = symbol
    self.side = side
    self.orderType = orderType
    self.quantity = quantity
    self.newClientOrderId = newClientOrderId
    self.stopPrice = stopPrice
    self.icebergQuantity = icebergQuantity
    self.newOrderResponseType = newOrderResponseType
    self.recvWindow = recvWindow
    self.timestamp = timestamp

    switch orderType {
    case .limit:
      assert(timeInForce != nil, "timeInForce should not be nil for a limit order")
      assert(price != nil, "price should not be nil for a limit order")
      self.timeInForce = timeInForce
      self.price = price
      break
    case .market:
      self.timeInForce = nil
      self.price = nil
      break
    case .stopLoss:
      assert(stopPrice != nil, "stopPrice should not be nil for a stopLoss order")
      self.timeInForce = nil
      self.price = price
    case .stopLossLimit:
      assert(timeInForce != nil, "timeInForce should not be nil for a stopLossLimit order")
      assert(price != nil, "price should not be nil for a stopLossLimit order")
      self.timeInForce = timeInForce
      self.price = price
      assert(stopPrice != nil, "stopPrice should not be nil for a stopLossLimit order")
    case .takeProfit:
      assert(stopPrice != nil, "stopPrice should not be nil for a takeProfit order")
      self.timeInForce = nil
      self.price = nil
    case .takeProfitLimit:
      assert(timeInForce != nil, "timeInForce should not be nil for a takeProfitLimit order")
      assert(price != nil, "price should not be nil for a takeProfitLimit order")
      assert(stopPrice != nil, "stopPrice should not be nil for a takeProfitLimit order")
      self.timeInForce = timeInForce
      self.price = price
    case .limitMaker:
      assert(price != nil, "price should not be nil for a limitMaker order")
      self.timeInForce = nil
      self.price = price
    }
  }

  enum CodingKeys: String, CodingKey {
    case symbol, side
    case orderType = "type"
    case timeInForce, quantity, price, newClientOrderId, stopPrice
    case icebergQuantity = "icebergQty"
    case newOrderResponseType = "newOrderRespType"
    case recvWindow, timestamp
  }

  public struct Response: Decodable {
    public struct Fill: Codable {
      public let price: Decimal
      public let quantity: Decimal
      public let commission: Decimal
      public let commissionAsset: String

      enum CodingKeys: String, CodingKey {
        case price
        case quantity = "qty"
        case commission, commissionAsset
      }
    }
    public let symbol: String
    public let orderId: UInt64
    public let clientOrderId: String
    public let price: Decimal
    public let originalQuantity: Decimal
    public let executedQuantity: Decimal
    public let status: BinanceOrderStatus
    public let timeInForce: BinanceOrderTime
    public let orderType: BinanceOrderType
    public let side: BinanceOrderSide
    public let transactTime: Date
    public let fills: [Fill]

    enum CodingKeys: String, CodingKey {
      case symbol, orderId, clientOrderId, price
      case originalQuantity = "origQty"
      case executedQuantity = "executedQty"
      case status, timeInForce
      case orderType = "type"
      case side
      case transactTime
      case fills
    }

    public init(from decoder: Decoder) throws {
      let dict = try decoder.container(keyedBy: CodingKeys.self)
      self.symbol = try dict.decode(type(of: self.symbol), forKey: .symbol)
      self.orderId = try dict.decode(type(of: self.orderId), forKey: .orderId)
      self.clientOrderId = try dict.decode(type(of: self.clientOrderId), forKey: .clientOrderId)
      self.price = try dict.decode(type(of: self.price), forKey: .price)
      self.originalQuantity = try dict.decode(type(of: self.originalQuantity), forKey: .originalQuantity)
      self.executedQuantity = try dict.decode(type(of: self.executedQuantity), forKey: .executedQuantity)
      self.status = try dict.decode(type(of: self.status), forKey: .status)
      self.timeInForce = try dict.decode(type(of: self.timeInForce), forKey: .timeInForce)
      self.orderType = try dict.decode(type(of: self.orderType), forKey: .orderType)
      self.side = try dict.decode(type(of: self.side), forKey: .side)
      self.transactTime = try dict.decode(type(of: self.transactTime), forKey: .transactTime)

      var fills = try? dict.nestedUnkeyedContainer(forKey: .fills)
      var decodedFills: [Fill] = []
      while (!(fills?.isAtEnd == true)) {
        let fill = try fills?.decode(Fill.self)
        guard let _fill = fill else { continue }
        decodedFills.append(_fill)
      }
      self.fills = decodedFills
    }
  }
}

/// Test new order creation.
/// Creates and validates a new order but does not send it into the matching engine.
public struct BinanceTestNewOrderRequest: BinanceSignedRequest, Codable {
  public static let endpoint = "v3/order/test"
  public static let method = HTTPMethod.post

  public let symbol: String
  public let side: BinanceOrderSide
  public let type: BinanceOrderType
  /// Should not be sent for a market order.
  public let timeInForce: BinanceOrderTime?
  public let quantity: Decimal
  /// Should not be sent for a market order.
  public let price: Decimal?
  /// A unique id for the order. Automatically generated if not sent.
  public let newClientOrderId: String?
  /// Used with stop orders.
  public let stopPrice: Decimal?
  /// Used with iceberg orders.
  public let icebergQuantity: Decimal?
  public let newOrderResponseType: BinanceOrderResponseType?
  public let recvWindow: TimeInterval?
  public let timestamp: Date

  public init(symbol: String, side: BinanceOrderSide, type: BinanceOrderType, quantity: Decimal,
              price: Decimal? = nil, timeInForce: BinanceOrderTime? = nil, newClientOrderId: String? = nil,
              stopPrice: Decimal? = nil, icebergQuantity: Decimal? = nil, newOrderResponseType: BinanceOrderResponseType? = .result,
              recvWindow: TimeInterval? = nil, timestamp: Date = Date()) {
    self.symbol = symbol
    self.side = side
    self.type = type
    self.quantity = quantity
    self.newClientOrderId = newClientOrderId
    self.stopPrice = stopPrice
    self.icebergQuantity = icebergQuantity
    self.newOrderResponseType = newOrderResponseType
    self.recvWindow = recvWindow
    self.timestamp = timestamp

    switch type {
    case .limit:
      assert(timeInForce != nil, "timeInForce should not be nil for a limit order")
      assert(price != nil, "price should not be nil for a limit order")
      self.timeInForce = timeInForce
      self.price = price
      break
    case .market:
      self.timeInForce = nil
      self.price = nil
      break
    case .stopLoss:
      assert(stopPrice != nil, "stopPrice should not be nil for a stopLoss order")
      self.timeInForce = nil
      self.price = price
    case .stopLossLimit:
      assert(timeInForce != nil, "timeInForce should not be nil for a stopLossLimit order")
      assert(price != nil, "price should not be nil for a stopLossLimit order")
      self.timeInForce = timeInForce
      self.price = price
      assert(stopPrice != nil, "stopPrice should not be nil for a stopLossLimit order")
    case .takeProfit:
      assert(stopPrice != nil, "stopPrice should not be nil for a takeProfit order")
      self.timeInForce = nil
      self.price = nil
    case .takeProfitLimit:
      assert(timeInForce != nil, "timeInForce should not be nil for a takeProfitLimit order")
      assert(price != nil, "price should not be nil for a takeProfitLimit order")
      assert(stopPrice != nil, "stopPrice should not be nil for a takeProfitLimit order")
      self.timeInForce = timeInForce
      self.price = price
    case .limitMaker:
      assert(price != nil, "price should not be nil for a limitMaker order")
      self.timeInForce = nil
      self.price = price
    }
  }

  enum CodingKeys: String, CodingKey {
    case symbol, side, type, timeInForce, quantity, price, newClientOrderId, stopPrice
    case icebergQuantity = "icebergQty"
    case newOrderResponseType = "newOrderRespType"
    case recvWindow, timestamp
  }

  public typealias Response = BinanceNewOrderRequest.Response
}

/// Check an order's status.
/// Either `orderId` or `originalClientOrderId` must be sent.
public struct BinanceQueryOrderRequest: BinanceSignedRequest, Codable {
  public static let endpoint = "v3/order"
  public static let method = HTTPMethod.get

  public let symbol: String
  public let orderId: UInt64?
  public let originalClientOrderId: String?
  public let timestamp: Date

  public init(symbol: String, orderId: UInt64? = nil, originalClientOrderId: String? = nil, timestamp: Date = Date()) {
    assert((orderId != nil && orderId != 0) || originalClientOrderId != nil, "Either orderId or originalClientOrderId must be provided")
    self.orderId = orderId != 0 ? orderId : nil
    self.symbol = symbol
    self.originalClientOrderId = originalClientOrderId
    self.timestamp = timestamp
  }

  enum CodingKeys: String, CodingKey {
    case symbol, orderId
    case originalClientOrderId = "origClientOrderId"
    case timestamp
  }

  public typealias Response = BinanceOrder
}

public struct BinanceCancelOrderRequest: BinanceSignedRequest, Codable {
  public static let endpoint = "v3/order"
  public static let method: HTTPMethod = .delete

  public let symbol: String
  public let orderId: UInt64?
  public let originalClientOrderId: String?
  /// Used to uniquely identify this cancel. Automatically generated by default.
  public let newClientOrderId: String?
  public let timestamp: Date

  public init(symbol: String, orderId: UInt64? = nil, originalClientOrderId: String? = nil, newClientOrderId: String? = nil, timestamp: Date = Date()) {
    self.symbol = symbol
    self.orderId = orderId != 0 ? orderId : nil
    self.originalClientOrderId = originalClientOrderId
    self.newClientOrderId = newClientOrderId
    self.timestamp = timestamp
  }

  enum CodingKeys: String, CodingKey {
    case symbol, orderId
    case originalClientOrderId = "origClientOrderId"
    case newClientOrderId, timestamp
  }

  public struct Response: Codable {
    public let symbol: String
    public let origClientOrderId: String
    public let orderId: UInt64
    public let clientOrderId: String
  }
}

/// Get all open orders for a `symbol`.
public struct BinanceOpenOrdersRequest: BinanceSignedRequest, Codable {
  public static let endpoint = "v3/openOrders"
  public static let method = HTTPMethod.get

  public let symbol: String
  public let timestamp: Date

  public init(symbol: String, timestamp: Date = Date()) {
    self.symbol = symbol
    self.timestamp = timestamp
  }

  public typealias Response = [BinanceOrder]
}

/// Get all account orders: active, canceled, or filled.
/// If `orderId` is set it will get orders >= `orderId`. Otherwise the most recent orders are returned.
public struct BinanceAllOrdersRequest: BinanceSignedRequest, Codable {
  public static let endpoint = "v3/allOrders"
  public static let method = HTTPMethod.get

  public let symbol: String
  public let orderId: UInt64?
  /// Default = 500; Max = 500.
  public let limit: Int32?
  public let timestamp: Date

  public init(symbol: String, orderId: UInt64? = nil, limit: Int32? = nil, timestamp: Date = Date()) {
    self.symbol = symbol
    self.orderId = orderId != 0 ? orderId : nil
    self.limit = limit != 0 ? limit : nil
    self.timestamp = timestamp
  }

  public typealias Response = [BinanceOrder]
}

/// Get current account information.
public struct BinanceAccountInformationRequest: BinanceSignedRequest {
  public static let endpoint = "v3/account"
  public static let method: HTTPMethod = .get

  public let timestamp: Date

  public init(timestamp: Date = Date()) {
    self.timestamp = timestamp
  }

  public struct Response: Decodable {
    /// Given in basis points (0.01% each)
    public let makerCommission: Int16
    /// Given in basis points (0.01% each)
    public let takerCommission: Int16
    /// Given in basis points (0.01% each)
    public let buyerCommission: Int16
    /// Given in basis points (0.01% each)
    public let sellerCommission: Int16
    public let canTrade: Bool
    public let canWithdraw: Bool
    public let canDeposit: Bool
    public let balances: [String: (free: Decimal, locked: Decimal, total: Decimal)]

    public init(from decoder: Decoder) throws {
      let dict = try decoder.container(keyedBy: CodingKeys.self)
      self.makerCommission = try dict.decode(type(of: self.makerCommission), forKey: .makerCommission)
      self.takerCommission = try dict.decode(type(of: self.takerCommission), forKey: .takerCommission)
      self.buyerCommission = try dict.decode(type(of: self.buyerCommission), forKey: .buyerCommission)
      self.sellerCommission = try dict.decode(type(of: self.sellerCommission), forKey: .sellerCommission)
      self.canTrade = try dict.decode(type(of: self.canTrade), forKey: .canTrade)
      self.canWithdraw = try dict.decode(type(of: self.canWithdraw), forKey: .canWithdraw)
      self.canDeposit = try dict.decode(type(of: self.canDeposit), forKey: .canDeposit)

      var balances = try dict.nestedUnkeyedContainer(forKey: .balances)
      var decodedBalances = [String: (free: Decimal, locked: Decimal, total: Decimal)]()
      while (!balances.isAtEnd) {
        let entry = try balances.decode(BalanceEntry.self)
        if entry.free > 0 || entry.locked > 0 {
          decodedBalances[entry.asset] = (free: entry.free, locked: entry.locked, total: entry.free + entry.locked)
        }
      }
      self.balances = decodedBalances
    }

    public struct BalanceEntry: Codable {
      public let asset: String
      public let free: Decimal
      public let locked: Decimal
    }

    enum CodingKeys: String, CodingKey {
      case makerCommission, takerCommission,buyerCommission, sellerCommission
      case canTrade, canWithdraw, canDeposit, balances
    }
  }
}

/// Get account trades for a specific `symbol`.
public struct BinanceAccountTradeListRequest: BinanceSignedRequest, Codable {
  public static let endpoint = "v3/myTrades"
  public static let method: HTTPMethod = .get

  public let symbol: String
  /// Default = 500; Max = 500.
  public let limit: Int32?
  /// tradeId to fetch from. Otherwise gets most recent trades.
  public let fromId: UInt64?
  public let timestamp: Date

  public init(symbol: String, limit: Int32? = nil, fromId: UInt64? = nil, timestamp: Date = Date()) {
    self.symbol = symbol
    self.limit = limit
    self.fromId = fromId
    self.timestamp = timestamp
  }

  public struct Element: Codable {
    public let id: UInt64
    public let price: Decimal
    public let quantity: Decimal
    public let commission: Decimal
    public let commissionAsset: String
    public let time: Date
    public let isBuyer: Bool
    public let isMaker: Bool
    public let isBestMatch: Bool

    enum CodingKeys: String, CodingKey {
      case id, price
      case quantity = "qty"
      case commission, commissionAsset, time, isBuyer, isMaker, isBestMatch
    }
  }

  public typealias Response = [Element]
}

// TODO: Websocket endpoints
