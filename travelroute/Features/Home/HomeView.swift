//
//  HomeView.swift
//  travelroute
//
//  Created by Kiro on 2024.
//

import SwiftUI
import SwiftData
import MapKit

struct HomeView: View {
    
    @State private var viewModel = HomeViewModel()
    @State private var showingPointInput = false
    @State private var showingRouteEditor = false
    @State private var showingPlayback = false
    @State private var showingSettings = false
    @State private var showingRouteList = false
    @State private var showingClearConfirmation = false
    @State private var cityName = ""
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var searchText = ""
    @State private var filteredCities: [(name: String, country: String, province: String)] = []
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 状态栏背景
                statusBarBackground
                
                ZStack {
                    // 交互式地图区域（带圆角，填满宽度）
                    InteractiveMapView(
                        route: viewModel.currentRoute,
                        region: $viewModel.mapRegion,
                        editMode: $viewModel.editMode,
                        tempPointCoordinate: $viewModel.tempPointCoordinate,
                        onBeginDragPoint: { point, coordinate in
                            viewModel.beginDragPoint(point, at: coordinate)
                        },
                        onUpdateDragPoint: { coordinate in
                            viewModel.updateDragPoint(to: coordinate)
                        },
                        onEndDragPoint: {
                            viewModel.endDragPoint()
                        },
                        onBeginDragSegment: { segmentIndex, coordinate in
                            viewModel.beginDragSegment(at: segmentIndex, coordinate: coordinate)
                        },
                        onUpdateDragSegment: { coordinate in
                            viewModel.updateDragSegment(to: coordinate)
                        },
                        onEndDragSegment: { releaseCoordinate in
                            viewModel.endDragSegment(releaseCoordinate: releaseCoordinate)
                        },
                        onDeleteWaypoint: { point in
                            viewModel.deleteWaypoint(point)
                        }
                    )
                    .cornerRadius(16)
                    
                    // 顶部按钮栏（浮动在地图上）
                    VStack {
                        topButtonBar
                        Spacer()
                    }
                }
                
