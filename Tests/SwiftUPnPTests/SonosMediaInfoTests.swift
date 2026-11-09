//
// Product: SwiftUPnP
// Package: SwiftUPnPTests
//
// Sonos answers GetMediaInfo with RecordMedium NOT_IMPLEMENTED. The response must decode: the
// transport's current URI is how a caller tells a room on its queue from one on another source.
//

import XCTest
import Mocker
@testable import SwiftUPnP

final class SonosMediaInfoTests: XCTestCase {
    private let controlUrl = URL(string: "http://127.0.0.1:1400/MediaRenderer/AVTransport/MediaInfoControl")!
    private var service: AVTransport1!

    override func setUp() {
        super.setUp()
        // `postWithResult` goes through the shared session
        URLProtocol.registerClass(MockingURLProtocol.self)
        let device = UPnPDevice(uuid: "uuid:test-device", deviceId: "urn:test:device:Source:1", deviceType: "urn:test:device:Source:1",
                                url: URL(string: "http://127.0.0.1:1400/desc.xml")!, lastSeen: Date())
        service = AVTransport1(device: device,
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

    private func mock(_ inner: String) {
        let body = """
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:GetMediaInfoResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">\(inner)</u:GetMediaInfoResponse></s:Body></s:Envelope>
        """
        Mock(url: controlUrl, statusCode: 200, data: [.post: Data(body.utf8)]).register()
    }

    func testARoomOnAStationDecodes() async throws {
        // As captured from a speaker playing an Apple Music station (ids shortened)
        mock("<NrTracks>7</NrTracks><MediaDuration>NOT_IMPLEMENTED</MediaDuration><CurrentURI>x-sonosapi-radio:radio%3ara.u-3af3ce43?sid=204&amp;flags=0&amp;sn=15</CurrentURI><CurrentURIMetaData></CurrentURIMetaData><NextURI></NextURI><NextURIMetaData></NextURIMetaData><PlayMedium>NETWORK</PlayMedium><RecordMedium>NOT_IMPLEMENTED</RecordMedium><WriteStatus>NOT_IMPLEMENTED</WriteStatus>")

        let info = try await service.getMediaInfo(instanceID: 0)
        XCTAssertEqual(info.currentURI, "x-sonosapi-radio:radio%3ara.u-3af3ce43?sid=204&flags=0&sn=15")
        XCTAssertEqual(info.nrTracks, 7)
        XCTAssertEqual(info.playMedium, .network)
        XCTAssertEqual(info.recordMedium, .notImplemented)
    }

    func testARoomOnItsQueueDecodes() async throws {
        mock("<NrTracks>13</NrTracks><MediaDuration>NOT_IMPLEMENTED</MediaDuration><CurrentURI>x-rincon-queue:RINCON_AAA01400#0</CurrentURI><CurrentURIMetaData></CurrentURIMetaData><NextURI></NextURI><NextURIMetaData></NextURIMetaData><PlayMedium>NETWORK</PlayMedium><RecordMedium>NOT_IMPLEMENTED</RecordMedium><WriteStatus>NOT_IMPLEMENTED</WriteStatus>")

        let info = try await service.getMediaInfo(instanceID: 0)
        XCTAssertTrue(info.currentURI.hasPrefix("x-rincon-queue:"))
        XCTAssertEqual(info.nrTracks, 13)
    }

    func testAnIdleRoomDecodes() async throws {
        mock("<NrTracks>0</NrTracks><MediaDuration>NOT_IMPLEMENTED</MediaDuration><CurrentURI></CurrentURI><CurrentURIMetaData></CurrentURIMetaData><NextURI></NextURI><NextURIMetaData></NextURIMetaData><PlayMedium>NONE</PlayMedium><RecordMedium>NOT_IMPLEMENTED</RecordMedium><WriteStatus>NOT_IMPLEMENTED</WriteStatus>")

        let info = try await service.getMediaInfo(instanceID: 0)
        XCTAssertEqual(info.currentURI, "")
        XCTAssertEqual(info.playMedium, AVTransport1.PlaybackStorageMediumEnum.none)
    }
}
