//
//  Recorder.swift
//  
//
//  Created by scchn on 2023/2/5.
//

import Foundation
import AVFoundation

public enum RecorderError: Error {
    case busy
    case invalidVideoInput
    case failedToStartWriting
    case internalError(Error)
    case unknown
}

public protocol RecorderDelegate: AnyObject {
    func recorder(_ recorder: Recorder, didChangeStatus status: Recorder.Status)
    func recorder(_ recorder: Recorder, didFailToInitializeWith error: RecorderError)
    func recorder(_ recorder: Recorder, didFinishRecordingTo outputFileURL: URL, fileType: Recorder.FileType, error: RecorderError?)
    func recorder(_ recorder: Recorder, didCancelRecordingTo outputFileURL: URL, fileType: Recorder.FileType)
    func recorderDidBecomeReadyForMoreVideoData(_ recorder: Recorder)
    func recorderDidBecomeReadyForMoreAudioData(_ recorder: Recorder)
}

public extension RecorderDelegate {
    func recorder(_ recorder: Recorder, didChangeStatus status: Recorder.Status) {}
    func recorder(_ recorder: Recorder, didFailToInitializeWith error: RecorderError) {}
    func recorder(_ recorder: Recorder, didFinishRecordingTo outputFileURL: URL, fileType: Recorder.FileType, error: RecorderError?) {}
    func recorder(_ recorder: Recorder, didCancelRecordingTo outputFileURL: URL, fileType: Recorder.FileType) {}
    func recorderDidBecomeReadyForMoreVideoData(_ recorder: Recorder) {}
    func recorderDidBecomeReadyForMoreAudioData(_ recorder: Recorder) {}
}

extension Recorder {
    
    public enum Status {
        case idle
        case initializing
        case ready
        case writing
        case finishing
        case cancelling
    }
    
    public enum FileType: Int, CaseIterable {
        case mov
        case mp4
        
        public var avFileType: AVFileType {
            switch self {
            case .mov: return .mov
            case .mp4: return .mp4
            }
        }
        
        @available(iOS 14.0, *)
        public var utType: UTType {
            switch self {
            case .mov: return .quickTimeMovie
            case .mp4: return .mpeg4Movie
            }
        }
        
    }
    
    public enum VideoSettings {
        case auto(
            codec: AVVideoCodecType,
            formatHint: CMFormatDescription,
            sourceAttributes: [String: Any]?,
            flipOptions: FlipOptions
        )
        case custom(
            codec: AVVideoCodecType,
            dimensions: CGSize,
            sourceAttributes: [String: Any]?,
            flipOptions: FlipOptions
        )
        
        var sourceAttributes: [String: Any]? {
            switch self {
            case let .auto(_, _, sourceAttributes, _):
                return sourceAttributes
            case let .custom(_, _, sourceAttributes, _):
                return sourceAttributes
            }
        }
        
    }
    
    public enum AudioSettings {
        case auto(formatID: AudioFormatID, formatHint: CMFormatDescription)
        
        /// If the number of channel specifies a channel count greater than 2,
        /// the settings must also specify a value for channel layout
        case custom(formatID: AudioFormatID, sampleRate: Float, numberOfChannels: Int, channelLayout: Data?)
    }
    
}

public class Recorder {
    
    // MAKR: - Private
    
    private var videoWriter: SingleUseVideoWriter?
    
    private var isRecording: Bool {
        status == .ready || status == .writing
    }
    
    // MAKR: - Public
    
    public weak var delegate: RecorderDelegate?
    
    public private(set) var status: Status = .idle {
        didSet {
            guard status != oldValue else {
                return
            }
            delegate?.recorder(self, didChangeStatus: status)
        }
    }
    
    public var outputURL: URL? {
        videoWriter?.outputURL
    }
    
    public var fileType: FileType? {
        videoWriter?.fileType
    }
    
    public var flipOptions: FlipOptions? {
        videoWriter?.flipOptions
    }
    
    public var isReadyForMoreVideoData: Bool {
        videoWriter?.isReadyForMoreVideoData ?? false
    }
    
    public var isReadyForMoreAudioData: Bool {
        videoWriter?.isReadyForMoreAudioData ?? false
    }
    
    // MARK: - Life Cycle
    
    public init() {
        
    }
    
