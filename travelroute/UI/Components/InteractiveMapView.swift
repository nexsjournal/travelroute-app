//
//  InteractiveMapView.swift
//  travelroute
//
//  Created by Kiro on 2024.
//

import SwiftUI
import MapKit

/// 可交互的地图视图，支持拖拽添加和编辑途经点
/// 基于状态机架构，分离数据层和交互层
struct InteractiveMapView: View {
    let route: Route?
    @Binding var region: MKCoordinateRegion
    @Binding var editMode: RouteEditMode
    @Binding var tempPointCoordinate: CLLocationCoordinate2D?
    
    let onBeginDragPoint: (RoutePoint, CLLocationCoordinate2D) -> Void
    let onUpdateDragPoint: (CLLocationCoordinate2D) -> Void
    let onEndDragPoint: () -> Void
    let onBeginDragSegment: (Int, CLLocationCoordinate2D) -> Void
    let onUpdateDragSegment: (CLLocationCoordinate2D) -> Void
    /// 松手时传入释放点坐标，用于插入途经点（与手指位置一致）
    let onEndDragSegment: (CLLocationCoordinate2D?) -> Void
    let onDeleteWaypoint: (RoutePoint) -> Void
    
    @State private var lastTapTime: Date?
    @State private var lastTappedPointID: UUID?
    
    var body: some View {
        GeometryReader { geometry in
            MapReader { mapProxy in
                ZStack {
                    // Map Layer
                    Map(
                        position: .constant(.region(region)),
                        interactionModes: editMode.allowsMapInteraction ? .all : []
                    ) {
                        ForEach(annotationItems(geometry: geometry)) { item in
                            if let coordinate = item.coordinate {
                                Annotation("", coordinate: coordinate) {
                                    PointAnnotationView(
                                        point: item.point,
                                        index: item.index,
                                        isStart: item.isStart,
                                        isEnd: item.isEnd,
                                        isDragging: item.isDragging,
                                        onDragStarted: {
                                            handlePointDragStarted(point: item.point!, geometry: geometry)
                                        },
                                        onDragChanged: { translation in
                                            handlePointDragChanged(translation: translation, geometry: geometry)
                                        },
                                        onDragEnded: {
                                            handlePointDragEnded()
                                        },
                                        onTap: {
                                            handlePointTap(point: item.point!)
                                        }
                                    )
                                }
                            }
                        }
                        
                        // 路径：拖动点时用 tempPointCoordinate 参与计算，自动更新
                        if let coordinates = pathCoordinates(geometry: geometry), coordinates.count >= 2 {
                            MapPolyline(coordinates: createSmoothPath(from: coordinates))
                                .stroke(Color.secondary, lineWidth: 8)
                        }
                        
                        // 临时拖拽中的新途经点 (Dragging Segment)
                        if case .draggingSegment = editMode, let coord = tempPointCoordinate {
                            Annotation("临时途经点", coordinate: coord) {
                                Circle()
                                    .fill(Color.orange.opacity(0.9))
                                    .frame(width: 40, height: 40)
                                    .overlay(Circle().stroke(Color.white, lineWidth: 3))
                            }
                        }
                    }
                    
                    // Path Interaction Overlay
                    // 使用 MapProxy 进行精准坐标转换
                    if (editMode == .idle || editMode.isDraggingSegment),
                       let route = route, route.points.count >= 2 {
                        
                        PathInteractionOverlay(
                            route: route,
                            mapProxy: mapProxy,
                            onSegmentDragStarted: { index, coord in
                                onBeginDragSegment(index, coord)
                            },
                            onSegmentDragChanged: { coord in
                                onUpdateDragSegment(coord)
                            },
                            onSegmentDragEnded: {
                                onEndDragSegment(nil)
                            }
                        )
                        // 不再需要显式 allowsHitTesting(true)，因为 Overlay 内部处理了 contentShape
                    }
                }
            }
        }
        .cornerRadius(12)
    }
    
    // MARK: - Annotation Items
    
    /// 生成标注项，考虑临时拖动状态
    private func annotationItems(geometry: GeometryProxy) -> [InteractiveMapAnnotationItem] {
        guard let route = route else { return [] }
        
        return route.points.enumerated().map { index, point in
            var coordinate = point.coordinate
            var isDragging = false
            
            // 拖动点期间只改临时坐标显示，不改数据
            if case .draggingPoint(let pointID) = editMode,
               pointID == point.id,
               let tempCoord = tempPointCoordinate {
                coordinate = tempCoord
                isDragging = true
            }
            
            return InteractiveMapAnnotationItem(
                id: point.id,
                point: point,
                coordinate: coordinate,
                index: index + 1,
                isStart: index == 0,
                isEnd: index == route.points.count - 1,
                isDragging: isDragging
            )
        }
    }
    
    /// 获取路径坐标，考虑临时拖动状态
    private func pathCoordinates(geometry: GeometryProxy) -> [CLLocationCoordinate2D]? {
        guard let route = route else { return nil }
        
        var coordinates = route.points.compactMap { $0.coordinate }
        
        // 如果正在拖动点，替换为临时坐标
        if case .draggingPoint(let pointID) = editMode,
           let tempCoord = tempPointCoordinate,
           let index = route.points.firstIndex(where: { $0.id == pointID }) {
            coordinates[index] = tempCoord
        }
        
        // 如果正在拖动 segment (新建点)，我们在视觉上需要把它加入到路径中吗？
        // TravelBoast 风格：拖动时，线条会折向手指
        // 所以我们需要找到插入点，插入临时坐标，生成用于预览的 polyline
        if case .draggingSegment(let segmentIndex) = editMode,
           let tempCoord = tempPointCoordinate {
             if segmentIndex + 1 <= coordinates.count {
                 coordinates.insert(tempCoord, at: segmentIndex + 1)
             }
        }
        
        return coordinates
    }
    
