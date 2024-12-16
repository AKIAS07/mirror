//
//  ContentView.swift
//  Mirror
//
//  Created by 林喵 on 2024/12/16.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    
    var body: some View {
        ZStack {
            if cameraManager.permissionGranted {
                CameraView(session: $cameraManager.session)
                    .ignoresSafeArea()
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
    }
}

#Preview {
    ContentView()
}
