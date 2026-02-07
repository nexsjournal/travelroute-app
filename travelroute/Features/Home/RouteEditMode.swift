//
//  RouteEditMode.swift
//  travelroute
//
//  Created by Kiro on 2024.
//

import Foundation

/// 路线编辑状态机
enum RouteEditMode: Equatable, CustomStringConvertible {
    case idle                                    // 空闲，可移动地图
    case draggingPoint(pointID: UUID)            // 正在拖动已有点
    case draggingSegment(segmentIndex: Int)      // 正在拖动路径线段（准备拆分）
    
    /// 是否允许地图交互
    var allowsMapInteraction: Bool {
        if case .idle = self {
            return true
        }
        return false
    }
    
    /// 是否正在编辑
    var isEditing: Bool {
        return self != .idle
    }

    /// 是否正在路径上拖拽添加途经点
    var isDraggingSegment: Bool {
        if case .draggingSegment = self { return true }
        return false
    }
    
    /// 描述字符串（用于日志）
    var description: String {
        switch self {
        case .idle:
            return "idle"
        case .draggingPoint(let pointID):
            return "draggingPoint(pointID: \(pointID))"
        case .draggingSegment(let segmentIndex):
            return "draggingSegment(segmentIndex: \(segmentIndex))"
        }
    }
}
