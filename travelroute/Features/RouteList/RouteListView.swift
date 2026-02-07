//
//  RouteListView.swift
//  travelroute
//
//  Created by Kiro on 2024.
//

import SwiftUI

struct RouteListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = RouteListViewModel()
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.routes.isEmpty {
                    emptyStateView
                } else {
                    routeListView
                }
            }
            .navigationTitle("我的路线")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.loadRoutes()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "map")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("还没有保存的路线")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.primary)
            
            Text("创建路线后会自动保存在这里")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
    }
    
    private var routeListView: some View {
        List {
            ForEach(viewModel.routes) { route in
                RouteListRow(route: route)
            }
            .onDelete { indexSet in
                viewModel.deleteRoutes(at: indexSet)
            }
        }
    }
}

struct RouteListRow: View {
    let route: Route
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(route.name)
                .font(.system(size: 16, weight: .medium))
            
            HStack {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 12))
                Text("\(route.points.count) 个地点")
                    .font(.system(size: 14))
                
                Spacer()
                
                Text(route.updatedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

@Observable
@MainActor
class RouteListViewModel {
    var routes: [Route] = []
    
    private let storageService: StorageServiceProtocol
    
    init(storageService: StorageServiceProtocol? = nil) {
        self.storageService = storageService ?? StorageService.shared
    }
    
    func loadRoutes() {
        routes = storageService.fetchAllRoutes()
    }
    
    func deleteRoutes(at indexSet: IndexSet) {
        for index in indexSet {
            let route = routes[index]
            try? storageService.deleteRoute(route)
        }
        routes.remove(atOffsets: indexSet)
    }
}

#Preview {
    RouteListView()
}
