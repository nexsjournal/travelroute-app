//
//  Colors.swift
//  travelroute
//
//  Created by Kiro
//

import SwiftUI

extension Color {
    // MARK: - 主色调
    
    /// 主色 - 蓝色
    static let primary = Color(hex: "319FF9")
    
    /// 辅助色 - 红色
    static let secondary = Color(hex: "FB595C")
    
    // MARK: - 状态色
    
    /// 成功状态
    static let success = Color(hex: "34C759")
    
    /// 警告状态
    static let warning = Color(hex: "FF9F0A")
    
    /// 错误状态
    static let error = Color(hex: "FF3B30")
    
    /// 禁用状态
    static let disabled = Color(hex: "C7C7CC")
    
    // MARK: - 文字颜色
    
    /// 主要文字
    static let primaryText = Color(hex: "1C1C1E")
    
    /// 次级文字
    static let secondaryText = Color(hex: "6E6E73")
    
    /// 占位文字
    static let placeholderText = Color(hex: "AEAEB2")
    
    // MARK: - 背景色
    
    /// 深色背景
    static let darkBackground = Color(hex: "0E2029")
    
    // MARK: - 辅助方法
    
    /// 从十六进制字符串创建颜色
    /// - Parameter hex: 十六进制颜色字符串（如 "319FF9" 或 "#319FF9"）
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
