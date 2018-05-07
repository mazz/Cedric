//
//  Cedric.swift
//  Cedric
//
//  Created by Szymon Mrozek on 06.05.2018.
//  Copyright © 2018 AppUnite. All rights reserved.
//

import Foundation

public protocol CedricDelegate: class {
    /// Invoked when download did start for paricular resource
    ///
    /// - Parameters:
    ///   - cedric: Cedric object
    ///   - resource: Resource which download did start
    func cedric(_ cedric: Cedric, didStartDownloadingResource resource: DownloadResource)
    
    /// Invoked when next chunk of data is downloaded of particular item
    ///
    /// - Parameters:
    ///   - cedric: Cedric object
    ///   - bytesDownloaded: Total bytes downloaded
    ///   - totalBytesExpected: Total bytes expected to download
    ///   - resource: Resource related with download
    func cedric(_ cedric: Cedric, didDownloadBytes bytesDownloaded: Int64, fromTotalBytesExpected totalBytesExpected: Int64?, ofResource resource: DownloadResource)
    
    /// Invoked when particular resource downloading is finished
    ///
    /// - Parameters:
    ///   - cedric: Cedric object
    ///   - resource: Resource related with download
    ///   - location: Location where downloaded file is stored
    ///   - relativePath: Relative path of downloaded file (the one that should be stored)
    func cedric(_ cedric: Cedric, didFinishDownloadingResource resource: DownloadResource, toFile file: DownloadedFile)
    
    /// Invoked when error occured during downloading particular resource
    ///
    /// - Parameters:
    ///   - cedric: Cedric object
    ///   - error: Error that occured during downloading
    ///   - resource: Downloaded resource
    func cedric(_ cedric: Cedric, didCompleteWithError error: Error?, whenDownloadingResource resource: DownloadResource)
}

public class Cedric {
    
    internal var delegates = MulticastDelegate<CedricDelegate>()
    private var items: [DownloadItem]
    private var operationQueue: OperationQueue
    
    public init(operationQueue: OperationQueue = OperationQueue()) {
        self.operationQueue = operationQueue
        self.items = []
    }
    
    /// Schedule multiple downloads
    ///
    /// - Parameter resources: Resources to download
    public func enqueueMultipleDownloads(forResources resources: [DownloadResource]) {
        resources.forEach { enqueueDownload(forResource: $0) }
    }
    
    /// Add new download to Cedric's queue
    ///
    /// - Parameter resouce: resource to be downloaded
    public func enqueueDownload(forResource resource: DownloadResource) {
        let item = DownloadItem(resource: resource, delegateQueue: operationQueue)
        
        switch resource.mode {
        case .newFile:
            items.append(item)
        case .notDownloadIfExists:
            if let existing = existingFileIfAvailable(forResource: resource) {
                DispatchQueue.main.async {
                    self.delegates.invoke({ $0.cedric(self, didFinishDownloadingResource: resource, toFile: existing) })
                }
                return
            } else {
                guard items.contains(where: { $0.resource.id == resource.id }) == false else { return } 
                items.append(item)
            }
        }
        
        item.delegate = self
        item.resume()
        
        DispatchQueue.main.async {
            self.delegates.invoke({ $0.cedric(self, didStartDownloadingResource: resource) })
        }
    }
    
    /// Cancel downloading resources with id
    ///
    /// - Parameter id: identifier of resource to be cancel (please not that there might be multiple resources with the same identifier, all of them will be canceled)
    public func cancel(downloadingResourcesWithId id: String) {
        items.filter { $0.resource.id == id }
            .filter { $0.completed == false }
            .forEach { $0.cancel() }
    }
    
    /// Cancel all running downloads
    public func cancelAllDownloads() {
        items.filter { $0.completed == false }
            .forEach { $0.cancel() }
    }
    
    /// Insert new delegate for multicast
    ///
    /// - Parameter object: Object
    public func addDelegate<T: CedricDelegate>(_ object: T) {
        DispatchQueue.main.async {
            self.delegates.addDelegate(object)
        }
    }
    
    /// Remove particular delegate from multicast
    ///
    /// - Parameter object: Object
    public func removeDelegate<T: CedricDelegate>(_ object: T) {
        DispatchQueue.main.async {
            self.delegates.removeDelegate(object)
        }
    }
    
    /// Returns download task for state observing
    ///
    /// - Parameter resource: Resource related with task (if using newFile mode first matching task is returned)
    /// - Returns: URLSessionDownloadTask for observing state / progress 
    public func downloadTask(forResource resource: DownloadResource) -> URLSessionDownloadTask? {
        return items.first(where: { $0.resource.id == resource.id })?.task
    }

    /// Remove all files downloaded by Cedric
    ///
    /// - Throws: Exception occured while removing files
    public func cleanDownloadsDirectory() throws {
        let documents = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent("Downloads")
        let content = try FileManager.default.contentsOfDirectory(atPath: documents.path)
        try content.forEach({ try FileManager.default.removeItem(atPath: "\(documents.path)/\($0)")})
    }
    
    private func existingFileIfAvailable(forResource resource: DownloadResource) -> DownloadedFile? {
        guard let url = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("Downloads").appendingPathComponent(resource.destinationName) else { return nil }
        
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? DownloadedFile(absolutePath: url)
    }
}

// MARK: - DownloadItemDelegate

extension Cedric: DownloadItemDelegate {
    
    internal func item(_ item: DownloadItem, didCompleteWithError error: Error?) {
        DispatchQueue.main.async {
            self.delegates.invoke({ $0.cedric(self, didCompleteWithError: error, whenDownloadingResource: item.resource) })
            self.remove(downloadItem: item)
        }
    }
    
    internal func item(_ item: DownloadItem, didDownloadBytes bytes: Int64) {
        // single item progress report
        
        DispatchQueue.main.async {
            self.delegates.invoke({ $0.cedric(self, didDownloadBytes: bytes, fromTotalBytesExpected: item.totalBytesExpected, ofResource: item.resource) })
        }
    }
    
    internal func item(_ item: DownloadItem, didFinishDownloadingTo location: URL) {
        do {
            let file = try DownloadedFile(absolutePath: location)
            DispatchQueue.main.async {
                self.delegates.invoke({ $0.cedric(self, didFinishDownloadingResource: item.resource, toFile: file) })
                self.remove(downloadItem: item)
            }
        } catch let error {
            DispatchQueue.main.async {
                self.delegates.invoke({ $0.cedric(self, didCompleteWithError: error, whenDownloadingResource: item.resource) })
                self.remove(downloadItem: item)
            }
        }
    }
    
    fileprivate func remove(downloadItem item: DownloadItem) {
        guard let index = items.index(of: item) else { return }
        let item = items[index]
        item.delegate = nil
        items.remove(at: index)
    }
}
