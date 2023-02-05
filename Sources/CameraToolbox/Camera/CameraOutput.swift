//
//  CameraOutput.swift
//  
//
//  Created by scchn on 2023/1/11.
//

import Foundation
import AVFoundation

public protocol CameraOutput: AnyObject {
    var underlyingOutput: AVCaptureOutput { get }
}

extension AVCaptureOutput: CameraOutput {
    
    public var underlyingOutput: AVCaptureOutput {
        self
    }
    
}
