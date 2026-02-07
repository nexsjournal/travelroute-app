//
//  Typography.swift
//  travelroute
//
//  Created by Kiro
//

import SwiftUI

/// 字体样式定义
struct Typography {
    // MARK: - 标题
    
    /// 大标题
    static let largeTitle = Font.system(size: 34, weight: .bold)
    
    /// 标题1
    static let title1 = Font.system(size: 28, weight: .bold)
    
    /// 标题2
    static let title2 = Font.system(size: 22, weight: .bold)
    
    /// 标题3
    static let title3 = Font.system(size: 20, weight: .semibold)
    
    // MARK: - 正文
    
    /// 正文
    static let body = Font.system(size: 17, weight: .regular)
    
    /// 正文（加粗）
    static let bodyBold = Font.system(size: 17, weight: .semibold)
    
    /// 副标题
    static let subheadline = Font.system(size: 15, weight: .regular)
    
    /// 脚注
    static let footnote = Font.system(size: 13, weight: .regular)
    
    /// 说明文字
    static let caption = Font.system(size: 12, weight: .regular)
    
    // MARK: - 按钮
    
    /// 按钮文字
    static let button = Font.system(size: 18, weight: .regular)
    
    /// 按钮文字（大）
    static let buttonLarge = Font.system(size: 20, weight: .semibold)
}

// MARK: - Text 扩展

extension Text {
    /// 应用主要文字颜色
    func primaryTextColor() -> Text {
        self.foregroundColor(.primaryText)
    }
    
    /// 应用次级文字颜色
    func secondaryTextColor() -> Text {
        self.foregroundColor(.secondaryText)
    }
    
    /// 应用占位文字颜色
    func placeholderTextColor() -> Text {
        self.foregroundColor(.placeholderText)
    }
}
