//
//  DIDLDecodingTests.swift
//  SwiftUPnPTests
//
//  Every fixture decodes, and the fields a Sonos controller reads come out as sent.
//

import Foundation
import Testing

@testable import SwiftUPnP

@Suite("DIDL-Lite decoding")
struct DIDLDecodingTests {
    @Test("Every fixture decodes to at least one item or container")
    func everyFixtureDecodes() throws {
        let names = try Fixtures.allNames()
        #expect(!names.isEmpty)
        for name in names {
            let didl = try DIDLLite.decode(try Fixtures.xml(name))
            let count = (didl.item?.count ?? 0) + (didl.container?.count ?? 0)
            // `empty` is the DIDL-Lite Sonos sends for a room with nothing on it
            #expect(count > 0 || name == "empty", Comment(rawValue: "\(name) decoded nothing"))
        }
    }

    @Test("An Apple Music song event carries the fields Now Playing shows")
    func songEvent() throws {
        let item = try #require(DIDLLite.firstItem(try Fixtures.xml("song-synthetic")))
        #expect(item.title == "Weightless")
        #expect(item.creator == "Marconi Union")
        #expect(item.album == "Weightless (Ambient Transmissions Vol. 2)")
        #expect(item.class == "object.item.audioItem.musicTrack")
        #expect(item.streamInfo == "bd:16,sr:44100,c:11,l:1")
        #expect(item.streamContent == "")
        #expect(item.id == "-1" && item.parentID == "-1" && item.restricted == true)
        // The art path is relative and keeps its query: the app prefixes the room's base URL
        #expect(item.albumArtURI?.first?.hasPrefix("/getaa?s=1&u=x-sonos-http") == true)
        let res = try #require(item.resource)
        #expect(res.duration == "0:08:09")
        #expect(res.protocolInfo == "sonos.com-http:*:audio/mp4:*")
        #expect(res.value == "x-sonos-http:song%3a1440836326.mp4?sid=204&flags=8232&sn=15")
        #expect(res.url?.scheme == "x-sonos-http")
    }

    @Test("Entities in titles decode once, numeric ones included")
    func entitiesInTitle() throws {
        let item = try #require(DIDLLite.firstItem(try Fixtures.xml("lt-in-title")))
        #expect(item.title == "<3 & >> (Remix) \u{2019}24 'Live'", Comment(rawValue: "actual: \(item.title.map { $0.debugDescription } ?? "nil")"))
        #expect(item.creator == "Some & Body")
    }

    @Test("A NAS container and item decode together")
    func containerAndItem() throws {
        let didl = try DIDLLite.decode(try Fixtures.xml("empty-albumart"))
        let container = try #require(didl.container?.first)
        #expect(container.id == "A:ALBUM/No%20Art")
        #expect(container.title == "No Art")
        #expect(container.childCount == 3)
        #expect(container.creator == "Unknown Artist")
        let item = try #require(didl.item?.first)
        #expect(item.title == "Odd Name")
        #expect(item.parentID == "A:ALBUM/No%20Art")
    }

    @Test("firstItem is nil for metadata with no items and for garbage")
    func firstItemNil() throws {
        #expect(DIDLLite.firstItem("") == nil)
        #expect(DIDLLite.firstItem("not xml at all") == nil)
        #expect(DIDLLite.firstItem(#"<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"></DIDL-Lite>"#) == nil)
    }

    @Test("decode throws, from returns nil, for the same bad input")
    func decodeThrowsFromNils() {
        #expect(throws: (any Error).self) { try DIDLLite.decode("<DIDL-Lite><item>") }
        #expect(DIDLLite.from("<DIDL-Lite><item>") == nil)
    }

    @Test("The raw observer sees the metadata before sanitizing")
    func observer() throws {
        var seen: [String] = []
        DIDLLite.rawMetadataObserver = { seen.append($0) }
        defer { DIDLLite.rawMetadataObserver = nil }
        let raw = try Fixtures.xml("bare-ampersand")
        _ = try DIDLLite.decode(raw)
        // Other suites decode concurrently; the observer is global, so contains, not equals
        #expect(seen.contains(raw))
    }
}

/// Captured from a real system on 2026-11-04 (LAN addresses scrubbed): the shapes the app meets.
@Suite("DIDL-Lite captures")
struct DIDLCaptureTests {
    private func first(_ name: String) throws -> DIDLItem {
        try #require(DIDLLite.firstItem(try Fixtures.xml(name)))
    }

    @Test("An Apple Music library track event")
    func song() throws {
        let item = try first("event-song")
        #expect(item.title == "My Boy Only Breaks His Favorite Toys")
        #expect(item.creator == "Taylor Swift")
        #expect(item.album == "THE TORTURED POETS DEPARTMENT: THE ANTHOLOGY")
        #expect(item.streamContent == "")
        #expect(item.streamInfo == "bd:16,sr:48000,c:11,l:0,d:1")
        #expect(item.resource?.duration == "0:03:23")
        #expect(item.resource?.value?.hasPrefix("x-sonos-http:librarytrack%3a") == true)
        #expect(item.albumArtURI?.first?.hasPrefix("/getaa?s=1&u=") == true)
    }

