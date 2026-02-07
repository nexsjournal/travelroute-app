//
//  ScreenRecordingVideoExportService.swift
//  travelroute
//
//  真正的屏幕录制方案：直接录制预览区域的显示内容
//

import Foundation
import AVFoundation
import UIKit
import SwiftUI
import MapKit

class ScreenRecordingVideoExportService {
    
    // MARK: - Properties
    
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var isCancelled = false
    
    // MARK: - Constants
    
    private let bitRate = 5_000_000 // 5 Mbps
    
    // MARK: - Public Methods
    
    func exportVideo(
        route: Route,
        viewModel: VideoPreviewViewModel,
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
        
        Logger.shared.info("开始视频导出（真实屏幕录制）: 尺寸=\(Int(videoSize.width))x\(Int(videoSize.height)), 帧率=\(frameRate), 时长=\(Int(config.duration))秒")
        
        // 创建临时文件 URL
        let tempDir = NSTemporaryDirectory()
        let videoID = UUID().uuidString
        let filename = "route_video_\(videoID).mp4"
        let outputURL = URL(fileURLWithPath: tempDir).appendingPathComponent(filename)
        
        // 在后台队列执行渲染
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                // 1. 设置视频写入器
                try self.setupAssetWriter(outputURL: outputURL, videoSize: videoSize, frameRate: frameRate)
                
                // 2. 重置动画到起点
                DispatchQueue.main.sync {
                    viewModel.stopAnimation()
                }
                
                // 3. 逐帧录制
                try self.recordFrames(
                    viewModel: viewModel,
                    config: config,
                    videoSize: videoSize,
                    frameRate: frameRate,
                    progressHandler: progressHandler
                )
                
                // 4. 完成写入
                self.finishWriting(outputURL: outputURL, completion: completion)
                
            } catch {
                Logger.shared.error("视频导出失败: \(error.localizedDescription)")
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
    
    /// 计算视频尺寸
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
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoMaxKeyFrameIntervalKey: 30
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
    
    /// 逐帧录制（直接捕获预览 View）
    private func recordFrames(
        viewModel: VideoPreviewViewModel,
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
        
        Logger.shared.info("开始逐帧录制，总帧数: \(totalFrames)")
        
        // 获取预览 View 的引用
        var captureView: UIView?
        let viewSemaphore = DispatchSemaphore(value: 0)
        
        DispatchQueue.main.async {
            // 查找包含 AnimatedRouteMapView 的 UIView
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                // 遍历查找 MKMapView
                captureView = self.findMapView(in: window)
            }
            viewSemaphore.signal()
        }
        viewSemaphore.wait()
        
        guard let targetView = captureView else {
            Logger.shared.error("无法找到预览 View")
            throw VideoExportError.renderingFailed
        }
        
        Logger.shared.info("找到预览 View，开始录制")
        
        for frameIndex in 0..<totalFrames {
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
                    
                    if waitCount > 500 {
                        Logger.shared.error("等待视频输入超时")
                        throw VideoExportError.renderingFailed
                    }
                }
                
                // 计算当前进度
                let progress = Double(frameIndex) / Double(totalFrames)
                let presentationTime = CMTime(value: Int64(frameIndex), timescale: frameRate)
                
                // 更新动画进度
                let updateSemaphore = DispatchSemaphore(value: 0)
                DispatchQueue.main.async {
                    viewModel.updateAnimationManually(progress: progress)
                    updateSemaphore.signal()
                }
                updateSemaphore.wait()
                
                // 等待渲染
                Thread.sleep(forTimeInterval: 0.1) // 100ms 等待渲染
                
                // 捕获当前帧（直接从预览 View）
                let frameImage = try self.captureViewDirectly(targetView)
                
                // 调整图片大小到目标尺寸
                guard let resizedImage = frameImage.resize(to: videoSize) else {
                    Logger.shared.error("调整图片大小失败，帧: \(frameIndex)")
                    throw VideoExportError.renderingFailed
                }
                
                // 转换为像素缓冲
                guard let pixelBuffer = resizedImage.toPixelBuffer(size: videoSize) else {
                    Logger.shared.error("创建像素缓冲失败，帧: \(frameIndex)")
                    throw VideoExportError.renderingFailed
                }
                
                // 添加像素缓冲
                if !pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime) {
                    Logger.shared.error("添加像素缓冲失败，帧: \(frameIndex)")
                    throw VideoExportError.renderingFailed
                }
                
                // 更新进度
                if frameIndex % 10 == 0 {
                    Task { @MainActor in
                        progressHandler(progress)
                    }
                    
                    if frameIndex % 24 == 0 {
                        Logger.shared.info("录制进度: \(frameIndex)/\(totalFrames) (\(Int(progress * 100))%)")
                    }
                }
            }
        }
        
        // 标记输入完成
        videoInput.markAsFinished()
        
        Logger.shared.info("视频帧录制完成，共 \(totalFrames) 帧")
    }
    
    /// 查找 MKMapView
    private func findMapView(in view: UIView) -> UIView? {
        // 查找 MKMapView
        if view is MKMapView {
            return view
        }
        
        // 递归查找子视图
        for subview in view.subviews {
            if let found = findMapView(in: subview) {
                return found
            }
        }
        
        return nil
    }
    
    /// 直接捕获 View 的内容
    private func captureViewDirectly(_ view: UIView) throws -> UIImage {
        var resultImage: UIImage?
        let semaphore = DispatchSemaphore(value: 0)
        
        DispatchQueue.main.async {
            let renderer = UIGraphicsImageRenderer(bounds: view.bounds)
            resultImage = renderer.image { context in
                view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        
        guard let image = resultImage else {
            throw VideoExportError.renderingFailed
        }
        
        return image
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

// MARK: - UIImage Extension for Resize

extension UIImage {
    /// 调整图片大小
    func resize(to targetSize: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
