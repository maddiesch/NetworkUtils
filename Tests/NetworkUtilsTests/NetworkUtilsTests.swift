import XCTest
@testable import NetworkUtils

final class NetworkUtilsTests: XCTestCase {
    func testAddressHostStringLiteral() {
        let h1: NetworkUtils.Host = "test.com:80"
        
        XCTAssertEqual(h1.name, "test.com")
        XCTAssertEqual(h1.port, 80)
        
        let h2: NetworkUtils.Host = "test.com"
        
        XCTAssertEqual(h2.name, "test.com")
        XCTAssertEqual(h2.port, 0)
    }
    
    func testAddressResolution() {
        let host: NetworkUtils.Host = "time.apple.com:123"
        
        let expectation = self.expectation(description: "resolution completion")
        
        var results = Array<SocketAddress>()
        
        let canceler = host.resolve().sink(receiveCompletion: { done in
            switch done {
            case .failure(let error):
                XCTFail(error.localizedDescription)
            default:
                break
            }
            expectation.fulfill()
        }, receiveValue: { addresses in
            results.append(contentsOf: addresses)
        })
        
        self.wait(for: [expectation], timeout: 1.0)
        
        canceler.cancel()
        
        XCTAssertTrue(results.count > 0)
    }
    
    func testReachability() throws {
        let reach = Reachability()
        
        try reach.start(address: .null)
        
        XCTAssertEqual(reach.state, .wifi)
        
        try reach.stop()
    }
    
    func testReachability6() throws {
        let reach = Reachability()
        
        try reach.start(address: .null6)
        
        XCTAssertEqual(reach.state, .wifi)
        
        try reach.stop()
    }
}
