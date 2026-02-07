//
//  VideoExportService.swift
//  travelroute
//
//  Created by Kiro on 2024.
//

import Foundation
import AVFoundation
import UIKit
import Photos
import MapKit

// MARK: - Video Export Config

struct VideoExportConfig {
    let aspectRatio: VideoAspectRatio
    let duration: Double
    let detailedRouteCoordinates: [CLLocationCoordinate2D]
    let cameraCenter: CLLocationCoordinate2D?
    let cameraDistance: Double
    let cameraHeading: Double
    let cameraPitch: Double
    let vehicleType: VehicleType
    let vehicleScale: Double
}

// MARK: - Video Export Error

enum VideoExportError: Error, LocalizedError {
    case renderingFailed
    case saveFailed
    case permissionDenied
    case insufficientStorage
    case invalidRoute
    case outOfMemory
    
    var errorDescription: String? {
        switch self {
        case .renderingFailed:
            return "视频渲染失败"
        case .saveFailed:
            return "视频保存失败"
        case .permissionDenied:
            return "需要相册访问权限"
        case .insufficientStorage:
            return "存储空间不足"
        case .invalidRoute:
            return "路线数据无效"
        case .outOfMemory:
            return "内存不足，请尝试缩短视频时长"
        }
    }
}

// MARK: - Video Export Service Protocol

protocol VideoExportServiceProtocol {
    func exportVideo(
        route: Route,
        animation: RouteAnimation,
        progressHandler: @escaping (Double) -> Void,
        completion: @escaping (Result<URL, VideoExportError>) -> Void
    )
    func renderVideo(
        route: Route,
        animation: RouteAnimation,
        config: VideoExportConfig,
        progressHandler: @escaping (Double) -> Void,
        completion: @escaping (Result<URL, VideoExportError>) -> Void
    )
    func cancelExport()
}

// MARK: - Video Export Service Implementation

class VideoExportService: VideoExportServiceProtocol {
    
    // MARK: - Properties
    
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var isCancelled = false
    
    // MARK: - Constants
    
    private let bitRate = 3_000_000 // 3 Mbps
    
    // 视频尺寸根据比例动态计算
    private func calculateVideoSize(for aspectRatio: VideoAspectRatio) -> CGSize {
        switch aspectRatio {
        case .square:
            return CGSize(width: 1080, height: 1080) // 1:1
        case .vertical:
            return CGSize(width: 720, height: 1280) // 9:16
        case .horizontal:
            return CGSize(width: 1280, height: 720) // 16:9
        }
    }
    
    // MARK: - Public Methods
    
    func exportVideo(
        route: Route,
        animation: RouteAnimation,
        progressHandler: @escaping (Double) -> Void,
        completion: @escaping (Result<URL, VideoExportError>) -> Void
    ) {
        // 创建默认配置
        let defaultConfig = VideoExportConfig(
            aspectRatio: .square,
            duration: animation.duration,
            detailedRouteCoordinates: route.points.compactMap { $0.coordinate },
            cameraCenter: nil,
            cameraDistance: 50000,
            cameraHeading: 0,
            cameraPitch: 0,
            vehicleType: .car,
            vehicleScale: 1.0
        )
        
        // 使用 renderVideo 实现
        renderVideo(route: route, animation: animation, config: defaultConfig, progressHandler: progressHandler, completion: completion)
    }
    
