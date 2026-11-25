//
//  UPnPRegistry.swift
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
//  Created by Berrie Kremers on 08/01/2023.
//

import Foundation
import Combine
import os.log

public class UPnPRegistry {
    public static let shared = UPnPRegistry()
    
    // Use CocoaAsyncSocket discovery for SSDP, as the standard network framework doesn't support when
    // multiple apps connect to the same multicast port (see https://developer.apple.com/forums/thread/716339)
    //private let discoveryEngine = SSDPNetworkDiscovery()
    private let discoveryEngine = SSDPCocoaAsyncSocketDiscovery()

    @MainActor
    private var devices = [UPnPDevice]()
    /// Devices whose description and services are being loaded.
    private var loadingDevices = Set<ObjectIdentifier>()
    private var deviceAddedSubject = PassthroughSubject<UPnPDevice, Never>()
    // devices are always delivered on the main thread.
    public var deviceAdded: AnyPublisher<UPnPDevice, Never> {
        deviceAddedSubject.receive(on: RunLoop.main).eraseToAnyPublisher()
    }
    public var deviceAddedStream: AsyncStream<UPnPDevice> {
        deviceAdded.stream
    }

    private var deviceRemovedSubject = PassthroughSubject<UPnPDevice, Never>()
    // devices are always delivered on the main thread.
    public var deviceRemoved: AnyPublisher<UPnPDevice, Never> {
        deviceRemovedSubject.receive(on: RunLoop.main).eraseToAnyPublisher()
    }
    public var deviceRemovedStream: AsyncStream<UPnPDevice> {
        deviceRemoved.stream
    }
    
    private let httpServer = HTTPServer()
    private let httpServerPortRange: Range<UInt16>
    private var httpServerPort: UInt16
    private let eventCallBackPath = "/Event/\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
    internal var eventCallbackUrl: URL?
    private let eventSubject = PassthroughSubject<(String, Data), Never>()
    internal lazy var eventPublisher: AnyPublisher<(String, Data), Never> = {
        eventSubject.share().eraseToAnyPublisher()
    }()

    init(httpServerPortRange: Range<UInt16> = 51000..<51099) {
        self.httpServerPortRange = httpServerPortRange
        httpServerPort = IPHelper.freePortFromRange(range: httpServerPortRange)

        httpServer.handler = { [weak self] request in
            guard let self else { return .internalServerError("Self released") }
            guard request.path == self.eventCallBackPath else { return .notFound() }
            guard request.method == "NOTIFY" else { return .internalServerError("Only handling NOTIFY") }

            if let sid = request.header("SID") {
                self.eventSubject.send((sid, request.body))
            }

            return .ok()
        }
        // A listener that stops accepting connections is the one cause of events drying up that
        // nothing else notices: the subscriptions stay valid and keep being renewed happily.
        httpServer.onFailure = { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let stops = self?.httpServerStops else { return }
                // The network is usually still settling when the listener drops out.
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                // Stopped on purpose meanwhile (discovery stopped, or the demo took over): that counts.
                guard let self, self.httpServerStops == stops else { return }
                await self.startHTTPServer()
            }
        }

