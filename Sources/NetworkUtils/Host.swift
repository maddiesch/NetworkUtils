//
//  Host.swift
//  
//
//  Created by Maddie Schipper on 7/19/20.
//

public struct Host {
    fileprivate static let delimiter: Character = ":"
    
    public let name: String
    public let port: UInt16
    
    public init(name: String, port: UInt16 = 0) {
        self.name = name
        self.port = port
    }
}

extension Host : CustomStringConvertible {
    public var description: String {
        if self.port > 0 {
            return "\(self.name)\(Host.delimiter)\(self.port)"
        }
        return self.name
    }
}

extension Host : ExpressibleByStringLiteral {
    public typealias StringLiteralType = String
    
    
    public init(stringLiteral value: String) {
        let parts = value.split(separator: Host.delimiter, maxSplits: 2, omittingEmptySubsequences: false)
        
        switch parts.count {
        case 1:
            self.init(name: String(parts[0]))
        case 2:
            self.init(name: String(parts[0]), port: UInt16(parts[1]) ?? 0)
        default:
            preconditionFailure("The given string is not the correct format")
        }
    }
}

