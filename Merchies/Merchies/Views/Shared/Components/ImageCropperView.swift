import SwiftUI
import UIKit

struct ImageCropperView: View {
    @Binding var selectedImage: UIImage?
    @Binding var isPresented: Bool
    
    let originalImage: UIImage
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    
    // Cropping frame dimensions - adaptive to image
    @State private var cropSize: CGSize = CGSize(width: 300, height: 200)
    
    private var adaptiveCropSize: CGSize {
        let imageAspectRatio = originalImage.size.width / originalImage.size.height
        let maxWidth: CGFloat = 300
        let maxHeight: CGFloat = 300
        
        if imageAspectRatio > 1 {
            // Landscape image
            return CGSize(width: maxWidth, height: maxWidth / imageAspectRatio)
        } else {
            // Portrait or square image
            return CGSize(width: maxHeight * imageAspectRatio, height: maxHeight)
        }
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                let imageSize = calculateImageSize(originalImage, containerSize: geometry.size)
                
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    // Background dimming overlay
                    Rectangle()
                        .fill(Color.black.opacity(0.5))
                        .ignoresSafeArea()
                    
                    // Image view
                    Image(uiImage: originalImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: imageSize.width, height: imageSize.height)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let newScale = lastScale * value
                                        scale = max(1.0, min(newScale, 5.0)) // Limit scale between 1x and 5x
                                    }
                                    .onEnded { _ in
                                        lastScale = scale
                                    },
                                
                                DragGesture()
                                    .onChanged { value in
                                        let newOffset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                        
                                        // Constrain offset to keep image within bounds
                                        offset = constrainOffset(newOffset, imageSize: imageSize, containerSize: geometry.size, scale: scale)
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                        )
                    
                    // Crop overlay frame
                    CropOverlayView(cropSize: adaptiveCropSize)
                        .allowsHitTesting(false)
                }
                .clipped()
            }
            .navigationTitle("Crop Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        cropImage()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func calculateImageSize(_ image: UIImage, containerSize: CGSize) -> CGSize {
        let imageAspectRatio = image.size.width / image.size.height
        let containerAspectRatio = containerSize.width / containerSize.height
        
        if imageAspectRatio > containerAspectRatio {
            // Image is wider than container
            let width = containerSize.width * 0.9
            let height = width / imageAspectRatio
            return CGSize(width: width, height: height)
        } else {
            // Image is taller than container
            let height = containerSize.height * 0.8
            let width = height * imageAspectRatio
            return CGSize(width: width, height: height)
        }
    }
    
    private func constrainOffset(_ newOffset: CGSize, imageSize: CGSize, containerSize: CGSize, scale: CGFloat) -> CGSize {
        let scaledImageSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let currentCropSize = adaptiveCropSize
        
        let maxOffsetX = max(0, (scaledImageSize.width - currentCropSize.width) / 2)
        let maxOffsetY = max(0, (scaledImageSize.height - currentCropSize.height) / 2)
        
        let constrainedX = max(-maxOffsetX, min(newOffset.width, maxOffsetX))
        let constrainedY = max(-maxOffsetY, min(newOffset.height, maxOffsetY))
        
        return CGSize(width: constrainedX, height: constrainedY)
    }
    
    private func cropImage() {
        let cropRect = calculateCropRect()
        
        if let croppedImage = cropImage(originalImage, to: cropRect) {
            selectedImage = croppedImage
        }
        
        isPresented = false
    }
    
    private func calculateCropRect() -> CGRect {
        // Calculate the crop rectangle in the original image coordinates
        let imageSize = originalImage.size
        let displayedImageSize = calculateImageSize(originalImage, containerSize: CGSize(width: 400, height: 800)) // Approximate container size
        
        let scaleX = imageSize.width / displayedImageSize.width
        let scaleY = imageSize.height / displayedImageSize.height
        
        // Account for current scale and offset
        let scaledDisplayedSize = CGSize(
            width: displayedImageSize.width * scale,
            height: displayedImageSize.height * scale
        )
        
        // Calculate the center of the crop area in the scaled image
        let cropCenterX = scaledDisplayedSize.width / 2 - offset.width
        let cropCenterY = scaledDisplayedSize.height / 2 - offset.height
        
        // Convert to original image coordinates
        let originalCropCenterX = (cropCenterX / scale) * scaleX
        let originalCropCenterY = (cropCenterY / scale) * scaleY
        
        let currentCropSize = adaptiveCropSize
        let originalCropSizeWidth = (currentCropSize.width / scale) * scaleX
        let originalCropSizeHeight = (currentCropSize.height / scale) * scaleY
        
        let cropRect = CGRect(
            x: max(0, originalCropCenterX - originalCropSizeWidth / 2),
            y: max(0, originalCropCenterY - originalCropSizeHeight / 2),
            width: min(originalCropSizeWidth, imageSize.width),
            height: min(originalCropSizeHeight, imageSize.height)
        )
        
        return cropRect
    }
    
    private func cropImage(_ image: UIImage, to rect: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage?.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}

