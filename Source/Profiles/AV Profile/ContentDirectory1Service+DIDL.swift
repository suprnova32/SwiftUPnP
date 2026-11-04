//
//  ContentDirectory1Service+DIDL.swift
//
//  Copyright (c) 2023 Katoemba Software, (https://rigelian.net/)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//
//  Created by Berrie Kremers on 15/01/2023.
//

import Foundation
import XMLCoder
import os.log

public struct DIDLLite: Codable {
    public init(
        container: [DIDLContainer]? = nil, item: [DIDLItem]? = nil, desc: [DIDLDescription]? = nil
    ) {
        self.container = container
        self.item = item
        self.desc = desc
    }

    public let container: [DIDLContainer]?
    public let item: [DIDLItem]?
    public let desc: [DIDLDescription]?

    /// Sees every raw metadata string before it is sanitized and decoded, on whatever thread
    /// decodes it. A debug build of an app installs a recorder here to collect fixtures.
    nonisolated(unsafe) public static var rawMetadataObserver: ((String) -> Void)?

    /// The decoder every DIDL-Lite path uses: prefixed keys (`dc:title`, `upnp:class`, `r:streamInfo`),
    /// so namespace processing stays off. With it on, Foundation's parser reports local names and
    /// none of the keys match.
    static func decoder() -> XMLDecoder {
        let decoder = XMLDecoder()
        decoder.shouldProcessNamespaces = false
        // The parser delivers text around entity references in chunks; trimming each chunk drops a
        // whitespace-only one, so "a &amp; b" would decode as "a &b". Sonos sends single-line
        // DIDL with no decorative whitespace, so nothing is lost by keeping it all.
        decoder.trimValueWhitespaces = false
        return decoder
    }

    /// Sanitizes and decodes; throws the decoder's error unchanged so a caller can log or
    /// surface it. `from(_:)` is the logging, nil-returning wrapper.
    public static func decode(_ metadata: String) throws -> DIDLLite {
        rawMetadataObserver?(metadata)
        let sanitized = sanitize(metadata)
        guard let data = sanitized.data(using: .utf8) else { throw ServiceParseError.noValidResponse }
        return try decoder().decode(DIDLLite.self, from: data)
    }

    public static func from(_ metadata: String) -> DIDLLite? {
        do {
            return try decode(metadata)
        } catch DecodingError.dataCorrupted(let context) {
            Logger.swiftUPnP.error("\(metadata)")
            Logger.swiftUPnP.error("\(context.debugDescription)")
        } catch DecodingError.keyNotFound(let key, let context) {
            Logger.swiftUPnP.error("\(metadata)")
            Logger.swiftUPnP.error("\(key.stringValue) was not found, \(context.debugDescription)")
        } catch DecodingError.typeMismatch(let type, let context) {
            Logger.swiftUPnP.error("\(metadata)")
            Logger.swiftUPnP.error("\(type) was expected, \(context.debugDescription)")
        } catch DecodingError.valueNotFound(let type, let context) {
            Logger.swiftUPnP.error("\(metadata)")
            Logger.swiftUPnP.error("no value was found for \(type), \(context.debugDescription)")
        } catch {
            Logger.swiftUPnP.error("\(metadata)")
            Logger.swiftUPnP.error("Unknown error \(error.localizedDescription)")
        }

        return nil
    }

    /// Repairs what Sonos and NAS indexers send that XML 1.0 forbids: a bare `&` (an ampersand not
    /// starting an entity) becomes `&amp;`, and C0 control characters other than tab, LF and CR
    /// are dropped. Valid entities, including numeric ones, are left alone; idempotent.
    static func sanitize(_ xml: String) -> String {
        let escaped = Self.bareAmpersand.stringByReplacingMatches(
            in: xml, options: [], range: NSRange(xml.startIndex..., in: xml), withTemplate: "&amp;")
        guard escaped.unicodeScalars.contains(where: Self.isForbiddenControl) else { return escaped }
        var scalars = String.UnicodeScalarView()
        scalars.append(contentsOf: escaped.unicodeScalars.filter { !Self.isForbiddenControl($0) })
        return String(scalars)
    }

    /// An `&` that is not followed by a named or numeric entity reference.
    private static let bareAmpersand = try! NSRegularExpression(
        pattern: "&(?!(amp|lt|gt|quot|apos|#\\d+|#x[0-9a-fA-F]+);)", options: [])

    private static func isForbiddenControl(_ scalar: Unicode.Scalar) -> Bool {
        scalar.value < 0x20 && scalar != "\t" && scalar != "\n" && scalar != "\r"
    }

    public static func firstItem(_ metadata: String) -> DIDLItem? {
        guard let didl = from(metadata) else { return nil }
        guard let didlItems = didl.item, !didlItems.isEmpty else { return nil }

        return didlItems[0]
    }
}

