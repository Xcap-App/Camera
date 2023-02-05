//
//  SingleUseVideoWriter.swift
//  
//
//  Created by scchn on 2023/2/5.
//

import Foundation
import AVFoundation

class SingleUseVideoWriter {
    
    private let assetWriter: AVAssetWriter
    private let videoInput: AVAssetWriterInput
    private let videoInputAdaptor: AVAssetWriterInputPixelBufferAdaptor
    private let audioInput: AVAssetWriterInput?
    
    let flipOptions: FlipOptions
    
    var status: AVAssetWriter.Status {
        assetWriter.status
    }
    
    var outputURL: URL {
        assetWriter.outputURL
    }
    
    let fileType: Recorder.FileType
    
    var isReadyForMoreVideoData: Bool {
        videoInput.isReadyForMoreMediaData
    }
    
    var isReadyForMoreAudioData: Bool {
        audioInput?.isReadyForMoreMediaData ?? false
    }
    
    var isCancellable: Bool {
        assetWriter.status != .failed && assetWriter.status != .completed
    }
    
    init(
        outputURL: URL,
        fileType: Recorder.FileType,
        videoInput: AVAssetWriterInput,
        pixelBufferAttribute: [String: Any]?,
        audioInput: AVAssetWriterInput?
    ) throws {
        do {
            self.assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: fileType.avFileType)
        } catch {
            throw RecorderError.internalError(error)
        }
        
        guard assetWriter.canAdd(videoInput) else {
            throw RecorderError.invalidVideoInput
        }
        
        self.videoInput = videoInput
        self.videoInputAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: pixelBufferAttribute
        )
        self.fileType = fileType
        self.flipOptions = FlipOptions(
            (videoInput.transform.d != 1 ? [.vertical] : []) +
            (videoInput.transform.a != 1 ? [.horizontal] : [])
        )
        
        // Video
        
        assetWriter.add(videoInput)
        
        // Audio
        
        if let audioInput = audioInput, assetWriter.canAdd(audioInput) {
            assetWriter.add(audioInput)
            self.audioInput = audioInput
        } else {
            self.audioInput = nil
        }
        
        // Start
        
        if !assetWriter.startWriting() {
            throw RecorderError.failedToStartWriting
        }
    }
    
    func setStartTime(at sourceTime: CMTime) {
        assetWriter.startSession(atSourceTime: sourceTime)
    }
    
    // MARK: - Video
    
    func appendVideoData(_ pixelBuffer: CVPixelBuffer, timeStamp: CMTime) -> Bool {
        guard videoInput.isReadyForMoreMediaData else {
            return false
        }
        
        return videoInputAdaptor.append(pixelBuffer, withPresentationTime: timeStamp)
    }
    
    func requestVideoDataWhenReady(on queue: DispatchQueue, using block: @escaping () -> Void) {
        videoInput.requestMediaDataWhenReady(on: queue) {
            block()
        }
    }
    
    func markVideoAsFinished() {
        videoInput.markAsFinished()
    }
    
    // MARK: - Audio
    
    func appendAudioData(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard let input = audioInput else {
            return false
        }
        
        return input.append(sampleBuffer)
    }
    
    func requestAudioDataWhenReady(on queue: DispatchQueue, using block: @escaping () -> Void) -> Bool {
        guard let audioInput = audioInput else {
            return false
        }
        
        audioInput.requestMediaDataWhenReady(on: queue) {
            block()
        }
        
        return true
    }
    
    func markAudioAsFinished() -> Bool {
        audioInput?.markAsFinished() != nil
    }
    
    // MARK: - Finish
    
    func cancel(_ completionHandler: @escaping (URL) -> Void) {
        let outputURL = assetWriter.outputURL
        
        guard isCancellable else {
            DispatchQueue.main.async {
                completionHandler(outputURL)
            }
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                return
            }
            
            self.assetWriter.cancelWriting()
            
            DispatchQueue.main.async {
                completionHandler(outputURL)
            }
        }
    }
    
    func finish(_ completionHandler: @escaping (URL, RecorderError?) -> Void) {
        assetWriter.finishWriting { [weak self] in
            guard let self = self else {
                return
            }
            
            let ok = self.assetWriter.status == .completed
            let outputURL = self.assetWriter.outputURL
            let error = self.assetWriter.error
            
            DispatchQueue.main.async {
                if ok {
                    completionHandler(outputURL, nil)
                } else {
                    if let error = error {
                        completionHandler(outputURL, .internalError(error))
                    } else {
                        completionHandler(outputURL, .unknown)
                    }
                }
            }
        }
    }
    
}
