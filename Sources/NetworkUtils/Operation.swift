//
//  Operation.swift
//  
//
//  Created by Maddie Schipper on 7/19/20.
//

import Foundation
import Combine

open class Operation<Element> : Foundation.Operation {
    public let publisher: PassthroughSubject<Element, Swift.Error>
    
    override init() {
        self.publisher = PassthroughSubject<Element, Swift.Error>()
    }
    
    func finish(withError error: Swift.Error? = nil) {
        if let error = error {
            self.publisher.send(completion: .failure(error))
        } else {
            self.publisher.send(completion: .finished)
        }
    }
    
    open override func main() {
        do {
            try self.execute()
            self.finish()
        } catch let error {
            self.finish(withError: error)
        }
    }
    
    func execute() throws {
    }
}

internal extension OperationQueue {
    static let defaultNetworking: OperationQueue = {
        let queue = OperationQueue()
        queue.name = NetworkUtilsIdentifier + ".DefaultNetworking"
        queue.qualityOfService = .utility
        return queue
    }()
}

internal extension DispatchGroup {
    func wait(withTimeout timeout: DispatchTime) throws {
        if self.wait(timeout: timeout) == .timedOut {
            throw NetworkError.timeout
        }
    }
}
