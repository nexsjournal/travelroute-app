//
//  AnimationService.swift
//  travelroute
//
//  Created by Kiro on 2024.
//

import Foundation
import MapKit
import CoreLocation

// MARK: - Animation Service Protocol

protocol AnimationServiceProtocol {
    func createRouteAnimation(for route: Route, duration: TimeInterval) -> RouteAnimation
    func createCameraAnimation(for route: Route, duration: TimeInterval) -> CameraAnimation
}

// MARK: - Route Animation

struct RouteAnimation {
    let keyframes: [AnimationKeyframe]
    let duration: TimeInterval
    
    /// 根据进度获取当前应该显示的地点索引
    func currentPointIndex(at progress: Double) -> Int {
        let clampedProgress = max(0, min(1, progress))
        let index = Int(clampedProgress * Double(keyframes.count - 1))
        return min(index, keyframes.count - 1)
    }
    
    /// 根据进度获取当前关键帧
    func currentKeyframe(at progress: Double) -> AnimationKeyframe {
        let index = currentPointIndex(at: progress)
        return keyframes[index]
    }
}

// MARK: - Animation Keyframe

struct AnimationKeyframe {
    let time: TimeInterval
    let coordinate: CLLocationCoordinate2D
    let pointIndex: Int
    let isPointReached: Bool
}

// MARK: - Camera Animation

struct CameraAnimation {
    let positions: [CameraPosition]
    let duration: TimeInterval
    
    /// 根据进度获取当前摄像机位置
    func currentPosition(at progress: Double) -> CameraPosition {
        let clampedProgress = max(0, min(1, progress))
        let index = Int(clampedProgress * Double(positions.count - 1))
        let safeIndex = min(index, positions.count - 1)
        return positions[safeIndex]
    }
}

// MARK: - Camera Position

struct CameraPosition {
    let center: CLLocationCoordinate2D
    let span: MKCoordinateSpan
    let time: TimeInterval
}

// MARK: - Animation Service Implementation

class AnimationService: AnimationServiceProtocol {
    
    // MARK: - Constants
    
    private let minDuration: TimeInterval = 3.0
    private let maxDuration: TimeInterval = 10.0
    private let keyframesPerSegment = 10
    
    // MARK: - Route Animation
    
    func createRouteAnimation(for route: Route, duration: TimeInterval) -> RouteAnimation {
        guard route.points.count >= 2 else {
            return RouteAnimation(keyframes: [], duration: 0)
        }
        
        // 计算动画时长
        let animationDuration = calculateDuration(for: route, requestedDuration: duration)
        
        // 生成关键帧
        var keyframes: [AnimationKeyframe] = []
        let totalSegments = route.points.count - 1
        let timePerSegment = animationDuration / Double(totalSegments)
        
        for segmentIndex in 0..<totalSegments {
            let startPoint = route.points[segmentIndex]
            let endPoint = route.points[segmentIndex + 1]
            
            guard let startCoord = startPoint.coordinate,
                  let endCoord = endPoint.coordinate else {
                continue
            }
            
            // 为每个路段生成多个关键帧
            for frameIndex in 0...keyframesPerSegment {
                let segmentProgress = Double(frameIndex) / Double(keyframesPerSegment)
                let time = Double(segmentIndex) * timePerSegment + segmentProgress * timePerSegment
                
                // 插值计算当前坐标
                let lat = startCoord.latitude + (endCoord.latitude - startCoord.latitude) * segmentProgress
                let lon = startCoord.longitude + (endCoord.longitude - startCoord.longitude) * segmentProgress
                
                let keyframe = AnimationKeyframe(
                    time: time,
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    pointIndex: segmentIndex,
                    isPointReached: frameIndex == keyframesPerSegment
                )
                
                keyframes.append(keyframe)
            }
        }
        
        return RouteAnimation(keyframes: keyframes, duration: animationDuration)
    }
    
    // MARK: - Camera Animation
    
    func createCameraAnimation(for route: Route, duration: TimeInterval) -> CameraAnimation {
        guard route.points.count >= 2 else {
            return CameraAnimation(positions: [], duration: 0)
        }
        
        // 计算动画时长
        let animationDuration = calculateDuration(for: route, requestedDuration: duration)
        
        // 生成摄像机位置
        var positions: [CameraPosition] = []
        let totalSegments = route.points.count - 1
        let timePerSegment = animationDuration / Double(totalSegments)
        
        for segmentIndex in 0..<totalSegments {
            let startPoint = route.points[segmentIndex]
            let endPoint = route.points[segmentIndex + 1]
            
            guard let startCoord = startPoint.coordinate,
                  let endCoord = endPoint.coordinate else {
                continue
            }
            
            // 为每个路段生成摄像机位置
            for frameIndex in 0...keyframesPerSegment {
                let segmentProgress = Double(frameIndex) / Double(keyframesPerSegment)
                let time = Double(segmentIndex) * timePerSegment + segmentProgress * timePerSegment
                
                // 插值计算当前中心点
                let lat = startCoord.latitude + (endCoord.latitude - startCoord.latitude) * segmentProgress
                let lon = startCoord.longitude + (endCoord.longitude - startCoord.longitude) * segmentProgress
                
                // 计算合适的缩放级别
                let span = calculateSpan(from: startCoord, to: endCoord)
                
                let position = CameraPosition(
                    center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    span: span,
                    time: time
                )
                
                positions.append(position)
            }
        }
        
        return CameraAnimation(positions: positions, duration: animationDuration)
    }
    
    // MARK: - Helper Methods
    
    /// 计算动画时长（基于路线长度）
    private func calculateDuration(for route: Route, requestedDuration: TimeInterval) -> TimeInterval {
        // 如果指定了时长，使用指定的时长
        if requestedDuration > 0 {
            return max(minDuration, min(maxDuration, requestedDuration))
        }
        
        // 根据路线长度计算时长
        let coordinates = route.points.compactMap { $0.coordinate }
        guard coordinates.count >= 2 else {
            return minDuration
        }
        
        var totalDistance: CLLocationDistance = 0
        for i in 0..<(coordinates.count - 1) {
            let from = CLLocation(latitude: coordinates[i].latitude, longitude: coordinates[i].longitude)
            let to = CLLocation(latitude: coordinates[i + 1].latitude, longitude: coordinates[i + 1].longitude)
            totalDistance += from.distance(from: to)
        }
        
        // 根据距离计算时长（每 1000 公里 1 秒，最少 3 秒，最多 10 秒）
        let calculatedDuration = totalDistance / 1000.0 / 1000.0
        return max(minDuration, min(maxDuration, calculatedDuration))
    }
    
    /// 计算合适的地图缩放级别
    private func calculateSpan(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> MKCoordinateSpan {
        let latDelta = abs(to.latitude - from.latitude)
        let lonDelta = abs(to.longitude - from.longitude)
        
        // 添加 50% 的边距
        let spanLat = max(latDelta * 1.5, 1.0)
        let spanLon = max(lonDelta * 1.5, 1.0)
        
        return MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
    }
}