struct CropOverlayView: View {
    let cropSize: CGSize
    
    var body: some View {
        GeometryReader { geometry in
            let centerX = geometry.size.width / 2
            let centerY = geometry.size.height / 2
            let halfCropWidth = cropSize.width / 2
            let halfCropHeight = cropSize.height / 2
            
            ZStack {
                // Dimming overlay with crop window cut out
                Rectangle()
                    .fill(Color.black.opacity(0.6))
                    .mask(
                        Rectangle()
                            .fill(Color.black)
                            .overlay(
                                Rectangle()
                                    .frame(width: cropSize.width, height: cropSize.height)
                                    .position(x: centerX, y: centerY)
                                    .blendMode(.destinationOut)
                            )
                    )
                
                // Crop frame border
                Rectangle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: cropSize.width, height: cropSize.height)
                    .position(x: centerX, y: centerY)
                
                // Corner indicators
                Group {
                    // Top-left corner
                    Path { path in
                        let startX = centerX - halfCropWidth
                        let startY = centerY - halfCropHeight
                        path.move(to: CGPoint(x: startX + 20, y: startY))
                        path.addLine(to: CGPoint(x: startX, y: startY))
                        path.addLine(to: CGPoint(x: startX, y: startY + 20))
                    }
                    .stroke(Color.white, lineWidth: 3)
                    
                    // Top-right corner
                    Path { path in
                        let startX = centerX + halfCropWidth
                        let startY = centerY - halfCropHeight
                        path.move(to: CGPoint(x: startX - 20, y: startY))
                        path.addLine(to: CGPoint(x: startX, y: startY))
                        path.addLine(to: CGPoint(x: startX, y: startY + 20))
                    }
                    .stroke(Color.white, lineWidth: 3)
                    
                    // Bottom-left corner
                    Path { path in
                        let startX = centerX - halfCropWidth
                        let startY = centerY + halfCropHeight
                        path.move(to: CGPoint(x: startX + 20, y: startY))
                        path.addLine(to: CGPoint(x: startX, y: startY))
                        path.addLine(to: CGPoint(x: startX, y: startY - 20))
                    }
                    .stroke(Color.white, lineWidth: 3)
                    
                    // Bottom-right corner
                    Path { path in
                        let startX = centerX + halfCropWidth
                        let startY = centerY + halfCropHeight
                        path.move(to: CGPoint(x: startX - 20, y: startY))
                        path.addLine(to: CGPoint(x: startX, y: startY))
                        path.addLine(to: CGPoint(x: startX, y: startY - 20))
                    }
                    .stroke(Color.white, lineWidth: 3)
                }
                
                // Instructions
                VStack {
                    Spacer()
                    Text("Pinch to zoom • Drag to move")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                        .padding(.bottom, 50)
                }
            }
        }
    }
}