import XCTest
@testable import BinanceAPI

class BinanceApiTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(BinancePingRequest.endpoint, "v1/ping")
    }


    static var allTests = [
        ("testExample", testExample),
    ]
}
