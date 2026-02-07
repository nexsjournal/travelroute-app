//
//  LoadingIndicator.swift
//  travelroute
//
//  Created by Kiro
//

import SwiftUI

/// 加载指示器组件
struct LoadingIndicator: View {
    let message: String?
    
    init(message: String? = nil) {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                .scaleEffect(1.5)
            
            if let message = message {
                Text(message)
                    .font(Typography.body)
                    .foregroundColor(.secondaryText)
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()
        
        VStack(spacing: 40) {
            LoadingIndicator()
            LoadingIndicator(message: "正在加载...")
            LoadingIndicator(message: "正在渲染视频...")
        }
    }
}
