//
//  RoutePlaybackView.swift
//  travelroute
//
//  Created by Kiro on 2024.
//

import SwiftUI
import SwiftData
import MapKit

struct RoutePlaybackView: View {
    
    @State private var viewModel: RoutePlaybackViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(route: Route) {
        _viewModel = State(initialValue: RoutePlaybackViewModel(route: route))
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 地图动画区域
                mapAnimationArea
                
                // 控制面板
                controlPanel
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    viewModel.stop()
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("返回")
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .onDisappear {
            viewModel.stop()
        }
    }
    
    // MARK: - Map Animation Area
    
    private var mapAnimationArea: some View {
        ZStack {
            // 地图
            AnimatedMapView(
                route: viewModel.route,
                currentPoints: viewModel.currentPoints,
                region: $viewModel.mapRegion,
                progress: viewModel.currentProgress
            )
            
            // 当前地点信息
            VStack {
                Spacer()
                
                if !viewModel.currentPointName.isEmpty {
                    HStack {
                        Spacer()
                        
                        Text(viewModel.currentPointName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                            .padding(.trailing, 16)
                            .padding(.bottom, 16)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Control Panel
    
    private var controlPanel: some View {
        VStack(spacing: 16) {
            // 进度条
            progressBar
            
            // 播放控制按钮
            playbackControls
        }
        .padding(24)
        .background(Color.darkBackground)
    }
    
    // MARK: - Progress Bar
    
    private var progressBar: some View {
        VStack(spacing: 8) {
            // 进度文本
            HStack {
                Text(viewModel.progressText)
                    .font(.system(size: 14))
                    .foregroundColor(Color.secondaryText)
                
                Spacer()
                
                Text(viewModel.route.name)
                    .font(.system(size: 14))
                    .foregroundColor(Color.primaryText)
            }
            
            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    // 进度
                    Rectangle()
                        .fill(Color.primary)
                        .frame(width: geometry.size.width * viewModel.currentProgress, height: 4)
                        .cornerRadius(2)
                }
            }
            .frame(height: 4)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let progress = value.location.x / UIScreen.main.bounds.width
                        viewModel.seekTo(progress: progress)
                    }
            )
        }
    }
    
    // MARK: - Playback Controls
    
    private var playbackControls: some View {
        HStack(spacing: 24) {
            // 停止按钮
            Button {
                viewModel.stop()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(28)
            }
            
            Spacer()
            
            // 播放/暂停按钮
            Button {
                if viewModel.isPlaying {
                    viewModel.pause()
                } else {
                    viewModel.play()
                }
            } label: {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                    .frame(width: 72, height: 72)
                    .background(Color.primary)
                    .cornerRadius(36)
            }
            
            Spacer()
            
            // 占位（保持布局对称）
            Color.clear
                .frame(width: 56, height: 56)
        }
    }
}

// MARK: - Animated Map View

struct AnimatedMapView: View {
    let route: Route
    let currentPoints: [RoutePoint]
    @Binding var region: MKCoordinateRegion
    let progress: Double
    
    var body: some View {
        Map(position: .constant(.region(region))) {
            ForEach(annotationItems) { item in
                Annotation(
                    "\(item.index)",
                    coordinate: item.coordinate
                ) {
                    AnimatedAnnotationView(
                        index: item.index,
                        isStart: item.isStart,
                        isEnd: item.isEnd,
                        isReached: item.isReached
                    )
                }
            }
        }
        .overlay {
            if currentPoints.count >= 2 {
                AnimatedRoutePolylineView(
                    points: currentPoints,
                    progress: progress
                )
            }
        }
    }
    
    // MARK: - Annotation Items
    
    private var annotationItems: [AnimatedMapAnnotationItem] {
        return currentPoints.enumerated().map { index, point in
            AnimatedMapAnnotationItem(
                id: point.id,
                coordinate: point.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0),
                index: index + 1,
                isStart: index == 0,
                isEnd: index == route.points.count - 1,
                isReached: index < currentPoints.count
            )
        }
    }
}

// MARK: - Animated Map Annotation Item

struct AnimatedMapAnnotationItem: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let index: Int
    let isStart: Bool
    let isEnd: Bool
    let isReached: Bool
}

// MARK: - Animated Annotation View

struct AnimatedAnnotationView: View {
    let index: Int
    let isStart: Bool
    let isEnd: Bool
    let isReached: Bool
    
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.0
    
    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(width: 32, height: 32)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            
            if isStart {
                Image(systemName: "flag.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            } else if isEnd {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            } else {
                Text("\(index)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            if isReached {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
        }
        .onChange(of: isReached) { _, newValue in
            if newValue {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
        }
    }
    
    private var backgroundColor: Color {
        if isStart {
            return Color.primary
        } else if isEnd {
            return Color.secondary
        } else {
            return Color.gray
        }
    }
}

// MARK: - Animated Route Polyline View

struct AnimatedRoutePolylineView: View {
    let points: [RoutePoint]
    let progress: Double
    
    var body: some View {
        Canvas { context, size in
            // 绘制路线
            var path = Path()
            let coordinates = points.compactMap { $0.coordinate }
            
            guard coordinates.count >= 2 else { return }
            
            // 简化的坐标转换（实际应用中需要更精确的转换）
            let firstPoint = coordinateToPoint(coordinates[0], in: size)
            path.move(to: firstPoint)
            
            for i in 1..<coordinates.count {
                let point = coordinateToPoint(coordinates[i], in: size)
                path.addLine(to: point)
            }
            
            // 绘制路径
            context.stroke(
                path,
                with: .color(Color.primary),
                lineWidth: 3
            )
        }
    }
    
    private func coordinateToPoint(_ coordinate: CLLocationCoordinate2D, in size: CGSize) -> CGPoint {
        // 简化的坐标转换
        let x = (coordinate.longitude + 180) / 360 * size.width
        let y = (90 - coordinate.latitude) / 180 * size.height
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Preview

#Preview {
    PreviewWrapper()
}

private struct PreviewWrapper: View {
    @State private var container: ModelContainer
    private let route: Route
    
    init() {
        let schema = Schema([Route.self, RoutePoint.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let tempContainer = try! ModelContainer(for: schema, configurations: [config])
        _container = State(initialValue: tempContainer)
        StorageService.shared = StorageService(modelContext: tempContainer.mainContext)
        
        let testRoute = Route(name: "测试路线")
        testRoute.points = [
            RoutePoint(cityName: "北京", latitude: 39.9, longitude: 116.4, orderIndex: 0),
            RoutePoint(cityName: "上海", latitude: 31.2, longitude: 121.5, orderIndex: 1),
            RoutePoint(cityName: "广州", latitude: 23.1, longitude: 113.3, orderIndex: 2)
        ]
        self.route = testRoute
    }
    
    var body: some View {
        NavigationStack {
            RoutePlaybackView(route: route)
        }
        .modelContainer(container)
    }
}
