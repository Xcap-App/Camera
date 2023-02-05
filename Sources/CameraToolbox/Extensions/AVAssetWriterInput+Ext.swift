//
//  AVAssetWriterInput+Ext.swift
//  
//
//  Created by scchn on 2023/2/5.
//

import Foundation
import AVFoundation

extension AVAssetWriterInput {
    
    convenience init(videoSettings: Recorder.VideoSettings, inRealTime: Bool) {
        let outputSettings: [String: Any]
        let sourceFormatHint: CMFormatDescription?
        let transform: CGAffineTransform
        
        switch videoSettings {
        case let .auto(codec, formatHint, _, flipOptions):
            outputSettings = [AVVideoCodecKey: codec]
            sourceFormatHint = formatHint
            transform = flipOptions.transform
            
        case let .custom(codec, dimensions, _, flipOptions):
            outputSettings = [
                AVVideoCodecKey: codec,
                AVVideoWidthKey: Int(dimensions.width),
                AVVideoHeightKey: Int(dimensions.height),
            ]
            sourceFormatHint = nil
            transform = flipOptions.transform
        }
        
        self.init(
            mediaType: .video,
            outputSettings: outputSettings,
            sourceFormatHint: sourceFormatHint
        )
        
        self.expectsMediaDataInRealTime = inRealTime
        self.transform = transform
    }
    
    convenience init(audioSettings: Recorder.AudioSettings) {
        var outputSettings: [String: Any]
        var sourceFormatHint: CMFormatDescription?
        
        switch audioSettings {
        case let .auto(formatID, formatHint):
            outputSettings = [
                AVFormatIDKey: formatID,
            ]
            sourceFormatHint = formatHint
            
        case let .custom(formatID, sampleRate, numberOfChannels, channelLayout):
            outputSettings = [
                AVFormatIDKey: formatID,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: numberOfChannels,
            ]
            if let channelLayout = channelLayout {
                outputSettings[AVChannelLayoutKey] = channelLayout
            }
        }
        
        self.init(
            mediaType: .audio,
            outputSettings: outputSettings,
            sourceFormatHint: sourceFormatHint
        )
    }
    
}

