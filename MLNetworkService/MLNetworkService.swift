//
//  MLNetworkService.swift
//  MLNetworkService
//
//  Created by apple on 2021/5/8.
//

import Foundation

public class MLNetworkService: NSObject {
    private lazy var session: URLSession = {
        let session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
        return session
    }()
    private lazy var operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    private lazy var runningOperationSet: [Int: MLNetworkOperation] = [:]
    private lazy var waitOperationSet: [Int: MLNetworkOperation] = [:]
}

public extension MLNetworkService {
    
    /// 添加下载任务，必须调用 resume 才开始任务
    func addDownloadTask(url: URL) -> MLNetworkTask {
        let task = session.downloadTask(with: url)
        let opertion = MLNetworkOperation(task: task)
        opertion.delegate = self
//        waitOperationSet[task.taskIdentifier] = opertion
        operationQueue.addOperation(opertion)
        return opertion.getNewTask()
    }
    func addDownloadTaskAndResume(url: URL) -> MLNetworkTask {
        let task = session.downloadTask(with: url)
        let opertion = MLNetworkOperation(task: task)
        opertion.delegate = self
        let downloadTask = opertion.getNewTask()
        downloadTask.resume()
        return downloadTask
    }
}

extension MLNetworkService: URLSessionDownloadDelegate {
    
    //MARK:- URLSessionTaskDelegate
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error else { return }
        print("\(task) 下载失败 \(error.localizedDescription)")
        guard let operation = runningOperationSet[task.taskIdentifier] else { return }
        operation.finish(result: .failure(error))
    }
    
    //MARK:- URLSessionDownloadDelegate
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let operation = runningOperationSet[downloadTask.taskIdentifier] else { return }
        operation.finish(result: .success(location))
    }
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        print("bytesWritten: \(bytesWritten), totalBytesWritten: \(totalBytesWritten), totalBytesExpectedToWrite: \(totalBytesExpectedToWrite)")
        if let operation = runningOperationSet[downloadTask.taskIdentifier] {
            operation.didChangeProgress(didWriteData: bytesWritten, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
        }
    }
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        print("")
    }
}

extension MLNetworkService: MLNetworkOperationDelegate {
    
    //MARK:- MLNetworkOperationDelegate
    func didIsRead(operation: MLNetworkOperation) -> Bool {
        guard let operation = waitOperationSet.removeValue(forKey: operation.taskIdentifier) else { return false }
        defer {
            operationQueue.addOperation(operation)
        }
        return true
    }
    func didStart(operation: MLNetworkOperation) {
        runningOperationSet[operation.taskIdentifier] = operation
    }
    func didCancel(operation: MLNetworkOperation, isSuspend: Bool) {
        guard let op = runningOperationSet.removeValue(forKey: operation.taskIdentifier) else { return }
        if isSuspend {
            waitOperationSet[operation.taskIdentifier] = operation
            op.isExistedQueue = false
        }
    }
}
