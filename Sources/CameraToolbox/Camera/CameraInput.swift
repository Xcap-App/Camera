//
//  CameraInput.swift
//  
//
//  Created by scchn on 2023/1/11.
//

import Foundation
import AVFoundation

public protocol CameraInput: AnyObject {
    var underlyingInput: AVCaptureInput { get }
}

extension AVCaptureInput: CameraInput {
    
    public var underlyingInput: AVCaptureInput {
        self
    }
    
}
