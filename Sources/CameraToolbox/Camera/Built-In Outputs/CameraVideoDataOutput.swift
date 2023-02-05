//
//  CameraVideoDataOutput.swift
//  
//
//  Created by scchn on 2023/1/11.
//

import Foundation
import AVFoundation

public class CameraVideoDataOutput: NSObject, CameraOutput {
    
    private let output = AVCaptureVideoDataOutput()
    
    public var underlyingOutput: AVCaptureOutput {
        output
    }
    
    public var videoDataOutputHandler: ((CMSampleBuffer) -> Void)?
    
    public init(queue: DispatchQueue, discardsLateFrames: Bool = true) {
        super.init()
        
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = discardsLateFrames
        output.setSampleBufferDelegate(self, queue: queue)
    }
    
}

extension CameraVideoDataOutput: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        videoDataOutputHandler?(sampleBuffer)
    }
    
}
