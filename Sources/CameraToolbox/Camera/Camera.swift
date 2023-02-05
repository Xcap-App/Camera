//
//  Camera.swift
//  
//
//  Created by scchn on 2023/1/11.
//

import Foundation
import AVFoundation

public protocol CameraDelegate: AnyObject {
    // Device
    func cameraDidDisconnect(_ camera: Camera)
    func camera(_ camera: Camera, runtimeErrorOccurred error: Error)
    // Preview
    func camera(_ camera: Camera, didChangeFormat format: AVCaptureDevice.Format)
    func camera(_ camera: Camera, didChangeFrameRateRange frameRateRange: AVFrameRateRange)
    // Focus
    func camera(_ camera: Camera, didChangeFocusPointOfInterest pointOfInterest: CGPoint)
    func camera(_ camera: Camera, didChangeFocusMode focusMode: AVCaptureDevice.FocusMode)
    func camera(_ camera: Camera, didBeginAdjustingFocusAt pointOfInterest: CGPoint)
    func camera(_ camera: Camera, didEndAdjustingFocusAt pointOfInterest: CGPoint)
}

public extension CameraDelegate {
    // Device
    func cameraDidDisconnect(_ camera: Camera) {}
    func camera(_ camera: Camera, runtimeErrorOccurred error: Error) {}
    // Preview
    func camera(_ camera: Camera, didChangeFormat format: AVCaptureDevice.Format) {}
    func camera(_ camera: Camera, didChangeFrameRateRange frameRateRange: AVFrameRateRange) {}
    // Focus
    func camera(_ camera: Camera, didBeginAdjustingFocusAt pointOfInterest: CGPoint) {}
    func camera(_ camera: Camera, didEndAdjustingFocusAt pointOfInterest: CGPoint) {}
    func camera(_ camera: Camera, didChangeFocusPointOfInterest pointOfInterest: CGPoint) {}
    func camera(_ camera: Camera, didChangeFocusMode focusMode: AVCaptureDevice.FocusMode) {}
}

public class Camera {
    
    // MARK: - Private
    
    private let session = AVCaptureSession()
    private let deviceInput: AVCaptureDeviceInput
    private var notificationObservers: [NSObjectProtocol] = []
    private var keyValueObservations: [NSKeyValueObservation] = []
    private let videoPreviewLayers: NSHashTable<AVCaptureVideoPreviewLayer> = .weakObjects()
    
    // MARK: - Public
    
    public weak var delegate: CameraDelegate?
    
    // MARK: Device Info
    
    public var device: AVCaptureDevice {
        deviceInput.device
    }
    
    public var name: String {
        device.localizedName
    }
    
    public var uniqueID: String {
        device.uniqueID
    }
    
    public var modelID: String {
        device.modelID
    }
    
    @available(iOS 14.0, *)
    public var manufacturer: String {
        device.manufacturer
    }
    
    // MARK: Session
    
    public var isRunning: Bool {
        session.isRunning
    }
    
    public var preset: AVCaptureSession.Preset {
        session.sessionPreset
    }
    
    public private(set) var outputs: [CameraOutput] = []
    
    public private(set) var inputs: [CameraInput] = []
    
    // MARK: Flip
    
    public var flipOptions: FlipOptions = [] {
        didSet {
            flipOptionsDidChange()
        }
    }
    
    // MARK: Format
    
    public var formats: [AVCaptureDevice.Format] {
        device.formats
    }
    
    public var activeFormat: AVCaptureDevice.Format {
        device.activeFormat
    }
    
    // MARK: Frame Rate Range
    
    public var frameRateRanges: [AVFrameRateRange] {
        device.activeFormat.videoSupportedFrameRateRanges
    }
    
    public var activeFrameRateRange: AVFrameRateRange? {
        device.activeFrameRateRange
    }
    
    // MARK: Focus
    
    public var isAdjustingFocus: Bool {
        device.isAdjustingFocus
    }
    
    public var focusMode: AVCaptureDevice.FocusMode {
        device.focusMode
    }
    
    public var isFocusPointOfInterestSupported: Bool {
        device.isFocusPointOfInterestSupported
    }
    
    public var focusPointOfInterest: CGPoint {
        device.focusPointOfInterest
    }
    
