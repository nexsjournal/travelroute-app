//
//  MapPreviewView.swift
//  travelroute
//
//  Created by Kiro on 2024.
//

import SwiftUI
import MapKit

// MARK: - Map Preview View

struct MapPreviewView: View {
    let route: Route?
    @Binding var region: MKCoordinateRegion
    
    var body: some View {
        Map(position: .constant(.region(region))) {
            // 添加标注点
            ForEach(annotationItems) { item in
                if let coordinate = item.coordinate {
                    Annotation(
                        "\(item.index)",
                        coordinate: coordinate
                    ) {
                        AnnotationView(
                            index: item.index,
                            isStart: item.isStart,
                            isEnd: item.isEnd
                        )
                    }
                }
            }
            
            // 添加贝塞尔曲线路径
            if let route = route, route.points.count >= 2 {
                let coordinates = route.points.compactMap { $0.coordinate }
                if coordinates.count >= 2 {
                    MapPolyline(coordinates: createSmoothPath(from: coordinates))
                        .stroke(Color.secondary, lineWidth: 4)
                }
            }
        }
        .cornerRadius(12)
    }
    
    // MARK: - Annotation Items
    
    private var annotationItems: [MapAnnotationItem] {
        guard let route = route else { return [] }
        
        return route.points.enumerated().compactMap { index, point in
            guard let coordinate = point.coordinate else { return nil }
            return MapAnnotationItem(
                id: point.id,
                coordinate: coordinate,
                index: index + 1,
                isStart: index == 0,
                isEnd: index == route.points.count - 1
            )
        }
    }
    
    // MARK: - Smooth Path Creation
    
    /// 创建平滑的 Catmull-Rom 样条曲线路径
    private func createSmoothPath(from coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        guard coordinates.count >= 2 else { return coordinates }
        
        // 如果只有两个点，直接返回
        if coordinates.count == 2 {
            return coordinates
        }
        
        var smoothPath: [CLLocationCoordinate2D] = []
        
        // 使用 Catmull-Rom 样条曲线，确保曲线经过所有控制点且在控制点处平滑
        // 为了让曲线在端点处也平滑，我们需要添加虚拟的起点和终点
        var extendedPoints = coordinates
        
        // 在起点前添加虚拟点
        let firstPoint = coordinates[0]
        let secondPoint = coordinates[1]
        let virtualStart = CLLocationCoordinate2D(
            latitude: firstPoint.latitude - (secondPoint.latitude - firstPoint.latitude) * 0.3,
            longitude: firstPoint.longitude - (secondPoint.longitude - firstPoint.longitude) * 0.3
        )
        extendedPoints.insert(virtualStart, at: 0)
        
        // 在终点后添加虚拟点
        let lastPoint = coordinates[coordinates.count - 1]
        let secondLastPoint = coordinates[coordinates.count - 2]
        let virtualEnd = CLLocationCoordinate2D(
            latitude: lastPoint.latitude + (lastPoint.latitude - secondLastPoint.latitude) * 0.3,
            longitude: lastPoint.longitude + (lastPoint.longitude - secondLastPoint.longitude) * 0.3
        )
        extendedPoints.append(virtualEnd)
        
        // 对每个线段使用 Catmull-Rom 样条插值
        for i in 0..<(extendedPoints.count - 3) {
            let p0 = extendedPoints[i]
            let p1 = extendedPoints[i + 1]
            let p2 = extendedPoints[i + 2]
            let p3 = extendedPoints[i + 3]
            
            // 每段生成多个插值点以确保平滑
            let steps = 30
            for step in 0...steps {
                let t = Double(step) / Double(steps)
                let point = catmullRomSpline(t: t, p0: p0, p1: p1, p2: p2, p3: p3)
                smoothPath.append(point)
            }
        }
        
        return smoothPath
    }
    
    /// Catmull-Rom 样条曲线插值
    /// 这种曲线保证经过 p1 和 p2，并且在这些点处曲率连续
    private func catmullRomSpline(
        t: Double,
        p0: CLLocationCoordinate2D,
        p1: CLLocationCoordinate2D,
        p2: CLLocationCoordinate2D,
        p3: CLLocationCoordinate2D
    ) -> CLLocationCoordinate2D {
        // Catmull-Rom 样条的张力参数，0.5 是标准值
        let tension: Double = 0.5
        
        let t2 = t * t
        let t3 = t2 * t
        
        // Catmull-Rom 基函数
        let v0 = -tension * t3 + 2.0 * tension * t2 - tension * t
        let v1 = (2.0 - tension) * t3 + (tension - 3.0) * t2 + 1.0
        let v2 = (tension - 2.0) * t3 + (3.0 - 2.0 * tension) * t2 + tension * t
        let v3 = tension * t3 - tension * t2
        
        let latitude = v0 * p0.latitude + v1 * p1.latitude + v2 * p2.latitude + v3 * p3.latitude
        let longitude = v0 * p0.longitude + v1 * p1.longitude + v2 * p2.longitude + v3 * p3.longitude
        
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Map Annotation Item

struct MapAnnotationItem: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D?
    let index: Int
    let isStart: Bool
    let isEnd: Bool
}

// MARK: - Annotation View

struct AnnotationView: View {
    let index: Int
    let isStart: Bool
    let isEnd: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(width: 36, height: 36)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            
            if isStart {
                Image("icon-start")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundColor(.white)
            } else if isEnd {
                Image("icon-end")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundColor(.white)
            } else {
                // 途经点使用统一图标
                Image("icon-waypoint")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundColor(.white)
            }
        }
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

// MARK: - Route Polyline View

struct RoutePolylineView: View {
    let route: Route
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let points = route.points.compactMap { point -> CGPoint? in
                    guard let coordinate = point.coordinate else { return nil }
                    return coordinateToPoint(coordinate, in: geometry.size)
                }
                
                guard points.count >= 2 else { return }
                
                path.move(to: points[0])
                for i in 1..<points.count {
                    path.addLine(to: points[i])
                }
            }
            .stroke(Color.primary, lineWidth: 3)
        }
    }
    
    // MARK: - Coordinate Conversion
    
    private func coordinateToPoint(_ coordinate: CLLocationCoordinate2D, in size: CGSize) -> CGPoint {
        // 简化的坐标转换，实际应用中需要根据地图的投影方式进行转换
        // 这里使用简单的线性映射
        let x = (coordinate.longitude + 180) / 360 * size.width
        let y = (90 - coordinate.latitude) / 180 * size.height
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.9, longitude: 116.4),
        span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
    )
    
    let route = Route(name: "测试路线")
    route.points = [
        RoutePoint(cityName: "北京", latitude: 39.9, longitude: 116.4, orderIndex: 0),
        RoutePoint(cityName: "上海", latitude: 31.2, longitude: 121.5, orderIndex: 1),
        RoutePoint(cityName: "广州", latitude: 23.1, longitude: 113.3, orderIndex: 2)
    ]
    
    return MapPreviewView(route: route, region: $region)
        .frame(height: 400)
        .padding()
}
