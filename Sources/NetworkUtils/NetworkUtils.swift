//
//  NetworkUtils.swift
//
//
//  Created by Maddie Schipper on 7/19/20.
//

import Foundation

public let NetworkUtilsIdentifier = "dev.schipper.NetworkUtils"

public enum NetworkError : Swift.Error {
    case timeout
    case generic(String)
    
    var localizedDescription: String {
        switch self {
        case .timeout:
            return "The network operation could not be completed in the allocated time"
        case .generic(let string):
            return "Generic Networking Error: (\(string))"
        }
    }
}
