//
//  MLNetworkTaskInfo.swift
//  MLNetworkService
//
//  Created by apple on 2021/5/8.
//

import Foundation

protocol MLNetworkTaskInfoDelegate: NSObjectProtocol {
    var task: URLSessionTask { get }
    var state: MLNetworkTaskState { get }
    func changeState(to toState: MLNetworkTaskState, from oldState: MLNetworkTaskState?)
    func task(_ task: MLNetworkTaskInfo, monitorProgress isEnable: Bool)
    func task(_ task: MLNetworkTaskInfo, monitorState isEnable: Bool)
}

class MLNetworkTaskInfo: NSObject, MLNetworkTask {
    
    let identifier: String
    var request: URLRequest? { delegate?.task.originalRequest }
    let originRequest: URLRequest? = nil
    var progress: ((Int64, Int64, Int64) -> Void)? {
        didSet {
            let oldIsEnable = oldValue != nil
            let isEnable = progress != nil
            if oldIsEnable != isEnable {
                delegate?.task(self, monitorProgress: isEnable)
            }
        }
    }
    var didChangeState: ((MLNetworkTaskState) -> Void)? {
        didSet {
            let oldIsEnable = oldValue != nil
            let isEnable = didChangeState != nil
            if oldIsEnable != isEnable {
                delegate?.task(self, monitorState: isEnable)
            }
        }
    }
    var isShouldCallbackStateChange: Bool {
        let isEnable = didChangeState != nil
        if !isEnable { return false }
        guard let state = _state else { return isEnable }
        if state == .suspend || state == .cancel { return false }
        return isEnable
    }
    
    weak var delegate: MLNetworkTaskInfoDelegate?
    init(identifier: String) {
        self.identifier = identifier
        super.init()
    }
    var state: MLNetworkTaskState {
        guard let state = _state,
              state != .running, state != .ready
        else { return delegate?.state ?? .suspend }
        return state
    }
    private var _state: MLNetworkTaskState? {
        didSet {
            if _state == nil { return }
            delegate?.changeState(to: _state!, from: oldValue)
        }
    }
    func resume() throws {
        let result = try isChangeStatus()
        let state = result.state
        if state == .ready || state == .running { return }
        _state = .ready
    }
    func suspend() throws {
        let result = try isChangeStatus()
        if result.state == .suspend { return }
        _state = .suspend
    }
    func cancel() throws {
        _ = try isChangeStatus()
        _state = .cancel
    }
    private func isChangeStatus() throws -> (delegate: MLNetworkTaskInfoDelegate, state: MLNetworkTaskState) {
        guard let delegate = delegate else { throw MLNetworkTaskError.isOver }
        let state = delegate.state
        if (state == .cancel) { throw MLNetworkTaskError.isCancelled }
        if (state == .completed) { throw MLNetworkTaskError.isCompleted }
        return (delegate, state)
    }
}