        eventCallbackUrl = callbackUrl()
    }

    /// Start discovering devices of the given types, and search for them. Calling this while
    /// discovery is already running sends a fresh search.
    public func startDiscovery(_ types: [String] = ["urn:schemas-upnp-org:device:MediaServer:1", "urn:linn-co-uk:device:Source:1", "urn:av-openhome-org:device:Source:1"]) {
        let filteredTypes = types.filter { $0.contains(":device:") }
        if filteredTypes.count != types.count {
            Logger.swiftUPnP.error("Only device types are discovered, service types will be discovered indirectly from the device description. Non-device types are ignored.")
        }
        guard !filteredTypes.isEmpty else { return }

        // A stop that comes after this call wins, also when it comes while the listener below is
        // still starting: otherwise discovery would begin after it (searching the network while a
        // demo runs, for one).
        let generation = discoveryGeneration
        // The discovery engine keeps its state on the main queue, like its socket callbacks.
        Task { @MainActor in
            guard generation == discoveryGeneration else { return }
            await startHTTPServerIfNotRunning()
            guard generation == discoveryGeneration else { return }
            do {
                try discoveryEngine.startDiscovery(forTypes: filteredTypes)
            }
            catch UPnPError.alreadyConnected {
                // Already listening: a repeated start is a request for a new search.
            }
            catch {
                Logger.swiftUPnP.error("Couldn't start discovery: \(error.localizedDescription)")
                return
            }
            discoveryEngine.searchRequest()
        }
    }
    
    public func stopDiscovery() {
        let generation = nextDiscoveryGeneration()
        Task { @MainActor in
            // A later stop already did this, and devices may have been added after it.
            guard generation == discoveryGeneration else { return }
            tearDownDiscovery()
        }
    }

    /// ``stopDiscovery()`` for a caller that adds devices right after: it returns once the devices
    /// are gone, where ``stopDiscovery()`` clears them later and could drop a device added meanwhile.
    /// A ``startDiscovery(_:)`` or ``stopDiscovery()`` asked for before it doesn't act after it.
    /// Like ``stopDiscovery()`` it stops the event listener; adding a device starts it again.
    @MainActor
    public func stopDiscoveryNow() {
        nextDiscoveryGeneration()
        tearDownDiscovery()
    }

    @MainActor
    private func tearDownDiscovery() {
        discoveryEngine.stopDiscovery()
        stopHTTPServer()
        devices.removeAll(keepingCapacity: false)
    }

    /// Bumped by every stop of discovery, so that a start or stop asked for before a later stop
    /// doesn't act after it. Read and bumped from any thread, hence the lock.
    private let discoveryGenerationLock = NSLock()
    private var _discoveryGeneration = 0

    private var discoveryGeneration: Int {
        discoveryGenerationLock.lock(); defer { discoveryGenerationLock.unlock() }
        return _discoveryGeneration
    }

    @discardableResult
    private func nextDiscoveryGeneration() -> Int {
        discoveryGenerationLock.lock(); defer { discoveryGenerationLock.unlock() }
        _discoveryGeneration += 1
        return _discoveryGeneration
    }
    
    @MainActor
    internal func startHTTPServerIfNotRunning() async {
        guard !httpServer.isRunning else {
            // Up, but possibly started before there was an address to put in the callback url
            if eventCallbackUrl == nil {
                publishCallbackUrl()
            }
            return
        }
        await startHTTPServer()
    }

    /// Make sure events can reach us again after the app was in the background or the network
    /// changed: the url the devices post to contains our ip address and port, and a listener may
    /// have been torn down while nobody was looking.
    ///
    /// Nothing happens when the listener is up and the address is the one the devices know. Otherwise
    /// the listener is restarted, and every active subscription is made anew, because renewals carry
    /// only the subscription id and would leave the devices posting to the old url.
    @MainActor
    public func recoverEventDelivery() async {
        let known = eventCallbackUrl
        if httpServer.isRunning, let known, callbackUrl() == known {
            return
        }

        Logger.swiftUPnP.notice("Rebuilding the event delivery path")
        await startHTTPServer()

        for service in knownServices() where service.subscriptionStatus == .subscribed || service.subscriptionStatus == .renewing {
            await service.resubscribeToEvents()
        }
    }

    /// Work out the callback url from the current address and hand it to every known service.
    @MainActor
    private func publishCallbackUrl() {
        eventCallbackUrl = callbackUrl()
        if let eventCallbackUrl = eventCallbackUrl {
            for service in knownServices() {
                service.eventCallbackUrl = eventCallbackUrl
            }
        }
    }

    /// Serializes the starts, so that a recovery that overlaps with a service asking for a server
    /// doesn't end up with two listeners fighting over the same port.
    @MainActor
    private var startTask: Task<Void, Never>?
    /// Bumped by every ``stopHTTPServer()``, so that a start can tell whether it was asked for before
    /// or after a stop that called off the start it joined.
    @MainActor
    private var httpServerStops = 0

    @MainActor
    internal func startHTTPServer() async {
        let stopsWhenAsked = httpServerStops
        while let pending = startTask {
            await pending.value
            // A start that a stop called off stopped its listener again. A caller that asked before
            // that stop is answered by it; one that asked after it (a service of a device added right
            // after the stop) still needs a listener, and starts one once the called-off start has
            // wound down, so that two starts never run side by side.
            guard pending.isCancelled, httpServerStops == stopsWhenAsked else { return }
            if startTask == pending {
                startTask = nil
            }
        }

        let task = Task { @MainActor in
            await bindHTTPServer()
        }
        startTask = task
        await task.value
        // A caller that joined a called-off start may have started the next one already.
        if startTask == task {
            startTask = nil
        }
    }

    /// Listen on a port from the range this registry was created with, and hand every known service
    /// the callback url that events will arrive on.
    @MainActor
    private func bindHTTPServer() async {
        for attempt in 0..<10 {
            guard Task.isCancelled == false else { return }

            // The port that was picked at startup is tried first, so that the callback url stays the
            // same across a restart of the server whenever it can.
            let port = attempt == 0 ? httpServerPort : IPHelper.freePortFromRange(range: httpServerPortRange)
            guard port != 0 else { continue }

            do {
                // Events that come back over loopback only need a loopback listener, and that one
                // also works without any network (a listener on every interface waits for one).
                try await httpServer.start(port: port, loopbackOnly: Self.isLoopback(callbackHostOverride))

                // Binding is not instant, and discovery may have been stopped while it was underway.
                guard Task.isCancelled == false else {
                    httpServer.stop()
                    return
                }

                httpServerPort = port
                publishCallbackUrl()
                return
            }
            catch {
                Logger.swiftUPnP.error("Couldn't start http server on port \(port)")
                Logger.swiftUPnP.error("\(error.localizedDescription)")
            }
        }

        Logger.swiftUPnP.error("Couldn't start http server on any port in \(self.httpServerPortRange.lowerBound)..<\(self.httpServerPortRange.upperBound)")
    }

    /// Services are held weakly: they are owned by their device, which for a device that was
    /// reanimated rather than discovered is not held by this registry at all.
    private final class WeakService {
        weak var service: UPnPService?
        init(_ service: UPnPService) {
            self.service = service
        }
    }
    @MainActor
    private var services = [WeakService]()

    @MainActor
    internal func register(_ service: UPnPService) {
        // Services come and go (the app makes a fresh one per request on some paths); the dead
        // entries are dropped here rather than only when the listener is rebound.
        services.removeAll { $0.service == nil }
        services.append(WeakService(service))
    }

    @MainActor
    private func knownServices() -> [UPnPService] {
        services.removeAll { $0.service == nil }
        return services.compactMap { $0.service }
    }
    
    @MainActor
    private func stopHTTPServer() {
        httpServerStops += 1
        startTask?.cancel()
        // Cleared also while a start is still underway (the listener isn't running yet): that start
        // is called off and won't publish, and services created meanwhile must not get the old url.
        eventCallbackUrl = nil
        guard httpServer.isRunning else { return }

        httpServer.stop()
    }

    /// The host devices are told to post their events to, in place of this device's Wi-Fi address.
    /// Set it to "127.0.0.1" when the devices run in this process (a demo or a test), so that events
    /// arrive without a network and without touching the local network: with a loopback host the
    /// listener is bound to the loopback interface only. Call ``recoverEventDelivery()`` after
    /// changing it while the listener is running; services keep the url they were handed until then.
    public var callbackHostOverride: String?

    func callbackUrl() -> URL? {
        guard let host = callbackHostOverride ?? IPHelper.getInterfaceIPAddress(interfaceNames: ["en0", "en1"]) else {
            return nil
        }
        // An IPv6 address is only a host in a url between brackets.
        let urlHost = host.contains(":") && !host.hasPrefix("[") ? "[\(host)]" : host
        return URL(string: "http://\(urlHost):\(httpServerPort)\(eventCallBackPath)")
    }

    /// Whether a callback host can only be reached from this device.
    static func isLoopback(_ host: String?) -> Bool {
        guard let host = host?.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "[]")) else { return false }
        return host == "localhost" || host == "::1" || host.hasPrefix("127.")
    }
    
    @MainActor
    public func add(_ device: UPnPDevice) {
        // A device that is already loaded is only loaded again when it is now found at another address (it got
        // a new IP address, for example), otherwise its services keep pointing at the old one.
        // The same goes for one that is still being loaded: devices answer each search more than once, and searches
        // are repeated, so loading it again would only produce a second copy of the same device.
        guard devices.contains(where: { $0.id == device.id && $0.url == device.url && ($0.servicesLoaded == true || loadingDevices.contains(ObjectIdentifier($0))) }) == false else { return }
        // The device that is replaced was announced to subscribers, so tell them it is gone before the new one comes.
        let replaced = devices.filter { $0.id == device.id }
        devices.removeAll(where:  { $0.id == device.id })
        devices.append(device)
        for old in replaced where old.servicesLoaded {
            deviceRemovedSubject.send(old)
        }
        
        Logger.swiftUPnP.debug("device \(device.id)")
        loadingDevices.insert(ObjectIdentifier(device))
        Task {
            defer { loadingDevices.remove(ObjectIdentifier(device)) }
            guard await device.loadRoot() == true else {
                Logger.swiftUPnP.error("Failed to load root on \(device.url)")
                return
            }
            // Replaced or removed while loading the description: don't register services for a device nobody holds.
            guard devices.contains(where: { $0 === device }) else { return }
            
            if let deviceServices = device.deviceDefinition?.device.allServices {
                for deviceService in deviceServices {
                    guard let service = typedService(device: device, deviceService: deviceService) else { continue }
                    
                    await service.loadScdp()
                    device.add(service)
                }
            }
            
            device.servicesLoaded = true
            // Found at another address while loading, or removed: that one counts now.
            guard devices.contains(where: { $0 === device }) else { return }
            deviceAddedSubject.send(device)
        }
    }

    @MainActor
    func remove(_ device: UPnPDevice) {
        guard let device = devices.first(where: { $0.id == device.id }) else { return }
        devices.removeAll(where: { $0.id == device.id })
        // A device that was still loading was never announced.
        if device.servicesLoaded {
            deviceRemovedSubject.send(device)
        }
    }
    
    /// Create a service that receives its events through this registry, and remember it so its
    /// callback url can be refreshed when the event delivery path is rebuilt.
    @MainActor
    func typedService(device: UPnPDevice, serviceUrn: String) -> UPnPService? {
        guard let deviceService = device.deviceDefinition?.device.allServices.first(where: { $0.serviceType == serviceUrn }) else { return nil }
        return typedService(device: device, deviceService: deviceService)
    }

    /// Create a service from a definition the app supplies (one a device description does not list,
    /// or a device the app described itself), receiving its events through this registry. The
    /// caller loads its description and adds it to the device.
    @MainActor
    public func typedService(device: UPnPDevice, deviceService: Service) -> UPnPService? {
        guard let service = Self.typedService(device: device, deviceService: deviceService, eventPublisher: eventPublisher, eventCallbackUrl: eventCallbackUrl) else { return nil }

        register(service)

        // The stored url can be from before the network changed, or missing because there was no
        // network yet when this registry was created. Starting the server hands the url to every
        // registered service, which is why the service above is registered first: it is one of them.
        if eventCallbackUrl == nil || httpServer.isRunning == false {
            Task {
                await startHTTPServerIfNotRunning()
            }
        }

        return service
    }
    
    static func typedService(device: UPnPDevice, serviceUrn: String, eventPublisher: AnyPublisher<(String, Data), Never>? = nil, eventCallbackUrl: URL? = nil) -> UPnPService? {
        guard let deviceService = device.deviceDefinition?.device.allServices.first(where: { $0.serviceType == serviceUrn }) else { return nil }
        return typedService(device: device, deviceService: deviceService, eventPublisher: eventPublisher, eventCallbackUrl: eventCallbackUrl)
    }

    static func typedService(device: UPnPDevice, deviceService: Service, eventPublisher: AnyPublisher<(String, Data), Never>? = nil, eventCallbackUrl: URL? = nil) -> UPnPService? {
        guard let scheme = device.url.scheme,
              let host = device.url.host,
              let port = device.url.port,
              let baseURL = URL(string: "\(scheme)://\(host):\(port)"),
              let controlUrl = URL(string: deviceService.controlURL, relativeTo: baseURL),
              let scpdUrl = URL(string: deviceService.SCPDURL, relativeTo: baseURL) else { return nil }
        
        let eventUrl = URL(string: deviceService.eventSubURL, relativeTo: baseURL)
        
        switch deviceService.serviceType {
        case "urn:av-openhome-org:service:Credentials:1":
            return OpenHomeCredentials1Service(device: device,
                                               controlUrl: controlUrl,
                                               scpdUrl: scpdUrl,
                                               eventUrl: eventUrl,
                                               serviceType: deviceService.serviceType,
                                               serviceId: deviceService.serviceId,
                                               eventPublisher: eventPublisher,
                                               eventCallbackUrl: eventCallbackUrl)
        case "urn:av-openhome-org:service:Info:1":
            return OpenHomeInfo1Service(device: device,
                                        controlUrl: controlUrl,
                                        scpdUrl: scpdUrl,
                                        eventUrl: eventUrl,
                                        serviceType: deviceService.serviceType,
                                        serviceId: deviceService.serviceId,
                                        eventPublisher: eventPublisher,
                                        eventCallbackUrl: eventCallbackUrl)
        case "urn:av-openhome-org:service:OAuth:1":
            return OpenHomeOAuth1Service(device: device,
                                         controlUrl: controlUrl,
                                         scpdUrl: scpdUrl,
                                         eventUrl: eventUrl,
                                         serviceType: deviceService.serviceType,
                                         serviceId: deviceService.serviceId,
                                         eventPublisher: eventPublisher,
                                         eventCallbackUrl: eventCallbackUrl)
        case "urn:av-openhome-org:service:Pins:1":
            return OpenHomePins1Service(device: device,
                                        controlUrl: controlUrl,
                                        scpdUrl: scpdUrl,
                                        eventUrl: eventUrl,
                                        serviceType: deviceService.serviceType,
                                        serviceId: deviceService.serviceId,
                                        eventPublisher: eventPublisher,
                                        eventCallbackUrl: eventCallbackUrl)
        case "urn:av-openhome-org:service:Playlist:1":
            return OpenHomePlaylist1Service(device: device,
                                            controlUrl: controlUrl,
                                            scpdUrl: scpdUrl,
                                            eventUrl: eventUrl,
                                            serviceType: deviceService.serviceType,
                                            serviceId: deviceService.serviceId,
                                            eventPublisher: eventPublisher,
                                            eventCallbackUrl: eventCallbackUrl)
        case "urn:av-openhome-org:service:PlaylistManager:1":
            return OpenHomePlaylistManager1Service(device: device,
                                                   controlUrl: controlUrl,
                                                   scpdUrl: scpdUrl,
                                                   eventUrl: eventUrl,
                                                   serviceType: deviceService.serviceType,
                                                   serviceId: deviceService.serviceId,
                                                   eventPublisher: eventPublisher,
                                                   eventCallbackUrl: eventCallbackUrl)
        case "urn:av-openhome-org:service:Product:1":
            return OpenHomeProduct1Service(device: device,
                                           controlUrl: controlUrl,
                                           scpdUrl: scpdUrl,
                                           eventUrl: eventUrl,
                                           serviceType: deviceService.serviceType,
                                           serviceId: deviceService.serviceId,
                                           eventPublisher: eventPublisher,
                                           eventCallbackUrl: eventCallbackUrl)
        case "urn:av-openhome-org:service:Product:2":
            return OpenHomeProduct2Service(device: device,
                                           controlUrl: controlUrl,
                                           scpdUrl: scpdUrl,
                                           eventUrl: eventUrl,
                                           serviceType: deviceService.serviceType,
                                           serviceId: deviceService.serviceId,
                                           eventPublisher: eventPublisher,
                                           eventCallbackUrl: eventCallbackUrl)
        case "urn:av-openhome-org:service:Radio:1":
            return OpenHomeRadio1Service(device: device,
                                         controlUrl: controlUrl,
                                         scpdUrl: scpdUrl,
                                         eventUrl: eventUrl,
                                         serviceType: deviceService.serviceType,
                                         serviceId: deviceService.serviceId,
                                         eventPublisher: eventPublisher,
                                         eventCallbackUrl: eventCallbackUrl)
        case "urn:av-openhome-org:service:Time:1":
            return OpenHomeTime1Service(device: device,
                                        controlUrl: controlUrl,
                                        scpdUrl: scpdUrl,
                                        eventUrl: eventUrl,
                                        serviceType: deviceService.serviceType,
                                        serviceId: deviceService.serviceId,
                                        eventPublisher: eventPublisher,
                                        eventCallbackUrl: eventCallbackUrl)
        case "urn:av-openhome-org:service:Transport:1":
            return OpenHomeTransport1Service(device: device,
                                             controlUrl: controlUrl,
                                             scpdUrl: scpdUrl,
                                             eventUrl: eventUrl,
                                             serviceType: deviceService.serviceType,
                                             serviceId: deviceService.serviceId,
                                             eventPublisher: eventPublisher,
                                             eventCallbackUrl: eventCallbackUrl)
        case "urn:av-openhome-org:service:Volume:1":
            return OpenHomeVolume1Service(device: device,
                                          controlUrl: controlUrl,
                                          scpdUrl: scpdUrl,
                                          eventUrl: eventUrl,
                                          serviceType: deviceService.serviceType,
                                          serviceId: deviceService.serviceId,
                                          eventPublisher: eventPublisher,
                                          eventCallbackUrl: eventCallbackUrl)
        case "urn:av-openhome-org:service:Volume:2":
            return OpenHomeVolume2Service(device: device,
                                          controlUrl: controlUrl,
                                          scpdUrl: scpdUrl,
                                          eventUrl: eventUrl,
                                          serviceType: deviceService.serviceType,
                                          serviceId: deviceService.serviceId,
                                          eventPublisher: eventPublisher,
                                          eventCallbackUrl: eventCallbackUrl)
        case "urn:av-openhome-org:service:Config:1":
            return OpenHomeConfig1Service(device: device,
                                          controlUrl: controlUrl,
                                          scpdUrl: scpdUrl,
                                          eventUrl: eventUrl,
                                          serviceType: deviceService.serviceType,
                                          serviceId: deviceService.serviceId,
                                          eventPublisher: eventPublisher,
                                          eventCallbackUrl: eventCallbackUrl)
        case "urn:av-openhome-org:service:Sender:1":
            return OpenHomeSender1Service(device: device,
                                          controlUrl: controlUrl,
                                          scpdUrl: scpdUrl,
                                          eventUrl: eventUrl,
                                          serviceType: deviceService.serviceType,
                                          serviceId: deviceService.serviceId,
                                          eventPublisher: eventPublisher,
                                          eventCallbackUrl: eventCallbackUrl)
        case "urn:av-openhome-org:service:Receiver:1":
            return OpenHomeReceiver1Service(device: device,
                                            controlUrl: controlUrl,
                                            scpdUrl: scpdUrl,
                                            eventUrl: eventUrl,
                                          serviceType: deviceService.serviceType,
                                          serviceId: deviceService.serviceId,
                                          eventPublisher: eventPublisher,
                                          eventCallbackUrl: eventCallbackUrl)
        case "urn:schemas-upnp-org:service:ConnectionManager:1":
            return ConnectionManager1Service(device: device,
                                             controlUrl: controlUrl,
                                             scpdUrl: scpdUrl,
                                             eventUrl: eventUrl,
                                             serviceType: deviceService.serviceType,
                                             serviceId: deviceService.serviceId,
                                             eventPublisher: eventPublisher,
                                             eventCallbackUrl: eventCallbackUrl)
        case "urn:schemas-upnp-org:service:ContentDirectory:1":
            let service = ContentDirectory1Service(device: device,
                                                   controlUrl: controlUrl,
                                                   scpdUrl: scpdUrl,
                                                   eventUrl: eventUrl,
                                                   serviceType: deviceService.serviceType,
                                                   serviceId: deviceService.serviceId,
                                                   eventPublisher: eventPublisher,
                                                   eventCallbackUrl: eventCallbackUrl)
            // Browsing a large library takes a player longer than any transport command
            service.requestTimeout = 30
            return service
        case "urn:schemas-upnp-org:service:AVTransport:1":
            // The Sonos variant: the standard actions plus queue, grouping and sleep timer.
            return AVTransport1(device: device,
                                controlUrl: controlUrl,
                                scpdUrl: scpdUrl,
                                eventUrl: eventUrl,
                                serviceType: deviceService.serviceType,
                                serviceId: deviceService.serviceId,
                                eventPublisher: eventPublisher,
                                eventCallbackUrl: eventCallbackUrl)
        case "urn:schemas-upnp-org:service:RenderingControl:1":
            return RenderingControl1Service(device: device,
                                            controlUrl: controlUrl,
                                            scpdUrl: scpdUrl,
                                            eventUrl: eventUrl,
                                            serviceType: deviceService.serviceType,
                                            serviceId: deviceService.serviceId,
                                            eventPublisher: eventPublisher,
                                            eventCallbackUrl: eventCallbackUrl)
        case "urn:schemas-upnp-org:service:ZoneGroupTopology:1":
            return ZoneGroupTopology1Service(device: device,
                                             controlUrl: controlUrl,
                                             scpdUrl: scpdUrl,
                                             eventUrl: eventUrl,
                                             serviceType: deviceService.serviceType,
                                             serviceId: deviceService.serviceId,
                                             eventPublisher: eventPublisher,
                                             eventCallbackUrl: eventCallbackUrl)
        default:
            return UPnPService(device: device,
                               controlUrl: controlUrl,
                               scpdUrl: scpdUrl,
                               eventUrl: eventUrl,
                               serviceType: deviceService.serviceType,
                               serviceId: deviceService.serviceId,
                               eventPublisher: eventPublisher,
                               eventCallbackUrl: eventCallbackUrl)
        }
    }
}