    public func initialize(
        outputFileURL: URL,
        fileType: FileType,
        videoSettings: VideoSettings,
        audioSettings: AudioSettings? = nil,
        inRealTime: Bool = true
    ) {
        guard status == .idle else {
            delegate?.recorder(self, didFailToInitializeWith: .busy)
            return
        }
        
        status = .initializing
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let videoInput = AVAssetWriterInput(videoSettings: videoSettings, inRealTime: inRealTime)
            let audioInput: AVAssetWriterInput? = {
                guard let settings = audioSettings else {
                    return nil
                }
                
                return AVAssetWriterInput(audioSettings: settings)
            }()
            
            do {
                let videoWriter = try SingleUseVideoWriter(
                    outputURL: outputFileURL,
                    fileType: fileType,
                    videoInput: videoInput,
                    pixelBufferAttribute: videoSettings.sourceAttributes,
                    audioInput: audioInput
                )
                
                DispatchQueue.main.async {
                    guard let self = self else {
                        return
                    }
                    
                    self.videoWriter = videoWriter
                    self.status = .ready
                }
            } catch {
                DispatchQueue.main.async {
                    guard let self = self else {
                        return
                    }
                    
                    self.status = .idle
                    
                    if let error = error as? RecorderError {
                        self.delegate?.recorder(self, didFailToInitializeWith: error)
                    } else {
                        self.delegate?.recorder(self, didFailToInitializeWith: .internalError(error))
                    }
                }
            }
        }
    }
    
    // MARK: - Start Time
    
    private func setStartTimeIfNeeded(_ time: CMTime) {
        guard let writer = videoWriter, status == .ready else {
            return
        }
        
        writer.setStartTime(at: time)
        
        status = .writing
    }
    
    private func setStartTimeIfNeeded(sampleBuffer: CMSampleBuffer) {
        guard let writer = videoWriter, status == .ready else {
            return
        }
        
        let timeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        writer.setStartTime(at: timeStamp)
        
        status = .writing
    }
    
    // MARK: - Video
    
    @discardableResult
    public func appendVideoData(_ pixelBuffer: CVPixelBuffer, timeStamp: CMTime) -> Bool {
        guard let writer = videoWriter, isRecording else {
            return false
        }
        
        setStartTimeIfNeeded(timeStamp)
        
        return writer.appendVideoData(pixelBuffer, timeStamp: timeStamp)
    }
    
    @discardableResult
    public func appendVideoData(_ pixelBuffer: CVPixelBuffer, timeStamp: CMTime, drawingHandler: (CGRect) -> Void) -> Bool {
        guard isRecording,
              let writer = videoWriter,
              let copiedPixelBuffer = pixelBuffer.copy()
        else {
            return false
        }
        
        setStartTimeIfNeeded(timeStamp)
        
        copiedPixelBuffer.applyOverlay(flipOptions: writer.flipOptions, drawingHandler: drawingHandler)
        
        return writer.appendVideoData(copiedPixelBuffer, timeStamp: timeStamp)
    }
    
    @discardableResult
    public func appendVideoData(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard isRecording,
              let writer = videoWriter,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        else {
            return false
        }
        
        let timeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        setStartTimeIfNeeded(timeStamp)
        
        return writer.appendVideoData(pixelBuffer, timeStamp: timeStamp)
    }
    
    @discardableResult
    public func appendVideoData(_ sampleBuffer: CMSampleBuffer, drawingHandler: (CGRect) -> Void) -> Bool {
        guard isRecording,
              let writer = videoWriter,
              let sourcePixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let copiedPixelBuffer = sourcePixelBuffer.copy()
        else {
            return false
        }
        
        let timeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        setStartTimeIfNeeded(timeStamp)
        
        copiedPixelBuffer.applyOverlay(flipOptions: writer.flipOptions, drawingHandler: drawingHandler)

        return writer.appendVideoData(copiedPixelBuffer, timeStamp: timeStamp)
    }
    
    @discardableResult
    func requestVideoDataWhenReady(on queue: DispatchQueue) -> Bool {
        guard let writer = videoWriter, isRecording else {
            return false
        }
        
        writer.requestVideoDataWhenReady(on: queue) { [weak self] in
            guard let self = self else {
                return
            }
            
            self.delegate?.recorderDidBecomeReadyForMoreVideoData(self)
        }
        
        return true
    }
    
    @discardableResult
    func markVideoAsFinished() -> Bool {
        guard let writer = videoWriter, isRecording else {
            return false
        }
        
        writer.markVideoAsFinished()
        
        return true
    }
    
    // MARK: - Audio
    
    @discardableResult
    public func appendAudioData(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard let writer = videoWriter, isRecording else {
            return false
        }
        
        setStartTimeIfNeeded(sampleBuffer: sampleBuffer)
        
        return writer.appendAudioData(sampleBuffer)
    }
    
    @discardableResult
    func requestAudioDataWhenReady(on queue: DispatchQueue) -> Bool {
        guard let writer = videoWriter, isRecording else {
            return false
        }
        
        return writer.requestAudioDataWhenReady(on: queue) { [weak self] in
            guard let self = self else {
                return
            }
            
            self.delegate?.recorderDidBecomeReadyForMoreAudioData(self)
        }
    }
    
    @discardableResult
    func markAudioAsFinished() -> Bool {
        guard let writer = videoWriter, isRecording else {
            return false
        }
        
        return writer.markAudioAsFinished()
    }
    
    // MARK: - Finish / Cancel
    
    @discardableResult
    public func cancel() -> Bool {
        guard let writer = videoWriter, isRecording else {
            return false
        }
        
        let fileType = writer.fileType
        
        status = .cancelling
        
        writer.cancel { [weak self] outputURL in
            guard let self = self else {
                return
            }
            
            self.videoWriter = nil
            self.status = .idle
            self.delegate?.recorder(self, didCancelRecordingTo: outputURL, fileType: fileType)
        }
        
        return true
    }
    
    @discardableResult
    public func finish() -> Bool {
        guard let writer = videoWriter, isRecording else {
            return false
        }
        
        let fileType = writer.fileType
        
        status = .finishing
        
        writer.finish { [weak self] outputURL, error in
            guard let self = self else {
                return
            }
            
            self.videoWriter = nil
            self.status = .idle
            self.delegate?.recorder(self, didFinishRecordingTo: outputURL, fileType: fileType, error: error)
        }
        
        return true
    }
    
}
