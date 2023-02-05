//
//  CameraPhotoOutput.swift
//  
//
//  Created by scchn on 2023/1/11.
//

import Foundation
import AVFoundation

public enum CameraPhotoOutputError: Error {
    case noVideoConnection
    case internalError(Error)
    case unknown
}

extension CameraPhotoOutput {
    
    public typealias PhotoOutputHandler = (Result<CVPixelBuffer, CameraPhotoOutputError>) -> Void
    
}

public class CameraPhotoOutput: NSObject, CameraOutput {
    
    private let output = AVCapturePhotoOutput()
    private var pendingOutputHandlers: [Int64: PhotoOutputHandler] = [:]
    
    public var underlyingOutput: AVCaptureOutput {
        output
    }
    
    public override init() {
        super.init()
    }
    
    public func capture(_ completionHandler: @escaping PhotoOutputHandler) {
        guard output.connection(with: .video) != nil else {
            completionHandler(.failure(.noVideoConnection))
            return
        }
        
        let format = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        let settings = AVCapturePhotoSettings(format: format)
        
        pendingOutputHandlers[settings.uniqueID] = completionHandler
        
        output.capturePhoto(with: settings, delegate: self)
    }
    
}

extension CameraPhotoOutput: AVCapturePhotoCaptureDelegate {
    
    public func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let id = photo.resolvedSettings.uniqueID
        
        guard let outputHandler = pendingOutputHandlers.removeValue(forKey: id) else {
            return
        }
        
        DispatchQueue.main.async {
            if let pixelBuffer = photo.pixelBuffer {
                outputHandler(.success(pixelBuffer))
            } else if let error = error {
                outputHandler(.failure(.internalError(error)))
            } else {
                outputHandler(.failure(.unknown))
            }
        }
    }
    
}

