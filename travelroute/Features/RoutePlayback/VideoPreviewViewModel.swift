//
//  VideoPreviewViewModel.swift
//  travelroute
//
//  视频预览 ViewModel
//

import Foundation
import MapKit
import SwiftUI
import Observation

@Observable
class VideoPreviewViewModel {
    
    // MARK: - Properties
    
    var route: Route
    
    /// 动画进度 (0.0 - 1.0)
    var animationProgress: Double = 0.0
    
    /// 地图摄像机位置
    var cameraPosition: MapCameraPosition = .automatic
    
    // 暴露给 AnimatedRouteMapView 使用的参数
    var cameraCenter: CLLocationCoordinate2D? { currentCoordinate }
    var cameraDistance: Double = 50000
    var cameraPitch: Double = 0
    var cameraHeading: Double = 0 // FIXED: North Up (0)
    
    /// 当前位置坐标
    var currentCoordinate: CLLocationCoordinate2D?
    
    /// 当前朝向角度
    var currentHeading: Double = 0.0
    
    /// 详细的路线坐标点（包含导航路径点）
    var detailedRouteCoordinates: [CLLocationCoordinate2D] = []
    
    /// 已走过的路径点（用于绘制轨迹）
    var travelledPath: [CLLocationCoordinate2D] = []
    
    // 用户设置
    var selectedVehicle: VehicleType = .car {
        didSet {
            UserDefaults.standard.set(selectedVehicle.rawValue, forKey: "selectedVehicle")
        }
    }
    
    var videoDuration: Double = 12.0 {
        didSet {
            // 保存用户设置的视频时长
            UserDefaults.standard.set(videoDuration, forKey: "videoDuration")
            
            // 视频时长改变时，重置并重新开始
            if isAnimating {
                stopAnimation()
                startAnimation()
            }
        }
    }
    
    var vehicleScale: Double = 1.0
    
    // 内部计算属性
    private var totalDistance: Double = 0
    private var segmentDistances: [Double] = []
    private var accumulatedDistances: [Double] = [] // 累积距离，用于快速查找
    
    // 动画控制
    private var displayLink: CADisplayLink?
    private var animationStartTime: Date?
    private var isAnimating = false
    
    // MARK: - Initialization
    
    init(route: Route) {
        self.route = route
        
        // 恢复用户上次选择的交通工具
        if let savedVehicle = UserDefaults.standard.string(forKey: "selectedVehicle"),
           let vehicle = VehicleType(rawValue: savedVehicle) {
            self.selectedVehicle = vehicle
        }
        
        // 恢复用户上次设置的视频时长
        let savedDuration = UserDefaults.standard.double(forKey: "videoDuration")
        if savedDuration > 0 {
            self.videoDuration = savedDuration
        }
        
        // 初始化为空
        self.detailedRouteCoordinates = []
        
        // 初始化位置到起点
        if let first = route.points.first, let coord = first.coordinate {
            self.currentCoordinate = coord
            // 初始相机高度设为 5000 或者根据 bounds 计算
            self.cameraPosition = .camera(MapCamera(centerCoordinate: coord, distance: 50000, heading: 0, pitch: 0))
        }
        
        // 生成平滑路径并计算距离
        generateSmoothRoute()
        calculateDistances()
        
        // 重新定位相机以包含全景
        if let start = self.detailedRouteCoordinates.first {
            self.currentCoordinate = start
            // self.cameraCenter updates automatically
        }
        
    }
    
    deinit {
        stopAnimation()
    }
    
    // MARK: - Public Methods
    
