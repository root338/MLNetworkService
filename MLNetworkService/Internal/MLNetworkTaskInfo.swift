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
    /// ??????????????????????????????
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
    
    /// ???????????????
    fileprivate lazy var monitorControlSemaphore: DispatchSemaphore = {
        DispatchSemaphore(value: 1)
    }()
    /// ?????????????????????
    private lazy var taskOperatedSemaphore: DispatchSemaphore = {
        DispatchSemaphore(value: 1)
    }()
    /// ?????????????????????
    private lazy var stateGetSemaphore: DispatchSemaphore = {
        DispatchSemaphore(value: 1)
    }()
    /// ????????????
    private var _progress: MLNetworkTaskProgress?
    /// ??????????????????
    private var _didChangeState: MLNetworkTaskStatusChangeCallback?
    /// ??????????????????
    private var _state: MLNetworkTaskState? {
        didSet {
            stateGetSemaphore.signal() // ?????????????????????????????????????????????
            if _state == nil { return }
            if let new = _state, let old = oldValue, new == old { return }
            /// ????????????????????????????????????????????????????????????
            try! delegate?.changeState(to: _state!, from: oldValue)
        }
    }
}

private extension MLNetworkTaskInfo {
    /// ????????????????????????
    func isChangeStatus() throws -> (delegate: MLNetworkTaskInfoDelegate, state: MLNetworkTaskState) {
        guard let delegate = delegate else { throw MLNetworkTaskError.isOver }
        let state = delegate.state
        if (state == .cancel) { throw MLNetworkTaskError.isCancelled }
        if (state == .completed) { throw MLNetworkTaskError.isCompleted }
        return (delegate, state)
    }
    
    func operated(state: MLNetworkTaskState, isNext: (MLNetworkTaskState) -> Bool) throws {
        taskOperatedSemaphore.wait()
        stateGetSemaphore.wait() // ????????????????????????
        defer {// ???????????????????????????
            taskOperatedSemaphore.signal()
        }
        do {
            let result = try isChangeStatus()
            if !isNext(result.state) {
                stateGetSemaphore.signal() // ??????????????????????????????????????????
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
