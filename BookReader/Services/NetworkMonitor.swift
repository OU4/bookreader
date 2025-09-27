//
//  NetworkMonitor.swift
//  BookReader
//
//  Network connectivity monitoring
//

import Foundation
import Network
import Combine

class NetworkMonitor: ObservableObject {
    
    // MARK: - Singleton
    static let shared = NetworkMonitor()
    
    // MARK: - Properties
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.bookreader.networkmonitor")
    
    @Published var isConnected = true
    @Published var connectionType = ConnectionType.unknown
    
    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
    }
    
    // MARK: - Initialization
    private init() {
        startMonitoring()
    }
    
    // MARK: - Public Methods
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.updateConnectionType(path)
            }
        }
        
        monitor.start(queue: queue)
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
    
    // MARK: - Private Methods
    
    private func updateConnectionType(_ path: NWPath) {
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else {
            connectionType = .unknown
        }
    }
    
    // MARK: - Reachability Check
    
    func waitForConnection(timeout: TimeInterval = 30) async -> Bool {
        if isConnected { return true }
        
        return await withCheckedContinuation { continuation in
            var cancellable: AnyCancellable?
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                cancellable?.cancel()
                continuation.resume(returning: false)
            }
            
            cancellable = $isConnected
                .filter { $0 }
                .first()
                .sink { _ in
                    timeoutTask.cancel()
                    continuation.resume(returning: true)
                }
        }
    }
}