public struct DIDLContainer: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case parentID
        case childCount
        case restricted
        case searchable

        case container
        case item
        case desc
        case res

        case `class` = "upnp:class"
        case title = "dc:title"
        case creator = "dc:creator"
        case date = "dc:date"
        case artist = "upnp:artist"
        case genre = "upnp:genre"
        case albumArtURI = "upnp:albumArtURI"
        case artistDiscographyURI = "upnp:artistDiscographyURI"
        case lyricsURI = "upnp:URI"
    }

    @Attribute public var id: String
    @Attribute public var parentID: String
    @Attribute public var childCount: Int?
    @Attribute public var restricted: Bool
    @Attribute public var searchable: Bool?

    public let container: [DIDLContainer]?
    public let item: [DIDLItem]?
    public let desc: [DIDLDescription]?
    public let res: [DIDLRes]?

    public let `class`: String?
    public let title: String?
    public let creator: String?
    public let date: String?
    public let artist: [DIDLArtist]?
    public let genre: String?
    /// Raw strings: Sonos sends relative paths (`/getaa?…`) the caller completes with the room's
    /// base URL, and one malformed value must not fail the whole container.
    public let albumArtURI: [String]?
    public let artistDiscographyURI: String?
    public let lyricsURI: String?

    public var albumArtURL: URL? { albumArtURI?.first.flatMap(URL.init(string:)) }
}

public struct DIDLItem: Codable, DynamicNodeDecoding, DynamicNodeEncoding {
    public init(
        id: String? = nil,
        refID: String? = nil,
        parentID: String? = nil,
        restricted: Bool? = nil,
        searchable: Bool? = nil,
        res: [DIDLRes]? = nil,
        desc: [DIDLDescription]? = nil,
        `class`: String? = nil,
        title: String? = nil,
        orig: String? = nil,
        date: String? = nil,
        album: String? = nil,
        artist: [DIDLArtist]? = nil,
        genre: String? = nil,
        playlist: String? = nil,
        albumArtURI: [String]? = nil,
        artistDiscographyURI: String? = nil,
        lyricsURI: String? = nil,
        originalTrackNumber: UInt32? = nil,
        originalDiscNumber: UInt32? = nil,
        streamInfo: String? = nil,
        creator: String? = nil,
        streamContent: String? = nil
    ) {
        self.id = id
        self.refID = refID
        self.parentID = parentID
        self.restricted = restricted
        self.searchable = searchable
        self.res = res
        self.desc = desc
        self.`class` = `class`
        self.title = title
        self.orig = orig
        self.date = date
        self.album = album
        self.artist = artist
        self.genre = genre
        self.playlist = playlist
        self.albumArtURI = albumArtURI
        self.artistDiscographyURI = artistDiscographyURI
        self.lyricsURI = lyricsURI
        self.originalTrackNumber = originalTrackNumber
        self.originalDiscNumber = originalDiscNumber
        self.streamInfo = streamInfo
        self.creator = creator
        self.streamContent = streamContent
    }

    enum CodingKeys: String, CodingKey {
        case id
        case refID
        case parentID
        case restricted
        case searchable

        case res
        case desc

        case `class` = "upnp:class"
        case title = "dc:title"
        case orig = "upnp:orig"
        case date = "dc:date"
        case album = "upnp:album"
        case artist = "upnp:artist"
        case genre = "upnp:genre"
        case playlist = "upnp:playlist"
        case albumArtURI = "upnp:albumArtURI"
        case artistDiscographyURI = "upnp:artistDiscographyURI"
        case lyricsURI = "upnp:URI"
        case originalTrackNumber = "upnp:originalTrackNumber"
        case originalDiscNumber = "upnp:originalDiscNumber"

        case streamInfo = "r:streamInfo"
        case creator = "dc:creator"
        case streamContent = "r:streamContent"
    }

    // Attributes
    public let id: String?
    public let refID: String?
    public let parentID: String?
    public let restricted: Bool?
    public let searchable: Bool?

    // Elements
    public let res: [DIDLRes]?
    public let desc: [DIDLDescription]?
    public let `class`: String?
    public let title: String?
    public let orig: String?
    public let date: String?
    public let album: String?
    public let artist: [DIDLArtist]?
    public let genre: String?
    public let playlist: String?
    /// Raw strings, see `DIDLContainer.albumArtURI`.
    public let albumArtURI: [String]?
    public let artistDiscographyURI: String?
    public let lyricsURI: String?
    public let originalTrackNumber: UInt32?
    public let originalDiscNumber: UInt32?
    public let streamInfo: String?
    public let creator: String?
    public let streamContent: String?

    public var resource: DIDLRes? { self.res?.first }
    public var albumArtURL: URL? { albumArtURI?.first.flatMap(URL.init(string:)) }

    static public func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key {
        case CodingKeys.id, CodingKeys.refID, CodingKeys.parentID, CodingKeys.restricted,
            CodingKeys.searchable:
            return .attribute
        default:
            return .element
        }
    }

    static public func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
        switch key {
        case CodingKeys.id, CodingKeys.refID, CodingKeys.parentID, CodingKeys.restricted,
            CodingKeys.searchable:
            return .attribute
        default:
            return .element
        }
    }
}