    /// 开始动画
    func startAnimation() {
        stopAnimation() // 确保先停止
        
        guard route.points.count >= 2, totalDistance > 0 else {
            return
        }
        
        isAnimating = true
        animationStartTime = Date()
        
        // 使用 CADisplayLink 与屏幕刷新同步（比 Timer 更流畅）
        displayLink = CADisplayLink(target: self, selector: #selector(updateFrame))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc private func updateFrame() {
        updateAnimation()
    }
    
    /// 停止动画
    func stopAnimation() {
        isAnimating = false
        displayLink?.invalidate()
        displayLink = nil
        animationStartTime = nil
    }
    
    /// 手动更新动画进度（用于视频导出）
    /// - Parameter progress: 动画进度 (0.0 - 1.0)
    func updateAnimationManually(progress: Double) {
        // 应用缓动函数
        let easedProgress = applyEasing(progress)
        animationProgress = easedProgress
        
        // 计算当前行驶的距离
        let currentDist = easedProgress * totalDistance
        
        // 找到当前所在的路段
        var currentSegmentIndex = 0
        for i in 0..<(accumulatedDistances.count - 1) {
            if currentDist >= accumulatedDistances[i] && currentDist < accumulatedDistances[i+1] {
                currentSegmentIndex = i
                break
            }
        }
        
        // 处理刚好到达终点的情况
        if currentDist >= totalDistance {
            currentSegmentIndex = detailedRouteCoordinates.count - 2
        }
        
        // 确保索引安全
        if currentSegmentIndex >= detailedRouteCoordinates.count - 1 {
             currentSegmentIndex = detailedRouteCoordinates.count - 2
        }
        if currentSegmentIndex < 0 { currentSegmentIndex = 0 }
        
        // 计算在当前路段内的进度
        let segmentStartDist = accumulatedDistances[currentSegmentIndex]
        let segmentLen = segmentDistances[currentSegmentIndex]
        let segmentProgress = segmentLen > 0 ? (currentDist - segmentStartDist) / segmentLen : 0
        
        let startCoord = detailedRouteCoordinates[currentSegmentIndex]
        let endCoord = detailedRouteCoordinates[currentSegmentIndex+1]
        
        // 插值计算当前坐标
        let currentLat = startCoord.latitude + (endCoord.latitude - startCoord.latitude) * segmentProgress
        let currentLon = startCoord.longitude + (endCoord.longitude - startCoord.longitude) * segmentProgress
        self.currentCoordinate = CLLocationCoordinate2D(latitude: currentLat, longitude: currentLon)
        
        // 计算朝向
        self.currentHeading = calculateHeading(from: startCoord, to: endCoord)
        
        // 更新已走过的路径
        var path: [CLLocationCoordinate2D] = []
        for i in 0...currentSegmentIndex {
            if i < detailedRouteCoordinates.count {
                path.append(detailedRouteCoordinates[i])
            }
        }
        if let current = self.currentCoordinate {
            path.append(current)
        }
        self.travelledPath = path
        
        // 更新摄像机距离（不更新 cameraPosition 避免动画）
        updateCameraDistance(progress: easedProgress)
    }
    
    /// 应用缓动函数
    private func applyEasing(_ rawProgress: Double) -> Double {
        let easeTime: Double = 0.02
        
        if rawProgress < easeTime {
            // Ease In (Quad)
            let t = rawProgress / easeTime
            return (t * t) * easeTime
        } else if rawProgress > (1.0 - easeTime) {
            // Ease Out (Quad)
            let t = (rawProgress - (1.0 - easeTime)) / easeTime
            let easeOut = 1 - (1 - t) * (1 - t)
            return (1.0 - easeTime) + easeOut * easeTime
        } else {
            // Linear
            return rawProgress
        }
    }
    
    // MARK: - Private Methods
    
    /// 生成平滑的路径 (Catmull-Rom Spline)
    private func generateSmoothRoute() {
        let points = route.points.sorted { $0.orderIndex < $1.orderIndex }
        guard points.count >= 2 else {
            self.detailedRouteCoordinates = points.compactMap { $0.coordinate }
            return
        }
        
        let coordinates = points.compactMap { $0.coordinate }
        self.detailedRouteCoordinates = createSmoothPath(from: coordinates)
    }
    
    private func createSmoothPath(from coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        guard coordinates.count >= 2 else { return coordinates }
        
        if coordinates.count == 2 {
            // 两点之间稍微插值一下，保证有足够的点用于动画
            let start = coordinates[0]
            let end = coordinates[1]
            var path: [CLLocationCoordinate2D] = []
            let steps = 60 // 增加点数
            for i in 0...steps {
                let t = Double(i) / Double(steps)
                let lat = start.latitude + (end.latitude - start.latitude) * t
                let lon = start.longitude + (end.longitude - start.longitude) * t
                path.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
            }
            return path
        }
        
        var smoothPath: [CLLocationCoordinate2D] = []
        var extendedPoints = coordinates
        
        // 添加虚拟端点以保证端点平滑
        let firstPoint = coordinates[0]
        let secondPoint = coordinates[1]
        let virtualStart = CLLocationCoordinate2D(
            latitude: firstPoint.latitude - (secondPoint.latitude - firstPoint.latitude) * 0.3,
            longitude: firstPoint.longitude - (secondPoint.longitude - firstPoint.longitude) * 0.3
        )
        extendedPoints.insert(virtualStart, at: 0)
        
        let lastPoint = coordinates[coordinates.count - 1]
        let secondLastPoint = coordinates[coordinates.count - 2]
        let virtualEnd = CLLocationCoordinate2D(
            latitude: lastPoint.latitude + (lastPoint.latitude - secondLastPoint.latitude) * 0.3,
            longitude: lastPoint.longitude + (lastPoint.longitude - secondLastPoint.longitude) * 0.3
        )
        extendedPoints.append(virtualEnd)
        
        for i in 0..<(extendedPoints.count - 3) {
            let p0 = extendedPoints[i]
            let p1 = extendedPoints[i + 1]
            let p2 = extendedPoints[i + 2]
            let p3 = extendedPoints[i + 3]
            
            let steps = 30
            for step in 0...steps {
                let t = Double(step) / Double(steps)
                let point = catmullRomSpline(t: t, p0: p0, p1: p1, p2: p2, p3: p3)
                smoothPath.append(point)
            }
        }
        
        return smoothPath
    }
    
    private func catmullRomSpline(
        t: Double,
        p0: CLLocationCoordinate2D,
        p1: CLLocationCoordinate2D,
        p2: CLLocationCoordinate2D,
        p3: CLLocationCoordinate2D
    ) -> CLLocationCoordinate2D {
        let tension: Double = 0.5
        let t2 = t * t
        let t3 = t2 * t
        
        let v0 = -tension * t3 + 2.0 * tension * t2 - tension * t
        let v1 = (2.0 - tension) * t3 + (tension - 3.0) * t2 + 1.0
        let v2 = (tension - 2.0) * t3 + (3.0 - 2.0 * tension) * t2 + tension * t
        let v3 = tension * t3 - tension * t2
        
        let latitude = v0 * p0.latitude + v1 * p1.latitude + v2 * p2.latitude + v3 * p3.latitude
        let longitude = v0 * p0.longitude + v1 * p1.longitude + v2 * p2.longitude + v3 * p3.longitude
        
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// 预计算所有路段的距离 (基于 detailedRouteCoordinates)
    private func calculateDistances() {
        segmentDistances = []
        accumulatedDistances = []
        totalDistance = 0
        
        let coords = detailedRouteCoordinates
        guard coords.count >= 2 else { return }
        
        var currentAcc: Double = 0
        accumulatedDistances.append(0) // 起点距离为0
        
        for i in 0..<(coords.count - 1) {
            let start = coords[i]
            let end = coords[i+1]
            
            let startLoc = CLLocation(latitude: start.latitude, longitude: start.longitude)
            let endLoc = CLLocation(latitude: end.latitude, longitude: end.longitude)
            let distance = startLoc.distance(from: endLoc)
            
            segmentDistances.append(distance)
            currentAcc += distance
            accumulatedDistances.append(currentAcc)
            totalDistance += distance
        }
    }
    
    /// 更新动画每一帧
    private func updateAnimation() {
        guard let startTime = animationStartTime, totalDistance > 0 else { return }
        
        let elapsed = Date().timeIntervalSince(startTime)
        var rawProgress = elapsed / videoDuration
        
        // 循环播放处理
        if rawProgress >= 1.0 {
            rawProgress = 0.0
            animationStartTime = Date() // 重置时间基准
            travelledPath.removeAll()
        }
        
        // 应用自定义缓动函数 (2% Ease In, 96% Linear, 2% Ease Out)
        // 用户指定：起步 2%，结尾 2%
        let easeTime: Double = 0.02
        let easedProgress: Double
        
        if rawProgress < easeTime {
            // Ease In (Quad)
            // normalize t to [0, 1]
            let t = rawProgress / easeTime
            easedProgress = (t * t) * easeTime // Scale back
        } else if rawProgress > (1.0 - easeTime) {
            // Ease Out (Quad)
            // normalize t to [0, 1]
            let t = (rawProgress - (1.0 - easeTime)) / easeTime
            // Quad ease out: 1 - (1-t)^2
            let easeOut = 1 - (1 - t) * (1 - t)
            easedProgress = (1.0 - easeTime) + easeOut * easeTime
        } else {
            // Linear
            // map [easeTime, 1-easeTime] to [easeTime, 1-easeTime]
            // actually it's just t because the curve connects
            // slight adjustment might be needed if curves don't match perfectly derivative,
            // but for simple visual:
            easedProgress = rawProgress
        }
        
        animationProgress = easedProgress
        
        // 计算当前行驶的距离
        let currentDist = easedProgress * totalDistance
        
        // 找到当前所在的路段
        // accumulatedDistances[i] <= currentDist < accumulatedDistances[i+1]
        var currentSegmentIndex = 0
        for i in 0..<(accumulatedDistances.count - 1) {
            if currentDist >= accumulatedDistances[i] && currentDist < accumulatedDistances[i+1] {
                currentSegmentIndex = i
                break
            }
        }
        
        // 处理刚好到达终点的情况
        if currentDist >= totalDistance {
            currentSegmentIndex = detailedRouteCoordinates.count - 2
        }
        
        // 确保索引安全
        if currentSegmentIndex >= detailedRouteCoordinates.count - 1 {
             currentSegmentIndex = detailedRouteCoordinates.count - 2
        }
        if currentSegmentIndex < 0 { currentSegmentIndex = 0 }
        
        // 计算在当前路段内的进度
        let segmentStartDist = accumulatedDistances[currentSegmentIndex]
        let segmentLen = segmentDistances[currentSegmentIndex]
        let segmentProgress = segmentLen > 0 ? (currentDist - segmentStartDist) / segmentLen : 0
        
        let startCoord = detailedRouteCoordinates[currentSegmentIndex]
        let endCoord = detailedRouteCoordinates[currentSegmentIndex+1]
        
        // 插值计算当前坐标
        let currentLat = startCoord.latitude + (endCoord.latitude - startCoord.latitude) * segmentProgress
        let currentLon = startCoord.longitude + (endCoord.longitude - startCoord.longitude) * segmentProgress
        self.currentCoordinate = CLLocationCoordinate2D(latitude: currentLat, longitude: currentLon)
        
        // 计算朝向
        self.currentHeading = calculateHeading(from: startCoord, to: endCoord)
        
        // 更新已走过的路径 (基于 currentSegmentIndex，与车辆位置同步)
        // 包含从起点到当前路段的所有点 + 当前插值点
        var path: [CLLocationCoordinate2D] = []
        
        // 添加所有已完成的路段点
        for i in 0...currentSegmentIndex {
            if i < detailedRouteCoordinates.count {
                path.append(detailedRouteCoordinates[i])
            }
        }
        
        // 添加当前插值点（车辆实际位置）
        if let current = self.currentCoordinate {
            path.append(current)
        }
        
        self.travelledPath = path
        
        // 调试日志
        print("🎬 动画更新: progress=\(String(format: "%.2f", easedProgress)), segmentIndex=\(currentSegmentIndex), travelledPath.count=\(path.count), currentCoord=\(self.currentCoordinate?.latitude ?? 0),\(self.currentCoordinate?.longitude ?? 0)")
        
        // 更新摄像机
        updateCamera(progress: easedProgress)
    }
    
    /// 计算两点间的方位角
    private func calculateHeading(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
        let lat1 = start.latitude * .pi / 180
        let lon1 = start.longitude * .pi / 180
        let lat2 = end.latitude * .pi / 180
        let lon2 = end.longitude * .pi / 180
        
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radiansBearing = atan2(y, x)
        
        return radiansBearing * 180 / .pi
    }
    
    /// 更新已走过的路径点
    private func updateTravelledPath(currentSegmentIndex: Int, currentPoint: CLLocationCoordinate2D) {
        var path: [CLLocationCoordinate2D] = []
        
        // 添加之前完整走过的路段点
        if currentSegmentIndex > 0 {
            for i in 0...currentSegmentIndex {
                path.append(detailedRouteCoordinates[i])
            }
        } else {
            // 第一个点总是在路径里
            if let first = detailedRouteCoordinates.first {
                path.append(first)
            }
        }
        
        // 添加当前点
        path.append(currentPoint)
        
        self.travelledPath = path
    }
    
    /// 更新摄像机位置和缩放
    private func updateCamera(progress: Double) {
        guard let center = currentCoordinate else { return }
        
        updateCameraDistance(progress: progress)
        
        withAnimation(.linear(duration: 0.1)) {
            cameraPosition = .camera(MapCamera(centerCoordinate: center, distance: self.cameraDistance, heading: 0, pitch: 0))
        }
    }
    
    /// 更新摄像机距离（不触发动画）
    private func updateCameraDistance(progress: Double) {
        // 智能缩放算法（与预览完全一致）
        let referenceDistance: Double = 500000
        let referenceDuration: Double = 30.0
        let baseAltitude: Double = 80000
        
        let routeFactor = totalDistance / referenceDistance
        let durationFactor = videoDuration / referenceDuration
        
        var targetAltitude = baseAltitude * routeFactor / max(durationFactor, 0.5)
        
        // 限制在 40000 到 200000 之间（用户要求的范围）
        let minAltitude: Double = 40000
        let maxAltitude: Double = 200000
        targetAltitude = min(max(targetAltitude, minAltitude), maxAltitude)
        
        // U型过渡（5% 缩放过渡）
        let zoomTransition: Double = 0.05
        let startEndAltitude = targetAltitude * 1.5
        
        let altitude: Double
        
        if progress < zoomTransition {
            let t = progress / zoomTransition
            altitude = startEndAltitude + (targetAltitude - startEndAltitude) * t
        } else if progress > (1.0 - zoomTransition) {
            let t = (progress - (1.0 - zoomTransition)) / zoomTransition
            altitude = targetAltitude + (startEndAltitude - targetAltitude) * t
        } else {
            altitude = targetAltitude
        }
        
        self.cameraDistance = altitude
        self.cameraPitch = 0
    }
    

}