    // MARK: - Point Interaction Handlers
    
    /// 开始拖动点
    private func handlePointDragStarted(point: RoutePoint, geometry: GeometryProxy) {
        guard let coordinate = point.coordinate else { return }
        Logger.log("handlePointDragStarted pointID=\(point.id)", module: .mapView)
        onBeginDragPoint(point, coordinate) // 进入 draggingPoint
    }
    
    /// 拖动点变化（只更新临时坐标，不写回数据）
    private func handlePointDragChanged(translation: CGSize, geometry: GeometryProxy) {
        // 必须确保当前是 draggingPoint 状态
        guard case .draggingPoint(let pointID) = editMode,
              let route = route,
              let point = route.points.first(where: { $0.id == pointID }),
              let originalCoord = point.coordinate else { return }
        
        let span = region.span
        let size = geometry.size
        
        // 简单的线性映射 (注意：在大范围缩放时可能有偏差，但作为“相对移动”通常足够平滑)
        let latOffset = -translation.height / size.height * span.latitudeDelta
        let lonOffset = translation.width / size.width * span.longitudeDelta
        
        let newCoordinate = CLLocationCoordinate2D(
            latitude: originalCoord.latitude + latOffset,
            longitude: originalCoord.longitude + lonOffset
        )
        onUpdateDragPoint(newCoordinate)
    }
    
    /// 结束拖动点
    private func handlePointDragEnded() {
        Logger.log("handlePointDragEnded", module: .mapView)
        onEndDragPoint()
    }
    
    /// 处理点的点击（双击删除途经点，仅 idle 且未发生拖拽时有效）
    private func handlePointTap(point: RoutePoint) {
        Logger.log("handlePointTap pointID=\(point.id) editMode=\(editMode.description)", module: .mapView)
        guard editMode == .idle else { return }
        
        let now = Date()
        let isDoubleTap = lastTapTime != nil
            && lastTappedPointID == point.id
            && now.timeIntervalSince(lastTapTime!) < 0.35
            
        if isDoubleTap {
            Logger.log("handlePointTap 双击删除 pointID=\(point.id)", module: .mapView)
            onDeleteWaypoint(point)
            lastTapTime = nil
            lastTappedPointID = nil
        } else {
            lastTapTime = now
            lastTappedPointID = point.id
        }
    }
    
    // MARK: - Helper Methods
    
    /// 将屏幕坐标转换为地理坐标 (供内部使用 if needed)
    private func screenPointToCoordinate(_ point: CGPoint, geometry: GeometryProxy) -> CLLocationCoordinate2D {
        let size = geometry.size
        let span = region.span
        let center = region.center
        
        let relativeX = point.x / size.width
        let relativeY = point.y / size.height
        
        let longitude = center.longitude - span.longitudeDelta / 2 + span.longitudeDelta * relativeX
        let latitude = center.latitude + span.latitudeDelta / 2 - span.latitudeDelta * relativeY
        
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    // MARK: - Smooth Path Creation
    
    private func createSmoothPath(from coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        guard coordinates.count >= 2 else { return coordinates }
        
        if coordinates.count == 2 {
            return coordinates
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
}

// MARK: - Interactive Map Annotation Item

struct InteractiveMapAnnotationItem: Identifiable {
    let id: UUID
    let point: RoutePoint?
    let coordinate: CLLocationCoordinate2D?
    let index: Int
    let isStart: Bool
    let isEnd: Bool
    let isDragging: Bool
}

// MARK: - Point Annotation View

struct PointAnnotationView: View {
    let point: RoutePoint?
    let index: Int
    let isStart: Bool
    let isEnd: Bool
    let isDragging: Bool
    let onDragStarted: () -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: () -> Void
    let onTap: () -> Void
    
    @State private var dragStarted: Bool = false
    
    var body: some View {
        // 只显示标记点图标，不显示文字标签
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(width: isDragging ? 44 : 36, height: isDragging ? 44 : 36)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            
            if isStart {
                Image("icon-start")
                    .resizable()
                    .scaledToFit()
                    .frame(width: isDragging ? 22 : 18, height: isDragging ? 22 : 18)
                    .foregroundColor(.white)
            } else if isEnd {
                Image("icon-end")
                    .resizable()
                    .scaledToFit()
                    .frame(width: isDragging ? 22 : 18, height: isDragging ? 22 : 18)
                    .foregroundColor(.white)
            } else {
                Image("icon-waypoint")
                    .resizable()
                    .scaledToFit()
                    .frame(width: isDragging ? 22 : 18, height: isDragging ? 22 : 18)
                    .foregroundColor(.white)
            }
        }
        .scaleEffect(isDragging ? 1.2 : 1.0)
        .animation(.spring(response: 0.3), value: isDragging)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let distance = hypot(value.translation.width, value.translation.height)
                    // 拖拽阈值
                    if distance > 5 { // 降低阈值，更灵敏
                        if !dragStarted {
                            dragStarted = true
                            onDragStarted()
                        }
                        onDragChanged(value.translation)
                    }
                }
                .onEnded { value in
                   if dragStarted {
                        onDragEnded()
                        dragStarted = false
                    } else {
                        // 纯点击
                        onTap()
                        dragStarted = false
                    }
                }
        )
    }
    
    private var backgroundColor: Color {
        if isStart {
            return Color.primary
        } else if isEnd {
            return Color.secondary
        } else {
            return Color.warning
        }
    }
}
