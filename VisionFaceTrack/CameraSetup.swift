//
//  CameraSetup.swift
//  VisionFaceTrack
//
//  Created by Giorgio Tempesta on 16/08/18.
//  Copyright © 2018 Apple. All rights reserved.
//

import Foundation
import AVKit
import Vision

class CameraController: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate{
    
    var captureDeviceResolution: CGSize = CGSize()
    var rootLayer: CALayer?
    var detectionOverlayLayer: CALayer?
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    var captureDevice: AVCaptureDevice?
    
    var detectedFaceRectangleShapeLayer: CAShapeLayer?
    
    /// - Tag: ConfigureDeviceResolution
    func highestResolution420Format(for device: AVCaptureDevice) -> (format: AVCaptureDevice.Format, resolution: CGSize)? {
        var highestResolutionFormat: AVCaptureDevice.Format? = nil
        var highestResolutionDimensions = CMVideoDimensions(width: 0, height: 0)
        
        for format in device.formats {
            let deviceFormat = format as AVCaptureDevice.Format
            
            let deviceFormatDescription = deviceFormat.formatDescription
            if CMFormatDescriptionGetMediaSubType(deviceFormatDescription) == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange {
                let candidateDimensions = CMVideoFormatDescriptionGetDimensions(deviceFormatDescription)
                if (highestResolutionFormat == nil) || (candidateDimensions.width > highestResolutionDimensions.width) {
                    highestResolutionFormat = deviceFormat
                    highestResolutionDimensions = candidateDimensions
                }
            }
        }
        
        if highestResolutionFormat != nil {
            let resolution = CGSize(width: CGFloat(highestResolutionDimensions.width), height: CGFloat(highestResolutionDimensions.height))
            return (highestResolutionFormat!, resolution)
        }
        
        return nil
    }
    
    func configureFrontCamera(for captureSession: AVCaptureSession) throws -> (device: AVCaptureDevice, resolution: CGSize) {
        // let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .front)
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .front)
        
        if let device = deviceDiscoverySession.devices.first {
            if let deviceInput = try? AVCaptureDeviceInput(device: device) {
                if captureSession.canAddInput(deviceInput) {
                    captureSession.addInput(deviceInput)
                }
                
                if let highestResolution = self.highestResolution420Format(for: device) {
                    try device.lockForConfiguration()
                    device.activeFormat = highestResolution.format
                    device.unlockForConfiguration()
                    
                    return (device, highestResolution.resolution)
                }
            }
        }
        
        throw NSError(domain: "ViewController", code: 1, userInfo: nil)
    }
    
    // MARK: Helper Methods for Handling Device Orientation & EXIF
    
    func radiansForDegrees(_ degrees: CGFloat) -> CGFloat {
        return CGFloat(Double(degrees) * Double.pi / 180.0)
    }
    
    func exifOrientationForDeviceOrientation(_ deviceOrientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
        
        switch deviceOrientation {
        case .portraitUpsideDown:
            return .rightMirrored
            
        case .landscapeLeft:
            return .downMirrored
            
        case .landscapeRight:
            return .upMirrored
            
        default:
            return .leftMirrored
        }
    }
    
    func exifOrientationForCurrentDeviceOrientation() -> CGImagePropertyOrientation {
        return exifOrientationForDeviceOrientation(UIDevice.current.orientation)
    }
    
    func addIndicators(to faceRectanglePath: CGMutablePath, for faceObservation: VNFaceObservation) {
        let displaySize = self.captureDeviceResolution
        
        let faceBounds = VNImageRectForNormalizedRect(faceObservation.boundingBox, Int(displaySize.width), Int(displaySize.height))
        
        /*
         guard let image = UIImage(named: "test2") else { return }
         let imageView = UIImageView(image: image)
         imageView.contentMode = .scaleAspectFit
         let imageWidth:CGFloat = 120
         let scaledHeight = imageWidth / image.size.width * image.size.height
         imageView.frame = CGRect(x: faceBounds.origin.x, y: faceBounds.origin.y, width: imageWidth, height: scaledHeight)
         */
        
        // print(faceBounds.origin.x, faceBounds.origin.y, faceBounds.width, faceBounds.height)
        
        faceRectanglePath.addRect(faceBounds)
    }
    
    func updateLayerGeometry() {
        guard let overlayLayer = self.detectionOverlayLayer,
            let rootLayer = self.rootLayer,
            let previewLayer = self.previewLayer
            else {
                return
        }
        
        CATransaction.setValue(NSNumber(value: true), forKey: kCATransactionDisableActions)
        
        let videoPreviewRect = previewLayer.layerRectConverted(fromMetadataOutputRect: CGRect(x: 0, y: 0, width: 1, height: 1))
        
        var rotation: CGFloat
        var scaleX: CGFloat
        var scaleY: CGFloat
        
        // Rotate the layer into screen orientation.
        switch UIDevice.current.orientation {
        case .portraitUpsideDown:
            rotation = 180
            scaleX = videoPreviewRect.width / captureDeviceResolution.width
            scaleY = videoPreviewRect.height / captureDeviceResolution.height
            
        case .landscapeLeft:
            rotation = 90
            scaleX = videoPreviewRect.height / captureDeviceResolution.width
            scaleY = scaleX
            
        case .landscapeRight:
            rotation = -90
            scaleX = videoPreviewRect.height / captureDeviceResolution.width
            scaleY = scaleX
            
        default:
            rotation = 0
            scaleX = videoPreviewRect.width / captureDeviceResolution.width
            scaleY = videoPreviewRect.height / captureDeviceResolution.height
        }
        
        // Scale and mirror the image to ensure upright presentation.
        let affineTransform = CGAffineTransform(rotationAngle: self.radiansForDegrees(rotation))
            .scaledBy(x: scaleX, y: -scaleY)
        overlayLayer.setAffineTransform(affineTransform)
        
        // Cover entire screen UI.
        let rootLayerBounds = rootLayer.bounds
        overlayLayer.position = CGPoint(x: rootLayerBounds.midX, y: rootLayerBounds.midY)
    }
    
    /// - Tag: DrawPaths
    func drawFaceObservations(faceObservations: [VNFaceObservation], faceRectangleShapeLayer: CAShapeLayer, displaySize: CGSize, overlayLayer: CALayer, rootLayer: CALayer, previewLayer: AVCaptureVideoPreviewLayer) {
        
        self.captureDeviceResolution = displaySize
        self.detectionOverlayLayer = overlayLayer
        self.rootLayer = rootLayer
        self.previewLayer = previewLayer
        
        CATransaction.begin()
        
        CATransaction.setValue(NSNumber(value: true), forKey: kCATransactionDisableActions)
        
        let faceRectanglePath = CGMutablePath()
        
        for faceObservation in faceObservations {
            self.addIndicators(to: faceRectanglePath, for: faceObservation)
        }
        
        faceRectangleShapeLayer.path = faceRectanglePath
        
        self.updateLayerGeometry()
        
        CATransaction.commit()
    }
    
}

