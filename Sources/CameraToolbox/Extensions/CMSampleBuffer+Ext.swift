//
//  CMSampleBuffer+Ext.swift
//  
//
//  Created by scchn on 2023/2/5.
//

import Foundation
import CoreMedia

extension CMSampleBuffer {
    
    func pixelBuffer(flipOptions: FlipOptions, drawingHandler: ((CGRect) -> Void)?) -> CVPixelBuffer? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(self) else {
            return nil
        }
        guard let drawingHandler = drawingHandler else {
            return imageBuffer
        }
        
        imageBuffer.applyDrawing(flipOptions: flipOptions, drawingHandler: drawingHandler)
        
        return imageBuffer
    }
    
}
