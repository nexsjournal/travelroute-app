//
//  ToastView.swift
//  travelroute
//
//  Created by Kiro on 2024.
//

import SwiftUI

// MARK: - Toast View

struct ToastView: View {
    let message: String
    let type: ToastType
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .font(.system(size: 16))
                .foregroundColor(.white)
            
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(type.backgroundColor)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Toast Type

enum ToastType {
    case success
    case error
    case info
    case warning
    
    var icon: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "xmark.circle.fill"
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .success:
            return Color.success
        case .error:
            return Color.error
        case .info:
            return Color.primary
        case .warning:
            return Color.warning
        }
    }
}

// MARK: - Toast Modifier

struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    let type: ToastType
    let duration: TimeInterval
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if isPresented {
                VStack {
                    ToastView(message: message, type: type)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 60) // 状态栏下方
                    
                    Spacer()
                }
                .animation(.spring(), value: isPresented)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - View Extension

extension View {
    func toast(
        isPresented: Binding<Bool>,
        message: String,
        type: ToastType = .info,
        duration: TimeInterval = 2.0
    ) -> some View {
        modifier(ToastModifier(
            isPresented: isPresented,
            message: message,
            type: type,
            duration: duration
        ))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        ToastView(message: "操作成功", type: .success)
        ToastView(message: "操作失败", type: .error)
        ToastView(message: "提示信息", type: .info)
        ToastView(message: "警告信息", type: .warning)
    }
    .padding()
    .background(Color.black)
}