                // 底部操作按钮区域
                actionArea
            }
            .background(Color.black)
            .navigationDestination(isPresented: $showingRouteEditor) {
                if let route = viewModel.currentRoute {
                    RouteEditorView(route: route)
                }
            }
            .navigationDestination(isPresented: $showingPlayback) {
                if let route = viewModel.currentRoute {
                    VideoPreviewView(route: route)
                }
            }
            .sheet(isPresented: $showingPointInput) {
                pointInputSheet
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingRouteList) {
                RouteListView()
            }
            .toast(
                isPresented: $viewModel.showToast,
                message: viewModel.toastMessage,
                type: viewModel.toastType
            )
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Status Bar Background
    
    private var statusBarBackground: some View {
        GeometryReader { geometry in
            Color.black
                .frame(height: geometry.safeAreaInsets.top)
                .ignoresSafeArea(edges: .top)
        }
        .frame(height: 0)
    }
    
    // MARK: - Top Button Bar
    
    private var topButtonBar: some View {
        HStack {
            Spacer()
            
            HStack(spacing: 12) {
                // 清除按钮
                TopBarButton(icon: "icon-delete") {
                    showingClearConfirmation = true
                }
                
                // 我的路线按钮
                TopBarButton(icon: "icon-route") {
                    showingRouteList = true
                }
                
                // 设置按钮
                TopBarButton(icon: "icon-setting") {
                    showingSettings = true
                }
            }
            .padding(.trailing, 16)
            .padding(.top, 16)
        }
        .alert("清除地图标记", isPresented: $showingClearConfirmation) {
            Button("取消", role: .cancel) { }
            Button("清除", role: .destructive) {
                viewModel.clearAllPoints()
            }
        } message: {
            Text("确定要清除地图上的所有标记和路线吗？")
        }
    }
    
    // MARK: - Map Area
    
    private var mapArea: some View {
        MapPreviewView(
            route: viewModel.currentRoute,
            region: $viewModel.mapRegion
        )
        .frame(height: 610)
        .padding(.top, 48) // 状态栏高度
    }
    
    // MARK: - Action Area
    
    private var actionArea: some View {
        VStack(spacing: 12) {
            // 起点、终点、添加按钮
            HStack(spacing: 8) {
                // 起点按钮
                ActionButton(
                    icon: "icon-start",
                    title: viewModel.startCityName.isEmpty ? "起点" : viewModel.startCityName,
                    isSelected: !viewModel.startCityName.isEmpty,
                    isStartPoint: true
                ) {
                    viewModel.showPointInput(type: .start)
                    showingPointInput = true
                }
                
                // 终点按钮
                ActionButton(
                    icon: "icon-end",
                    title: viewModel.endCityName.isEmpty ? "终点" : viewModel.endCityName,
                    isSelected: !viewModel.endCityName.isEmpty,
                    isStartPoint: false
                ) {
                    viewModel.showPointInput(type: .end)
                    showingPointInput = true
                }
                
                // 添加按钮
                AddButton {
                    viewModel.showPointInput(type: .intermediate)
                    showingPointInput = true
                }
            }
            .padding(.horizontal, 16)
            
            // 预览视频按钮
            Button {
                if viewModel.isPreviewEnabled {
                    showingPlayback = true
                }
            } label: {
                Text("预览视频")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(viewModel.isPreviewEnabled ? .white : Color.white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(viewModel.isPreviewEnabled ? Color.primary : Color.white.opacity(0.2))
                    .cornerRadius(12)
            }
            .disabled(!viewModel.isPreviewEnabled)
            .padding(.horizontal, 16)
        }
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(Color.black)
    }
    
    // MARK: - Point Input Sheet
    
    private var pointInputSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 城市名称搜索
                VStack(alignment: .leading, spacing: 8) {
                    Text("搜索城市")
                        .font(.system(size: 14))
                        .foregroundColor(Color.secondaryText)
                    
                    TextField("例如：北京", text: $searchText)
                        .textFieldStyle(RoundedTextFieldStyle())
                        .onChange(of: searchText) { _, newValue in
                            filterCities(with: newValue)
                        }
                }
                .padding(.horizontal, 24)
                
                // 热门城市列表
                VStack(alignment: .leading, spacing: 12) {
                    Text(searchText.isEmpty ? "热门城市" : "搜索结果")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.primaryText)
                        .padding(.horizontal, 24)
                    
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            let citiesToShow = searchText.isEmpty ? popularCitiesWithInfo : filteredCities
                            
                            if citiesToShow.isEmpty {
                                Text("未找到匹配的城市")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.secondaryText)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                            } else {
                                ForEach(citiesToShow, id: \.name) { cityInfo in
                                    CityListRow(
                                        cityInfo: cityInfo,
                                        pointType: viewModel.pointInputType
                                    ) {
                                        addPointDirectly(cityName: cityInfo.name)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // 错误提示
                if let error = viewModel.validationError {
                    ErrorMessageView(message: error)
                        .padding(.horizontal, 24)
                }
            }
            .navigationTitle(viewModel.pointInputType.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        showingPointInput = false
                        clearInputs()
                    }
                }
            }
            .onAppear {
                filteredCities = popularCitiesWithInfo
            }
        }
    }
    
    // 热门城市信息
    private let popularCitiesWithInfo: [(name: String, country: String, province: String)] = [
        ("北京", "中国", "北京市"),
        ("上海", "中国", "上海市"),
        ("广州", "中国", "广东省"),
        ("深圳", "中国", "广东省"),
        ("成都", "中国", "四川省"),
        ("杭州", "中国", "浙江省"),
        ("西安", "中国", "陕西省"),
        ("重庆", "中国", "重庆市"),
        ("武汉", "中国", "湖北省"),
        ("南京", "中国", "江苏省"),
        ("苏州", "中国", "江苏省"),
        ("天津", "中国", "天津市"),
        ("长沙", "中国", "湖南省"),
        ("郑州", "中国", "河南省"),
        ("青岛", "中国", "山东省"),
        ("厦门", "中国", "福建省"),
        ("大连", "中国", "辽宁省"),
        ("昆明", "中国", "云南省")
    ]
    
    // MARK: - Helper Methods
    
    private func addPointDirectly(cityName: String) {
        // 使用城市名称创建地点
        let point = RoutePoint(
            cityName: cityName,
            latitude: nil,
            longitude: nil,
            orderIndex: 0
        )
        
        // 根据类型添加地点
        switch viewModel.pointInputType {
        case .start:
            viewModel.addStartPoint(point)
        case .end:
            viewModel.addEndPoint(point)
        case .intermediate:
            viewModel.addIntermediatePoint(point)
        }
        
        // 如果没有错误，关闭输入界面
        if viewModel.validationError == nil {
            showingPointInput = false
            clearInputs()
        }
    }
    
    private func filterCities(with query: String) {
        if query.isEmpty {
            filteredCities = popularCitiesWithInfo
        } else {
            filteredCities = popularCitiesWithInfo.filter { cityInfo in
                cityInfo.name.localizedCaseInsensitiveContains(query) ||
                cityInfo.province.localizedCaseInsensitiveContains(query) ||
                cityInfo.country.localizedCaseInsensitiveContains(query)
            }
        }
    }
    
    private func clearInputs() {
        cityName = ""
        searchText = ""
        latitude = ""
        longitude = ""
        filteredCities = popularCitiesWithInfo
        viewModel.validationError = nil
    }
}

