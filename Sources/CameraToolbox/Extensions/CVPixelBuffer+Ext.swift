//
//  CVPixelBuffer+Ext.swift
//  
//
//  Created by scchn on 2023/2/5.
//

#if os(macOS)
import Cocoa
#else
import UIKit
#endif

import CoreMedia

extension CVPixelBufferLockFlags {
    static let none = CVPixelBufferLockFlags()
}

extension CVPixelBuffer {
    
    private func makeContext(width: Int, height: Int) -> CGContext? {
        let data = CVPixelBufferGetBaseAddress(self)
        let bitsPerComponent = 8
        let bytesPerRow = CVPixelBufferGetBytesPerRow(self)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo: UInt32 = (
            CGImageByteOrderInfo.order32Little.rawValue |
            CGImageAlphaInfo.premultipliedFirst.rawValue
        )
        
        return CGContext(
            data: data,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        )
    }
    
    private func draw(context: CGContext, drawingHandler: () -> Void) {
        #if os(macOS)
        
        let oldGraphicsContext = NSGraphicsContext.current
        let currentGraphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
        
        NSGraphicsContext.current = currentGraphicsContext
        
        drawingHandler()
        
        NSGraphicsContext.current = oldGraphicsContext
        
        #else
        
        UIGraphicsPushContext(context)
        
        drawingHandler()
        
        UIGraphicsPopContext()
        
        #endif
    }
    
    public func applyDrawing(flipOptions: FlipOptions, drawingHandler: (CGRect) -> Void) {
        guard CVPixelBufferLockBaseAddress(self, .none) == kCVReturnSuccess else {
            return
        }
        
        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetHeight(self)
        
        if let context = makeContext(width: width, height: height) {
            draw(context: context) {
                let rect = CGRect(x: 0, y: 0, width: width, height: height)
                
                if flipOptions.contains(.horizontal) {
                    context.translateBy(x: rect.width, y: 0)
                    context.scaleBy(x: -1, y: 1)
                }
                
                if flipOptions.contains(.vertical) {
                    context.translateBy(x: 0, y: rect.height)
                    context.scaleBy(x: 1, y: -1)
                }
                
                drawingHandler(rect)
            }
        }
        
        CVPixelBufferUnlockBaseAddress(self, .none)
    }
    
}
