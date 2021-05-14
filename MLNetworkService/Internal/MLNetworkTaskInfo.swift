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
    func changeState(to toState: MLNetworkTaskState, from oldState: MLNetworkTaskState?) throws
    func task(_ task: MLNetworkTaskInfo, monitorState isEnable: Bool)
    
    func task(_ task: MLNetworkTaskInfo, monitorProgress isEnable: Bool)
}

extension MLNetworkTaskInfo {
    //MARK:- MLNetworkTask
    var request: URLRequest? { delegate?.task.originalRequest }
    var response: URLResponse? { delegate?.task.response }
    var state: MLNetworkTaskState {
        stateGetSemaphore.wait()
        defer {
            stateGetSemaphore.signal()
        }
        guard let state = _state,
              state != .running, state != .ready
        else {
            let state = delegate?.state ?? .suspend
            return state
        }
        return state
    }
    var didChangeState: MLNetworkTaskStatusChangeCallback? {
        get {
            monitorControlSemaphore.wait()
            defer { monitorControlSemaphore.signal() }
            return _didChangeState
        }
        set {
            monitorControlSemaphore.wait()
            defer { monitorControlSemaphore.signal() }
            let oldIsEnable = _didChangeState != nil
            let isEnable = newValue != nil
            _didChangeState = newValue
            if oldIsEnable != isEnable {
                delegate?.task(self, monitorState: isEnable)
            }
        }
    }
    
    func resume() throws {
        try operated(state: .ready) { !($0 == .ready || $0 == .running) }
    }
    func suspend() throws {
        try operated(state: .suspend) { $0 != .suspend }
    }
    func cancel() throws {
        try operated(state: .cancel) { _ in true }
    }
    //MARK:- MLNetworkDownloadTask
    var progress: MLNetworkTaskProgress? {
        get {
            monitorControlSemaphore.wait()
            defer { monitorControlSemaphore.signal() }
            return _progress
        }
        set {
            monitorControlSemaphore.wait()
            defer { monitorControlSemaphore.signal() }
            let oldIsEnable = _progress != nil
            let isEnable = newValue != nil
            _progress = newValue
            if oldIsEnable != isEnable {
                delegate?.task(self, monitorProgress: isEnable)
            }
        }
    }
    var result: MLNetworkDownloadResult? {
        if state != .completed { return nil }
        return nil
    }
}

extension MLNetworkTaskInfo {
    /// 状态改变是否应该回调
    var stateDidChangeIsShouldCallback: Bool {
        let isEnable = didChangeState != nil
        if !isEnable { return false }
        guard let state = _state else { return isEnable }
        if state == .suspend || state == .cancel { return false }
        return isEnable
    }
}

class MLNetworkTaskInfo: NSObject, MLNetworkTask, MLNetworkDownloadTask {
    
    let identifier: String
    weak var delegate: MLNetworkTaskInfoDelegate?
    
    init(identifier: String) {
        self.identifier = identifier
        super.init()
    }
    
    /// 监听信号量
    fileprivate lazy var monitorControlSemaphore: DispatchSemaphore = {
        DispatchSemaphore(value: 1)
    }()
    /// 任务操作信号量
    private lazy var taskOperatedSemaphore: DispatchSemaphore = {
        DispatchSemaphore(value: 1)
    }()
    /// 状态只读信号量
    private lazy var stateGetSemaphore: DispatchSemaphore = {
        DispatchSemaphore(value: 1)
    }()
    /// 进度回调
    private var _progress: MLNetworkTaskProgress?
    /// 状态改变回调
    private var _didChangeState: MLNetworkTaskStatusChangeCallback?
    /// 内部自身状态
    private var _state: MLNetworkTaskState? {
        didSet {
            stateGetSemaphore.signal() // 在设置好之后直接接触状态的获取
            if _state == nil { return }
            if let new = _state, let old = oldValue, new == old { return }
            /// 内部进行检查后续执行可以确保不会抛出异常
            try! delegate?.changeState(to: _state!, from: oldValue)
        }
    }
}

private extension MLNetworkTaskInfo {
    /// 是否可以改变状态
    func isChangeStatus() throws -> (delegate: MLNetworkTaskInfoDelegate, state: MLNetworkTaskState) {
        guard let delegate = delegate else { throw MLNetworkTaskError.isOver }
        let state = delegate.state
        if (state == .cancel) { throw MLNetworkTaskError.isCancelled }
        if (state == .completed) { throw MLNetworkTaskError.isCompleted }
        return (delegate, state)
    }
    
    func operated(state: MLNetworkTaskState, isNext: (MLNetworkTaskState) -> Bool) throws {
        taskOperatedSemaphore.wait()
        stateGetSemaphore.wait() // 先限制状态的获取
        defer {// 抛出异常时也会执行
            taskOperatedSemaphore.signal()
        }
        do {
            let result = try isChangeStatus()
            if !isNext(result.state) {
                stateGetSemaphore.signal() // 再不设置时解除状态的获取限制
                return
            }
            _state = state
        } catch let err as MLNetworkTaskError {
            switch err {
            case .isOver: fallthrough
            case .isCancelled: fallthrough
            case .isCompleted:
                _state = nil
            case .notSupportOperation(msg: _): fallthrough
            case .needWaitOperatedEnd: break
            }
            throw err
        }
    }
}

//class MLNetworkDownloadTaskInfo: MLNetworkTaskInfo, MLNetworkDownloadTask {
//
//}
