//
//  RouteEditorView.swift
//  travelroute
//
//  Created by Kiro on 2024.
//

import SwiftUI
import SwiftData

struct RouteEditorView: View {
    
    @State private var viewModel: RouteEditorViewModel
    @State private var cityName = ""
    @State private var latitude = ""
    @State private var longitude = ""
    @Environment(\.dismiss) private var dismiss
    
    init(route: Route) {
        _viewModel = State(initialValue: RouteEditorViewModel(route: route))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 路线统计信息
                    statsHeader
                    
                    // 地点列表
                    if viewModel.points.isEmpty {
                        emptyStateView
                    } else {
                        pointsList
                    }
                }
            }
            .navigationTitle(viewModel.route.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.showAddPointInput()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingPointInput) {
                pointInputSheet
            }
        }
    }
    
    // MARK: - Stats Header
    
    private var statsHeader: some View {
        VStack(spacing: 8) {
            Text(viewModel.routeStats.statusText)
                .font(.system(size: 14))
                .foregroundColor(Color.secondaryText)
            
            if let error = viewModel.validationError {
                ErrorMessageView(message: error)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.darkBackground)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "map")
                .font(.system(size: 64))
                .foregroundColor(Color.gray)
            
            Text("还没有添加地点")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color.primaryText)
            
            Text("点击右上角的 + 按钮添加地点")
                .font(.system(size: 14))
                .foregroundColor(Color.secondaryText)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Points List
    
    private var pointsList: some View {
        List {
            ForEach(Array(viewModel.points.enumerated()), id: \.element.id) { index, point in
                PointRow(
                    point: point,
                    index: index,
                    isFirst: index == 0,
                    isLast: index == viewModel.points.count - 1,
                    onTap: {
                        viewModel.selectPoint(point)
                    },
                    onEdit: {
                        viewModel.showEditPointInput(point)
                    }
                )
            }
            .onDelete { indexSet in
                indexSet.forEach { index in
                    viewModel.removePoint(viewModel.points[index])
                }
            }
            .onMove { source, destination in
                viewModel.reorderPoints(from: source, to: destination)
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(.active))
    }
    
    // MARK: - Point Input Sheet
    
    private var pointInputSheet: some View {
        NavigationView {
            VStack(spacing: 24) {
                // 城市名称输入
                VStack(alignment: .leading, spacing: 8) {
                    Text("城市名称")
                        .font(.system(size: 14))
                        .foregroundColor(Color.secondaryText)
                    
                    TextField("例如：北京", text: $cityName)
                        .textFieldStyle(RoundedTextFieldStyle())
                }
                
                // 或者分隔线
                HStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                    
                    Text("或")
                        .font(.system(size: 14))
                        .foregroundColor(Color.secondaryText)
                        .padding(.horizontal, 8)
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                }
                
                // 经纬度输入
                VStack(alignment: .leading, spacing: 8) {
                    Text("经纬度")
                        .font(.system(size: 14))
                        .foregroundColor(Color.secondaryText)
                    
                    HStack(spacing: 12) {
                        TextField("纬度", text: $latitude)
                            .textFieldStyle(RoundedTextFieldStyle())
                            .keyboardType(.decimalPad)
                        
                        TextField("经度", text: $longitude)
                            .textFieldStyle(RoundedTextFieldStyle())
                            .keyboardType(.decimalPad)
                    }
                }
                
                // 错误提示
                if let error = viewModel.validationError {
                    ErrorMessageView(message: error)
                }
                
                Spacer()
                
                // 保存按钮
                PrimaryButton(
                    title: viewModel.editingPoint == nil ? "添加" : "保存",
                    action: savePoint,
                    isEnabled: true
                )
            }
            .padding(24)
            .navigationTitle(viewModel.editingPoint == nil ? "添加地点" : "编辑地点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        viewModel.hidePointInput()
                        clearInputs()
                    }
                }
            }
            .onAppear {
                loadEditingPoint()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func savePoint() {
        let point: RoutePoint
        
        if let editingPoint = viewModel.editingPoint {
            // 编辑现有地点
            point = editingPoint
            
            if !cityName.isEmpty {
                point.cityName = cityName
                point.latitude = nil
                point.longitude = nil
            } else if let lat = Double(latitude), let lon = Double(longitude) {
                point.cityName = nil
                point.latitude = lat
                point.longitude = lon
            } else {
                viewModel.validationError = "请输入城市名称或经纬度"
                return
            }
            
            viewModel.updatePoint(point)
        } else {
            // 添加新地点
            if !cityName.isEmpty {
                point = RoutePoint(
                    cityName: cityName,
                    latitude: nil,
                    longitude: nil,
                    orderIndex: 0
                )
            } else if let lat = Double(latitude), let lon = Double(longitude) {
                point = RoutePoint(
                    cityName: nil,
                    latitude: lat,
                    longitude: lon,
                    orderIndex: 0
                )
            } else {
                viewModel.validationError = "请输入城市名称或经纬度"
                return
            }
            
            viewModel.addPoint(point)
        }
        
        // 如果没有错误，关闭输入界面
        if viewModel.validationError == nil {
            viewModel.hidePointInput()
            clearInputs()
        }
    }
    
    private func loadEditingPoint() {
        guard let point = viewModel.editingPoint else { return }
        
        if let city = point.cityName {
            cityName = city
            latitude = ""
            longitude = ""
        } else if let lat = point.latitude, let lon = point.longitude {
            cityName = ""
            latitude = String(lat)
            longitude = String(lon)
        }
    }
    
    private func clearInputs() {
        cityName = ""
        latitude = ""
        longitude = ""
        viewModel.validationError = nil
    }
}

// MARK: - Point Row

struct PointRow: View {
    let point: RoutePoint
    let index: Int
    let isFirst: Bool
    let isLast: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 标记图标
            ZStack {
                Circle()
                    .fill(markerColor)
                    .frame(width: 32, height: 32)
                
                if isFirst {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                } else if isLast {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                } else {
                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            
            // 地点信息
            VStack(alignment: .leading, spacing: 4) {
                if let cityName = point.cityName {
                    Text(cityName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.primaryText)
                } else if let lat = point.latitude, let lon = point.longitude {
                    Text("(\(String(format: "%.4f", lat)), \(String(format: "%.4f", lon)))")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.primaryText)
                }
                
                Text(pointTypeText)
                    .font(.system(size: 12))
                    .foregroundColor(Color.secondaryText)
            }
            
            Spacer()
            
            // 编辑按钮
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                    .foregroundColor(Color.primary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
    
    private var markerColor: Color {
        if isFirst {
            return Color.primary
        } else if isLast {
            return Color.secondary
        } else {
            return Color.gray
        }
    }
    
    private var pointTypeText: String {
        if isFirst {
            return "起点"
        } else if isLast {
            return "终点"
        } else {
            return "途经点"
        }
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
        RouteEditorView(route: route)
            .modelContainer(container)
    }
}
