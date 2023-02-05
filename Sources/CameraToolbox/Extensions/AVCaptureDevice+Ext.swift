//
//  AVCaptureDevice+Ext.swift
//  
//
//  Created by scchn on 2023/1/11.
//

import Foundation
import AVFoundation

extension AVCaptureDevice {
    
    var activeFrameRateRange: AVFrameRateRange? {
        activeFormat.videoSupportedFrameRateRanges.first {
            CMTimeCompare(activeVideoMinFrameDuration, $0.minFrameDuration) == 0
        }
    }
    
}
