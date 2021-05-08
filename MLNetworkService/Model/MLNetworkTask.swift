//
//  MLNetworkTask.swift
//  MLNetworkService
//
//  Created by apple on 2021/5/8.
//

import Foundation

public enum MLNetworkTaskState {
    case running
    case suspend
    case cancel
    case completed
}

public protocol MLNetworkTask {
    var taskIdentifier: String { get }
    var originRequest: URLRequest? { get }
    var state: MLNetworkTaskState { get }
    var progress: ((_ didWriteData: Int64, _ totalBytesWritten: Int64, _ totalBytesExpectedToWrite: Int64) -> Void)? { get set }
    
    func resume()
    func suspend()
    func cancel()
}
