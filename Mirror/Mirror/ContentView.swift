//
//  ContentView.swift
//  Mirror
//
//  Created by 林喵 on 2024/12/16.
//

import SwiftUI
import AVFoundation

struct CircleButton: View {
    let systemName: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemName)
                    .font(.system(size: 24))
                Text(title)
                    .font(.system(size: 12))
            }
            .foregroundColor(.white)
            .frame(width: 60, height: 60)
            .background(Color.black.opacity(0.5))
            .clipShape(Circle())
        }
    }
}

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var showingTwoOfMe = false
    
    var body: some View {
        ZStack {
            if cameraManager.permissionGranted {
                CameraView(session: $cameraManager.session, isMirrored: $cameraManager.isMirrored)
                    .ignoresSafeArea()
                
                // 底部按钮栏
                VStack {
                    Spacer()
                    HStack(spacing: 40) {
                        CircleButton(systemName: "camera", title: "左") {
                            print("点击了左侧按钮")
                            print("时间：\(Date())")
                            print("功能：正常拍摄")
                            print("切换到正常模式")
                            cameraManager.isMirrored = false
                            print("------------------------")
                        }
                        
                        CircleButton(systemName: "rectangle.split.2x1", title: "中") {
                            print("点击了中间按钮")
                            print("时间：\(Date())")
                            print("功能：Two of Me")
                            showingTwoOfMe = true
                            print("------------------------")
                        }
                        
                        CircleButton(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right", title: "右") {
                            print("点击了右侧按钮")
                            print("时间：\(Date())")
                            print("功能：镜像拍摄")
                            print("切换到镜像模式")
                            cameraManager.isMirrored = true
                            print("------------------------")
                        }
                    }
                    .padding(.bottom, 50)
                }
            } else {
                VStack {
                    Image(systemName: "camera.fill")
                        .foregroundColor(.red)
                        .font(.largeTitle)
                    Text("需要相机权限")
                        .padding()
                    Button(action: {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("授权相机")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .onAppear {
            cameraManager.checkPermission()
        }
        .fullScreenCover(isPresented: $showingTwoOfMe) {
            TwoOfMeScreens()
        }
    }
}

#Preview {
    ContentView()
}
