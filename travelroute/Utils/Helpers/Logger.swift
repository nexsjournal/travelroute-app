//
//  Logger.swift
//  travelroute
//
//  Created by Kiro
//

import Foundation
import os.log

/// 日志级别
enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
}

/// 日志模块标签（便于在控制台筛选）
enum LogModule: String {
    case general = "App"
    case map = "Map"
    case mapView = "MapView"
    case pathOverlay = "PathOverlay"
    case pointAnnotation = "PointAnnotation"
    case homeVM = "HomeVM"
    case data = "Data"
    case network = "Network"
    case video = "Video"
}

/// 日志工具：带模块 tag、级别，便于在 Xcode 控制台筛选和定位问题
struct Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.travelroute"

    // MARK: - 按模块的 Logger（os.Logger 用于 Console 筛选）
    static let general = os.Logger(subsystem: subsystem, category: "general")
    static let data = os.Logger(subsystem: subsystem, category: "data")
    static let ui = os.Logger(subsystem: subsystem, category: "ui")
    static let map = os.Logger(subsystem: subsystem, category: "map")
    static let video = os.Logger(subsystem: subsystem, category: "video")

    /// 兼容旧代码：默认使用 general
    static let shared = os.Logger(subsystem: subsystem, category: "general")

    // MARK: - 带模块与级别的统一入口（推荐用于地图编辑等关键路径）

    /// 输出带 [Module] 前缀和级别的日志，便于一眼定位是哪个模块、哪类问题
    static func log(
        _ message: String,
        module: LogModule = .general,
        level: LogLevel = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let tag = "[\(module.rawValue)]"
        let shortFile = (file as NSString).lastPathComponent
        let location = "\(shortFile):\(line)"
        let full = "\(tag) [\(level.rawValue)] \(message) (\(location))"
        let logger = os.Logger(subsystem: subsystem, category: module.rawValue)
        switch level {
        case .debug:
            logger.debug("\(full, privacy: .public)")
        case .info:
            logger.info("\(full, privacy: .public)")
        case .warning:
            logger.warning("\(full, privacy: .public)")
        case .error:
            logger.error("\(full, privacy: .public)")
        }
    }

    static func debug(_ message: String, module: LogModule = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, module: module, level: .debug, file: file, function: function, line: line)
    }

    static func info(_ message: String, module: LogModule = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, module: module, level: .info, file: file, function: function, line: line)
    }

    static func warning(_ message: String, module: LogModule = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, module: module, level: .warning, file: file, function: function, line: line)
    }

    static func error(_ message: String, module: LogModule = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, module: module, level: .error, file: file, function: function, line: line)
    }
}
