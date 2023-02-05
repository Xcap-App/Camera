//
//  FlipOptions.swift
//  
//
//  Created by scchn on 2023/2/5.
//

import Foundation
import CoreGraphics

public struct FlipOptions: OptionSet {
    
    public static let vertical   = FlipOptions(rawValue: 1 << 0)
    public static let horizontal = FlipOptions(rawValue: 1 << 1)
    
    public var rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    var transform: CGAffineTransform {
        CGAffineTransform.identity.scaledBy(
            x: contains(.horizontal) ? -1 : 1,
            y: contains(.vertical) ? -1 : 1
        )
    }
    
}
