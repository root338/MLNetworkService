//
//  MLNetworkService.swift
//  MLNetworkService
//
//  Created by apple on 2021/5/8.
//

import Foundation

public enum MLNetworkServiceError: Error {
    /// 服务不存在
    case notExist(msg: String)
    /// 服务已存在
    case existed(msg: String)
    /// 服务不存在时的默认实现
    static func notExist(name: String) -> Self {
        return MLNetworkServiceError.notExist(msg: "\"\(name)\" network service does not exist")
    }
    /// 服务已存在时的默认实现
    static func existed(name: String) -> Self {
        return MLNetworkServiceError.notExist(msg: "\"\(name)\" network service existed")
    }
}

public class MLNetworkService: NSObject {
    private lazy var container: MLNetworkContainer = {
        return MLNetworkContainer()
    }()
    private lazy var containerSet: [String: MLNetworkContainer] = {
        [:]
    }()
}
//MARK:- control Task
public extension MLNetworkService {
    /// 添加下载任务，必须调用 resume 才能开始任务
    /// - Parameters:
    ///   - url: 下载链接
    ///   - serviceName: 使用指定的网络服务执行下载
    ///   - completion: 任务执行结果回调
    /// - Throws: 会抛出 MLNetworkServiceError 异常
    /// - Returns: 返回创建的任务对象
    func addDownloadTask(url: URL, serviceName: String? = nil, completion: MLNetworkDownloadCompletion? = nil) throws -> MLNetworkDownloadTask {
        return try container(name: serviceName).addDownloadTask(url: url, completion: completion)
    }
    /// 添加下载任务并直接进行下载
    func addDownloadTaskAndResume(url: URL, serviceName: String? = nil, completion: MLNetworkDownloadCompletion? = nil) throws -> MLNetworkDownloadTask {
        return try container(name: serviceName).addDownloadTaskAndResume(url: url, completion: completion)
    }
    
}
//MARK:- configuration
public extension MLNetworkService {
    func contains(name: String) -> Bool { return containerSet[name] != nil }
    /// 添加新的网络服务
    /// - Parameters:
    ///   - name: 服务名称
    ///   - sessionConfiguration: 网络服务的自定义配置 为 nil 时使用内部自定义配置
    /// - Throws: 需要处理 MLNetworkServiceError 异常
    func newService(name: String, sessionConfiguration: (() -> (URLSessionConfiguration))? = nil) throws {
        if containerSet[name] != nil {
            throw MLNetworkServiceError.existed(name: name)
        }
        let container = MLNetworkContainer(name: name, seesionConfiguration: sessionConfiguration)
        containerSet[name] = container
    }
    func removeService(name: String) throws {
        if containerSet.removeValue(forKey: name) == nil {
            throw MLNetworkServiceError.notExist(name: name)
        }
    }
    func configuration(name: String?, queue: ((MLNetworkQueue) -> Void)? = nil, manager: ((MLNetworkManager) -> Void)? = nil) throws {
        try container(name: name).configuration(queue: queue, manager: manager)
    }
}

extension MLNetworkService {
    func container(name: String?) throws -> MLNetworkContainer {
        guard let container = (name == nil ? container : containerSet[name!]) else {
            throw MLNetworkServiceError.notExist(name: name!)
        }
        return container
    }
}
