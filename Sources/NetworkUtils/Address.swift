//
//  Address.swift
//  
//
//  Created by Maddie Schipper on 7/19/20.
//

import Foundation
import Combine
import os.log

public extension Host {
    func resolve(inQueue queue: OperationQueue? = nil, withTimeout timeout: DispatchTimeInterval = .milliseconds(500)) -> AnyPublisher<SocketAddress.Collection, Error> {
        let op = HostResolutionOperation(self, timeout)
        (queue ?? .defaultNetworking).addOperation(op)
        return op.publisher.eraseToAnyPublisher()
    }
}

public enum SocketAddress {
    public typealias Collection = Array<SocketAddress>
    
    public static let null: SocketAddress = {
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout.size(ofValue: address))
        address.sin_family = sa_family_t(AF_INET)
        
        return .v4(address)
    }()
    
    public static let null6: SocketAddress = {
        var address = sockaddr_in6()
        address.sin6_len = UInt8(MemoryLayout.size(ofValue: address))
        address.sin6_family = sa_family_t(AF_INET)
        
        return .v6(address)
    }()
    
    case v4(sockaddr_in)
    case v6(sockaddr_in6)
    
    internal init?(storage: UnsafePointer<sockaddr_storage>, port: UInt16) {
        switch Int32(storage.pointee.ss_family) {
        case AF_INET:
            self = storage.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                var addr = $0.pointee.nativeEndian
                addr.sin_port = port > 0 ? port : addr.sin_port
                return .v4(addr)
            }
        case AF_INET6:
            self = storage.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { pointer in
                var addr = pointer.pointee.nativeEndian
                addr.sin6_port = port > 0 ? port : addr.sin6_port
                return .v6(addr)
            }
        default:
            return nil
        }
    }
    
    public var host: Host {
        switch self {
        case .v4(let addr):
            return addr.host
        case .v6(let addr):
            return addr.host
        }
    }
    
    internal var family: Int32 {
        switch self {
        case .v4(_):
            return PF_INET
        case .v6(_):
            return PF_INET6
        }
    }
    
    internal func withSockaddr<Result>(block: (UnsafePointer<sockaddr>) throws -> Result) rethrows -> Result {
        switch self {
        case .v4(let addr):
            var v4 = addr
            return try withUnsafePointer(to: &v4) { ptr in
                try ptr.withMemoryRebound(to: sockaddr.self, capacity: MemoryLayout<sockaddr>.size) {
                    try block($0)
                }
            }
        case .v6(let addr):
            var v6 = addr
            return try withUnsafePointer(to: &v6) { ptr in
                try ptr.withMemoryRebound(to: sockaddr.self, capacity: MemoryLayout<sockaddr>.size) {
                    try block($0)
                }
            }
        }
    }
}

extension SocketAddress : CustomStringConvertible {
    public var description: String {
        self.host.description
    }
}

internal extension sockaddr_in {
    var host: Host {
        return Host(name: String(cString: inet_ntoa(self.sin_addr)), port: self.sin_port)
    }
}

internal extension sockaddr_in6 {
    var host: Host {
        var buffer = [Int8](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        var addr = self.sin6_addr
        inet_ntop(AF_INET6, &addr, &buffer, socklen_t(INET6_ADDRSTRLEN))
        
        return Host(name: String(cString: buffer), port: self.sin6_port)
    }
}

internal class HostResolutionOperation : Operation<SocketAddress.Collection> {
    let host: Host
    let timeout: DispatchTimeInterval
    
    private let group = DispatchGroup()
    
    init(_ host: Host, _ timeout: DispatchTimeInterval) {
        self.host = host
        self.timeout = timeout
        
        super.init()
    }
    
    
    override func execute() throws {
        self.group.enter()
        
        os_log("Resolving host: %{public}@", log: .network, type: .debug, self.host.description)
        
        let host = CFHostCreateWithName(nil, self.host.name as CFString).takeRetainedValue()
        
        var context = CFHostClientContext(
            version: 0,
            info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        
        CFHostSetClient(host, hostResolutionOperationCallback, &context)
        defer {
            CFHostSetClient(host, nil, nil)
        }
        
        var err = CFStreamError()
        guard CFHostStartInfoResolution(host, .addresses, &err) else {
            throw NetworkError.generic("The requested host couldn't not be resolved")
        }
        
        CFHostScheduleWithRunLoop(host, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        
        defer {
            CFHostCancelInfoResolution(host, .addresses)
            CFHostUnscheduleFromRunLoop(host, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        }
        
        try self.group.wait(withTimeout: .now() + self.timeout)
    }
    
    fileprivate func resolved(_ host: CFHost) {
        defer {
            self.group.leave()
        }
        
        os_log("Resovled: %@", log: .network, type: .debug, self.host.description)
        
        var resolved = DarwinBoolean(false)
        let addrData = CFHostGetAddressing(host, &resolved)?.takeUnretainedValue() as Array<AnyObject>?
        guard let addresses = addrData, resolved.boolValue else {
            self.finish(withError: NetworkError.generic("DNS lookup failed"))
            return
        }
        
        let addrs = addresses.compactMap { raw -> SocketAddress? in
            guard let data = raw as? Data else {
                return nil
            }
            
            return data.withUnsafeBytes { bytes in
                let storage = bytes.bindMemory(to: sockaddr_storage.self)
                
                return SocketAddress(storage: storage.baseAddress!, port: self.host.port)
            }
        }
        
        self.publisher.send(addrs)
    }
}

fileprivate func hostResolutionOperationCallback(_ host: CFHost, _ types: CFHostInfoType, _ error: UnsafePointer<CFStreamError>?, _ infoPtr: UnsafeMutableRawPointer?) {
    guard let infoPtr = infoPtr else {
        return
    }
    
    let operation = Unmanaged<HostResolutionOperation>.fromOpaque(infoPtr)
    
    operation.takeUnretainedValue().resolved(host)
}