    #if os(iOS)
    public var isSmoothAutoFocusSupported: Bool {
        device.isSmoothAutoFocusSupported
    }
    #endif
    
    // MARK: - Life Cycle
    
    deinit {
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        
        for observation in keyValueObservations {
            observation.invalidate()
        }
        
        for output in outputs {
            removeOutput(output)
        }
        
        for input in inputs {
            removeInput(input)
        }
        
        for previewLayer in videoPreviewLayers.allObjects {
            previewLayer.session = nil
        }
        
        session.stopRunning()
    }
    
    public init?(device: AVCaptureDevice) {
        guard let deviceInput = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(deviceInput)
        else {
            return nil
        }
        
        session.addInput(deviceInput)
        
        self.deviceInput = deviceInput
        
        setupNotifications()
        setupKeyValueObservations()
    }
    
    public convenience init?(deviceUniqueID: String) {
        guard let device = AVCaptureDevice(uniqueID: deviceUniqueID) else {
            return nil
        }
        
        self.init(device: device)
    }
    
    private func setupNotifications() {
        let center = NotificationCenter.default
        let runtimeErrorObserver = center.addObserver(
            forName: .AVCaptureSessionRuntimeError,
            object: session,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let error = notification.userInfo?[AVCaptureSessionErrorKey] as? Error
            else {
                return
            }
            
            self.delegate?.camera(self, runtimeErrorOccurred: error)
        }
        let disconnectionObserver = center.addObserver(
            forName: .AVCaptureDeviceWasDisconnected,
            object: device,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else {
                return
            }
            
            self.delegate?.cameraDidDisconnect(self)
        }
        
        notificationObservers = [runtimeErrorObserver, disconnectionObserver]
    }
    
    private func setupKeyValueObservations() {
        let formatKVO = device.observe(\.activeFormat, options: [.initial, .new]) { [weak self] device, _ in
            guard let self = self else {
                return
            }
            self.delegate?.camera(self, didChangeFormat: device.activeFormat)
        }
        let frameRateRangeKVO = device.observe(\.activeVideoMinFrameDuration, options: [.initial, .new]) { [weak self] device, _ in
            guard let self = self, let frameRateRange = device.activeFrameRateRange else {
                return
            }
            self.delegate?.camera(self, didChangeFrameRateRange: frameRateRange)
        }
        let adjustingFocusKVO = device.observe(\.isAdjustingFocus, options: .new) { [weak self] device, _ in
            guard let self = self else {
                return
            }
            if device.isAdjustingFocus {
                self.delegate?.camera(self, didBeginAdjustingFocusAt: device.focusPointOfInterest)
            } else {
                self.delegate?.camera(self, didEndAdjustingFocusAt: device.focusPointOfInterest)
            }
        }
        let focusPointOfInterestKVO = device.observe(\.focusPointOfInterest, options: .new) { [weak self] device, _ in
            guard let self = self else {
                return
            }
            self.delegate?.camera(self, didChangeFocusPointOfInterest: device.focusPointOfInterest)
        }
        let focusModeKVO = device.observe(\.focusMode, options: .new) { [weak self] device, _ in
            guard let self = self else {
                return
            }
            self.delegate?.camera(self, didChangeFocusMode: device.focusMode)
        }
        
        keyValueObservations = [formatKVO, frameRateRangeKVO, adjustingFocusKVO, focusPointOfInterestKVO, focusModeKVO]
    }
    
    private func flipOptionsDidChange() {
        for output in session.outputs {
            output.connection(with: .video)?
                .flip(options: flipOptions)
        }
        
        for previewLayer in videoPreviewLayers.allObjects {
            previewLayer.connection?
                .flip(options: flipOptions)
        }
    }
    
    // MARK: - Configuration
    
