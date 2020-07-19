//
//  NetworkOrderConvertible.swift
//  
//
//  Created by Maddie Schipper on 7/19/20.
//

import Foundation

public protocol NetworkOrderConvertible {
    var byteSwapped: Self { get }
}

public extension NetworkOrderConvertible {
    var littleEndian: Self {
        return ByteOrder.isLittleEndian ? self : self.byteSwapped
    }
    
    var bigEndian: Self {
        return ByteOrder.isLittleEndian ? self.byteSwapped : self
    }
    
    var nativeEndian: Self {
        return ByteOrder.isLittleEndian ? self.byteSwapped : self
    }
}

extension Int: NetworkOrderConvertible {}

extension sockaddr_in6: NetworkOrderConvertible {
    public var byteSwapped: sockaddr_in6 {
        return sockaddr_in6(sin6_len: sin6_len, sin6_family: sin6_family, sin6_port: sin6_port.byteSwapped, sin6_flowinfo: sin6_flowinfo.byteSwapped, sin6_addr: sin6_addr, sin6_scope_id: sin6_scope_id.byteSwapped)
    }
}

extension sockaddr_in: NetworkOrderConvertible {
    public var byteSwapped: sockaddr_in {
        return sockaddr_in(sin_len: sin_len, sin_family: sin_family, sin_port: sin_port.byteSwapped, sin_addr: in_addr(s_addr: sin_addr.s_addr.byteSwapped), sin_zero: sin_zero)
    }
}

fileprivate enum ByteOrder {
    static let bigEndian = CFByteOrder(CFByteOrderBigEndian.rawValue)
    static let littleEndian = CFByteOrder(CFByteOrderLittleEndian.rawValue)
    static let unknown = CFByteOrder(CFByteOrderUnknown.rawValue)
    
    static let isLittleEndian = CFByteOrderGetCurrent() == ByteOrder.littleEndian
}
