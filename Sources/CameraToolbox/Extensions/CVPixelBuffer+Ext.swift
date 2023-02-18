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
    
    public func applyOverlay(flipOptions: FlipOptions, drawingHandler: (CGRect) -> Void) {
        guard CVPixelBufferLockBaseAddress(self, .none) == kCVReturnSuccess else {
            return
        }
        
        let data = CVPixelBufferGetBaseAddress(self)
        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetWidth(self)
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
#if os(macOS)
            let oldGraphicsContext = NSGraphicsContext.current
            let currentGraphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
            NSGraphicsContext.current = currentGraphicsContext
#else
            UIGraphicsPushContext(context)
#endif
            
            let size = CGSize(width: width, height: height)
            let rect = CGRect(origin: .zero, size: size)
            
            if flipOptions.contains(.horizontal) {
                context.translateBy(x: size.width, y: 0)
                context.scaleBy(x: -1, y: 1)
            }
            
            if flipOptions.contains(.vertical) {
                context.translateBy(x: 0, y: size.height)
                context.scaleBy(x: 1, y: -1)
            }
            
            drawingHandler(rect)
            
#if os(macOS)
            NSGraphicsContext.current = oldGraphicsContext
#else
            UIGraphicsPopContext()
#endif
        }
        
        CVPixelBufferUnlockBaseAddress(self, .none)
    }
    
    public func copy() -> CVPixelBuffer? {
        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetHeight(self)
        let formatType = CVPixelBufferGetPixelFormatType(self)
        let attachments: CFDictionary?
        var tempCopy: CVPixelBuffer?
        
        if #available(macOS 12.0, iOS 15.0, *) {
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
        
        let planeCount = CVPixelBufferGetPlaneCount(self)
        
        if planeCount == 0 {
            let dest = CVPixelBufferGetBaseAddress(copy)
            let source = CVPixelBufferGetBaseAddress(self)
            let bytesPerRowSrc = CVPixelBufferGetBytesPerRow(self)
            let bytesPerRowDest = CVPixelBufferGetBytesPerRow(copy)
            
            if bytesPerRowSrc == bytesPerRowDest {
                memcpy(dest, source, height * bytesPerRowSrc)
            } else {
                var startOfRowSrc = source
                var startOfRowDest = dest
                
                for _ in 0..<height {
                    memcpy(startOfRowDest, startOfRowSrc, min(bytesPerRowSrc, bytesPerRowDest))
                    startOfRowSrc = startOfRowSrc?.advanced(by: bytesPerRowSrc)
                    startOfRowDest = startOfRowDest?.advanced(by: bytesPerRowDest)
                }
            }
        } else {
            for plane in 0..<planeCount {
                let dest = CVPixelBufferGetBaseAddressOfPlane(copy, plane)
                let source = CVPixelBufferGetBaseAddressOfPlane(self, plane)
                let bytesPerRowSrc = CVPixelBufferGetBytesPerRowOfPlane(self, plane)
                let bytesPerRowDest = CVPixelBufferGetBytesPerRowOfPlane(copy, plane)
                
                if bytesPerRowSrc == bytesPerRowDest {
                    memcpy(dest, source, height * bytesPerRowSrc)
                } else {
                    var startOfRowSrc = source
                    var startOfRowDest = dest
                    
                    for _ in 0..<height {
                        memcpy(startOfRowDest, startOfRowSrc, min(bytesPerRowSrc, bytesPerRowDest))
                        startOfRowSrc = startOfRowSrc?.advanced(by: bytesPerRowSrc)
                        startOfRowDest = startOfRowDest?.advanced(by: bytesPerRowDest)
                    }
                }
            }
        }
        
        CVPixelBufferUnlockBaseAddress(copy, .none)
        
        return copy
    }
    
}