    func renderVideo(
        route: Route,
        animation: RouteAnimation,
        config: VideoExportConfig,
        progressHandler: @escaping (Double) -> Void,
        completion: @escaping (Result<URL, VideoExportError>) -> Void
    ) {
        // 验证路线
        guard route.points.count >= 2 else {
            completion(.failure(.invalidRoute))
            return
        }
        
        // 重置取消标志
        isCancelled = false
        
        // 计算视频尺寸
        let videoSize = calculateVideoSize(for: config.aspectRatio)
        
        // 计算帧率（固定 24fps）
        let frameRate: Int32 = 24
        
        // 输出日志（避免复杂字符串插值导致类型推断问题）
        let videoSizeStr = "\(videoSize)"
        let frameRateStr = "\(frameRate)"
        let durationStr = "\(config.duration)"
        Logger.shared.info("开始渲染视频: 尺寸=\(videoSizeStr), 帧率=\(frameRateStr), 时长=\(durationStr)秒")
        
        // 创建临时文件 URL（完全拆分避免类型推断问题）
        let tempDirPath = NSTemporaryDirectory()
        let tempDirURL = URL(fileURLWithPath: tempDirPath)
        let videoFileName = "route_video_\(UUID().uuidString).mp4"
        let outputURL = tempDirURL.appendingPathComponent(videoFileName)
        
        // 在后台队列执行渲染
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                // 1. 预生成地图快照（使用配置的相机参数）
                Logger.shared.info("开始生成地图快照...")
                guard let baseSnapshot = self.generateBaseMapSnapshot(
                    route: route,
                    config: config,
                    videoSize: videoSize
                ) else {
                    throw VideoExportError.renderingFailed
                }
                Logger.shared.info("地图快照生成成功")
                
                // 2. 设置视频写入器
                try self.setupAssetWriter(outputURL: outputURL, videoSize: videoSize, frameRate: frameRate)
                
                // 3. 渲染视频帧（使用预生成的快照和详细路径）
                try self.renderFramesWithBaseSnapshot(
                    baseSnapshot: baseSnapshot,
                    route: route,
                    animation: animation,
                    config: config,
                    videoSize: videoSize,
                    frameRate: frameRate,
                    progressHandler: progressHandler
                )
                
                // 4. 完成写入
                self.finishWriting(outputURL: outputURL, completion: completion)
                
            } catch {
                Logger.shared.error("视频渲染失败: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(.renderingFailed))
                }
            }
        }
    }
    
    func cancelExport() {
        isCancelled = true
        assetWriter?.cancelWriting()
        Logger.shared.info("取消视频导出")
    }
    
    // MARK: - Private Methods
    
    /// 预生成地图快照（只生成一次，大幅提升性能）
    private func generateBaseMapSnapshot(
        route: Route,
        config: VideoExportConfig,
        videoSize: CGSize
    ) -> (image: UIImage, snapshot: MKMapSnapshotter.Snapshot)? {
        // 使用详细路径坐标
        let allCoordinates = config.detailedRouteCoordinates.isEmpty 
            ? route.points.compactMap { $0.coordinate }
            : config.detailedRouteCoordinates
        
        guard !allCoordinates.isEmpty else {
            Logger.shared.error("路线坐标为空")
            return nil
        }
        
        // 使用配置的相机参数计算地图区域
        let mapRegion: MKCoordinateRegion
        if let center = config.cameraCenter {
            // 使用预览的相机参数
            let span = MKCoordinateSpan(
                latitudeDelta: config.cameraDistance / 111000.0, // 粗略转换
                longitudeDelta: config.cameraDistance / 111000.0
            )
            mapRegion = MKCoordinateRegion(center: center, span: span)
        } else {
            // 降级方案：计算包含所有点的区域
            mapRegion = calculateMapRegion(for: allCoordinates)
        }
        
        // 配置地图快照选项
        let options = MKMapSnapshotter.Options()
        options.region = mapRegion
        options.size = videoSize
        options.mapType = .standard
        
        // 使用新的配置方式（iOS 13+）
        if #available(iOS 13.0, *) {
            let mapConfig = MKStandardMapConfiguration()
            mapConfig.pointOfInterestFilter = .includingAll
            mapConfig.showsTraffic = false
            options.preferredConfiguration = mapConfig
        } else {
            options.showsBuildings = true
        }
        
        // 创建信号量用于同步等待
        let semaphore = DispatchSemaphore(value: 0)
        var result: (UIImage, MKMapSnapshotter.Snapshot)?
        
        // 创建地图快照
        let snapshotter = MKMapSnapshotter(options: options)
        snapshotter.start { snapshot, error in
            defer { semaphore.signal() }
            
            if let error = error {
                Logger.shared.error("地图快照失败: \(error.localizedDescription)")
                return
            }
            
            guard let snapshot = snapshot else {
                Logger.shared.error("地图快照为空")
                return
            }
            
            result = (snapshot.image, snapshot)
        }
        
        // 等待快照完成（最多 10 秒）
        let timeout = semaphore.wait(timeout: .now() + 10.0)
        
        if timeout == .timedOut {
            Logger.shared.error("地图快照超时")
            return nil
        }
        
        return result
    }
    
    /// 使用预生成的快照渲染视频帧
    private func renderFramesWithBaseSnapshot(
        baseSnapshot: (image: UIImage, snapshot: MKMapSnapshotter.Snapshot),
        route: Route,
        animation: RouteAnimation,
        config: VideoExportConfig,
        videoSize: CGSize,
        frameRate: Int32,
        progressHandler: @escaping (Double) -> Void
    ) throws {
        guard let videoInput = videoInput,
              let pixelBufferAdaptor = pixelBufferAdaptor else {
            throw VideoExportError.renderingFailed
        }
        
        let totalFrames = Int(config.duration * Double(frameRate))
        
        Logger.shared.info("开始渲染视频帧，总帧数: \(totalFrames)")
        
        for frameIndex in 0..<totalFrames {
            // 使用 autoreleasepool 及时释放每帧的临时对象
            try autoreleasepool {
                // 检查是否取消
                if isCancelled {
                    Logger.shared.info("渲染被取消，当前帧: \(frameIndex)/\(totalFrames)")
                    throw VideoExportError.renderingFailed
                }
                
                // 等待输入准备好
                var waitCount = 0
                while !videoInput.isReadyForMoreMediaData {
                    Thread.sleep(forTimeInterval: 0.01)
                    waitCount += 1
                    
                    // 防止无限等待
                    if waitCount > 500 { // 5 秒超时
                        Logger.shared.error("等待视频输入超时")
                        throw VideoExportError.renderingFailed
                    }
                }
                
                // 计算当前进度
                let progress = Double(frameIndex) / Double(totalFrames)
                let presentationTime = CMTime(value: Int64(frameIndex), timescale: frameRate)
                
                // 生成帧图像（使用预生成的快照和详细路径）
                let image = generateFrameWithBaseSnapshot(
                    baseSnapshot: baseSnapshot,
                    route: route,
                    animation: animation,
                    config: config,
                    videoSize: videoSize,
                    progress: progress
                )
                
                // 转换为像素缓冲
                guard let pixelBuffer = image.toPixelBuffer(size: videoSize) else {
                    Logger.shared.error("创建像素缓冲失败，帧: \(frameIndex)")
                    throw VideoExportError.renderingFailed
                }
                
                // 添加像素缓冲
                if !pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime) {
                    Logger.shared.error("添加像素缓冲失败，帧: \(frameIndex)")
                    throw VideoExportError.renderingFailed
                }
                
                // 更新进度（每 10 帧更新一次，减少主线程压力）
                if frameIndex % 10 == 0 {
                    Task { @MainActor in
                        progressHandler(progress)
                    }
                    
                    // 每 30 帧输出一次日志
                    if frameIndex % 30 == 0 {
                        Logger.shared.info("渲染进度: \(frameIndex)/\(totalFrames) (\(Int(progress * 100))%)")
                    }
                }
            }
        }
        
        // 标记输入完成
        videoInput.markAsFinished()
        
        Logger.shared.info("视频帧渲染完成，共 \(totalFrames) 帧")
    }
    
    /// 在基础快照上绘制动画帧
    private func generateFrameWithBaseSnapshot(
        baseSnapshot: (image: UIImage, snapshot: MKMapSnapshotter.Snapshot),
        route: Route,
        animation: RouteAnimation,
        config: VideoExportConfig,
        videoSize: CGSize,
        progress: Double
    ) -> UIImage {
        // 使用详细路径坐标
        let pathCoordinates = config.detailedRouteCoordinates.isEmpty
            ? route.points.compactMap { $0.coordinate }
            : config.detailedRouteCoordinates
        
        guard !pathCoordinates.isEmpty else {
            return baseSnapshot.image
        }
        
        // 计算当前应该显示的路径点（逐步绘制效果）
        let totalPoints = pathCoordinates.count
        let currentPointIndex = min(Int(progress * Double(totalPoints)), totalPoints - 1)
        
        // 计算已走过的路径（基于进度）
        var travelledCoordinates: [CLLocationCoordinate2D] = []
        
        // 添加已完成的路径段
        for i in 0...currentPointIndex {
            if i < pathCoordinates.count {
                travelledCoordinates.append(pathCoordinates[i])
            }
        }
        
        // 如果还在某段路径中间，添加插值点
        if currentPointIndex < totalPoints - 1 {
            let segmentProgress = (progress * Double(totalPoints - 1)) - Double(currentPointIndex)
            if segmentProgress > 0 {
                let start = pathCoordinates[currentPointIndex]
                let end = pathCoordinates[currentPointIndex + 1]
                let interpolatedLat = start.latitude + (end.latitude - start.latitude) * segmentProgress
                let interpolatedLon = start.longitude + (end.longitude - start.longitude) * segmentProgress
                travelledCoordinates.append(CLLocationCoordinate2D(latitude: interpolatedLat, longitude: interpolatedLon))
            }
        }
        
        guard !travelledCoordinates.isEmpty else {
            return baseSnapshot.image
        }
        
        // 在快照上绘制路径和标记
        let renderer = UIGraphicsImageRenderer(size: videoSize)
        return renderer.image { context in
            // 1. 绘制基础地图快照
            baseSnapshot.image.draw(at: .zero)
            
            // 2. 绘制已走过的路径（逐步绘制）
            drawTravelledPath(
                context: context.cgContext,
                coordinates: travelledCoordinates,
                snapshot: baseSnapshot.snapshot
            )
            
            // 3. 绘制所有地点标记（起点、终点、途经点）
            drawPointMarkers(
                context: context.cgContext,
                points: route.points,
                snapshot: baseSnapshot.snapshot
            )
            
            // 4. 绘制交通工具（在路径末端）
            if let currentLocation = travelledCoordinates.last {
                let heading = calculateHeading(
                    from: travelledCoordinates.count >= 2 ? travelledCoordinates[travelledCoordinates.count - 2] : currentLocation,
                    to: currentLocation
                )
                drawVehicle(
                    context: context.cgContext,
                    location: currentLocation,
                    heading: heading,
                    vehicleType: config.vehicleType,
                    vehicleScale: config.vehicleScale,
                    snapshot: baseSnapshot.snapshot
                )
            }
            
            // 5. 绘制当前位置信息
            drawCurrentLocationInfo(
                context: context.cgContext,
                route: route,
                pathCoordinates: pathCoordinates,
                currentIndex: currentPointIndex
            )
        }
    }
    
    /// 设置 AVAssetWriter
    private func setupAssetWriter(outputURL: URL, videoSize: CGSize, frameRate: Int32) throws {
        // 删除已存在的文件
        try? FileManager.default.removeItem(at: outputURL)
        
        // 创建 AVAssetWriter
        assetWriter = try AVAssetWriter(url: outputURL, fileType: .mp4)
        
        // 配置视频设置
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoSize.width,
            AVVideoHeightKey: videoSize.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitRate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        
        // 创建视频输入
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = false
        
        // 创建像素缓冲适配器
        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: videoSize.width,
            kCVPixelBufferHeightKey as String: videoSize.height
        ]
        
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput!,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )
        
        // 添加输入到写入器
        if let videoInput = videoInput {
            assetWriter?.add(videoInput)
        }
        
        // 开始写入
        guard assetWriter?.startWriting() == true else {
            throw VideoExportError.renderingFailed
        }
        
        assetWriter?.startSession(atSourceTime: .zero)
        
        Logger.shared.info("视频写入器设置完成")
    }
    
    // 注意：此方法已废弃，使用 renderFramesWithBaseSnapshot 代替
    
    // 注意：这些方法已废弃，使用 generateFrameWithBaseSnapshot 代替
    
    /// 计算地图区域
    private func calculateMapRegion(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
            )
        }
        
        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude
        
        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.5, // 增加 50% 边距
            longitudeDelta: (maxLon - minLon) * 1.5
        )
        
        return MKCoordinateRegion(center: center, span: span)
    }
    
    /// 绘制已走过的路径
    private func drawTravelledPath(
        context: CGContext,
        coordinates: [CLLocationCoordinate2D],
        snapshot: MKMapSnapshotter.Snapshot
    ) {
        guard coordinates.count >= 2 else { return }
        
        // 转换坐标到屏幕点
        let points = coordinates.map { snapshot.point(for: $0) }
        
        // 绘制路径（使用辅助色 #FB595C）
        context.setStrokeColor(UIColor(red: 251/255, green: 89/255, blue: 92/255, alpha: 1.0).cgColor)
        context.setLineWidth(6)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        let path = CGMutablePath()
        path.move(to: points[0])
        for i in 1..<points.count {
            path.addLine(to: points[i])
        }
        
        context.addPath(path)
        context.strokePath()
    }
    
    /// 绘制地点标记
    private func drawPointMarkers(
        context: CGContext,
        points: [RoutePoint],
        snapshot: MKMapSnapshotter.Snapshot
    ) {
        for (index, point) in points.enumerated() {
            guard let coord = point.coordinate else { continue }
            
            let screenPoint = snapshot.point(for: coord)
            let isStart = index == 0
            let isEnd = index == points.count - 1
            
            // 绘制圆形标记
            let markerSize: CGFloat = 28
            let markerRect = CGRect(
                x: screenPoint.x - markerSize / 2,
                y: screenPoint.y - markerSize / 2,
                width: markerSize,
                height: markerSize
            )
            
            // 设置颜色
            let color: UIColor
            if isStart {
                color = UIColor.black  // 起点：黑色
            } else if isEnd {
                color = UIColor.gray  // 终点：灰色
            } else {
                color = UIColor.orange  // 途经点：橙色
            }
            
            // 绘制外圈
            context.setFillColor(color.cgColor)
            context.fillEllipse(in: markerRect)
            
            // 绘制白色边框
            context.setStrokeColor(UIColor.white.cgColor)
            context.setLineWidth(3)
            context.strokeEllipse(in: markerRect)
            
            // 绘制内圈（白色）
            let innerSize = markerSize * 0.35
            let innerRect = CGRect(
                x: screenPoint.x - innerSize / 2,
                y: screenPoint.y - innerSize / 2,
                width: innerSize,
                height: innerSize
            )
            context.setFillColor(UIColor.white.cgColor)
            context.fillEllipse(in: innerRect)
        }
    }
    
    /// 绘制当前位置信息（使用详细路径坐标）
    private func drawCurrentLocationInfo(
        context: CGContext,
        route: Route,
        pathCoordinates: [CLLocationCoordinate2D],
        currentIndex: Int
    ) {
        // 找到最接近当前索引的路线点
        guard !pathCoordinates.isEmpty, currentIndex < pathCoordinates.count else { return }
        
        // 根据当前索引找到对应的路线点
        let totalDetailedPoints = pathCoordinates.count
        let totalRoutePoints = route.points.count
        
        // 计算当前在哪个路线点附近
        let pointIndex = min(Int(Double(currentIndex) / Double(totalDetailedPoints) * Double(totalRoutePoints)), totalRoutePoints - 1)
        
        guard pointIndex < route.points.count else { return }
        
        let point = route.points[pointIndex]
        let text = point.cityName ?? "未知地点"
        
        // 计算视频尺寸（需要从 config 获取，这里使用默认值）
        let videoSize = CGSize(width: 1080, height: 1080) // 默认 1:1
        
        // 绘制半透明背景
        let padding: CGFloat = 20
        let textHeight: CGFloat = 60
        let textRect = CGRect(
            x: padding,
            y: videoSize.height - textHeight - padding,
            width: videoSize.width - padding * 2,
            height: textHeight
        )
        
        // 绘制背景（黑色半透明）
        context.setFillColor(UIColor.black.withAlphaComponent(0.7).cgColor)
        let backgroundRect = textRect.insetBy(dx: -16, dy: -12)
        let backgroundPath = UIBezierPath(roundedRect: backgroundRect, cornerRadius: 12)
        context.addPath(backgroundPath.cgPath)
        context.fillPath()
        
        // 绘制文字
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 22, weight: .semibold),
            .foregroundColor: UIColor.white
        ]
        
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        attributedText.draw(in: textRect)
    }
    
    /// 绘制交通工具（支持不同类型和缩放）
    private func drawVehicle(
        context: CGContext,
        location: CLLocationCoordinate2D,
        heading: Double,
        vehicleType: VehicleType,
        vehicleScale: Double,
        snapshot: MKMapSnapshotter.Snapshot
    ) {
        let screenPoint = snapshot.point(for: location)
        
        // 根据缩放调整大小
        let baseSize: CGFloat = 40
        let size: CGFloat = baseSize * CGFloat(vehicleScale)
        
        // 保存上下文状态
        context.saveGState()
        
        // 移动到交通工具位置
        context.translateBy(x: screenPoint.x, y: screenPoint.y)
        
        // 旋转（heading - 90 度，因为 SF Symbol 默认朝右）
        let rotation = (heading - 90) * .pi / 180
        context.rotate(by: CGFloat(rotation))
        
        // 绘制背景圆（主色 #319FF9）
        let bgRect = CGRect(x: -size / 2, y: -size / 2, width: size, height: size)
        context.setFillColor(UIColor(red: 49/255, green: 159/255, blue: 249/255, alpha: 1.0).cgColor)
        context.fillEllipse(in: bgRect)
        
        // 绘制白色边框
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(3)
        context.strokeEllipse(in: bgRect)
        
        // 绘制阴影
        context.setShadow(offset: CGSize(width: 0, height: 3), blur: 6, color: UIColor.black.withAlphaComponent(0.4).cgColor)
        
        // 根据交通工具类型选择图标
        let iconName: String
        switch vehicleType {
        case .car:
            iconName = "car.fill"
        case .plane:
            iconName = "airplane"
        case .train:
            iconName = "tram.fill"
        case .ship:
            iconName = "ferry.fill"
        case .bike:
            iconName = "bicycle"
        case .walk:
            iconName = "figure.walk"
        }
        
        // 绘制交通工具图标（使用 SF Symbol）
        let iconSize: CGFloat = 24 * CGFloat(vehicleScale)
        let iconRect = CGRect(x: -iconSize / 2, y: -iconSize / 2, width: iconSize, height: iconSize)
        
        let config = UIImage.SymbolConfiguration(pointSize: iconSize, weight: .regular)
        if let icon = UIImage(systemName: iconName, withConfiguration: config)?.withTintColor(.white, renderingMode: .alwaysOriginal) {
            // 恢复上下文（移除阴影）
            context.restoreGState()
            context.saveGState()
            
            // 重新应用变换
            context.translateBy(x: screenPoint.x, y: screenPoint.y)
            context.rotate(by: CGFloat(rotation))
            
            // 绘制图标
            icon.draw(in: iconRect)
        }
        
        // 恢复上下文状态
        context.restoreGState()
    }
    
    /// 计算两点之间的方向角度（度数）
    private func calculateHeading(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let deltaLon = to.longitude - from.longitude
        let y = sin(deltaLon * .pi / 180) * cos(to.latitude * .pi / 180)
        let x = cos(from.latitude * .pi / 180) * sin(to.latitude * .pi / 180) -
                sin(from.latitude * .pi / 180) * cos(to.latitude * .pi / 180) * cos(deltaLon * .pi / 180)
        let heading = atan2(y, x) * 180 / .pi
        return (heading + 360).truncatingRemainder(dividingBy: 360)
    }
    
    /// 完成写入
    private func finishWriting(outputURL: URL, completion: @escaping (Result<URL, VideoExportError>) -> Void) {
        guard let assetWriter = assetWriter else {
            Task { @MainActor in
                completion(.failure(.renderingFailed))
            }
            return
        }
        
        assetWriter.finishWriting { [weak self] in
            guard let self = self else { return }
            
            Task { @MainActor in
                if self.isCancelled {
                    Logger.shared.info("视频导出已取消")
                    completion(.failure(.renderingFailed))
                    return
                }
                
                if let error = assetWriter.error {
                    Logger.shared.error("视频写入失败: \(error.localizedDescription)")
                    completion(.failure(.renderingFailed))
                } else if assetWriter.status == .completed {
                    Logger.shared.info("视频导出成功: \(outputURL.path)")
                    completion(.success(outputURL))
                } else {
                    Logger.shared.error("视频写入状态异常: \(assetWriter.status.rawValue)")
                    completion(.failure(.renderingFailed))
                }
            }
        }
    }
}

// MARK: - UIImage Extension

extension UIImage {
    func toPixelBuffer(size: CGSize) -> CVPixelBuffer? {
        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height)
        ]
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32ARGB,
            attributes as CFDictionary,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            Logger.shared.error("创建像素缓冲失败，状态码: \(status)")
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        guard let pixelData = CVPixelBufferGetBaseAddress(buffer) else {
            Logger.shared.error("获取像素缓冲地址失败")
            return nil
        }
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: pixelData,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            Logger.shared.error("创建 CGContext 失败")
            return nil
        }
        
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(context)
        self.draw(in: CGRect(origin: .zero, size: size))
        UIGraphicsPopContext()
        
        return buffer
    }
}
