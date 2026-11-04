//
// Product: SwiftUPnP
// Package: SwiftUPnPTests
//
// A device that refuses an action answers with a SOAP fault. The error the caller gets must carry
// the UPnP error code and description from that body, not the HTTP status alone.
//

import XCTest
import Mocker
@testable import SwiftUPnP

final class SOAPFaultTests: XCTestCase {
    private struct Envelope: Codable {
        let body: String
    }

    private let controlUrl = URL(string: "http://127.0.0.1:1400/MediaRenderer/AVTransport/Control")!
    private var service: UPnPService!

    override func setUp() {
        super.setUp()
        // `post` goes through the shared session
        URLProtocol.registerClass(MockingURLProtocol.self)
        let device = UPnPDevice(uuid: "uuid:test-device", deviceId: "urn:test:device:Source:1", deviceType: "urn:test:device:Source:1",
                                url: URL(string: "http://127.0.0.1:1400/desc.xml")!, lastSeen: Date())
        service = UPnPService(device: device,
                              controlUrl: controlUrl,
                              scpdUrl: URL(string: "http://127.0.0.1:1400/desc.xml")!,
                              eventUrl: nil,
                              serviceType: "urn:schemas-upnp-org:service:AVTransport:1",
                              serviceId: "urn:upnp-org:serviceId:AVTransport")
    }

    override func tearDown() {
        // The protocol stays registered: other suites' mocks for the shared session rely on it.
        Mocker.removeAll()
        service = nil
        super.tearDown()
    }

    func testFaultCarriesTheUPnPErrorCodeAndDescription() async throws {
        let body = """
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><s:Fault><faultcode>s:Client</faultcode><faultstring>UPnPError</faultstring><detail><UPnPError xmlns="urn:schemas-upnp-org:control-1-0"><errorCode>711</errorCode><errorDescription>Illegal seek target</errorDescription></UPnPError></detail></s:Fault></s:Body></s:Envelope>
        """
        Mock(url: controlUrl, statusCode: 500, data: [.post: Data(body.utf8)]).register()

        do {
            try await service.post(action: "Seek", envelope: Envelope(body: "x"))
            XCTFail("a fault passed for success")
        }
        catch let ServiceParseError.soapFault(action, code, description) {
            XCTAssertEqual(action, "Seek")
            XCTAssertEqual(code, "711")
            XCTAssertEqual(description, "Illegal seek target")
        }
    }

    func testFaultWithoutDescriptionFallsBackToTheFaultString() async throws {
        let body = """
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body><s:Fault><faultcode>s:Client</faultcode><faultstring>UPnPError</faultstring><detail><UPnPError xmlns="urn:schemas-upnp-org:control-1-0"><errorCode>402</errorCode></UPnPError></detail></s:Fault></s:Body></s:Envelope>
        """
        Mock(url: controlUrl, statusCode: 500, data: [.post: Data(body.utf8)]).register()

        do {
            try await service.post(action: "Play", envelope: Envelope(body: "x"))
            XCTFail("a fault passed for success")
        }
        catch let ServiceParseError.soapFault(_, code, description) {
            XCTAssertEqual(code, "402")
            XCTAssertEqual(description, "UPnPError")
        }
    }

    func testSuccessIsNotAFault() async throws {
        let body = """
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"><s:Body><u:PlayResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1"/></s:Body></s:Envelope>
        """
        Mock(url: controlUrl, statusCode: 200, data: [.post: Data(body.utf8)]).register()

        try await service.post(action: "Play", envelope: Envelope(body: "x"))
    }
}
