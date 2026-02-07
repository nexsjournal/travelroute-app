//
//  RoutePlaybackViewModel.swift
//  travelroute
//
//  Created by Kiro on 2024.
//

import Foundation
import MapKit
import SwiftUI
import Observation

@Observable
class RoutePlaybackViewModel {
    
    // MARK: - Properties
    
    var route: Route
    var isPlaying: Bool = false
    var currentProgress: Double = 0.0
    var currentPointIndex: Int = 0
    var mapRegion: MKCoordinateRegion
    
    private var routeAnimation: RouteAnimation?
    private var cameraAnimation: CameraAnimation?
    private var timer: Timer?
    private var startTime: Date?
    
    // MARK: - Dependencies
    
    private let animationService: AnimationServiceProtocol
    
    // MARK: - Initialization
    
    init(
        route: Route,
        animationService: AnimationServiceProtocol = AnimationService()
    ) {
        self.route = route
        self.animationService = animationService
        
        // 初始化地图区域
        if let firstPoint = route.points.first,
           let coordinate = firstPoint.coordinate {
            self.mapRegion = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 5)
            )
        } else {
            self.mapRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 360)
            )
        }
        
        // 不在初始化时创建动画，等到真正需要播放时再创建
        // setupAnimations()
    }
    
    deinit {
        stop()
    }
    
    // MARK: - Public Methods
    
    /// 播放动画
    func play() {
        guard !isPlaying else { return }
        
        // 如果还没有创建动画，先创建
        if routeAnimation == nil {
            setupAnimations()
        }
        
        isPlaying = true
        startTime = Date()
        
        // 如果已经播放完成，重新开始
        if currentProgress >= 1.0 {
            currentProgress = 0.0
            currentPointIndex = 0
        }
        
        // 启动定时器
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.updateAnimation()
        }
        
    }
    
    /// 暂停动画
    func pause() {
        guard isPlaying else { return }
        
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }
    
    /// 停止动画
    func stop() {
        isPlaying = false
        currentProgress = 0.0
        currentPointIndex = 0
        
        timer?.invalidate()
        timer = nil
        startTime = nil
        
        if let firstPoint = route.points.first,
           let coordinate = firstPoint.coordinate {
            mapRegion = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 5)
            )
        }
    }
    
    /// 跳转到指定进度
    func seekTo(progress: Double) {
        let clampedProgress = max(0, min(1, progress))
        currentProgress = clampedProgress
        
        // 更新当前地点索引
        if let animation = routeAnimation {
            currentPointIndex = animation.currentPointIndex(at: clampedProgress)
        }
        
        // 更新摄像机位置
        updateCameraPosition()
    }
    
    // MARK: - Private Methods
    
    /// 设置动画
    private func setupAnimations() {
        // 创建路线动画（5 秒）
        routeAnimation = animationService.createRouteAnimation(for: route, duration: 5.0)
        
        // 创建摄像机动画
        cameraAnimation = animationService.createCameraAnimation(for: route, duration: 5.0)
    }
    
    /// 更新动画
    private func updateAnimation() {
        guard let animation = self.routeAnimation,
              let startTime = startTime else {
            return
        }
        
        // 计算当前进度
        let elapsed = Date().timeIntervalSince(startTime)
        let progress = elapsed / animation.duration
        
        if progress >= 1.0 {
            currentProgress = 1.0
            currentPointIndex = route.points.count - 1
            pause()
        } else {
            // 更新进度
            currentProgress = progress
            currentPointIndex = animation.currentPointIndex(at: progress)
            
            // 更新摄像机位置
            updateCameraPosition()
        }
    }
    
    /// 更新摄像机位置
    private func updateCameraPosition() {
        guard let cameraAnimation = cameraAnimation else { return }
        
        let position = cameraAnimation.currentPosition(at: currentProgress)
        
        // 平滑更新地图区域
        withAnimation(.easeInOut(duration: 0.3)) {
            mapRegion = MKCoordinateRegion(
                center: position.center,
                span: position.span
            )
        }
    }
    
    // MARK: - Computed Properties
    
    /// 当前显示的地点
    var currentPoints: [RoutePoint] {
        guard currentPointIndex < route.points.count else {
            return route.points
        }
        return Array(route.points.prefix(currentPointIndex + 1))
    }
    
    /// 进度百分比文本
    var progressText: String {
        return "\(Int(currentProgress * 100))%"
    }
    
    /// 当前地点名称
    var currentPointName: String {
        guard currentPointIndex < route.points.count else {
            return ""
        }
        let point = route.points[currentPointIndex]
        return point.cityName ?? "(\(point.latitude ?? 0), \(point.longitude ?? 0))"
    }
}
