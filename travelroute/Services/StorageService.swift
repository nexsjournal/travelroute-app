//
//  StorageService.swift
//  travelroute
//
//  Created by Kiro
//

import Foundation
import SwiftData

/// 数据存储服务协议
@MainActor
protocol StorageServiceProtocol {
    /// 获取所有路线
    func fetchAllRoutes() -> [Route]
    
    /// 根据 ID 获取路线
    func fetchRoute(id: UUID) -> Route?
    
    /// 保存路线
    func saveRoute(_ route: Route) throws
    
    /// 删除路线
    func deleteRoute(_ route: Route) throws
}

/// 数据存储服务实现
class StorageService: StorageServiceProtocol {
    private let modelContext: ModelContext
    
    /// 共享实例（需要在 App 启动时初始化）
    static var shared: StorageService!
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// 获取所有路线
    func fetchAllRoutes() -> [Route] {
        let descriptor = FetchDescriptor<Route>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("获取路线失败: \(error)")
            return []
        }
    }
    
    /// 根据 ID 获取路线
    func fetchRoute(id: UUID) -> Route? {
        let descriptor = FetchDescriptor<Route>(
            predicate: #Predicate { route in
                route.id == id
            }
        )
        
        do {
            let routes = try modelContext.fetch(descriptor)
            return routes.first
        } catch {
            print("获取路线失败: \(error)")
            return nil
        }
    }
    
    /// 保存路线
    func saveRoute(_ route: Route) throws {
        route.updateTimestamp()
        try modelContext.save()
    }
    
    /// 删除路线
    func deleteRoute(_ route: Route) throws {
        modelContext.delete(route)
        try modelContext.save()
    }
}
