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
                // The network is usually still settling when the listener drops out.
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await self?.startHTTPServer()
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

        // The discovery engine keeps its state on the main queue, like its socket callbacks.
        Task { @MainActor in
            await startHTTPServerIfNotRunning()
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
        Task { @MainActor in
            discoveryEngine.stopDiscovery()
            stopHTTPServer()
            devices.removeAll(keepingCapacity: false)
        }
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

    @MainActor
    internal func startHTTPServer() async {
        if let startTask {
            await startTask.value
            return
        }

        let task = Task { @MainActor in
            await bindHTTPServer()
        }
        startTask = task
        await task.value
        startTask = nil
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
                try await httpServer.start(port: port)

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
        startTask?.cancel()
        guard httpServer.isRunning else { return }

        httpServer.stop()
        eventCallbackUrl = nil
    }
    
    func callbackUrl() -> URL? {
        if let ipAddress = IPHelper.getInterfaceIPAddress(interfaceNames: ["en0", "en1"]) {
            return  URL(string: "http://\(ipAddress):\(httpServerPort)\(eventCallBackPath)")
        }
        return nil
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
