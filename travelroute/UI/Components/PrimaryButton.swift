//
//  PrimaryButton.swift
//  travelroute
//
//  Created by Kiro
//

import SwiftUI

/// 主要按钮组件
struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    let isEnabled: Bool
    let backgroundColor: Color
    
    init(
        title: String,
        action: @escaping () -> Void,
        isEnabled: Bool = true,
        backgroundColor: Color = .primary
    ) {
        self.title = title
        self.action = action
        self.isEnabled = isEnabled
        self.backgroundColor = backgroundColor
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typography.button)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(isEnabled ? backgroundColor : Color.disabled)
                .cornerRadius(12)
        }
        .disabled(!isEnabled)
    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryButton(title: "预览视频", action: {})
        PrimaryButton(title: "禁用按钮", action: {}, isEnabled: false)
        PrimaryButton(
            title: "深色按钮",
            action: {},
            backgroundColor: .darkBackground
        )
    }
    .padding()
}
