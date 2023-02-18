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
    
    public func copy() -> CVPixelBuffer? {
        deepCopy(drawingHandler: nil)
    }
    
    func copy(flipOptions: FlipOptions, drawingHandler: @escaping (CGRect) -> Void) -> CVPixelBuffer? {
        deepCopy { rect, context in
            #if os(macOS)
            let oldGraphicsContext = NSGraphicsContext.current
            let currentGraphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
            NSGraphicsContext.current = currentGraphicsContext
            #else
            UIGraphicsPushContext(context)
            #endif
            
            if flipOptions.contains(.horizontal) {
                context.translateBy(x: rect.width, y: 0)
                context.scaleBy(x: -1, y: 1)
            }
            
            if flipOptions.contains(.vertical) {
                context.translateBy(x: 0, y: rect.height)
                context.scaleBy(x: 1, y: -1)
            }
            
            drawingHandler(rect)
            
            #if os(macOS)
            NSGraphicsContext.current = oldGraphicsContext
            #else
            UIGraphicsPopContext()
            #endif
        }
    }
    
    private func deepCopy(drawingHandler: ((CGRect, CGContext) -> Void)?) -> CVPixelBuffer? {
        let attachments: CFDictionary?
        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetHeight(self)
        let formatType = CVPixelBufferGetPixelFormatType(self)
        var tempCopy : CVPixelBuffer?
        
        if #available(macOS 12.0, *) {
            attachments = CVBufferCopyAttachments(self, .shouldPropagate)
        } else {
            attachments = CVBufferGetAttachments(self, .shouldPropagate)
        }
        
        CVPixelBufferCreate(nil, width, height, formatType, attachments, &tempCopy)
        
        guard let copy = tempCopy, CVPixelBufferLockBaseAddress(self, .readOnly) == kCVReturnSuccess else {
            return nil
        }
        
        defer {
            CVPixelBufferUnlockBaseAddress(self, .readOnly)
        }
        
        guard CVPixelBufferLockBaseAddress(copy, .none) == kCVReturnSuccess else {
            return nil
        }
        
        defer {
            CVPixelBufferUnlockBaseAddress(copy, .none)
        }
        
        for plane in 0..<CVPixelBufferGetPlaneCount(self) {
            let dest = CVPixelBufferGetBaseAddressOfPlane(copy, plane)
            let source = CVPixelBufferGetBaseAddressOfPlane(self, plane)
            let height = CVPixelBufferGetHeightOfPlane(self, plane)
            let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(self, plane)
            
            memcpy(dest, source, height * bytesPerRow)
        }
        
        if let drawingHandler = drawingHandler {
            let data = CVPixelBufferGetBaseAddress(self)
            let bitsPerComponent = 8
            let bytesPerRow = CVPixelBufferGetBytesPerRow(self)
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo: UInt32 = (
                CGImageByteOrderInfo.order32Little.rawValue |
                CGImageAlphaInfo.premultipliedFirst.rawValue
            )
            let context = CGContext(
                data: data,
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            )
            
            if let context = context {
                let size = CGSize(width: width, height: height)
                let rect = CGRect(origin: .zero, size: size)
                
                drawingHandler(rect, context)
            }
        }
        
        return copy
    }
    
}
