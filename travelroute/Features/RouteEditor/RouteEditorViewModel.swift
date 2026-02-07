//
//  RouteEditorViewModel.swift
//  travelroute
//
//  Created by Kiro on 2024.
//

import Foundation
import Observation

@Observable
@MainActor
class RouteEditorViewModel {
    
    // MARK: - Properties
    
    var route: Route
    var points: [RoutePoint]
    var selectedPoint: RoutePoint?
    var validationError: String?
    var showingPointInput: Bool = false
    var editingPoint: RoutePoint?
    
    // MARK: - Dependencies
    
    private let routeService: RouteServiceProtocol
    private let storageService: StorageServiceProtocol
    
    // MARK: - Initialization
    
    init(
        route: Route,
        routeService: RouteServiceProtocol = RouteService(),
        storageService: StorageServiceProtocol? = nil
    ) {
        self.route = route
        self.points = route.points
        self.routeService = routeService
        self.storageService = storageService ?? StorageService.shared
    }
    
    // MARK: - Public Methods
    
    /// 添加地点
    func addPoint(_ point: RoutePoint) {
        // 验证地点
        let validationResult = routeService.validatePoint(point)
        guard case .valid = validationResult else {
            if case .invalid(let reason) = validationResult {
                validationError = reason
            }
            return
        }
        
        // 设置正确的索引
        let newPoint = point
        newPoint.orderIndex = points.count
        
        // 添加到路线
        routeService.addPoint(newPoint, to: route)
        
        // 更新本地列表
        points = route.points
        
        // 保存路线
        saveRoute()
        
        // 清除错误
        validationError = nil
        
        Logger.shared.info("添加地点: \(newPoint.cityName ?? "(\(newPoint.latitude ?? 0), \(newPoint.longitude ?? 0))")")
    }
    
    /// 删除地点
    func removePoint(_ point: RoutePoint) {
        // 从路线中删除
        routeService.removePoint(point, from: route)
        
        // 更新本地列表
        points = route.points
        
        // 保存路线
        saveRoute()
        
        Logger.shared.info("删除地点: \(point.cityName ?? "(\(point.latitude ?? 0), \(point.longitude ?? 0))")")
    }
    
    /// 调整地点顺序
    func reorderPoints(from source: IndexSet, to destination: Int) {
        // 更新本地列表
        points.move(fromOffsets: source, toOffset: destination)
        
        // 重新编号
        for (index, point) in points.enumerated() {
            point.orderIndex = index
        }
        
        // 更新路线
        route.points = points
        
        // 保存路线
        saveRoute()
        
        Logger.shared.info("调整地点顺序")
    }
    
    /// 更新地点
    func updatePoint(_ point: RoutePoint) {
        // 验证地点
        let validationResult = routeService.validatePoint(point)
        guard case .valid = validationResult else {
            if case .invalid(let reason) = validationResult {
                validationError = reason
            }
            return
        }
        
        // 更新路线中的地点
        routeService.updatePoint(point)
        
        // 更新本地列表
        points = route.points
        
        // 保存路线
        saveRoute()
        
        // 清除错误
        validationError = nil
        
        Logger.shared.info("更新地点: \(point.cityName ?? "(\(point.latitude ?? 0), \(point.longitude ?? 0))")")
    }
    
    /// 验证路线
    func validateRoute() -> Bool {
        let validationResult = routeService.validateRoute(route)
        
        switch validationResult {
        case .valid:
            validationError = nil
            return true
        case .invalid(let reason):
            validationError = reason
            return false
        }
    }
    
    /// 保存路线
    func saveRoute() {
        // 更新修改时间
        self.route.updatedAt = Date()
        
        // 保存到存储
        try? storageService.saveRoute(self.route)
        
        Logger.shared.info("保存路线: \(self.route.name)")
    }
    
    /// 显示地点输入界面（添加新地点）
    func showAddPointInput() {
        editingPoint = nil
        showingPointInput = true
    }
    
    /// 显示地点输入界面（编辑现有地点）
    func showEditPointInput(_ point: RoutePoint) {
        editingPoint = point
        showingPointInput = true
    }
    
    /// 隐藏地点输入界面
    func hidePointInput() {
        showingPointInput = false
        editingPoint = nil
        validationError = nil
    }
    
    /// 选择地点
    func selectPoint(_ point: RoutePoint) {
        selectedPoint = point
    }
    
    /// 取消选择
    func deselectPoint() {
        selectedPoint = nil
    }
    
    // MARK: - Computed Properties
    
    /// 是否可以保存（至少有 2 个地点）
    var canSave: Bool {
        return points.count >= 2
    }
    
    /// 路线统计信息
    var routeStats: RouteStats {
        return RouteStats(
            pointCount: points.count,
            hasStartPoint: !points.isEmpty,
            hasEndPoint: points.count >= 2
        )
    }
}

// MARK: - Route Stats

struct RouteStats {
    let pointCount: Int
    let hasStartPoint: Bool
    let hasEndPoint: Bool
    
    var statusText: String {
        if pointCount == 0 {
            return "还没有添加地点"
        } else if pointCount == 1 {
            return "已添加 1 个地点，至少需要 2 个地点"
        } else {
            return "已添加 \(pointCount) 个地点"
        }
    }
}
