//
//  CameraMovieFileOutput.swift
//  
//
//  Created by scchn on 2023/1/11.
//

import Foundation
import AVFoundation

public class CameraMovieFileOutput: NSObject, CameraOutput {
    
    public static func makeTemporaryMovieFileURL() -> URL {
        let directory = NSTemporaryDirectory()
        let fileName = NSUUID().uuidString.appending("mov")
        
        return NSURL.fileURL(withPathComponents: [directory, fileName])!
    }
    
    private var output = AVCaptureMovieFileOutput()
    
    public var underlyingOutput: AVCaptureOutput {
        output
    }
    
    public var isRecording: Bool {
        output.isRecording
    }
    
    #if os(macOS)
    public var isPaused: Bool {
        output.isRecordingPaused
    }
    #endif
    
    public var recordingStartHandler: ((URL) -> Void)?
    public var recordingPauseHandler: ((URL) -> Void)?
    public var recordingResumeHandler: ((URL) -> Void)?
    public var recordingFinishHandler: ((URL, Error?) -> Void)?
    
    public override init() {
        super.init()
    }
    
    public func start(outputFileURL: URL? = nil) {
        let outputFileURL = outputFileURL ?? Self.makeTemporaryMovieFileURL()
        
        output.startRecording(to: outputFileURL, recordingDelegate: self)
    }
    
    #if os(macOS)
    public func pause() {
        output.pauseRecording()
    }
    
    public func resume() {
        output.resumeRecording()
    }
    #endif
    
    public func stop() {
        output.stopRecording()
    }
    
}

extension CameraMovieFileOutput: AVCaptureFileOutputRecordingDelegate {
    
    public func fileOutput(
        _ output: AVCaptureFileOutput,
        didStartRecordingTo fileURL: URL,
        from connections: [AVCaptureConnection]
    ) {
        DispatchQueue.main.async {
            self.recordingStartHandler?(fileURL)
        }
    }
    
    #if os(macOS)
    public func fileOutput(
        _ output: AVCaptureFileOutput,
        didPauseRecordingTo fileURL: URL,
        from connections: [AVCaptureConnection]
    ) {
        DispatchQueue.main.async {
            self.recordingPauseHandler?(fileURL)
        }
    }
    
    public func fileOutput(
        _ output: AVCaptureFileOutput,
        didResumeRecordingTo fileURL: URL,
        from connections: [AVCaptureConnection]
    ) {
        DispatchQueue.main.async {
            self.recordingResumeHandler?(fileURL)
        }
    }
    #endif
    
    public func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.recordingFinishHandler?(outputFileURL, error)
        }
    }
    
}
