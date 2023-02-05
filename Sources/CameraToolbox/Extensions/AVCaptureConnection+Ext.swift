//
//  AVCaptureConnection+Ext.swift
//  
//
//  Created by scchn on 2023/1/11.
//

import Foundation
import AVFoundation

extension AVCaptureConnection {
    
    func flip(options: FlipOptions) {
        guard isVideoMirroringSupported && isVideoOrientationSupported else {
            return
        }
        
        let vertical = options.contains(.vertical)
        let horizontal = options.contains(.horizontal)
        
        automaticallyAdjustsVideoMirroring = false
        
        if vertical && horizontal {
            isVideoMirrored = false
            videoOrientation = .portraitUpsideDown
        } else if horizontal {
            isVideoMirrored = true
            videoOrientation = .portrait
        } else if vertical {
            isVideoMirrored = true
            videoOrientation = .portraitUpsideDown
        } else {
            isVideoMirrored = false
            videoOrientation = .portrait
        }
    }
    
}
