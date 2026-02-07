//
//  VideoPreviewView.swift
//  travelroute
//
//  视频预览页面 - 按照 Figma 设计稿实现
//

import SwiftUI
import SwiftData
import MapKit

/// 视频比例选项
enum VideoAspectRatio: String, CaseIterable {
    case square = "1:1"
    case vertical = "9:16"
    case horizontal = "16:9"
    
    var size: CGSize {
        switch self {
        case .square:
            return CGSize(width: 1, height: 1)
        case .vertical:
            return CGSize(width: 9, height: 16)
        case .horizontal:
            return CGSize(width: 16, height: 9)
        }
    }
}

/// 交通工具类型
enum VehicleType: String, CaseIterable, Identifiable {
    case car = "小轿车"
    case plane = "飞机"
    case train = "火车"
    case ship = "轮船"
    case bike = "自行车"
    case walk = "步行"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .car: return "car.fill"
        case .plane: return "airplane"
        case .train: return "tram.fill"
        case .ship: return "ferry.fill"
        case .bike: return "bicycle"
        case .walk: return "figure.walk"
        }
    }
}

struct VideoPreviewView: View {
    
    @State private var viewModel: VideoPreviewViewModel
    @State private var exportViewModel: VideoExportViewModel
    @Environment(\.dismiss) private var dismiss
    
    // UI 状态
    @State private var selectedRatio: VideoAspectRatio = .square
    @State private var showVehicleSelector = false
    
    init(route: Route) {
        _viewModel = State(initialValue: VideoPreviewViewModel(route: route))
        
        // 从 viewModel 获取视频时长
        let duration = UserDefaults.standard.double(forKey: "videoDuration")
        let videoDuration = duration > 0 ? duration : 12.0
        
        // 创建 exportViewModel
        _exportViewModel = State(initialValue: VideoExportViewModel(
            route: route,
            videoDuration: videoDuration,
            selectedRatio: .square
        ))
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 自定义导航栏
                navigationBar
                
                // 地图视频预览区域
                mapPreviewArea
                
                // 操作区域
                actionArea
            }
            
            // 渲染进度弹窗
            if case .rendering(let progress) = exportViewModel.renderState {
                renderProgressOverlay(progress: progress)
            }
            
            // 成功弹窗
            if exportViewModel.showSuccessOverlay {
                successOverlay()
            }
            
