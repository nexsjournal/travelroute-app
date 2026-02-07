//
//  RouteService.swift
//  travelroute
//
//  Created by Kiro
//

import Foundation

/// 验证结果
enum ValidationResult: Equatable {
    case valid
    case invalid(reason: String)
}

/// 路线服务协议
protocol RouteServiceProtocol {
    /// 创建路线
    func createRoute(name: String) -> Route
    
    /// 更新路线
    func updateRoute(_ route: Route)
    
    /// 删除路线
    func deleteRoute(_ route: Route)
    
    /// 验证地点
    func validatePoint(_ point: RoutePoint) -> ValidationResult
    
    /// 验证路线
    func validateRoute(_ route: Route) -> ValidationResult
    
    /// 添加地点
    func addPoint(_ point: RoutePoint, to route: Route)
    
    /// 删除地点
    func removePoint(_ point: RoutePoint, from route: Route)
    
    /// 调整地点顺序
    func reorderPoints(in route: Route, from sourceIndex: Int, to destinationIndex: Int)
    
    /// 更新地点
    func updatePoint(_ point: RoutePoint)
}

/// 路线服务实现
class RouteService: RouteServiceProtocol {
    
    // MARK: - 路线管理
    
    /// 创建路线
    func createRoute(name: String) -> Route {
        return Route(name: name)
    }
    
    /// 更新路线
    func updateRoute(_ route: Route) {
        route.updateTimestamp()
    }
    
    /// 删除路线
    func deleteRoute(_ route: Route) {
        // 实际删除操作由 StorageService 处理
        // 这里只是业务逻辑层的接口
    }
    
    // MARK: - 验证
    
    /// 验证地点
    func validatePoint(_ point: RoutePoint) -> ValidationResult {
        // 验证城市名称
        if let cityName = point.cityName {
            let trimmedName = cityName.trimmingCharacters(in: .whitespaces)
            if trimmedName.isEmpty {
                return .invalid(reason: "城市名称不能为空")
            }
            // 如果有城市名称，则认为有效
            return .valid
        }
        
        // 验证经纬度
        if let latitude = point.latitude, let longitude = point.longitude {
            // 验证纬度范围
            if latitude < -90 || latitude > 90 {
                return .invalid(reason: "纬度必须在 -90 到 90 之间")
            }
            
            // 验证经度范围
            if longitude < -180 || longitude > 180 {
                return .invalid(reason: "经度必须在 -180 到 180 之间")
            }
            
            return .valid
        }
        
        // 既没有城市名称，也没有完整的经纬度
        return .invalid(reason: "请提供城市名称或经纬度")
    }
    
    /// 验证路线
    func validateRoute(_ route: Route) -> ValidationResult {
        // 检查路线是否至少有 2 个地点
        if route.points.count < 2 {
            return .invalid(reason: "路线至少需要 2 个地点")
        }
        
        // 验证每个地点
        for point in route.points {
            let pointValidation = validatePoint(point)
            if case .invalid = pointValidation {
                return pointValidation
            }
        }
        
        return .valid
    }
    
    // MARK: - 地点管理
    
    /// 添加地点
    func addPoint(_ point: RoutePoint, to route: Route) {
        // 设置地点的顺序索引
        point.orderIndex = route.points.count
        point.route = route
        route.points.append(point)
        route.updateTimestamp()
    }
    
    /// 删除地点
    func removePoint(_ point: RoutePoint, from route: Route) {
        guard let index = route.points.firstIndex(where: { $0.id == point.id }) else {
            return
        }
        
        // 删除地点
        route.points.remove(at: index)
        
        // 重新编号剩余地点的索引
        reindexPoints(in: route)
        
        route.updateTimestamp()
    }
    
    /// 调整地点顺序
    func reorderPoints(in route: Route, from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex >= 0 && sourceIndex < route.points.count &&
              destinationIndex >= 0 && destinationIndex < route.points.count else {
            return
        }
        
        // 移动地点
        let point = route.points.remove(at: sourceIndex)
        route.points.insert(point, at: destinationIndex)
        
        // 重新编号所有地点的索引
        reindexPoints(in: route)
        
        route.updateTimestamp()
    }
    
    /// 更新地点
    func updatePoint(_ point: RoutePoint) {
        point.timestamp = Date()
        if let route = point.route {
            route.updateTimestamp()
        }
    }
    
    // MARK: - 私有方法
    
    /// 重新编号地点索引
    private func reindexPoints(in route: Route) {
        for (index, point) in route.points.enumerated() {
            point.orderIndex = index
        }
    }
}