public struct DIDLDescription: Codable, Sendable, DynamicNodeDecoding {
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case nameSpace
        case value = ""
    }

    public let id: String?
    public let type: String?
    public let nameSpace: String?
    public let value: String?

    static public func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key {
        case CodingKeys.value:
            return .element
        default:
            return .attribute
        }
    }
}

public struct DIDLRes: Codable, DynamicNodeDecoding, DynamicNodeEncoding {
    public init(
        importUri: String? = nil,
        protocolInfo: String? = nil,
        size: UInt64? = nil,
        duration: String? = nil,
        bitrate: UInt? = nil,
        sampleFrequency: UInt? = nil,
        bitsPerSample: UInt? = nil,
        nrAudioChannels: UInt? = nil,
        colorDepth: UInt? = nil,
        protection: String? = nil,
        resolution: String? = nil,
        value: String? = nil
    ) {
        self.importUri = importUri
        self.protocolInfo = protocolInfo
        self.size = size
        self.duration = duration
        self.bitrate = bitrate
        self.sampleFrequency = sampleFrequency
        self.bitsPerSample = bitsPerSample
        self.nrAudioChannels = nrAudioChannels
        self.colorDepth = colorDepth
        self.protection = protection
        self.resolution = resolution
        self.value = value
    }

    enum CodingKeys: String, CodingKey {
        case importUri
        case protocolInfo
        case size
        case duration
        case bitrate
        case sampleFrequency
        case bitsPerSample
        case nrAudioChannels
        case colorDepth
        case protection
        case resolution
        case value = ""
    }

    // Attributes
    public let importUri: String?
    public let protocolInfo: String?
    public let size: UInt64?
    public let duration: String?
    public let bitrate: UInt?
    public let sampleFrequency: UInt?
    public let bitsPerSample: UInt?
    public let nrAudioChannels: UInt?
    public let colorDepth: UInt?
    public let protection: String?
    public let resolution: String?

    // Content: the resource URI as sent (`x-sonos-http:…`, `x-file-cifs://…`); a value that is not
    // a well-formed URL still decodes, so one odd resource does not fail the item.
    public let value: String?

    public var url: URL? { value.flatMap(URL.init(string:)) }

    static public func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key {
        case CodingKeys.value:
            return .element
        default:
            return .attribute
        }
    }

    static public func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
        switch key {
        case CodingKeys.value:
            return .element
        default:
            return .attribute
        }
    }
}

public struct DIDLArtist: Codable, DynamicNodeDecoding, DynamicNodeEncoding {
    public init(role: String? = nil, value: String? = nil) {
        self.role = role
        self.value = value
    }

    enum CodingKeys: String, CodingKey {
        case role
        case value = ""
    }

    public let role: String?
    public let value: String?

    static public func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        switch key {
        case CodingKeys.value:
            return .element
        default:
            return .attribute
        }
    }

    static public func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
        switch key {
        case CodingKeys.value:
            return .element
        default:
            return .attribute
        }
    }
}

public struct BrowseDIDLResponse {
    public let container: [DIDLContainer]?
    public let item: [DIDLItem]?

    public let numberReturned: UInt32
    public let totalMatches: UInt32
    public let updateID: UInt32
}

public struct SearchDIDLResponse {
    public let container: [DIDLContainer]?
    public let item: [DIDLItem]?

    public let numberReturned: UInt32
    public let totalMatches: UInt32
    public let updateID: UInt32
}

extension ContentDirectory1Service {
    public func browseDIDL(
        objectID: String, browseFlag: A_ARG_TYPE_BrowseFlagEnum, filter: String,
        startingIndex: UInt32, requestedCount: UInt32, sortCriteria: String
    ) async throws -> BrowseDIDLResponse {
        let response = try await browse(
            objectID: objectID,
            browseFlag: browseFlag,
            filter: filter,
            startingIndex: startingIndex,
            requestedCount: requestedCount,
            sortCriteria: sortCriteria)

        let didl = try DIDLLite.decode(response.result)

        return BrowseDIDLResponse(
            container: didl.container,
            item: didl.item,
            numberReturned: response.numberReturned,
            totalMatches: response.totalMatches,
            updateID: response.updateID)
    }

    public func searchDIDL(
        containerID: String, searchCriteria: String, filter: String, startingIndex: UInt32,
        requestedCount: UInt32, sortCriteria: String
    ) async throws -> SearchDIDLResponse {
        let response = try await search(
            containerID: containerID,
            searchCriteria: searchCriteria,
            filter: filter,
            startingIndex: startingIndex,
            requestedCount: requestedCount,
            sortCriteria: sortCriteria)

        let didl = try DIDLLite.decode(response.result)

        return SearchDIDLResponse(
            container: didl.container,
            item: didl.item,
            numberReturned: response.numberReturned,
            totalMatches: response.totalMatches,
            updateID: response.updateID)
    }
}
