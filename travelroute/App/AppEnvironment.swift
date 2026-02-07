//
//  AppEnvironment.swift
//  travelroute
//
//  Created by Kiro
//

import Foundation
import SwiftData

/// 应用环境配置
@MainActor
class AppEnvironment: ObservableObject {
    /// SwiftData 模型容器
    let modelContainer: ModelContainer
    
    /// 单例实例
    static let shared = AppEnvironment()
    
    private init() {
        do {
            // 配置 SwiftData 模型容器
            let schema = Schema([
                Route.self,
                RoutePoint.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            
            self.modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            
            // 初始化 StorageService.shared
            let modelContext = modelContainer.mainContext
            StorageService.shared = StorageService(modelContext: modelContext)
        } catch {
            fatalError("无法创建 ModelContainer: \(error)")
        }
    }
}
