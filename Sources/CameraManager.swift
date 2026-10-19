import Cocoa
import AVFoundation
import SwiftUI

class CameraManager: ObservableObject {
    static let shared = CameraManager()
    
    @Published var isRunning: Bool = false
    @Published var hasPermission: Bool = false
    @Published var permissionDenied: Bool = false
    
    let session = AVCaptureSession()
    private var isConfigured: Bool = false
    
    init() {
        checkPermission()
    }
    
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            hasPermission = true
            permissionDenied = false
            configureSessionIfNeeded()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.hasPermission = granted
                    self?.permissionDenied = !granted
                    if granted {
                        self?.configureSessionIfNeeded()
                    }
                }
            }
        case .denied, .restricted:
            hasPermission = false
            permissionDenied = true
        @unknown default:
            hasPermission = false
        }
    }
    
    func configureSessionIfNeeded() {
        guard !isConfigured else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            self.session.sessionPreset = .high
            
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) ??
                            AVCaptureDevice.default(for: .video),
               let input = try? AVCaptureDeviceInput(device: device),
               self.session.canAddInput(input) {
                self.session.addInput(input)
                self.isConfigured = true
            }
            
            self.session.commitConfiguration()
        }
    }
    
    func start() {
        guard !session.isRunning else { return }
        checkPermission()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            if self.isConfigured {
                self.session.startRunning()
                DispatchQueue.main.async {
                    self.isRunning = true
                }
            }
        }
    }
    
    func stop() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.session.stopRunning()
            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }
}

struct CameraPreviewView: NSViewRepresentable {
    func makeNSView(context: Context) -> CameraPreviewNSView {
        let view = CameraPreviewNSView()
        view.videoLayer.session = CameraManager.shared.session
        return view
    }
    
    func updateNSView(_ nsView: CameraPreviewNSView, context: Context) {}
}

class CameraPreviewNSView: NSView {
    let videoLayer = AVCaptureVideoPreviewLayer()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayer()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }
    
    private func setupLayer() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        videoLayer.videoGravity = .resizeAspectFill
        if let conn = videoLayer.connection, conn.isVideoMirroringSupported {
            conn.automaticallyAdjustsVideoMirroring = false
            conn.isVideoMirrored = true
        }
        layer?.addSublayer(videoLayer)
    }
    
    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        videoLayer.frame = bounds
        if let conn = videoLayer.connection, conn.isVideoMirroringSupported {
            conn.automaticallyAdjustsVideoMirroring = false
            conn.isVideoMirrored = true
        }
        CATransaction.commit()
    }
}
