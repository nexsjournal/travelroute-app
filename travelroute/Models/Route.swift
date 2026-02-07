//
//  Route.swift
//  travelroute
//
//  Created by Kiro
//

import Foundation
import SwiftData

/// 旅行路线模型
@Model
final class Route {
    /// 唯一标识符
    var id: UUID
    
    /// 路线名称
    var name: String
    
    /// 创建时间
    var createdAt: Date
    
    /// 最后修改时间
    var updatedAt: Date
    
    /// 路线包含的地点列表
    @Relationship(deleteRule: .cascade, inverse: \RoutePoint.route)
    var points: [RoutePoint]
    
    /// 初始化路线
    /// - Parameter name: 路线名称
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.updatedAt = Date()
        self.points = []
    }
    
    /// 更新修改时间
    func updateTimestamp() {
        self.updatedAt = Date()
    }
}
