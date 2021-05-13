//
//  MLNetworkTask.swift
//  MLNetworkService
//
//  Created by apple on 2021/5/8.
//

import Foundation

public enum MLNetworkTaskState {
    /// 任务本身已准备完成，在等待队列或依赖任务完成后自动开始执行
    case ready
    /// 任务正在开始执行中
    case running
    /// 任务挂起
    case suspend
    /// 取消任务
    case cancel
    /// 任务完成
    case completed
}

public enum MLNetworkTaskError: Error {
    /// 任务已结束
    case isOver
    /// 任务已取消
    case isCancelled
    /// 任务已完成
    case isCompleted
    /// 不支持操作
    case notSupportOperation(msg: String)
    /// 需要等待操作结束，一般是操作触发时上一个操作还没有执行完毕
    case needWaitOperatedEnd
}

public protocol MLNetworkTask {
    var identifier: String { get }
    var request: URLRequest? { get }
    var state: MLNetworkTaskState { get }
    
//    typealias MLNetworkTaskResultCompleted = (Result<Bool, MLNetworkServiceError>) -> Void
    typealias MLNetworkTaskProgress = (_ didWriteData: Int64, _ totalBytesWritten: Int64, _ totalBytesExpectedToWrite: Int64) -> Void
    typealias MLNetworkTaskStatusChangeCallback = (MLNetworkTaskState) -> Void
    
    /// 进度监听回调，不保证在主线程
    var progress: MLNetworkTaskProgress? { get set }
    /// 状态监听回调，不保证在主线程
    var didChangeState: MLNetworkTaskStatusChangeCallback? { get set }
    
    /// 恢复任务，执行错误时报 MLNetworkTaskError 异常
    func resume() throws
    /// 挂起任务，执行错误时报 MLNetworkTaskError 异常
    func suspend() throws
    /// 取消任务，执行错误时报 MLNetworkTaskError 异常
    func cancel() throws
}

