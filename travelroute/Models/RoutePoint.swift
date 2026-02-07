//
//  RoutePoint.swift
//  travelroute
//
//  Created by Kiro
//

import Foundation
import SwiftData
import CoreLocation

/// 路线中的单个地点
@Model
final class RoutePoint {
    /// 唯一标识符
    var id: UUID
    
    /// 城市名称（可选）
    var cityName: String?
    
    /// 纬度（可选）
    var latitude: Double?
    
    /// 经度（可选）
    var longitude: Double?
    
    /// 在路线中的顺序索引
    var orderIndex: Int
    
    /// 时间戳
    var timestamp: Date?
    
    /// 所属路线
    var route: Route?
    
    /// 初始化地点
    /// - Parameters:
    ///   - cityName: 城市名称
    ///   - latitude: 纬度
    ///   - longitude: 经度
    ///   - orderIndex: 顺序索引
    init(cityName: String? = nil, latitude: Double? = nil, longitude: Double? = nil, orderIndex: Int) {
        self.id = UUID()
        self.cityName = cityName
        self.latitude = latitude
        self.longitude = longitude
        self.orderIndex = orderIndex
        self.timestamp = Date()
    }
    
    /// 获取坐标（如果有经纬度）
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    /// 是否有有效的位置信息
    var hasValidLocation: Bool {
        if let cityName = cityName, !cityName.trimmingCharacters(in: .whitespaces).isEmpty {
            return true
        }
        if latitude != nil && longitude != nil {
            return true
        }
        return false
    }
}
