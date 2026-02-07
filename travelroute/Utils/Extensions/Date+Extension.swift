//
//  Date+Extension.swift
//  travelroute
//
//  Created by Kiro
//

import Foundation

extension Date {
    /// 格式化为字符串
    func formatted(style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = .none
        formatter.locale = Locale.current
        return formatter.string(from: self)
    }
    
    /// 格式化为日期时间字符串
    func formattedWithTime(dateStyle: DateFormatter.Style = .medium, timeStyle: DateFormatter.Style = .short) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        formatter.locale = Locale.current
        return formatter.string(from: self)
    }
}