    private func configureDevice(_ configure: () -> Void) -> Bool {
        do {
            try device.lockForConfiguration()
            configure()
            device.unlockForConfiguration()
            
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Session
    
    public func startRunning() {
        guard !isRunning else {
            return
        }
        
        session.startRunning()
    }
    
    public func stopRunning() {
        guard isRunning else {
            return
        }
        
        session.stopRunning()
    }
    
    public func canSetPreset(_ preset: AVCaptureSession.Preset) -> Bool {
        session.canSetSessionPreset(preset)
    }
    
    public func setPreset(_ preset: AVCaptureSession.Preset) {
        guard canSetPreset(preset) else {
            return
        }
        
        session.sessionPreset = preset
    }
    
    // MARK: - Input
    
    public func canAddInput(_ input: CameraInput) -> Bool {
        !inputs.contains(where: { $0 === input }) &&
        session.canAddInput(input.underlyingInput)
    }
    
    @discardableResult
    public func addInput(_ input: CameraInput) -> Bool {
        guard canAddInput(input) else {
            return false
        }
        
        session.addInput(input.underlyingInput)
        inputs.append(input)
        
        return true
    }
    
    @discardableResult
    public func removeInput(_ input: CameraInput) -> Bool {
        guard let index = inputs.firstIndex(where: { $0 === input }) else {
            return false
        }
        
        session.removeInput(input.underlyingInput)
        inputs.remove(at: index)
        
        return true
    }
    
    // MARK: - Output
    
    public func canAddOutput(_ output: CameraOutput) -> Bool {
        !outputs.contains(where: { $0 === output }) &&
        session.canAddOutput(output.underlyingOutput)
    }
    
    @discardableResult
    public func addOutput(_ output: CameraOutput) -> Bool {
        guard canAddOutput(output) else {
            return false
        }
        
        session.addOutput(output.underlyingOutput)
        outputs.append(output)
        
        if let connection = output.underlyingOutput.connection(with: .video) {
            connection.flip(options: flipOptions)
        }
        
        return true
    }
    
    @discardableResult
    public func removeOutput(_ output: CameraOutput) -> Bool {
        guard let index = inputs.firstIndex(where: { $0 === output }) else {
            return false
        }
        
        session.removeOutput(output.underlyingOutput)
        outputs.remove(at: index)
        
        return true
    }
    
    // MARK: - Device Settings
    
    @discardableResult
    public func setFormat(_ format: AVCaptureDevice.Format) -> Bool {
        guard device.activeFormat != format else {
            return true
        }
        
        return configureDevice {
            device.activeFormat = format
        }
    }
    
    @discardableResult
    public func setFrameRateRange(_ frameRateRange: AVFrameRateRange) -> Bool {
        guard device.activeFrameRateRange != frameRateRange else {
            return true
        }
        
        return configureDevice {
            device.activeVideoMinFrameDuration = frameRateRange.minFrameDuration
        }
    }
    
    // MARK: - Focus
    
    public func isFocusModeSupported(_ mode: AVCaptureDevice.FocusMode) -> Bool {
        device.isFocusModeSupported(mode)
    }
    
    @discardableResult
    public func setFocusPointOfInterest(_ poi: CGPoint) -> Bool {
        guard isFocusPointOfInterestSupported else {
            return false
        }
        
        return configureDevice {
            device.focusPointOfInterest = poi
        }
    }
    
    @discardableResult
    public func setFocusMode(_ mode: AVCaptureDevice.FocusMode) -> Bool {
        guard isFocusModeSupported(mode) else {
            return false
        }
        
        return configureDevice {
            device.focusMode = mode
        }
    }
    
    @discardableResult
    public func focus(at poi: CGPoint, mode: AVCaptureDevice.FocusMode) -> Bool {
        guard isFocusPointOfInterestSupported, isFocusModeSupported(mode) else {
            return false
        }
        
        return configureDevice {
            device.focusPointOfInterest = poi
            device.focusMode = mode
        }
    }
    
    #if os(iOS)
    public func setSmoothAutoFocusEnabled(_ enabled: Bool) -> Bool {
        guard isSmoothAutoFocusSupported else {
            return false
        }
        
        return configureDevice {
            device.isSmoothAutoFocusEnabled = enabled
        }
    }
    #endif
    
    // MARK: - Video Preview Layer
    
    public func makeVideoPreviewLayer() -> AVCaptureVideoPreviewLayer {
        let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
        
        videoPreviewLayer.connection?
            .flip(options: flipOptions)
        
        videoPreviewLayers.add(videoPreviewLayer)
        
        return videoPreviewLayer
    }
    
}
