//
//  AnimatedRouteMapView.swift
//  travelroute
//
//  动画路线地图视图 - 使用 Canvas Overlay 实现逐步绘制效果
//  参考 TravelBoast / Travel Animator 的实现方式
//

import SwiftUI
import MapKit

struct AnimatedRouteMapView: UIViewRepresentable {
    let route: Route
    let detailedRouteCoordinates: [CLLocationCoordinate2D]
    let travelledPath: [CLLocationCoordinate2D]
    let vehicleType: VehicleType
    let vehicleScale: Double
    let vehicleHeading: Double
    
    // Camera parameters
    let cameraCenter: CLLocationCoordinate2D?
    let cameraDistance: Double
    let cameraHeading: Double
    let cameraPitch: Double
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: AnimatedRouteMapView
        var pathOverlayView: PathOverlayView?
        
        init(_ parent: AnimatedRouteMapView) {
            self.parent = parent
        }
    }
    
    // MARK: - UIViewRepresentable
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.isUserInteractionEnabled = false
        mapView.showsUserLocation = false
        mapView.mapType = .standard
        mapView.backgroundColor = .white  // 确保背景是白色，避免透明
        
        // 创建路径绘制层（Canvas Overlay）
        // 在这个 Canvas 上绘制路径、标注和交通工具
        let pathOverlay = PathOverlayView(frame: mapView.bounds)
        pathOverlay.backgroundColor = .clear
        pathOverlay.isUserInteractionEnabled = false
        mapView.addSubview(pathOverlay)
        context.coordinator.pathOverlayView = pathOverlay
        
        print("✅ 地图初始化: 创建 Canvas Overlay（统一绘制路径和标注）")
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        
        // 1. 更新 Canvas Overlay 的 frame（跟随地图大小）
        if let pathOverlay = coordinator.pathOverlayView {
            pathOverlay.frame = mapView.bounds
        }
        
        // 2. 更新摄像机
        if let center = cameraCenter {
            let mkCamera = MKMapCamera(
                lookingAtCenter: center,
                fromDistance: cameraDistance,
                pitch: cameraPitch,
                heading: cameraHeading
            )
            mapView.setCamera(mkCamera, animated: false)
        }
        
        // 3. 准备绘制数据
        if let pathOverlay = coordinator.pathOverlayView {
            // 转换路径坐标
            let pathScreenPoints = travelledPath.map { coord in
                mapView.convert(coord, toPointTo: pathOverlay)
            }
            
            // 转换标注坐标
            var annotationData: [(point: CGPoint, type: AnnotationType, iconName: String?)] = []
            for (index, point) in route.points.enumerated() {
                guard let coord = point.coordinate else { continue }
                let screenPoint = mapView.convert(coord, toPointTo: pathOverlay)
                
                let type: AnnotationType
                let iconName: String?
                if index == 0 {
                    type = .start
                    iconName = "icon-start"
                } else if index == route.points.count - 1 {
                    type = .end
                    iconName = "icon-end"
                } else {
                    type = .waypoint
                    iconName = "icon-waypoint"
                }
                
                annotationData.append((screenPoint, type, iconName))
            }
            
            // 转换交通工具坐标
            var vehicleData: (point: CGPoint, heading: Double, scale: Double, type: VehicleType)?
            if let lastPoint = travelledPath.last {
                let screenPoint = mapView.convert(lastPoint, toPointTo: pathOverlay)
                vehicleData = (screenPoint, vehicleHeading, vehicleScale, vehicleType)
            }
            
            // 更新 Canvas 并触发重绘
            pathOverlay.updateDrawing(
                pathPoints: pathScreenPoints,
                annotations: annotationData,
                vehicle: vehicleData
            )
        }
    }
}

// MARK: - Path Overlay View (Canvas)

/// 标注类型
enum AnnotationType {
    case start
    case end
    case waypoint
}

/// 路径绘制层 - 使用 Core Graphics 统一绘制路径、标注和交通工具
/// 这是 TravelBoast / Travel Animator 的实现方式
class PathOverlayView: UIView {
    
    private var pathPoints: [CGPoint] = []
    private var annotations: [(point: CGPoint, type: AnnotationType, iconName: String?)] = []
    private var vehicle: (point: CGPoint, heading: Double, scale: Double, type: VehicleType)?
    
    // 缓存图标
    private var iconCache: [String: UIImage] = [:]
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isOpaque = false
        self.contentMode = .redraw
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// 更新绘制数据并触发重绘
    func updateDrawing(
        pathPoints: [CGPoint],
        annotations: [(point: CGPoint, type: AnnotationType, iconName: String?)],
        vehicle: (point: CGPoint, heading: Double, scale: Double, type: VehicleType)?
    ) {
        self.pathPoints = pathPoints
        self.annotations = annotations
        self.vehicle = vehicle
        setNeedsDisplay()
    }
    
    /// 绘制所有内容（每帧调用）
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // 清空画布
        context.clear(rect)
        
        // 1. 绘制路径（最底层）
        drawPath(context: context)
        
        // 2. 绘制标注（中间层）
        drawAnnotations(context: context)
        
