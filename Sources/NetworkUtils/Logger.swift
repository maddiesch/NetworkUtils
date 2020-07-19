//
//  Logger.swift
//  
//
//  Created by Maddie Schipper on 7/19/20.
//

import Foundation
import os.log

internal extension OSLog {
    static let network = OSLog(subsystem: NetworkUtilsIdentifier, category: "network")
}
