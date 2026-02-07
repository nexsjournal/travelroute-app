//
//  PointInputView.swift
//  travelroute
//
//  Created by Kiro
//

import SwiftUI

/// 地点输入视图组件
struct PointInputView: View {
    @Binding var cityName: String
    @Binding var latitude: String
    @Binding var longitude: String
    let validationError: String?
    let onSubmit: () -> Void
    
    @FocusState private var focusedField: Field?
    
    enum Field {
        case cityName
        case latitude
        case longitude
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题
            Text("添加地点")
                .font(Typography.title3)
                .foregroundColor(.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // 城市名称输入
            VStack(alignment: .leading, spacing: 8) {
                Text("城市名称")
                    .font(Typography.subheadline)
                    .foregroundColor(.secondaryText)
                
                TextField("例如：北京", text: $cityName)
                    .font(Typography.body)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .focused($focusedField, equals: .cityName)
            }
            
            // 分隔线
            HStack {
                Rectangle()
                    .fill(Color(.systemGray4))
                    .frame(height: 1)
                
                Text("或")
                    .font(Typography.caption)
                    .foregroundColor(.secondaryText)
                    .padding(.horizontal, 8)
                
                Rectangle()
                    .fill(Color(.systemGray4))
                    .frame(height: 1)
            }
            
            // 经纬度输入
            VStack(alignment: .leading, spacing: 8) {
                Text("经纬度")
                    .font(Typography.subheadline)
                    .foregroundColor(.secondaryText)
                
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("纬度")
                            .font(Typography.caption)
                            .foregroundColor(.secondaryText)
                        
                        TextField("39.9042", text: $latitude)
                            .font(Typography.body)
                            .keyboardType(.decimalPad)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .focused($focusedField, equals: .latitude)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("经度")
                            .font(Typography.caption)
                            .foregroundColor(.secondaryText)
                        
                        TextField("116.4074", text: $longitude)
                            .font(Typography.body)
                            .keyboardType(.decimalPad)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .focused($focusedField, equals: .longitude)
                    }
                }
            }
            
            // 错误消息
            if let error = validationError {
                ErrorMessageView(message: error)
            }
            
            // 提交按钮
            PrimaryButton(
                title: "添加",
                action: {
                    focusedField = nil
                    onSubmit()
                }
            )
        }
        .padding(20)
    }
}

#Preview {
    VStack {
        PointInputView(
            cityName: .constant(""),
            latitude: .constant(""),
            longitude: .constant(""),
            validationError: nil,
            onSubmit: {}
        )
        
        Spacer()
        
        PointInputView(
            cityName: .constant("北京"),
            latitude: .constant("39.9042"),
            longitude: .constant("116.4074"),
            validationError: "城市名称不能为空",
            onSubmit: {}
        )
    }
}
