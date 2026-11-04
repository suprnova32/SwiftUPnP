//
//  Fixtures.swift
//  SwiftUPnPTests
//
//  Raw metadata as Sonos speakers and NAS indexers send it. Files named `event-*`, `queue-*`,
//  `position-info-*`, `media-info-*` and `browse-*` are captures from a real system; the others
//  are hand-written for one malformation each.
//

import Foundation

enum Fixtures {
    static func xml(_ name: String) throws -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: "xml", subdirectory: "Fixtures") else {
            throw FixtureError.missing(name)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// Every fixture in the folder, by name, for the "all of them decode" sweep.
    static func allNames() throws -> [String] {
        guard let folder = Bundle.module.url(forResource: "Fixtures", withExtension: nil) else {
            throw FixtureError.missing("Fixtures")
        }
        return try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "xml" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }

    enum FixtureError: Error { case missing(String) }
}
