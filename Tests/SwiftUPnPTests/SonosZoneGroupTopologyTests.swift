//
// Product: SwiftUPnP
// Package: SwiftUPnPTests
//
// A Sonos ZoneGroupTopology event: the ZoneGroupState a player sends when a room joins or leaves a
// group. The ids, names and addresses are made up; the shape is a player's (firmware 98.0).
//

import XCTest
@testable import SwiftUPnP

final class SonosZoneGroupTopologyTests: XCTestCase {
    private func service() -> ZoneGroupTopology1Service {
        let device = UPnPDevice(uuid: "uuid:RINCON_TEST000000001400", deviceId: "urn:schemas-upnp-org:device:ZonePlayer:1",
                                deviceType: "urn:schemas-upnp-org:device:ZonePlayer:1",
                                url: URL(string: "http://127.0.0.1:1400/xml/device_description.xml")!, lastSeen: Date())
        return ZoneGroupTopology1Service(device: device,
                                         controlUrl: URL(string: "http://127.0.0.1:1400/ZoneGroupTopology/Control")!,
                                         scpdUrl: URL(string: "http://127.0.0.1:1400/xml/ZoneGroupTopology1.xml")!,
                                         eventUrl: URL(string: "http://127.0.0.1:1400/ZoneGroupTopology/Event"),
                                         serviceType: "urn:schemas-upnp-org:service:ZoneGroupTopology:1",
                                         serviceId: "urn:upnp-org:serviceId:ZoneGroupTopology")
    }

    func testEventCarriesTheZoneGroupState() throws {
        // The state is escaped XML inside the property, as a player sends it
        let event = """
        <e:propertyset xmlns:e="urn:schemas-upnp-org:event-1-0">\
        <e:property><ZoneGroupState>&lt;ZoneGroupState&gt;&lt;ZoneGroups&gt;\
        &lt;ZoneGroup Coordinator="RINCON_A00000000001400" ID="RINCON_A00000000001400:1"&gt;\
        &lt;ZoneGroupMember UUID="RINCON_A00000000001400" Location="http://10.0.0.2:1400/xml/device_description.xml" ZoneName="Office"/&gt;\
        &lt;ZoneGroupMember UUID="RINCON_B00000000001400" Location="http://10.0.0.3:1400/xml/device_description.xml" ZoneName="Kitchen"/&gt;\
        &lt;/ZoneGroup&gt;&lt;/ZoneGroups&gt;&lt;/ZoneGroupState&gt;</ZoneGroupState></e:property>\
        <e:property><ZoneGroupName>Office</ZoneGroupName></e:property>\
        <e:property><ZoneGroupID>RINCON_A00000000001400:1</ZoneGroupID></e:property>\
        <e:property><ZonePlayerUUIDsInGroup>RINCON_A00000000001400,RINCON_B00000000001400</ZonePlayerUUIDsInGroup></e:property>\
        </e:propertyset>
        """
        let state = try service().state(xml: Data(event.utf8))
        let groupState = try XCTUnwrap(state.zoneGroupState)
        XCTAssertTrue(groupState.hasPrefix("<ZoneGroupState><ZoneGroups>"))
        XCTAssertTrue(groupState.contains(#"ZoneName="Kitchen""#))
        XCTAssertEqual(state.zoneGroupName, "Office")
        XCTAssertEqual(state.zonePlayerUUIDsInGroup, "RINCON_A00000000001400,RINCON_B00000000001400")
    }

    func testRegistryMakesTheTypedService() async throws {
        let device = UPnPDevice(uuid: "uuid:RINCON_TEST000000001400", deviceId: "urn:schemas-upnp-org:device:ZonePlayer:1",
                                deviceType: "urn:schemas-upnp-org:device:ZonePlayer:1",
                                url: URL(string: "http://127.0.0.1:1400/xml/device_description.xml")!, lastSeen: Date())
        let definition = Service(serviceType: "urn:schemas-upnp-org:service:ZoneGroupTopology:1",
                                 serviceId: "urn:upnp-org:serviceId:ZoneGroupTopology",
                                 SCPDURL: "/xml/ZoneGroupTopology1.xml",
                                 controlURL: "/ZoneGroupTopology/Control",
                                 eventSubURL: "/ZoneGroupTopology/Event")
        let typed = UPnPRegistry.typedService(device: device, deviceService: definition)
        XCTAssertTrue(typed is ZoneGroupTopology1Service)
    }
}
