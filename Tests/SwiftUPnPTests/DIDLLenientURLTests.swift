//
//  DIDLLenientURLTests.swift
//  SwiftUPnPTests
//
//  A URI that is not a well-formed URL costs that one field, never the item or the page.
//

import Foundation
import Testing

@testable import SwiftUPnP

@Suite("DIDL-Lite lenient URIs")
struct DIDLLenientURLTests {
    @Test("An empty albumArtURI decodes; the URL accessor is nil")
    func emptyAlbumArt() throws {
        let didl = try DIDLLite.decode(try Fixtures.xml("empty-albumart"))
        let container = try #require(didl.container?.first)
        #expect(container.albumArtURI == [""])
        #expect(container.albumArtURL == nil)
        let item = try #require(didl.item?.first)
        #expect(item.albumArtURL == nil)
        #expect(item.title == "Odd Name")
    }

    @Test("A resource value with spaces, braces and bars decodes as text; url is best effort")
    func oddResourceValue() throws {
        let item = try #require(DIDLLite.firstItem(try Fixtures.xml("empty-albumart")))
        let res = try #require(item.resource)
        #expect(res.value == "x-file-cifs://nas/music/odd name {with} |bars|.flac")
        #expect(res.duration == "0:04:00")
        // Foundation may or may not percent-encode this into a URL; either way the item decoded
        _ = res.url
    }

    @Test("Several albumArtURI elements decode as a list in order")
    func repeatedAlbumArt() throws {
        let xml = """
        <DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"><item id="1" parentID="0" restricted="true"><dc:title>Two covers</dc:title><upnp:albumArtURI>/getaa?a=1</upnp:albumArtURI><upnp:albumArtURI>http://example.com/cover.jpg</upnp:albumArtURI></item></DIDL-Lite>
        """
        let item = try #require(DIDLLite.firstItem(xml))
        #expect(item.albumArtURI == ["/getaa?a=1", "http://example.com/cover.jpg"])
        #expect(item.albumArtURL?.path == "/getaa")
    }

    @Test("A desc element keeps its namespace string and token")
    func descriptor() throws {
        let xml = """
        <DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"><item id="1" parentID="0" restricted="true"><dc:title>With desc</dc:title><desc id="cdudn" nameSpace="urn:schemas-rinconnetworks-com:metadata-1-0/">SA_RINCON52231_X_#Svc52231-b224bb86-Token</desc></item></DIDL-Lite>
        """
        let item = try #require(DIDLLite.firstItem(xml))
        let desc = try #require(item.desc?.first)
        #expect(desc.id == "cdudn")
        #expect(desc.nameSpace == "urn:schemas-rinconnetworks-com:metadata-1-0/")
        #expect(desc.value == "SA_RINCON52231_X_#Svc52231-b224bb86-Token")
    }
}
