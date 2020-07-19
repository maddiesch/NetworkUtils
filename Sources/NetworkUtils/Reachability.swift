//
//  Reachability.swift
//  
//
//  Created by Maddie Schipper on 7/19/20.
//

import Foundation
import SystemConfiguration
import Combine
import os.log

public final class Reachability {
    public enum Status {
        case unreachable
        case wwan
        case wifi
        
        internal init(_ flags: SCNetworkReachabilityFlags) {
            if flags.isAvailable {
                #if os(iOS)
                    if flags.contains(.isWWAN) {
                        self = .wwan
                    } else {
                        self = .wifi
                    }
                #else
                    self = .wifi
                #endif
            } else {
                self = .unreachable
            }
        }
    }
    
    public static let global = Reachability()
    
    private let _publisher = CurrentValueSubject<Status, Never>(.unreachable)
    
    private let _queue = DispatchQueue(label: NetworkUtilsIdentifier + ".Reachability", qos: .utility)
    
    public var state: Reachability.Status {
        return self._publisher.value
    }
    
    public var publisher: AnyPublisher<Status, Never> {
        return self._publisher.eraseToAnyPublisher()
    }
    
    public init() {}
    
    deinit {
        try? self.stop()
    }
    
    public func start(address: SocketAddress = .null) throws {
        try self._queue.sync { try self._start(address: address) }
    }
    
    public func stop() throws {
        try self._queue.sync { try self._stop() }
    }
    
    private var _instance: SCNetworkReachability?
    
    private func _start(address: SocketAddress) throws {
        try self._stop()
        
        os_log("Starting network reachability checks for %{public}@", log: .network, address.host.description)
        
        guard let net = address.withSockaddr(block: { SCNetworkReachabilityCreateWithAddress(nil, $0) }) else {
            throw NetworkError.generic("Failed to create a reachability connection to the specified address")
        }
        
        var context = SCNetworkReachabilityContext(
            version: 1,
            info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        
        SCNetworkReachabilitySetCallback(net, reachabilityUpdateCallbackHandler, &context)
        SCNetworkReachabilitySetDispatchQueue(net, .global(qos: .background))
        
        var flags: SCNetworkReachabilityFlags = []
        if SCNetworkReachabilityGetFlags(net, &flags) {
            self._update(Status(flags))
        }
        
        self._instance = net
    }
    
    private func _stop() throws {
        guard let instance = self._instance else {
            return
        }
        
        SCNetworkReachabilitySetCallback(instance, nil, nil)
        SCNetworkReachabilitySetDispatchQueue(instance, nil)
        
        self._instance = nil
    }
    
    fileprivate func callback(_ flags: SCNetworkReachabilityFlags) {
        let status = Status(flags)
        
        os_log("Network Reachability Changed")
        
        self._queue.async {
            self._update(status)
        }
    }
    
    fileprivate func _update(_ status: Status) {
        os_log("Network Reachability Updated: %{public}@", log: .network, type: .debug, status.description)
        
        self._publisher.send(status)
    }
}

extension Reachability.Status {
    var isReachable: Bool {
        switch self {
        case .unreachable:
            return false
        case .wifi, .wwan:
            return true
        }
    }
}

extension Reachability.Status : CustomStringConvertible {
    public var description: String {
        switch self {
        case .unreachable:
            return NSLocalizedString("Unreachable", comment: "Reachability Status Unreachable")
        case .wifi:
            return NSLocalizedString("WiFi", comment: "Reachability Status WiFi")
        case .wwan:
            return NSLocalizedString("Cellular", comment: "Reachability Status WWAN")
        }
    }
}
    
fileprivate extension SCNetworkReachabilityFlags {
    var isReachable: Bool {
        return self.contains(.reachable)
    }
    
    var isConnectionRequired: Bool {
        return self.contains(.connectionRequired)
    }
    
    var isAutomatic: Bool {
        return self.contains(.connectionOnDemand) || self.contains(.connectionOnTraffic)
    }
    
    var isInteractionRequired: Bool {
        return self.contains(.interventionRequired) || !self.isAutomatic
    }
    
    var isAvailable: Bool {
        return self.isReachable && (!self.isConnectionRequired || !self.isInteractionRequired)
    }
}

fileprivate func reachabilityUpdateCallbackHandler(reachability: SCNetworkReachability, flags: SCNetworkReachabilityFlags, infoPtr: UnsafeMutableRawPointer?) {
    guard let info = infoPtr else {
        return
    }
    Unmanaged<Reachability>.fromOpaque(info).takeUnretainedValue().callback(flags)
}
