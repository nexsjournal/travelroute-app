//
//  PathInteractionOverlay.swift
//  travelroute
//
//  Created by Kiro on 2024.
//

import SwiftUI
import MapKit

/// 路径交互覆盖层，用于检测路径上的拖拽操作
/// 关键：基于原始 points 进行命中检测，不使用 smoothPath
/// 使用 MapProxy 处理坐标转换，解决投影误差问题
struct PathInteractionOverlay: View {
    let route: Route
    let mapProxy: MapProxy
    let onSegmentDragStarted: (Int, CLLocationCoordinate2D) -> Void
    let onSegmentDragChanged: (CLLocationCoordinate2D) -> Void
    let onSegmentDragEnded: () -> Void
    
    @State private var isDragging: Bool = false
    @State private var draggedSegmentIndex: Int?
    
    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .contentShape(interactivePath(in: geometry)) // 使用路径轮廓作为点击区域
                .simultaneousGesture(
                    DragGesture(minimumDistance: 2) // 稍微降低一点阈值
                        .onChanged { value in
                            if !isDragging {
                                // 检查是否在路径附近开始拖拽
                                if let segmentIndex = findNearestSegment(at: value.startLocation, in: geometry) {
                                    isDragging = true
                                    draggedSegmentIndex = segmentIndex
                                    
                                    // 获取手指在作为地图上的坐标
                                    if let coordinate = mapProxy.convert(value.startLocation, from: .local) {
                                        onSegmentDragStarted(segmentIndex, coordinate)
                                        Logger.shared.info("开始拖拽线段 \(segmentIndex)")
                                    }
                                }
                            } else {
                                // 继续拖拽
                                if let coordinate = mapProxy.convert(value.location, from: .local) {
                                    onSegmentDragChanged(coordinate)
                                }
                            }
                        }
                        .onEnded { value in
                            if isDragging {
                                onSegmentDragEnded()
                                isDragging = false
                                draggedSegmentIndex = nil
                            }
                        }
                )
        }
    }
    
    /// 生成交互路径的形状（加宽的描边）
    /// 注意：在每个节点处留出空隙，防止遮挡底部的 PointAnnotationView 手势
    private func interactivePath(in geometry: GeometryProxy) -> Path {
        var path = Path()
        let coordinates = route.points.compactMap { $0.coordinate }
        guard coordinates.count >= 2 else { return path }
        
        let lineWidth: CGFloat = 44
        let pointTouchRadius: CGFloat = 22 // 点的触摸半径
        // 我们需要截断的长度 = 点的触摸半径 + 线宽的一半(因为 lineCap .round 会延伸)
        // 稍微多留一点空隙（buffer）确保不重叠
        let cutLength = pointTouchRadius + (lineWidth / 2) + 5 
        
        for i in 0..<(coordinates.count - 1) {
            guard let p1 = mapProxy.convert(coordinates[i], to: .local),
                  let p2 = mapProxy.convert(coordinates[i+1], to: .local) else {
                continue
            }
            
            let dx = p2.x - p1.x
            let dy = p2.y - p1.y
            let dist = hypot(dx, dy)
            
            // 如果线段太短，无法留出空隙，则不绘制交互区域（也就是这小段无法拖出新点，这是合理的）
            if dist <= cutLength * 2 {
                continue
            }
            
            let unitX = dx / dist
            let unitY = dy / dist
            
            // 计算截断后的起点和终点
            let startX = p1.x + unitX * cutLength
            let startY = p1.y + unitY * cutLength
            let endX = p2.x - unitX * cutLength
            let endY = p2.y - unitY * cutLength
            
            path.move(to: CGPoint(x: startX, y: startY))
            path.addLine(to: CGPoint(x: endX, y: endY))
        }
        
        // 返回加宽的路径作为触摸区域
        return path.strokedPath(StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
    }
    
    // MARK: - Helper Methods
    
    /// 查找点击位置最近的路径段（基于原始 points，不是 smoothPath）
    /// 返回线段索引，表示 points[i] -> points[i+1]
    private func findNearestSegment(at point: CGPoint, in geometry: GeometryProxy) -> Int? {
        guard route.points.count >= 2 else { return nil }
        
        let coordinates = route.points.compactMap { $0.coordinate }
        guard coordinates.count >= 2 else { return nil }
        
        let threshold: CGFloat = 44  // 点击阈值
        var nearestSegment: Int?
        var minDistance: CGFloat = threshold
        
        // 直接检测原始线段（不使用平滑路径）
        for i in 0..<(coordinates.count - 1) {
            // 将经纬度转为屏幕坐标
            guard let start = mapProxy.convert(coordinates[i], to: .local),
                  let end = mapProxy.convert(coordinates[i + 1], to: .local) else {
                continue
            }
            
            let distance = distanceFromPointToLineSegment(
                point: point,
                lineStart: start,
                lineEnd: end
            )
            
            if distance < minDistance {
                minDistance = distance
                nearestSegment = i  // 返回线段索引
            }
        }
        
        return nearestSegment
    }
    
    /// 计算点到线段的距离
    private func distanceFromPointToLineSegment(
        point: CGPoint,
        lineStart: CGPoint,
        lineEnd: CGPoint
    ) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        
        if dx == 0 && dy == 0 {
            // 线段退化为点
            return hypot(point.x - lineStart.x, point.y - lineStart.y)
        }
        
        // 计算投影参数 t（0到1之间）
        let t = max(0, min(1,
            ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) /
            (dx * dx + dy * dy)
        ))
        
        // 计算投影点
        let projectionX = lineStart.x + t * dx
        let projectionY = lineStart.y + t * dy
        
        // 返回距离
        return hypot(point.x - projectionX, point.y - projectionY)
    }
}