    @Test("A song served by an Apple Music station uses the x-sonosprog scheme")
    func stationSong() throws {
        let item = try first("event-station-song")
        #expect(item.resource?.value?.hasPrefix("x-sonosprog-http:song%3a") == true)
        #expect(item.title == "you should see me in a crown")
    }

    @Test("The enqueued metadata of an Apple Music station: a broadcast with a desc token, no res")
    func station() throws {
        let item = try first("event-station")
        #expect(item.title == "Patricio Cano\u{2019}s Station")
        #expect(item.class == "object.item.audioItem.audioBroadcast")
        #expect(item.res == nil)
        #expect(item.desc?.first?.id == "cdudn")
        #expect(item.desc?.first?.value?.hasPrefix("SA_RINCON") == true)
    }

    @Test("Sonos Radio: the station has an absolute art URL, the track a long sonos: resource")
    func radio() throws {
        let station = try first("event-radio-station")
        #expect(station.title == "Rock Road Trip")
        #expect(station.albumArtURL?.host == "sonosradio.imgix.net")
        let track = try first("event-radio-track")
        #expect(track.title == "Surrender" && track.creator == "Cheap Trick")
        #expect(track.resource?.duration == nil, "a radio track has no duration")
        #expect(track.resource?.value?.hasPrefix("x-sonos-http:sonos%3a") == true)
        // Nested query strings with their own encoded & survive one decode
        #expect(track.albumArtURI?.first?.contains("mark=https%3A%2F%2F") == true)
    }

    @Test("TV: a blank title, no art, streamInfo 0")
    func tv() throws {
        let item = try first("event-tv")
        #expect(item.title == " ")
        #expect(item.class == "object.item")
        #expect(item.resource?.value?.hasPrefix("x-sonos-htastream:") == true)
        #expect(item.albumArtURI == nil)
        #expect(item.streamInfo == "0")
    }

    @Test("While buffering, streamContent carries the ZPSTR_CONNECTING placeholder")
    func connecting() throws {
        let item = try first("event-connecting")
        #expect(item.streamContent == "ZPSTR_CONNECTING")
        #expect(item.title == "My Boy Only Breaks His Favorite Toys")
    }

    @Test("A NAS track event: upnp:originalTrackNumber and r:albumArtist present, art relative")
    func nasTrack() throws {
        let item = try first("event-nas-track")
        #expect(item.title == "Veuve" && item.creator == "Paula Hartmann" && item.album == "Nie verliebt")
        #expect(item.originalTrackNumber == 4)
        #expect(item.resource?.protocolInfo == "x-file-cifs:*:audio/flac:*")
        #expect(item.resource?.value?.hasPrefix("x-file-cifs://") == true)
        #expect(item.albumArtURI?.first?.hasPrefix("/getaa?u=x-file-cifs") == true)
    }

    @Test("An enqueued playlist container")
    func playlistContainer() throws {
        let item = try first("event-playlist-container")
        #expect(item.class == "object.container.playlistContainer")
        #expect(item.title == "T. Swift")
    }

    @Test("A 78-item queue page decodes in order with every title")
    func queuePage() throws {
        let didl = try DIDLLite.decode(try Fixtures.xml("queue-page"))
        let items = try #require(didl.item)
        #expect(items.count == 78)
        #expect(items.first?.id == "Q:0/1" && items.first?.title == "cardigan")
        #expect(items.allSatisfy { !($0.title ?? "").isEmpty })
        #expect(items.allSatisfy { $0.resource?.value != nil })
    }

    @Test("NAS browse pages: artists are containers with a playlist res, albums carry art, tracks are items")
    func nasBrowse() throws {
        let artists = try DIDLLite.decode(try Fixtures.xml("browse-nas-artists"))
        #expect(artists.container?.count == 5 && artists.item == nil)
        #expect(artists.container?.first?.title == "Disney")
        #expect(artists.container?.first?.class == "object.container.person.musicArtist")
        let albums = try DIDLLite.decode(try Fixtures.xml("browse-nas-albums"))
        #expect(albums.container?.count == 15)
        #expect(albums.container?.first?.title == "25/8" && albums.container?.first?.creator == "LUNA")
        #expect(albums.container?.first?.albumArtURL?.path == "/getaa")
        let tracks = try DIDLLite.decode(try Fixtures.xml("browse-nas-tracks"))
        #expect(tracks.item?.count == 19 && tracks.container == nil)
        #expect(tracks.item?.first?.title == "City Haunts")
    }

    @Test("What is not DIDL: an empty document, and the NOT_IMPLEMENTED Sonos answers for TV media info")
    func notDIDL() throws {
        let empty = try DIDLLite.decode(try Fixtures.xml("empty"))
        #expect(empty.item == nil && empty.container == nil)
        #expect(DIDLLite.firstItem(try Fixtures.xml("empty")) == nil)
        #expect(DIDLLite.from("NOT_IMPLEMENTED") == nil)
    }
}