        // 3. 绘制交通工具（最上层）
        drawVehicle(context: context)
    }
    
    // MARK: - 绘制路径
    
    private func drawPath(context: CGContext) {
        guard pathPoints.count >= 2 else { return }
        
        context.setStrokeColor(UIColor(red: 251/255, green: 89/255, blue: 92/255, alpha: 1.0).cgColor) // #FB595C
        context.setLineWidth(8)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        context.beginPath()
        context.move(to: pathPoints[0])
        
        for i in 1..<pathPoints.count {
            context.addLine(to: pathPoints[i])
        }
        
        context.strokePath()
    }
    
    // MARK: - 绘制标注
    
    private func drawAnnotations(context: CGContext) {
        for annotation in annotations {
            drawAnnotation(
                context: context,
                at: annotation.point,
                type: annotation.type,
                iconName: annotation.iconName
            )
        }
    }
    
    private func drawAnnotation(
        context: CGContext,
        at point: CGPoint,
        type: AnnotationType,
        iconName: String?
    ) {
        let size: CGFloat = 24
        let iconRect = CGRect(
            x: point.x - size / 2,
            y: point.y - size / 2,
            width: size,
            height: size
        )
        
        // 尝试使用自定义图标
        if let iconName = iconName, let icon = loadIcon(named: iconName) {
            icon.draw(in: iconRect)
        } else {
            // 降级方案：绘制圆点
            let color: UIColor
            switch type {
            case .start:
                color = .black
            case .end:
                color = .gray
            case .waypoint:
                color = .orange
            }
            
            context.setFillColor(color.cgColor)
            context.fillEllipse(in: iconRect)
            
            // 白色边框
            context.setStrokeColor(UIColor.white.cgColor)
            context.setLineWidth(2)
            context.strokeEllipse(in: iconRect)
        }
    }
    
    // MARK: - 绘制交通工具
    
    private func drawVehicle(context: CGContext) {
        guard let vehicle = vehicle else { return }
        
        let size: CGFloat = 30 * vehicle.scale
        
        // 保存上下文状态
        context.saveGState()
        
        // 移动到交通工具位置
        context.translateBy(x: vehicle.point.x, y: vehicle.point.y)
        
        // 旋转（heading - 90 度，因为 SF Symbol 默认朝右）
        let rotation = (vehicle.heading - 90) * .pi / 180
        context.rotate(by: CGFloat(rotation))
        
        // 绘制背景圆
        let bgRect = CGRect(x: -size / 2, y: -size / 2, width: size, height: size)
        context.setFillColor(UIColor.systemBlue.cgColor)
        context.fillEllipse(in: bgRect)
        
        // 绘制阴影
        context.setShadow(offset: CGSize(width: 0, height: 2), blur: 4, color: UIColor.black.withAlphaComponent(0.3).cgColor)
        
        // 绘制交通工具图标
        let iconSize: CGFloat = 20 * vehicle.scale
        let iconRect = CGRect(x: -iconSize / 2, y: -iconSize / 2, width: iconSize, height: iconSize)
        
        if let icon = loadVehicleIcon(type: vehicle.type, size: iconSize) {
            // 恢复上下文（移除阴影）
            context.restoreGState()
            context.saveGState()
            
            // 重新应用变换
            context.translateBy(x: vehicle.point.x, y: vehicle.point.y)
            context.rotate(by: CGFloat(rotation))
            
            // 绘制图标
            icon.draw(in: iconRect)
        }
        
        // 恢复上下文状态
        context.restoreGState()
    }
    
    // MARK: - 图标加载
    
    private func loadIcon(named name: String) -> UIImage? {
        if let cached = iconCache[name] {
            return cached
        }
        
        if let image = UIImage(named: name) {
            iconCache[name] = image
            return image
        }
        
        return nil
    }
    
    private func loadVehicleIcon(type: VehicleType, size: CGFloat) -> UIImage? {
        let cacheKey = "\(type.iconName)_\(size)"
        
        if let cached = iconCache[cacheKey] {
            return cached
        }
        
        let config = UIImage.SymbolConfiguration(pointSize: size, weight: .regular)
        if let image = UIImage(systemName: type.iconName, withConfiguration: config)?.withTintColor(.white, renderingMode: .alwaysOriginal) {
            iconCache[cacheKey] = image
            return image
        }
        
        return nil
    }
}

// MARK: - Custom Annotations (已废弃，现在在 Canvas 上绘制)

// 保留这些类型定义以保持兼容性，但不再使用
class VehicleAnnotation: MKPointAnnotation {}
class PointAnnotation: MKPointAnnotation {
    var color: UIColor = .systemBlue
    var iconName: String?
}

// MARK: - Preview

#Preview {
    AnimatedRouteMapView(
        route: {
            let route = Route(name: "测试路线")
            route.points = [
                RoutePoint(cityName: "北京", latitude: 39.9, longitude: 116.4, orderIndex: 0),
                RoutePoint(cityName: "上海", latitude: 31.2, longitude: 121.5, orderIndex: 1)
            ]
            return route
        }(),
        detailedRouteCoordinates: [],
        travelledPath: [],
        vehicleType: .car,
        vehicleScale: 1.0,
        vehicleHeading: 0,
        cameraCenter: CLLocationCoordinate2D(latitude: 39.9, longitude: 116.4),
        cameraDistance: 1000,
        cameraHeading: 0,
        cameraPitch: 45
    )
}
