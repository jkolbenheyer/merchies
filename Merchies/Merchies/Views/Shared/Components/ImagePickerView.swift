import SwiftUI
import PhotosUI
import UIKit
import Foundation

struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        
        // Debug logging to verify source type
        print("📸 ImagePickerView: Setting source type to \(sourceType == .camera ? "camera" : "photoLibrary")")
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView
        
        init(_ parent: ImagePickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Modern Photo Picker (iOS 14+)
@available(iOS 14.0, *)
struct PhotoPickerView: View {
    @Binding var selectedImage: UIImage?
    @State private var selectedItem: PhotosPickerItem?
    let title: String
    
    var body: some View {
        VStack(spacing: 20) {
            // Current image display
            if let selectedImage = selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .cornerRadius(12)
                    .shadow(radius: 4)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 200)
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("Tap to select \(title.lowercased())")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    )
            }
            
            // Photo picker button
            PhotosPicker(
                selection: $selectedItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                HStack {
                    Image(systemName: selectedImage == nil ? "photo.badge.plus" : "photo.badge.arrow.down")
                    Text(selectedImage == nil ? "Select \(title)" : "Change \(title)")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.cyan)
                .cornerRadius(12)
            }
            .onChange(of: selectedItem) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            selectedImage = image
                        }
                    }
                }
            }
            
            // Remove image button
            if selectedImage != nil {
                Button("Remove Image") {
                    selectedImage = nil
                    selectedItem = nil
                }
                .font(.subheadline)
                .foregroundColor(.red)
            }
        }
    }
}

// MARK: - Legacy Image Picker Sheet
struct LegacyImagePickerSheet: View {
    @Binding var selectedImage: UIImage?
    @Binding var isPresented: Bool
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var showingImagePicker = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.cyan)
                
                Text("Select Image Source")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(spacing: 16) {
                    Button(action: {
                        sourceType = .camera
                        showingImagePicker = true
                    }) {
                        HStack {
                            Image(systemName: "camera")
                            Text("Take Photo")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.cyan)
                        .cornerRadius(12)
                    }
                    .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                    
                    Button(action: {
                        sourceType = .photoLibrary
                        showingImagePicker = true
                    }) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                            Text("Choose from Library")
                        }
                        .font(.headline)
                        .foregroundColor(.cyan)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.cyan.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    Button("Cancel") {
                        isPresented = false
                    }
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 32)
            }
            .padding()
            .navigationTitle("Select Image")
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerView(selectedImage: $selectedImage, sourceType: sourceType)
                .onDisappear {
                    isPresented = false
                }
        }
    }
}
