//
//  MapService.swift
//  travelroute
//
//  Created by Kiro on 2024.
//

import Foundation
import MapKit
import CoreLocation

// MARK: - Map Error

enum MapError: Error, LocalizedError {
    case cityNotFound
    case invalidCoordinates
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .cityNotFound:
            return "未找到该城市"
        case .invalidCoordinates:
            return "坐标数据无效"
        case .networkError:
            return "网络连接失败"
        }
    }
}

// MARK: - MapService Protocol

protocol MapServiceProtocol {
    func searchCity(name: String) async -> Result<CLLocationCoordinate2D, MapError>
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async -> Result<String, MapError>
    func calculateRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> MKPolyline
    func fitRegion(for points: [CLLocationCoordinate2D]) -> MKCoordinateRegion
}

// MARK: - MapService Implementation

class MapService: MapServiceProtocol {
    
    // MARK: - City Search
    
    /// 搜索城市并返回坐标
    func searchCity(name: String) async -> Result<CLLocationCoordinate2D, MapError> {
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = name
        
        let search = MKLocalSearch(request: searchRequest)
        
        do {
            let response = try await search.start()
            
            guard let firstItem = response.mapItems.first else {
                return .failure(.cityNotFound)
            }
            
            let coordinate = firstItem.placemark.coordinate
            
            // 验证坐标有效性
            guard coordinate.latitude >= -90 && coordinate.latitude <= 90 &&
                  coordinate.longitude >= -180 && coordinate.longitude <= 180 else {
                return .failure(.invalidCoordinates)
            }
            
            return .success(coordinate)
            
        } catch {
            Logger.shared.error("城市搜索失败: \(error.localizedDescription)")
            return .failure(.networkError)
        }
    }
    
    /// 反向地理编码：根据坐标获取城市名称
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async -> Result<String, MapError> {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            
            guard let placemark = placemarks.first else {
                return .failure(.cityNotFound)
            }
            
            // 优先使用城市名，其次使用行政区域
            if let city = placemark.locality {
                return .success(city)
            } else if let area = placemark.administrativeArea {
                return .success(area)
            } else if let country = placemark.country {
                return .success(country)
            } else {
                return .failure(.cityNotFound)
            }
        } catch {
            Logger.shared.error("反向地理编码失败: \(error.localizedDescription)")
            return .failure(.networkError)
        }
    }
    
    // MARK: - Route Calculation
    
    /// 计算两点之间的路线（直线）
    func calculateRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> MKPolyline {
        let coordinates = [from, to]
        return MKPolyline(coordinates: coordinates, count: coordinates.count)
    }
    
    /// 计算多个地点之间的路线
    func calculateRoutes(for points: [CLLocationCoordinate2D]) -> [MKPolyline] {
        guard points.count >= 2 else { return [] }
        
        var polylines: [MKPolyline] = []
        
        for i in 0..<(points.count - 1) {
            let polyline = calculateRoute(from: points[i], to: points[i + 1])
            polylines.append(polyline)
        }
        
        return polylines
    }
    
    // MARK: - Region Calculation
    
    /// 计算包含所有地点的地图区域
    func fitRegion(for points: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !points.isEmpty else {
            // 返回默认世界地图视图
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 360)
            )
        }
        
        if points.count == 1 {
            // 单个地点，返回该地点的局部视图
            return MKCoordinateRegion(
                center: points[0],
                span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
            )
        }
        
        // 计算所有地点的边界
        var minLat = points[0].latitude
        var maxLat = points[0].latitude
        var minLon = points[0].longitude
        var maxLon = points[0].longitude
        
        for point in points {
            minLat = min(minLat, point.latitude)
            maxLat = max(maxLat, point.latitude)
            minLon = min(minLon, point.longitude)
            maxLon = max(maxLon, point.longitude)
        }
        
        // 计算中心点
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        
        // 计算跨度，添加 20% 的边距
        let latDelta = (maxLat - minLat) * 1.2
        let lonDelta = (maxLon - minLon) * 1.2
        
        // 确保最小跨度
        let minDelta = 0.5
        let finalLatDelta = max(latDelta, minDelta)
        let finalLonDelta = max(lonDelta, minDelta)
        
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: finalLatDelta, longitudeDelta: finalLonDelta)
        )
    }
    
    // MARK: - Helper Methods
    
    /// 计算两点之间的距离（米）
    func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDistance {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }
    
    /// 计算路线的总距离（米）
    func totalDistance(for points: [CLLocationCoordinate2D]) -> CLLocationDistance {
        guard points.count >= 2 else { return 0 }
        
        var total: CLLocationDistance = 0
        
        for i in 0..<(points.count - 1) {
            total += distance(from: points[i], to: points[i + 1])
        }
        
        return total
    }
}
