//
//  VideoExportViewModel.swift
//  travelroute
//
//  Created by Kiro on 2024.
//

import Foundation
import Photos
import SwiftUI

// MARK: - Video Render State

enum VideoRenderState: Equatable {
    case idle
    case rendering(progress: Double)
    case completed(videoURL: URL)
    case failed(error: String)
    
    var isCompleted: Bool {
        if case .completed = self {
            return true
        }
        return false
    }
    
    var isRendering: Bool {
        if case .rendering = self {
            return true
        }
        return false
    }
    
    static func == (lhs: VideoRenderState, rhs: VideoRenderState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.rendering(let p1), .rendering(let p2)):
            return abs(p1 - p2) < 0.001
        case (.completed(let url1), .completed(let url2)):
            return url1 == url2
        case (.failed(let e1), .failed(let e2)):
            return e1 == e2
        default:
            return false
        }
    }
}

@Observable
class VideoExportViewModel {
    
    // MARK: - Properties
    
    var route: Route
    var videoDuration: Double = 12.0
    var selectedRatio: VideoAspectRatio = .square
    
    // 预览参数（从 VideoPreviewViewModel 传入）
    var detailedRouteCoordinates: [CLLocationCoordinate2D] = []
    var cameraCenter: CLLocationCoordinate2D?
    var cameraDistance: Double = 50000
    var cameraHeading: Double = 0
    var cameraPitch: Double = 0
    var vehicleType: VehicleType = .car
    var vehicleScale: Double = 1.0
    
    // 保存 VideoPreviewViewModel 的引用（用于屏幕录制）
    var previewViewModel: VideoPreviewViewModel?
    
    // 渲染状态
    var renderState: VideoRenderState = .idle
    
    // 成功弹窗显示状态
    var showSuccessOverlay: Bool = false
    
    // 保存错误
    var saveError: String?
    
    private let screenRecordingService: ScreenRecordingVideoExportService
    
    // MARK: - Initialization
    
    init(
        route: Route,
        videoDuration: Double = 12.0,
        selectedRatio: VideoAspectRatio = .square,
        screenRecordingService: ScreenRecordingVideoExportService = ScreenRecordingVideoExportService()
    ) {
        self.route = route
        self.videoDuration = videoDuration
        self.selectedRatio = selectedRatio
        self.screenRecordingService = screenRecordingService
    }
    
    // MARK: - Public Methods
    
    /// 开始后台渲染（进入页面时自动调用）
    func startBackgroundRender() {
        // 如果已经在渲染或已完成，不重复渲染
        guard case .idle = renderState else {
            Logger.shared.info("视频已在渲染或已完成，跳过")
            return
        }
        
        // 验证路线
        guard route.points.count >= 2 else {
            renderState = .failed(error: "路线至少需要 2 个地点")
            return
        }
        
        // 必须有 previewViewModel
        guard let previewViewModel = previewViewModel else {
            renderState = .failed(error: "缺少预览 ViewModel")
            return
        }
        
        Logger.shared.info("开始后台渲染视频（屏幕录制），路线: \(self.route.name), 时长: \(self.videoDuration)秒, 比例: \(self.selectedRatio.rawValue)")
        
        renderState = .rendering(progress: 0.0)
        
        // 创建视频配置
        let config = VideoExportConfig(
            aspectRatio: self.selectedRatio,
            duration: self.videoDuration,
            detailedRouteCoordinates: self.detailedRouteCoordinates,
            cameraCenter: self.cameraCenter,
            cameraDistance: self.cameraDistance,
            cameraHeading: self.cameraHeading,
            cameraPitch: self.cameraPitch,
            vehicleType: self.vehicleType,
            vehicleScale: self.vehicleScale
        )
        
        // 使用屏幕录制服务导出
        screenRecordingService.exportVideo(
            route: self.route,
            viewModel: previewViewModel,
            config: config,
            progressHandler: { [weak self] progress in
                Task { @MainActor in
                    self?.renderState = .rendering(progress: progress)
                }
            },
            completion: { [weak self] result in
                Task { @MainActor in
                    self?.handleRenderResult(result)
                }
            }
        )
    }
    
    /// 处理渲染结果
    private func handleRenderResult(_ result: Result<URL, VideoExportError>) {
        switch result {
        case .success(let videoURL):
            Logger.shared.info("视频渲染成功: \(videoURL.path)")
            renderState = .completed(videoURL: videoURL)
            
            // 自动保存到相册
            saveToPhotoLibrary(videoURL: videoURL)
            
        case .failure(let error):
            Logger.shared.error("视频渲染失败: \(error.localizedDescription)")
            renderState = .failed(error: error.localizedDescription)
        }
    }
    
    /// 保存到相册
    private func saveToPhotoLibrary(videoURL: URL) {
        // 检查相册权限
        checkPhotoLibraryPermission { [weak self] authorized in
            guard let self = self else { return }
            
            if authorized {
                self.performSave(videoURL: videoURL)
            } else {
                self.saveError = "需要相册访问权限，请在设置中授权"
                self.renderState = .idle
            }
        }
    }
    
    /// 执行保存
    private func performSave(videoURL: URL) {
        Logger.shared.info("开始保存视频到相册: \(videoURL.path)")
        
        // 实际保存到相册
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
        }) { [weak self] success, error in
            Task { @MainActor in
                guard let self = self else { return }
                
                if success {
                    Logger.shared.info("视频已保存到相册")
                    self.showSuccessOverlay = true
                } else {
                    Logger.shared.error("保存到相册失败: \(error?.localizedDescription ?? "未知错误")")
                    self.saveError = "保存到相册失败"
                    self.renderState = .idle
                }
            }
        }
    }
    
    /// 关闭成功弹窗
    func dismissSuccess() {
        showSuccessOverlay = false
    }
    
    /// 取消渲染
    func cancelRender() {
        screenRecordingService.cancelExport()
        renderState = .idle
        Logger.shared.info("用户取消视频渲染")
    }
    
    // MARK: - Private Methods
    
    /// 检查相册权限
    private func checkPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        switch status {
        case .authorized, .limited:
            completion(true)
            
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                DispatchQueue.main.async {
                    completion(newStatus == .authorized || newStatus == .limited)
                }
            }
            
        case .denied, .restricted:
            completion(false)
            
        @unknown default:
            completion(false)
        }
    }
}
