//
//  DIDLSanitizeTests.swift
//  SwiftUPnPTests
//
//  The repairs applied before decoding: bare ampersands and control characters.
//

import Foundation
import Testing

@testable import SwiftUPnP

@Suite("DIDL-Lite sanitizer")
struct DIDLSanitizeTests {
    @Test("A bare ampersand is escaped; entities are left alone")
    func bareAmpersand() {
        #expect(DIDLLite.sanitize("Simon & Garfunkel") == "Simon &amp; Garfunkel")
        #expect(DIDLLite.sanitize("a &amp; b &lt; c &gt; d &quot;e&quot; &apos;f&apos;") == "a &amp; b &lt; c &gt; d &quot;e&quot; &apos;f&apos;")
        #expect(DIDLLite.sanitize("&#39; &#x2019; &#8217;") == "&#39; &#x2019; &#8217;")
        // Only the bare one in a mixed string
        #expect(DIDLLite.sanitize("&amp; & &#39; &") == "&amp; &amp; &#39; &amp;")
        // A query string inside an attribute or text
        #expect(DIDLLite.sanitize("/getaa?u=x&v=12") == "/getaa?u=x&amp;v=12")
    }

    @Test("Control characters are dropped, tab / LF / CR kept")
    func controlCharacters() {
        #expect(DIDLLite.sanitize("a\u{01}b\u{1F}c\u{08}d") == "abcd")
        #expect(DIDLLite.sanitize("a\tb\nc\r\nd") == "a\tb\nc\r\nd")
        // Non-ASCII is untouched
        #expect(DIDLLite.sanitize("Café — ‘quoted’ 日本") == "Café — ‘quoted’ 日本")
    }

    @Test("Sanitizing is idempotent")
    func idempotent() throws {
        for name in try Fixtures.allNames() {
            let once = DIDLLite.sanitize(try Fixtures.xml(name))
            #expect(DIDLLite.sanitize(once) == once, Comment(rawValue: name))
        }
    }

    @Test("A bare ampersand in text, in an attribute and in a resource URI all decode")
    func bareAmpersandFixture() throws {
        let item = try #require(DIDLLite.firstItem(try Fixtures.xml("bare-ampersand")))
        #expect(item.title == "Mrs. Robinson & Friends")
        #expect(item.creator == "Simon & Garfunkel")
        #expect(item.id == "S://nas/music/Simon%20&%20Garfunkel/01.flac")
        #expect(item.resource?.value == "x-file-cifs://nas/music/Simon & Garfunkel/01.flac")
        #expect(item.albumArtURI?.first?.hasSuffix("&v=12") == true)
        #expect(item.originalTrackNumber == 1)
    }

    @Test("Control characters in tags decode to the clean text")
    func controlCharFixture() throws {
        let item = try #require(DIDLLite.firstItem(try Fixtures.xml("control-char")))
        #expect(item.title == "Taggedwithcontrol\tchars")
        #expect(item.creator == "BadTagger")
    }
}
