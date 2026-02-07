//
//  ErrorMessageView.swift
//  travelroute
//
//  Created by Kiro
//

import SwiftUI

/// 错误消息视图组件
struct ErrorMessageView: View {
    let message: String
    let onDismiss: (() -> Void)?
    
    init(message: String, onDismiss: (() -> Void)? = nil) {
        self.message = message
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.error)
                .font(.system(size: 20))
            
            Text(message)
                .font(Typography.body)
                .foregroundColor(.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
            
            if let onDismiss = onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondaryText)
                        .font(.system(size: 20))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.error.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.error.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        ErrorMessageView(message: "城市名称不能为空")
        
        ErrorMessageView(
            message: "纬度必须在 -90 到 90 之间",
            onDismiss: {}
        )
        
        ErrorMessageView(
            message: "这是一个很长的错误消息，用于测试文本换行的效果。当错误消息很长时，应该能够正确换行显示。"
        )
    }
    .padding()
}
