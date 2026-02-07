//
//  HomeViewModel.swift
//  travelroute
//
//  Created by Kiro on 2024.
//

import Foundation
import MapKit
import Observation

@Observable
@MainActor
class HomeViewModel {
    
    // MARK: - Properties
    
    var currentRoute: Route?
    var isPreviewEnabled: Bool = false
    var mapRegion: MKCoordinateRegion
    var showingPointInput: Bool = false
    var pointInputType: PointInputType = .start
    var validationError: String?
    var showToast: Bool = false
    var toastMessage: String = ""
    var toastType: ToastType = .info
    
    // MARK: - 编辑状态机（核心）
    
    var editMode: RouteEditMode = .idle
    var tempPointCoordinate: CLLocationCoordinate2D?  // 临时交互坐标，不进数据层
    
    // MARK: - Dependencies
    
    private let routeService: RouteServiceProtocol
    private let storageService: StorageServiceProtocol
    private let mapService: MapServiceProtocol
    
    // MARK: - Initialization
    
    init(
        routeService: RouteServiceProtocol = RouteService(),
        storageService: StorageServiceProtocol? = nil,
        mapService: MapServiceProtocol = MapService()
    ) {
        self.routeService = routeService
        self.storageService = storageService ?? StorageService.shared
        self.mapService = mapService
        
        // 初始化默认地图区域（世界地图）
        self.mapRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 360)
        )
        
        // 加载最近的路线
        loadLastRoute()
    }
    
    // MARK: - Public Methods
    
    /// 添加起点
    func addStartPoint(_ point: RoutePoint) {
        // 验证地点
        let validationResult = routeService.validatePoint(point)
        guard case .valid = validationResult else {
            if case .invalid(let reason) = validationResult {
                validationError = reason
                showToastMessage(reason, type: .error)
            }
            return
        }
        
        // 如果没有当前路线，创建新路线
        if currentRoute == nil {
            currentRoute = routeService.createRoute(name: "新路线 \(Date().formatted())")
        }
        
        guard let route = currentRoute else { return }
        
        // 检查是否与现有地点重复
        if isDuplicatePoint(point, in: route) {
            validationError = "该地点已存在"
            showToastMessage("该地点已存在", type: .error)
            return
        }
        
        // 设置为起点（索引 0）
        let startPoint = point
        startPoint.orderIndex = 0
        
        // 如果已有起点，替换它
        if !route.points.isEmpty {
            route.points[0] = startPoint
        } else {
            route.points.append(startPoint)
        }
        
        // 保存路线
        try? storageService.saveRoute(route)
        
        // 异步获取城市坐标并更新地图
        Task {
            await fetchCoordinatesAndUpdateMap(for: startPoint)
        }
        
        // 更新预览按钮状态
        updatePreviewButtonState()
        
        // 清除错误
        validationError = nil
        
        // 显示成功提示
        showToastMessage("起点添加成功", type: .success)
    }
    
    /// 添加终点
    func addEndPoint(_ point: RoutePoint) {
        // 验证地点
        let validationResult = routeService.validatePoint(point)
        guard case .valid = validationResult else {
            if case .invalid(let reason) = validationResult {
                validationError = reason
                showToastMessage(reason, type: .error)
            }
            return
        }
        
        // 如果没有当前路线，创建新路线
        if currentRoute == nil {
            currentRoute = routeService.createRoute(name: "新路线 \(Date().formatted())")
        }
        
        guard let route = currentRoute else { return }
        
        // 检查是否与现有地点重复（排除当前终点）
        let pointsToCheck = route.points.count >= 2 ? Array(route.points.dropLast()) : route.points
        if pointsToCheck.contains(where: { existingPoint in
            existingPoint.cityName?.lowercased() == point.cityName?.lowercased()
        }) {
            validationError = "该地点已存在"
            showToastMessage("该地点已存在", type: .error)
            return
        }
        
        // 设置为终点
        let endPoint = point
        
        // 如果已有终点（至少 2 个点），直接替换最后一个
        if route.points.count >= 2 {
            endPoint.orderIndex = route.points.count - 1
            route.points[route.points.count - 1] = endPoint
            showToastMessage("终点已更新", type: .success)
        } else {
            // 否则添加新终点
            endPoint.orderIndex = route.points.count
            route.points.append(endPoint)
            showToastMessage("终点添加成功", type: .success)
        }
        
        // 保存路线
        try? storageService.saveRoute(route)
        
        // 异步获取城市坐标并更新地图
        Task {
            await fetchCoordinatesAndUpdateMap(for: endPoint)
        }
        
        // 更新预览按钮状态
        updatePreviewButtonState()
        
        // 清除错误
        validationError = nil
    }
    
    /// 添加中间点
    func addIntermediatePoint(_ point: RoutePoint) {
        // 验证地点
        let validationResult = routeService.validatePoint(point)
        guard case .valid = validationResult else {
            if case .invalid(let reason) = validationResult {
                validationError = reason
                showToastMessage(reason, type: .error)
            }
            return
        }
        
        // 如果没有当前路线，创建新路线
        if currentRoute == nil {
            currentRoute = routeService.createRoute(name: "新路线 \(Date().formatted())")
        }
        
        guard let route = currentRoute else { return }
        
        // 检查是否与现有地点重复
        if isDuplicatePoint(point, in: route) {
            validationError = "该地点已存在"
            showToastMessage("该地点已存在", type: .error)
            return
        }
        
        // 添加到倒数第二个位置（如果有终点的话）
        let intermediatePoint = point
        if route.points.count >= 2 {
            // 插入到倒数第二个位置
            intermediatePoint.orderIndex = route.points.count - 1
            route.points.insert(intermediatePoint, at: route.points.count - 1)
            
            // 重新编号
            for (index, point) in route.points.enumerated() {
                point.orderIndex = index
            }
        } else {
            // 直接添加到末尾
            intermediatePoint.orderIndex = route.points.count
            route.points.append(intermediatePoint)
        }
        
        // 保存路线
        try? storageService.saveRoute(route)
        
        // 异步获取城市坐标并更新地图
        Task {
            await fetchCoordinatesAndUpdateMap(for: intermediatePoint)
        }
        
        // 更新预览按钮状态
        updatePreviewButtonState()
        
        // 清除错误
        validationError = nil
        
        // 显示成功提示
        showToastMessage("途经点添加成功", type: .success)
    }
    
    /// 开始预览
    func startPreview() {
        guard let route = currentRoute else { return }
        
        // 验证路线
        let validationResult = routeService.validateRoute(route)
        guard case .valid = validationResult else {
            if case .invalid(let reason) = validationResult {
                validationError = reason
            }
            return
        }
        
        // 导航到预览页面（由 View 层处理）
        Logger.shared.info("开始预览路线: \(route.name)")
    }
    
    /// 加载最近的路线
    func loadLastRoute() {
        let routes = storageService.fetchAllRoutes()
        
        if let lastRoute = routes.sorted(by: { $0.updatedAt > $1.updatedAt }).first {
            currentRoute = lastRoute
            updateMapRegion()
            updatePreviewButtonState()
            Logger.shared.info("加载最近路线: \(lastRoute.name)")
        } else {
            Logger.shared.info("没有找到已保存的路线")
        }
    }
    
    /// 显示地点输入界面
    func showPointInput(type: PointInputType) {
        pointInputType = type
        showingPointInput = true
    }
    
    /// 隐藏地点输入界面
    func hidePointInput() {
        showingPointInput = false
        validationError = nil
    }
    
    /// 显示 Toast 提示
    func showToastMessage(_ message: String, type: ToastType) {
        toastMessage = message
        toastType = type
        showToast = true
    }
    
    /// 清除所有地点
    func clearAllPoints() {
        currentRoute = nil
        isPreviewEnabled = false
        
        // 重置地图区域到世界地图
        mapRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 360)
        )
        
        showToastMessage("已清除所有标记", type: .info)
        Logger.shared.info("清除所有地点标记")
    }
    
    /// 获取当前起点城市名
    var startCityName: String {
        guard let route = currentRoute, !route.points.isEmpty else { return "" }
        return route.points[0].cityName ?? ""
    }
    
    /// 获取当前终点城市名
    var endCityName: String {
        guard let route = currentRoute, route.points.count >= 2 else { return "" }
        return route.points.last?.cityName ?? ""
    }
    
    // MARK: - 编辑状态机方法
    
    /// 开始拖动点
    func beginDragPoint(_ point: RoutePoint, at coordinate: CLLocationCoordinate2D) {
        Logger.log("beginDragPoint pointID=\(point.id) 当前=\(editMode.description)", module: .homeVM)
        guard editMode == .idle else {
            Logger.log("beginDragPoint 忽略：非空闲", module: .homeVM, level: .warning)
            return
        }
        editMode = .draggingPoint(pointID: point.id)
        tempPointCoordinate = coordinate
    }
    
    /// 更新拖动点位置（只更新临时坐标，不修改数据）
    func updateDragPoint(to coordinate: CLLocationCoordinate2D) {
        guard case .draggingPoint = editMode else { return }
        tempPointCoordinate = coordinate
    }
    
    /// 结束拖动点（提交到数据层）
    func endDragPoint() {
        // 临时保存，避免 defer 之前状态已经被清
        let currentMode = editMode
        let currentTemp = tempPointCoordinate
        
        // 无论如何都要退回到 idle
        defer {
            editMode = .idle
            tempPointCoordinate = nil
        }

        guard case .draggingPoint(let pointID) = currentMode,
              let finalCoordinate = currentTemp else {
            return
        }
        
        if let route = currentRoute,
           let point = route.points.first(where: { $0.id == pointID }) {
            
            // 更新坐标
            point.latitude = finalCoordinate.latitude
            point.longitude = finalCoordinate.longitude
            point.cityName = nil // 标记为脏，需要重新获取
            
            try? storageService.saveRoute(route)
            
            // 异步获取新城市名
            Task { await fetchCityName(for: point) }
            
            showToastMessage("位置已更新", type: .info)
        }
    }
    
    /// 开始拖动线段（在路径上按下：只进入状态，不插入数据，避免闪烁）
    func beginDragSegment(at segmentIndex: Int, coordinate: CLLocationCoordinate2D) {
        Logger.log("beginDragSegment segmentIndex=\(segmentIndex) 当前状态=\(editMode.description)", module: .homeVM)
        guard editMode == .idle else {
            Logger.log("beginDragSegment 忽略：非空闲", module: .homeVM, level: .warning)
            return
        }
        editMode = .draggingSegment(segmentIndex: segmentIndex)
        tempPointCoordinate = coordinate
    }
    
    /// 更新拖动线段（只更新临时坐标，不修改 route.points）
    func updateDragSegment(to coordinate: CLLocationCoordinate2D) {
        guard case .draggingSegment = editMode else { return }
        tempPointCoordinate = coordinate
    }
    
    /// 结束拖动线段：用松手时的坐标插入途经点
    func endDragSegment(releaseCoordinate: CLLocationCoordinate2D?) {
        // 如果没有传入具体松手位置（可能在中途取消），则尝试使用最后已知的 tempPointCoordinate
        let finalCoord = releaseCoordinate ?? tempPointCoordinate
        
        let currentMode = editMode
        
        // 无论如何都要退回到 idle
        defer {
            editMode = .idle
            tempPointCoordinate = nil
        }
        
        guard case .draggingSegment(let segmentIndex) = currentMode,
              let coord = finalCoord else {
            return
        }
        
        insertWaypointAtSegment(segmentIndex, coordinate: coord)
        
        if let route = currentRoute {
            try? storageService.saveRoute(route)
            
            // 为新插入的点（index + 1）获取城市名
            if segmentIndex + 1 < route.points.count {
                let newPoint = route.points[segmentIndex + 1]
                Task { await fetchCityName(for: newPoint) }
            }
        }
        
        updatePreviewButtonState()
        showToastMessage("途经点已添加", type: .success)
    }
    
    /// 取消编辑（恢复 idle，不提交）
    func cancelEdit() {
        editMode = .idle
        tempPointCoordinate = nil
    }
    
    /// 插入途经点到指定线段（拆线操作）
    private func insertWaypointAtSegment(_ segmentIndex: Int, coordinate: CLLocationCoordinate2D) {
        guard let route = currentRoute else { return }
        guard segmentIndex >= 0 && segmentIndex < route.points.count else { return }
        
        // 创建新途经点（先不设置城市名，异步获取）
        let waypoint = RoutePoint(
            cityName: "新途经点",
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            orderIndex: segmentIndex
        )
        
        // 插入到 segmentIndex 之后（拆分线段）
        // 例如：A(0) -> B(1)，点击线段0，插入到 0+1 = 1 位置。变成 A(0)->New(1)->B(2)
        let insertIndex = segmentIndex + 1
        route.points.insert(waypoint, at: insertIndex)
        
        // 重新编号
        for (idx, point) in route.points.enumerated() {
            point.orderIndex = idx
        }
    }
    
    /// 删除途经点
    func deleteWaypoint(_ point: RoutePoint) {
        Logger.log("deleteWaypoint pointID=\(point.id) 当前=\(editMode.description)", module: .homeVM)
        guard let route = currentRoute else { return }
        guard let index = route.points.firstIndex(where: { $0.id == point.id }) else { return }
        
        guard index != 0 && index != route.points.count - 1 else {
            showToastMessage("不能删除起点或终点", type: .error)
            return
        }
        
        route.points.remove(at: index)
        
        // 重新编号
        for (idx, pt) in route.points.enumerated() { pt.orderIndex = idx }
        
        try? storageService.saveRoute(route)
        updatePreviewButtonState()
        showToastMessage("途经点已删除", type: .success)
    }
    
    // MARK: - Private Methods
    
    /// 获取城市坐标并更新地图
    private func fetchCoordinatesAndUpdateMap(for point: RoutePoint) async {
        // 如果已有坐标，直接更新地图
        if point.latitude != nil && point.longitude != nil {
            updateMapRegion()
            return
        }
        
        // 使用城市名称搜索坐标
        guard let cityName = point.cityName else {
            updateMapRegion()
            return
        }
        
        let result = await mapService.searchCity(name: cityName)
        
        switch result {
        case .success(let coordinate):
            // 更新地点坐标
            point.latitude = coordinate.latitude
            point.longitude = coordinate.longitude
            
            // 保存更新
            if let route = currentRoute {
                try? storageService.saveRoute(route)
            }
            
            // 更新地图区域
            updateMapRegion()
            
            Logger.shared.info("成功获取城市坐标: \(cityName) (\(coordinate.latitude), \(coordinate.longitude))")
            
        case .failure(let error):
            Logger.shared.error("获取城市坐标失败: \(error.localizedDescription)")
            // 即使失败也更新地图区域，显示已有的地点
            updateMapRegion()
        }
    }
    
    /// 根据坐标获取城市名称
    private func fetchCityName(for point: RoutePoint) async {
        guard let lat = point.latitude, let lon = point.longitude else { return }
        
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let result = await mapService.reverseGeocode(coordinate: coordinate)
        
        switch result {
        case .success(let cityName):
            point.cityName = cityName
            
            // 保存更新
            if let route = currentRoute {
                try? storageService.saveRoute(route)
            }
            
            Logger.shared.info("成功获取城市名称: \(cityName)")
            
        case .failure(let error):
            Logger.shared.error("获取城市名称失败: \(error.localizedDescription)")
            // 使用坐标作为备用名称
            point.cityName = String(format: "%.2f, %.2f", lat, lon)
        }
    }
    
    /// 更新地图区域
    private func updateMapRegion() {
        guard let route = currentRoute, !route.points.isEmpty else {
            // 没有路线或路线为空，显示世界地图
            mapRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 360)
            )
            return
        }
        
        // 计算包含所有地点的区域
        let coordinates = route.points.compactMap { point -> CLLocationCoordinate2D? in
            guard let lat = point.latitude, let lon = point.longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        
        if !coordinates.isEmpty {
            mapRegion = mapService.fitRegion(for: coordinates)
        }
    }
    
    /// 更新预览按钮状态
    private func updatePreviewButtonState() {
        guard let route = currentRoute else {
            isPreviewEnabled = false
            return
        }
        
        // 至少需要 2 个地点才能预览
        isPreviewEnabled = route.points.count >= 2
    }
    
    /// 检查地点是否重复
    private func isDuplicatePoint(_ point: RoutePoint, in route: Route) -> Bool {
        guard let cityName = point.cityName else { return false }
        
        // 检查是否有相同城市名的地点
        return route.points.contains { existingPoint in
            existingPoint.cityName?.lowercased() == cityName.lowercased()
        }
    }
}

// MARK: - Point Input Type

enum PointInputType {
    case start
    case end
    case intermediate
    
    var title: String {
        switch self {
        case .start:
            return "添加起点"
        case .end:
            return "添加终点"
        case .intermediate:
            return "添加地点"
        }
    }
}