            // 错误提示
            if let error = exportViewModel.saveError {
                errorToast(message: error)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            // 只启动预览动画
            viewModel.startAnimation()
            
            // 传递 previewViewModel 引用给 exportViewModel（但不开始渲染）
            exportViewModel.previewViewModel = viewModel
        }
        .onDisappear {
            viewModel.stopAnimation()
            // 只在渲染中时才取消
            if exportViewModel.renderState.isRendering {
                exportViewModel.cancelRender()
            }
        }
        .onChange(of: viewModel.videoDuration) { _, newValue in
            exportViewModel.videoDuration = newValue
        }
        .onChange(of: selectedRatio) { _, newValue in
            exportViewModel.selectedRatio = newValue
        }
        .onChange(of: viewModel.selectedVehicle) { _, newValue in
            exportViewModel.vehicleType = newValue
        }
        .onChange(of: viewModel.vehicleScale) { _, newValue in
            exportViewModel.vehicleScale = newValue
        }
    }
    
    // MARK: - Navigation Bar
    
    private var navigationBar: some View {
        HStack(spacing: 0) {
            // 返回按钮
            Button {
                viewModel.stopAnimation()
                dismiss()
            } label: {
                Image("icon-arrow-left")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
            }
            
            Spacer()
            
            // 比例切换按钮
            ratioSwitchButton
            
            Spacer()
            
            // 右侧占位
            Color.clear
                .frame(width: 48, height: 48)
        }
        .frame(height: 48)
        .background(Color.black)
    }
    
    private var ratioSwitchButton: some View {
        HStack(spacing: 4) {
            Image("icon-ratio")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundColor(.white)
            
            Text(selectedRatio.rawValue)
                .font(.system(size: 16))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .frame(width: 88, height: 36)
        .background(Color.white.opacity(0.08))
        .cornerRadius(18)
        .onTapGesture {
            cycleRatio()
        }
    }
    
    // MARK: - Map Preview Area
    
    private var mapPreviewArea: some View {
        GeometryReader { geometry in
            ZStack {
                // 地图视频预览
                AnimatedRouteMapView(
                    route: viewModel.route,
                    detailedRouteCoordinates: viewModel.detailedRouteCoordinates,
                    travelledPath: viewModel.travelledPath,
                    vehicleType: viewModel.selectedVehicle,
                    vehicleScale: viewModel.vehicleScale,
                    vehicleHeading: viewModel.currentHeading,
                    cameraCenter: viewModel.cameraCenter,
                    cameraDistance: viewModel.cameraDistance,
                    cameraHeading: viewModel.cameraHeading,
                    cameraPitch: viewModel.cameraPitch
                )
                .frame(
                    width: calculateMapSize(in: geometry.size).width,
                    height: calculateMapSize(in: geometry.size).height
                )
                .cornerRadius(12)
                .clipped()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(16)
    }
    
    // MARK: - Action Area
    
    private var actionArea: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                // 交通工具选择
                vehicleSelectionItem
                
                // 视频长度
                videoDurationItem
                
                // 模型大小
                vehicleSizeItem
            }
            
            // 输出视频按钮
            exportButton
        }
        .padding(16)
        .background(Color.black)
    }
    
    private var vehicleSelectionItem: some View {
        VStack(spacing: 6) {
            HStack {
                Text("交通工具")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text(viewModel.selectedVehicle.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Image("icon-arrow-right")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundColor(.white)
                }
            }
            
            // 交通工具图标列表
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(VehicleType.allCases) { vehicle in
                        vehicleIconButton(vehicle)
                    }
                }
            }
        }
    }
    
    private func vehicleIconButton(_ vehicle: VehicleType) -> some View {
        Button {
            viewModel.selectedVehicle = vehicle
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(viewModel.selectedVehicle == vehicle ? Color.primary : Color.white.opacity(0.08))
                    .frame(width: 48, height: 48)
                
                Image(systemName: vehicle.iconName)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
        }
    }
    
    private var videoDurationItem: some View {
        VStack(spacing: 6) {
            HStack {
                Text("视频长度")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(Int(viewModel.videoDuration))秒")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            // 滑块
            Slider(value: $viewModel.videoDuration, in: 12...60, step: 1)
                .tint(Color.primary)
        }
    }
    
    private var vehicleSizeItem: some View {
        VStack(spacing: 6) {
            HStack {
                Text("模型大小")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(String(format: "%.2f", viewModel.vehicleScale))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            // 滑块
            Slider(value: $viewModel.vehicleScale, in: 0.2...1.5, step: 0.05)
                .tint(Color.primary)
        }
    }
    
    private var exportButton: some View {
        Button {
            // 只在 idle 或 failed 状态下可以点击
            if case .idle = exportViewModel.renderState {
                startVideoExport()
            } else if case .failed = exportViewModel.renderState {
                startVideoExport()
            }
        } label: {
            HStack(spacing: 8) {
                // 按钮始终显示"导出视频"，不显示渲染状态
                // 渲染状态由弹窗显示
                if case .failed = exportViewModel.renderState {
                    Image(systemName: "arrow.clockwise")
                    Text("重试")
                } else {
                    Text("导出视频")
                }
            }
            .font(.system(size: 18))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(buttonBackgroundColor)
            .cornerRadius(12)
        }
        .disabled(exportViewModel.renderState.isRendering)
    }
    
    private var buttonBackgroundColor: Color {
        switch exportViewModel.renderState {
        case .idle, .completed:
            return Color.primary
        case .rendering:
            return Color.gray.opacity(0.6)
        case .failed:
            return Color.error
        }
    }
    
    private func startVideoExport() {
        // 暂停预览动画
        viewModel.stopAnimation()
        
        // 更新 exportViewModel 的所有参数
        exportViewModel.videoDuration = viewModel.videoDuration
        exportViewModel.selectedRatio = selectedRatio
        exportViewModel.detailedRouteCoordinates = viewModel.detailedRouteCoordinates
        exportViewModel.cameraCenter = viewModel.cameraCenter
        exportViewModel.cameraDistance = viewModel.cameraDistance
        exportViewModel.cameraHeading = viewModel.cameraHeading
        exportViewModel.cameraPitch = viewModel.cameraPitch
        exportViewModel.vehicleType = viewModel.selectedVehicle
        exportViewModel.vehicleScale = viewModel.vehicleScale
        
        // 开始渲染
        exportViewModel.startBackgroundRender()
    }
    
    // MARK: - Render Progress Overlay
    
    private func renderProgressOverlay(progress: Double) -> some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // 进度环
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 12)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.primary, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: progress)
                    
                    VStack(spacing: 4) {
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("渲染中")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                VStack(spacing: 12) {
                    Text("正在渲染视频")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("请稍候，这可能需要几分钟")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // 取消按钮
                Button {
                    exportViewModel.cancelRender()
                    // 恢复预览动画
                    viewModel.startAnimation()
                } label: {
                    Text("取消")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 200, height: 48)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(12)
                }
            }
            .padding(48)
            .background(Color.darkBackground)
            .cornerRadius(24)
        }
    }
    
    // MARK: - Success Overlay
    
    private func successOverlay() -> some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // 成功图标
                ZStack {
                    Circle()
                        .fill(Color.success)
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 12) {
                    Text("视频已成功保存")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("已保存到相册")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // 确定按钮
                Button {
                    // 关闭弹窗
                    exportViewModel.dismissSuccess()
                    // 重置状态
                    exportViewModel.renderState = .idle
                    // 恢复预览动画
                    viewModel.startAnimation()
                } label: {
                    Text("确定")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 200, height: 48)
                        .background(Color.primary)
                        .cornerRadius(12)
                }
            }
            .padding(48)
            .background(Color.darkBackground)
            .cornerRadius(24)
        }
    }
    
    // MARK: - Vehicle Selector Sheet
    
    private var vehicleSelectorSheet: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    showVehicleSelector = false
                }
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 16) {
                    // 标题
                    HStack {
                        Text("选择交通工具")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button {
                            showVehicleSelector = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    
                    // 交通工具列表
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(VehicleType.allCases) { vehicle in
                                vehicleSelectionRow(vehicle)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(maxHeight: 400)
                }
                .background(Color.darkBackground)
                .cornerRadius(16, corners: [.topLeft, .topRight])
            }
        }
    }
    
    private func vehicleSelectionRow(_ vehicle: VehicleType) -> some View {
        Button {
            viewModel.selectedVehicle = vehicle
            showVehicleSelector = false
        } label: {
            HStack(spacing: 12) {
                Image(systemName: vehicle.iconName)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                
                Text(vehicle.rawValue)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                
                Spacer()
                
                if viewModel.selectedVehicle == vehicle {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                }
            }
            .padding()
            .background(viewModel.selectedVehicle == vehicle ? Color.primary.opacity(0.1) : Color.clear)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Export Progress Overlay
    
    private func saveProgressOverlay(progress: Double) -> some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // 进度环
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 8)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.primary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: progress)
                    
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Text("正在保存到相册...")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }
            .padding(40)
            .background(Color.darkBackground)
            .cornerRadius(16)
        }
    }
    
    // MARK: - Success Toast
    
    private var successToast: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                
                Text("视频已保存到相册")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color.success)
            .cornerRadius(12)
            .padding(.bottom, 100)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                exportViewModel.saveError = nil
            }
        }
    }
    
    // MARK: - Error Toast
    
    private func errorToast(message: String) -> some View {
        VStack {
            Spacer()
            
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                
                Text(message)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color.error)
            .cornerRadius(12)
            .padding(.bottom, 100)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                exportViewModel.saveError = nil
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func cycleRatio() {
        let allRatios = VideoAspectRatio.allCases
        if let currentIndex = allRatios.firstIndex(of: selectedRatio) {
            let nextIndex = (currentIndex + 1) % allRatios.count
            selectedRatio = allRatios[nextIndex]
        }
    }
    
    private func calculateMapSize(in containerSize: CGSize) -> CGSize {
        let padding: CGFloat = 0  // 移除内边距，直接使用容器大小
        let availableWidth = max(containerSize.width - padding, 100)  // 确保最小尺寸
        let availableHeight = max(containerSize.height - padding, 100)
        
        let ratio = selectedRatio.size
        let aspectRatio = ratio.width / ratio.height
        
        var width = availableWidth
        var height = width / aspectRatio
        
        if height > availableHeight {
            height = availableHeight
            width = height * aspectRatio
        }
        
        // 确保尺寸为正数
        width = max(width, 100)
        height = max(height, 100)
        
        return CGSize(width: width, height: height)
    }
}
