//
//  CameraView.swift
//  CardUp
//
//  Created by Yuval Farangi on 20/02/2026.
//

import SwiftUI
import UIKit
import Combine
import AVFoundation

struct CameraView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.cameraDevice = .rear
        
        // Optimize for document scanning
        if picker.cameraDevice == .rear {
            picker.cameraCaptureMode = .photo
        }
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Camera Permission Helper

final class CameraPermissionManager: ObservableObject {
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined
    
    init() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }
    
    func requestPermission() async -> Bool {
        switch authorizationStatus {
        case .authorized:
            return true
        case .notDetermined:
            let status = await AVCaptureDevice.requestAccess(for: .video)
            await MainActor.run {
                authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
            }
            return status
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
}