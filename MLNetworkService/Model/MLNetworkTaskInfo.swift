//
//  MLNetworkTaskInfo.swift
//  MLNetworkService
//
//  Created by apple on 2021/5/8.
//

import Foundation

protocol MLNetworkTaskInfoDelegate: NSObjectProtocol {
    var taskState: MLNetworkTaskState { get }
    func resume(task: MLNetworkTaskInfo)
    func suspend(task: MLNetworkTaskInfo)
    func cancel(task: MLNetworkTaskInfo)
    func task(_ task: MLNetworkTaskInfo, progressMonitorDidChange isEnable: Bool)
}

class MLNetworkTaskInfo: NSObject, MLNetworkTask {
    
    let taskIdentifier: String
    let originRequest: URLRequest?
    var progress: ((Int64, Int64, Int64) -> Void)? {
        didSet {
            let oldIsEnable = oldValue != nil
            let isEnable = progress != nil
            if oldIsEnable != isEnable {
                delegate?.task(self, progressMonitorDidChange: progress != nil)
            }
        }
    }
    weak var delegate: MLNetworkTaskInfoDelegate?
    
    init(identifier: String, request: URLRequest?) {
        taskIdentifier = identifier
        originRequest = request
        super.init()
    }
    
    private(set) var isAutoChange = true
    var state = MLNetworkTaskState.suspend
    func resume() {
        if state != .suspend { return }
        guard let state = delegate?.taskState else { return }
        if state == .completed || state == .cancel {
            self.state = state
            return
        }
        delegate?.resume(task: self)
        self.state = .running
        isAutoChange = false
    }
    func suspend() {
        if state != .running { return }
        guard let state = delegate?.taskState else { return }
        if state == .completed || state == .cancel {
            self.state = state
            return
        }
        delegate?.suspend(task: self)
        self.state = .suspend
        isAutoChange = false
    }
    func cancel() {
        if state != .running { return }
        delegate?.cancel(task: self)
        state = .cancel
        isAutoChange = false
    }
}