// MARK: - City List Row

struct CityListRow: View {
    let cityInfo: (name: String, country: String, province: String)
    let pointType: PointInputType
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // 图标
                Image(pointIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundColor(pointColor)
                    .frame(width: 32, height: 32)
                    .background(pointColor.opacity(0.1))
                    .clipShape(Circle())
                
                // 城市信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(cityInfo.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.primaryText)
                    
                    Text("\(cityInfo.country) · \(cityInfo.province)")
                        .font(.system(size: 13))
                        .foregroundColor(Color.secondaryText)
                }
                
                Spacer()
                
                // 右箭头
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(Color.secondaryText)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        
        Divider()
            .padding(.leading, 68)
    }
    
    private var pointIcon: String {
        switch pointType {
        case .start:
            return "icon-start"
        case .end:
            return "icon-end"
        case .intermediate:
            return "icon-add"
        }
    }
    
    private var pointColor: Color {
        switch pointType {
        case .start:
            return Color.primary
        case .end:
            return Color.secondary
        case .intermediate:
            return Color.warning
        }
    }
}

// MARK: - Top Bar Button

struct TopBarButton: View {
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Color.black.opacity(0.6))
                .clipShape(Circle())
        }
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let isStartPoint: Bool // 新增：标识是否为起点
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                // 使用自定义图标，调大尺寸
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                
                Text(title)
                    .font(.system(size: 16))
                    .lineLimit(1)
                
                Spacer()
            }
            .foregroundColor(isSelected ? .white : Color.white.opacity(0.4))
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(selectedBackgroundColor)
            .cornerRadius(12)
        }
    }
    
    private var selectedBackgroundColor: Color {
        if isSelected {
            // 起点使用主色40%透明，终点使用辅助色40%透明
            return isStartPoint ? Color.primary.opacity(0.4) : Color.secondary.opacity(0.4)
        } else {
            return Color.white.opacity(0.2)
        }
    }
}

// MARK: - Add Button

struct AddButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image("icon-add")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundColor(.white)
        }
        .frame(width: 56, height: 56)
        .background(Color.white.opacity(0.2))
        .cornerRadius(12)
    }
}

// MARK: - Rounded Text Field Style

struct RoundedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    PreviewWrapper()
}

private struct PreviewWrapper: View {
    @State private var container: ModelContainer
    
    init() {
        let schema = Schema([Route.self, RoutePoint.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let tempContainer = try! ModelContainer(for: schema, configurations: [config])
        _container = State(initialValue: tempContainer)
        StorageService.shared = StorageService(modelContext: tempContainer.mainContext)
    }
    
    var body: some View {
        HomeView()
            .modelContainer(container)
    }
}
