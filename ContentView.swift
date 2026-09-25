import SwiftUI
import Combine
import AVFoundation
import Photos
import PhotosUI
import CoreLocation
import ImageIO
import UniformTypeIdentifiers
import AudioToolbox
import UIKit
import CoreMotion
import CallKit
import MediaPlayer
import AVKit

// MARK: - App Main
@main
struct GlassCameraApp: App {
    var body: some Scene {
        WindowGroup {
            CameraMainView()
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Haptic Manager
class HapticManager {
    static let shared = HapticManager()
    
    private let peek = SystemSoundID(1519)
    private let pop = SystemSoundID(1520)
    
    func playPhoto(isSoundOn: Bool) {
        if isSoundOn {
            AudioServicesPlaySystemSound(1108)
            DispatchQueue.main.async {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        } else {
            AudioServicesPlaySystemSound(peek)
        }
    }
    
    func playVideoStart(isSoundOn: Bool) {
        if isSoundOn {
            AudioServicesPlaySystemSound(1117)
            DispatchQueue.main.async {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
        } else {
            AudioServicesPlaySystemSound(pop)
        }
    }
    
    func playVideoStop(isSoundOn: Bool) {
        if isSoundOn {
            AudioServicesPlaySystemSound(1118)
            DispatchQueue.main.async {
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.impactOccurred()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    generator.impactOccurred()
                }
            }
        } else {
            AudioServicesPlaySystemSound(peek)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                AudioServicesPlaySystemSound(self.peek)
            }
        }
    }
    
    func playExit() {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
    
    func playTimerTick() {
        AudioServicesPlaySystemSound(peek)
    }
}

// MARK: - Main View
struct CameraMainView: View {
    @StateObject private var camera = CameraManager()
    @Namespace private var topBarNamespace
    @AppStorage("onboardingStep") private var onboardingStep = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                HiddenVolumeView().frame(width: 0, height: 0)
                
                Group {
                    if camera.frameRatioIndex == 0 {
                        CameraPreview(camera: camera)
                            .overlay(
                                Group {
                                    if let focusPoint = camera.focusPoint {
                                        Rectangle()
                                            .stroke(Color.yellow, lineWidth: 1.5)
                                            .frame(width: 70, height: 70)
                                            .scaleEffect(camera.focusBoxScale)
                                            .opacity(camera.focusBoxOpacity)
                                            .position(focusPoint)
                                            .allowsHitTesting(false)
                                    }
                                }
                            )
                            .ignoresSafeArea()
                    } else {
                        CameraPreview(camera: camera)
                            .overlay(
                                Group {
                                    if let focusPoint = camera.focusPoint {
                                        Rectangle()
                                            .stroke(Color.yellow, lineWidth: 1.5)
                                            .frame(width: 70, height: 70)
                                            .scaleEffect(camera.focusBoxScale)
                                            .opacity(camera.focusBoxOpacity)
                                            .position(focusPoint)
                                            .allowsHitTesting(false)
                                    }
                                }
                            )
                            .aspectRatio(camera.frameRatioIndex == 1 ? 3.0/4.0 : 1.0, contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .saturation(camera.filterIndex == 1 ? 0.0 : (camera.filterIndex == 2 ? 0.5 : 1.0))
                .colorMultiply(camera.filterIndex == 2 ? Color(red: 1.1, green: 0.95, blue: 0.8) : .white)
                .blur(radius: camera.isChangingQuality ? 15 : 0)
                .overlay(Color.black.opacity(camera.isChangingQuality ? 0.4 : 0).ignoresSafeArea())
                .animation(.easeInOut(duration: 0.3), value: camera.isChangingQuality)
                
                if let message = camera.floatingMessage, !camera.isBlackoutMode {
                    VStack {
                        Text(message)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 28)
                            .glassEffect(.regular.interactive(), in: .capsule)
                            .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.9)),
                        removal: .opacity.combined(with: .scale(scale: 1.05))
                    ))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: camera.floatingMessage)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 200)
                    .zIndex(10)
                }
                
                VStack {
                    HStack(spacing: 6) {
                        let commonHeight: CGFloat = 36
                        let horizontalPadding: CGFloat = 12
                        
                        GlassEffectContainer(spacing: 0) {
                            HStack(spacing: 6) {
                                Image(systemName: "timer")
                                    .font(.system(size: 13))
                                Text(camera.timerIndex == 0 ? "꺼짐" : (camera.timerIndex == 1 ? "3초" : "10초"))
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .frame(height: commonHeight)
                            .padding(.horizontal, horizontalPadding)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    camera.timerIndex = (camera.timerIndex + 1) % 3
                                }
                            }
                        }
                        .glassEffect(.regular.interactive(), in: .capsule)
                        
                        GlassEffectContainer(spacing: 0) {
                            HStack(spacing: 6) {
                                Image(systemName: camera.flashMode == 0 ? "bolt.slash.fill" : "bolt.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(camera.flashMode == 1 ? .yellow : nil)
                            }
                            .frame(height: commonHeight)
                            .padding(.horizontal, horizontalPadding)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    camera.flashMode = (camera.flashMode + 1) % 2
                                }
                            }
                        }
                        .glassEffect(.regular.interactive(), in: .capsule)
                        
                        GlassEffectContainer(spacing: 0) {
                            HStack(spacing: 6) {
                                Image(systemName: "plusminus.circle")
                                    .font(.system(size: 14))
                                Text(camera.exposureText)
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .frame(height: commonHeight)
                            .padding(.horizontal, horizontalPadding)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    camera.cycleExposure()
                                }
                            }
                        }
                        .glassEffect(.regular.interactive(), in: .capsule)
                        
                        Spacer()
                        
                        GlassEffectContainer(spacing: 0) {
                            HStack(spacing: 6) {
                                Text("절전")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(camera.isBlackoutMode ? .red : nil)
                                
                                Toggle("", isOn: $camera.isBlackoutMode)
                                    .labelsHidden()
                                    .tint(.red)
                                    .scaleEffect(0.8)
                                    .frame(width: 45)
                            }
                            .frame(height: commonHeight)
                            .padding(.horizontal, horizontalPadding)
                        }
                        .glassEffect(.regular, in: .capsule)
                        
                        GlassEffectContainer(spacing: 0) {
                            HStack(spacing: 8) {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 14))
                            }
                            .frame(height: commonHeight)
                            .padding(.horizontal, horizontalPadding)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                camera.showSettings = true
                            }
                        }
                        .glassEffect(.regular.interactive(), in: .capsule)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    
                    Spacer()
                    
                    if camera.availableZoomFactors.count > 1 {
                        HStack(spacing: 15) {
                            let activeFactor = camera.availableZoomFactors.sorted().filter { camera.currentZoomFactor >= ($0 - 0.01) }.last ?? camera.availableZoomFactors.first ?? 1.0

                            ForEach(camera.availableZoomFactors, id: \.self) { factor in
                                let isActive = (factor == activeFactor)
                                Button(action: {
                                    HapticManager.shared.playTimerTick()
                                    camera.setZoom(factor)
                                }) {
                                    Text(isActive ? String(format: "%.1fx", camera.currentZoomFactor) : (factor == 0.5 ? "0.5x" : String(format: "%.0fx", factor)))
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(isActive ? .yellow : nil)                                        .frame(width: 40, height: 40)
                                        .glassEffect(.regular.interactive(), in: .circle)
                                        .contentShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.bottom, 12)
                    } else {
                        Button(action: {
                            HapticManager.shared.playTimerTick()
                            camera.cycleZoom()
                        }) {
                            Text(String(format: "%.1fx", camera.currentZoomFactor))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .glassEffect(.regular.interactive(), in: .circle)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 10)
                    }
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 32)
                            .fill(Color.clear)
                            .glassEffect(.clear, in: .rect(cornerRadius: 32))
                            .shadow(color: Color.black.opacity(0.2), radius: 25, y: 15)
                        
                        HStack(alignment: .center) {
                            HStack(spacing: 6) {
                                if camera.showPreview {
                                    Button(action: {
                                        if camera.latestPhoto != nil {
                                            camera.showPhotoPreviewSheet = true
                                        }
                                    }) {
                                        Group {
                                            if let img = camera.latestPhoto {
                                                Image(uiImage: img)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 36, height: 36)
                                                    .clipShape(Circle())
                                            } else {
                                                Image(systemName: "photo")
                                                    .font(.title2)
                                            }
                                        }
                                        .frame(width: 64, height: 54)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .glassEffect(.regular.interactive(), in: .capsule)
                                    .transition(.scale)
                                }
                                
                                Button(action: { camera.switchCamera() }) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.title2.weight(.medium))
                                        .frame(width: 64, height: 54)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .glassEffect(.regular.interactive(), in: .capsule)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Button(action: {
                                camera.takePhoto()
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.05))
                                        .frame(width: 72, height: 72)
                                        .glassEffect(.regular.interactive(), in: .circle)
                                    
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 56, height: 56)
                                    
                                    Circle()
                                        .stroke(Color.white.opacity(0.8), lineWidth: 2)
                                        .frame(width: 72, height: 72)
                                }
                                .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                            
                            HStack(spacing: 6) {
                                Button(action: {
                                    camera.toggleRecording()
                                }) {
                                    Image(systemName: camera.isRecording ? "stop.fill" : "record.circle")
                                        .font(.title2.weight(.bold))
                                        .foregroundColor(camera.isRecording ? .red : nil)
                                        .frame(width: 64, height: 54)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .glassEffect(.regular.interactive(), in: .capsule)
                                
                                Menu {
                                    Button(action: { camera.filterIndex = 0 }) {
                                        Text("원본")
                                        if camera.filterIndex == 0 { Image(systemName: "checkmark") }
                                    }
                                    Button(action: { camera.filterIndex = 1 }) {
                                        Text("흑백")
                                        if camera.filterIndex == 1 { Image(systemName: "checkmark") }
                                    }
                                    Button(action: { camera.filterIndex = 2 }) {
                                        Text("세피아")
                                        if camera.filterIndex == 2 { Image(systemName: "checkmark") }
                                    }
                                } label: {
                                    Image(systemName: "camera.filters")
                                        .font(.title2.weight(.medium))
                                        .foregroundColor(.white)
                                        .frame(width: 64, height: 54)
                                        .contentShape(Rectangle())
                                }
                                .glassEffect(.regular.interactive(), in: .capsule)
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding(12)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                
                if camera.isBlackoutMode {
                    Color.black
                        .ignoresSafeArea()
                        .zIndex(100)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            HapticManager.shared.playPhoto(isSoundOn: camera.isShutterSoundOn)
                            camera.takePhoto()
                        }
                        .onLongPressGesture(minimumDuration: 0.5) {
                            if camera.isRecording {
                                HapticManager.shared.playVideoStop(isSoundOn: camera.isShutterSoundOn)
                            } else {
                                HapticManager.shared.playVideoStart(isSoundOn: camera.isShutterSoundOn)
                            }
                            camera.toggleRecording()
                        }
                        .gesture(
                            DragGesture(minimumDistance: 50)
                                .onEnded { value in
                                    if value.translation.height > 50 {
                                        HapticManager.shared.playExit()
                                        camera.isBlackoutMode = false
                                    }
                                }
                        )
                }
                
                if camera.isRecording {
                    VStack {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                            
                            Text(camera.formattedRecordingDuration)
                                .font(.system(size: 13, weight: .bold).monospacedDigit())
                                .foregroundColor(.white)
                        }
                        .frame(height: 36)
                        .padding(.horizontal, 12)
                        .glassEffect(.regular.interactive(), in: .capsule)
                        .padding(.top, 55)
                        
                        Spacer()
                    }
                    .zIndex(15)
                }
                
                if camera.isOnCall {
                    ZStack {
                        Color.black.ignoresSafeArea()
                        VStack(spacing: 20) {
                            Image(systemName: "phone.down.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.red)
                            Text("통화 중에는 카메라 사용이 제한됩니다.")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    .zIndex(2000)
                }
                
                if onboardingStep < 4 {
                    OnboardingOverlayView(step: $onboardingStep, camera: camera)
                        .zIndex(1000)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .alert("절전 모드 안내", isPresented: $camera.showBlackoutAlert) {
                Button("확인", role: .cancel) { }
            } message: {
                Text("절전 모드를 켜더라도 시스템의 카메라, 마이크, 위치 등 권한 사용 표시는 유지됩니다. 이를 통해 촬영 중임을 인지할 수 있습니다.\n\n화면을 가볍게 탭하여 사진을, 길게 눌러 영상을 촬영할 수 있습니다. 위에서 아래로 스와이프하여 해제하세요.")
            }
            .statusBarHidden(camera.isBlackoutMode)
            .onChange(of: geometry.size) {
                camera.deviceOrientationDidChange()
            }
        }
        .sheet(item: $camera.shareURL) { shareItem in
            ShareSheet(items: [shareItem.url])
        }
        .sheet(isPresented: $camera.showSettings) {
            CameraSettingsView(camera: camera)
                .preferredColorScheme(.dark)
        }
        .fullScreenCover(isPresented: $camera.showPhotoPreviewSheet) {
            PhotoPreviewSheet(camera: camera)
        }
    }
}

// MARK: - Capture Item
struct CaptureItem: Identifiable {
    let id = UUID()
    let url: URL
    let isVideo: Bool
    var thumbnail: UIImage?
    var localIdentifier: String?
}

// MARK: - Share Item
struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Camera Manager
class CameraManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isShareOn: Bool = UserDefaults.standard.bool(forKey: "isShareOn") {
        didSet {
            guard oldValue != isShareOn else { return }
            UserDefaults.standard.set(isShareOn, forKey: "isShareOn")
        }
    }
    @Published var qualityIndex: Int = UserDefaults.standard.object(forKey: "qualityIndex") as? Int ?? 1 {
        didSet {
            guard oldValue != qualityIndex else { return }
            UserDefaults.standard.set(qualityIndex, forKey: "qualityIndex")
            updateSessionPresetAsync()
        }
    }
    @Published var fpsIndex: Int = UserDefaults.standard.object(forKey: "fpsIndex") as? Int ?? 0 {
        didSet {
            guard oldValue != fpsIndex else { return }
            UserDefaults.standard.set(fpsIndex, forKey: "fpsIndex")
            updateSessionPresetAsync()
        }
    }
    @Published var isShutterSoundOn: Bool = UserDefaults.standard.object(forKey: "isShutterSoundOn") as? Bool ?? true {
        didSet {
            guard oldValue != isShutterSoundOn else { return }
            UserDefaults.standard.set(isShutterSoundOn, forKey: "isShutterSoundOn")
        }
    }
    @Published var volumeButtonAction: Int = UserDefaults.standard.object(forKey: "volumeButtonAction") as? Int ?? 2 {
        didSet {
            guard oldValue != volumeButtonAction else { return }
            UserDefaults.standard.set(volumeButtonAction, forKey: "volumeButtonAction")
        }
    }
    
    @Published var showSettings = false
    @Published var showPhotoPreviewSheet = false
    
    @Published var isAutoFocusOn: Bool = UserDefaults.standard.object(forKey: "isAutoFocusOn") as? Bool ?? true {
        didSet {
            guard oldValue != isAutoFocusOn else { return }
            UserDefaults.standard.set(isAutoFocusOn, forKey: "isAutoFocusOn")
            updateAutoFocus()
        }
    }
    @Published var frameRatioIndex: Int = UserDefaults.standard.object(forKey: "frameRatioIndex") as? Int ?? 1 {
        didSet {
            guard oldValue != frameRatioIndex else { return }
            UserDefaults.standard.set(frameRatioIndex, forKey: "frameRatioIndex")
            updateSessionPresetAsync()
        }
    }
    @Published var showPreview: Bool = UserDefaults.standard.object(forKey: "showPreview") as? Bool ?? true {
        didSet {
            guard oldValue != showPreview else { return }
            UserDefaults.standard.set(showPreview, forKey: "showPreview")
        }
    }
    @Published var isTimeStampOn: Bool = UserDefaults.standard.bool(forKey: "isTimeStampOn") {
        didSet {
            guard oldValue != isTimeStampOn else { return }
            UserDefaults.standard.set(isTimeStampOn, forKey: "isTimeStampOn")
        }
    }
    
    @Published var filterIndex: Int = 0
    @Published var latestPhoto: UIImage? = nil
    @Published var capturedItems: [CaptureItem] = []
    var assetIdentifiers: [URL: String] = [:]
    
    @Published var showBlackoutAlert = false
    @Published var isBlackoutMode = false {
        didSet {
            if isBlackoutMode && !oldValue {
                showBlackoutAlert = true
            }
        }
    }
    
    @Published var floatingMessage: String? = nil
    @Published var shareURL: ShareItem?
    @Published var isChangingQuality = false
    
    @Published var timerIndex: Int = 0
    @Published var flashMode: Int = 0
    @Published var exposureIndex: Int = 2
    @Published var currentZoomFactor: CGFloat = 1.0
    @Published var availableZoomFactors: [CGFloat] = [1.0]
    
    @Published var isOnCall = false
    private let callObserver = CXCallObserver()
    
    @Published var recordingDuration: TimeInterval = 0
    private var recordingTimer: Timer?
    
    var formattedRecordingDuration: String {
        let hours = Int(recordingDuration) / 3600
        let minutes = (Int(recordingDuration) % 3600) / 60
        let seconds = Int(recordingDuration) % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private var volumeObserver: NSKeyValueObservation?
    private var lastVolumePressTime = Date()
    private var lastVolume: Float = 0.5
    
    var exposureText: String {
        let biases: [Float] = [-2.0, -1.0, 0.0, 1.0, 2.0]
        let bias = biases[exposureIndex]
        if bias > 0 { return "+\(Int(bias))" }
        else if bias < 0 { return "\(Int(bias))" }
        else { return "0" }
    }
    
    @Published var isTimerRunning: Bool = false
    private var countdown: Int = 0
    
    @Published var focusPoint: CGPoint? = nil
    @Published var focusBoxScale: CGFloat = 1.0
    @Published var focusBoxOpacity: Double = 0.0
    private var focusTimer: Timer?
    
    let captureSession = AVCaptureSession()
    let previewLayer = AVCaptureVideoPreviewLayer()
    
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let audioDataOutput = AVCaptureAudioDataOutput()
    
    private var assetWriter: AVAssetWriter?
    private var videoWriterInput: AVAssetWriterInput?
    private var audioWriterInput: AVAssetWriterInput?
    private var isWriting = false
    private var sessionAtSourceTime: CMTime?
    private var currentVideoURL: URL?
    private let writerLock = NSLock()
    
    private let captureLock = NSLock()
    private var _isTakingPicture = false
    private var isTakingPicture: Bool {
        get {
            captureLock.lock()
            defer { captureLock.unlock() }
            return _isTakingPicture
        }
        set {
            captureLock.lock()
            _isTakingPicture = newValue
            captureLock.unlock()
        }
    }
    
    private var isBackCamera = true
    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation?
    private var messageTimer: Timer?
    
    private var lastValidOrientation: UIDeviceOrientation = .portrait
    private var lastUIOrientation: UIInterfaceOrientation = .portrait
    private let motionManager = CMMotionManager()
    private var trueDeviceOrientation: UIDeviceOrientation = .portrait
    
    private let sessionQueue = DispatchQueue(label: "cameraSessionQueue")
    
    private let ciContext = CIContext()
    private var cachedScreenRatio: CGFloat = 19.5 / 9.0
    private var isAppActive: Bool = true
    private var backgroundRecordingID: UIBackgroundTaskIdentifier = .invalid
    
    private var initialPinchZoomFactor: CGFloat = 1.0
    private var _targetAVZoom: CGFloat? = nil
    private var _isApplyingZoom: Bool = false
    private let zoomLock = NSLock()
    
    override init() {
        super.init()
        
        clearTempFolder()
        
        previewLayer.session = captureSession
        
        callObserver.setDelegate(self, queue: .main)
        isOnCall = callObserver.calls.contains { !$0.hasEnded }
        
        if UserDefaults.standard.integer(forKey: "onboardingStep") >= 4 {
            checkPermissions()
            setupLocationManager()
        }
        
        setupMotionManager()
        
        lastVolume = AVAudioSession.sharedInstance().outputVolume
        volumeObserver = AVAudioSession.sharedInstance().observe(\.outputVolume, options: [.new]) { [weak self] session, change in
            guard let self = self, let newVolume = change.newValue else { return }
            DispatchQueue.main.async {
                guard self.isAppActive else {
                    self.lastVolume = newVolume
                    return
                }
                
                let isUp = newVolume > self.lastVolume
                let isDown = newVolume < self.lastVolume
                
                if isUp || isDown {
                    self.handleVolumeButtonPress(isUp: isUp)
                } else if newVolume == 1.0 || newVolume == 0.0 {
                    self.handleVolumeButtonPress(isUp: true)
                }
                
                self.lastVolume = newVolume
            }
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAudioInterruption(_:)), name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance())
        NotificationCenter.default.addObserver(self, selector: #selector(handleAudioRouteChange(_:)), name: AVAudioSession.routeChangeNotification, object: AVAudioSession.sharedInstance())
        NotificationCenter.default.addObserver(self, selector: #selector(handleSessionInterruption(_:)), name: AVCaptureSession.wasInterruptedNotification, object: captureSession)
        
        DispatchQueue.main.async {
            let bounds = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.screen.bounds ?? CGRect(x: 0, y: 0, width: 393, height: 852)
            self.cachedScreenRatio = max(bounds.width, bounds.height) / min(bounds.width, bounds.height)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        motionManager.stopAccelerometerUpdates()
        messageTimer?.invalidate()
        focusTimer?.invalidate()
        recordingTimer?.invalidate()
    }
    
    @objc private func handleAudioInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        if type == .began {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if self.isRecording {
                    self.stopRecording()
                }
            }
        } else if type == .ended {
            sessionQueue.async { [weak self] in
                self?.setupAudioSession()
            }
        }
    }
    
    @objc private func handleAudioRouteChange(_ notification: Notification) {
        if isRecording {
            sessionQueue.async { [weak self] in
                self?.setupAudioSession()
            }
        }
    }
    
    @objc private func handleSessionInterruption(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.isRecording {
                self.stopRecording()
            }
        }
    }
    
    @objc private func appWillResignActive() {
        isAppActive = false
        if isRecording {
            beginSaveBackgroundTask()
            stopRecording()
        }
    }
    
    @objc private func appWillEnterForeground() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.setupAudioSession()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            self.isAppActive = true
            self.lastVolume = AVAudioSession.sharedInstance().outputVolume
        }
    }
    
    private func beginSaveBackgroundTask() {
        DispatchQueue.main.async {
            if self.backgroundRecordingID == .invalid {
                self.backgroundRecordingID = UIApplication.shared.beginBackgroundTask(withName: "VideoSaveTask") {
                    self.endSaveBackgroundTask()
                }
            }
        }
    }
    
    private func endSaveBackgroundTask() {
        DispatchQueue.main.async {
            if self.backgroundRecordingID != .invalid {
                UIApplication.shared.endBackgroundTask(self.backgroundRecordingID)
                self.backgroundRecordingID = .invalid
            }
        }
    }
    
    private func clearTempFolder() {
        DispatchQueue.global(qos: .background).async {
            let tempPath = NSTemporaryDirectory()
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: tempPath) {
                for file in contents where file.hasPrefix("Captured_") || file.hasPrefix("video_") {
                    let filePath = URL(fileURLWithPath: tempPath).appendingPathComponent(file)
                    try? FileManager.default.removeItem(at: filePath)
                }
            }
        }
    }
    
    private func getBestBackCamera() -> AVCaptureDevice? {
        let deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera]
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: .video, position: .back)
        return discoverySession.devices.first
    }
    
    private func setupMotionManager() {
        motionManager.accelerometerUpdateInterval = 0.2
        if motionManager.isAccelerometerAvailable {
            motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
                guard let data = data else { return }
                self?.updateTrueOrientation(from: data.acceleration)
            }
        }
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(self, selector: #selector(deviceOrientationDidChange), name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    private func updateTrueOrientation(from acceleration: CMAcceleration) {
        let x = acceleration.x
        let y = acceleration.y
        
        var newOrientation = trueDeviceOrientation
        if abs(x) > abs(y) {
            if x > 0.5 { newOrientation = .landscapeRight }
            else if x < -0.5 { newOrientation = .landscapeLeft }
        } else {
            if y < -0.5 { newOrientation = .portrait }
            else if y > 0.5 { newOrientation = .portraitUpsideDown }
        }
        
        if newOrientation != trueDeviceOrientation {
            trueDeviceOrientation = newOrientation
            deviceOrientationDidChange()
        }
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .videoRecording, options: [.defaultToSpeaker, .mixWithOthers])
            try audioSession.setAllowHapticsAndSystemSoundsDuringRecording(true)
            try audioSession.setActive(true)
        } catch {}
    }
    
    func handleVolumeButtonPress(isUp: Bool) {
        guard Date().timeIntervalSince(lastVolumePressTime) > 0.4 else { return }
        lastVolumePressTime = Date()
        
        if volumeButtonAction == 0 {
            if isRecording {
                toggleRecording()
            } else {
                takePhoto()
            }
        } else if volumeButtonAction == 1 {
            zoomStep(isZoomIn: isUp)
        }
    }
    
    func zoomStep(isZoomIn: Bool) {
        let step: CGFloat = isZoomIn ? 1.1 : (1.0 / 1.1)
        var newZoom = currentZoomFactor * step
        
        guard let device = videoDeviceInput?.device else { return }
        
        let isUltraWideBase = (device.deviceType == .builtInTripleCamera || device.deviceType == .builtInDualWideCamera)
        let baseZoom: CGFloat = isUltraWideBase ? 0.5 : 1.0
        
        let minUIZoom: CGFloat = availableZoomFactors.first ?? baseZoom
        let maxAVZoom = min(device.activeFormat.videoMaxZoomFactor, 10.0)
        let maxUIZoom = maxAVZoom * baseZoom
        
        newZoom = max(minUIZoom, min(newZoom, maxUIZoom))
        setZoom(newZoom)
    }
    
    private func showFloatingAlert(_ text: String) {
        guard !isBlackoutMode else { return }
        DispatchQueue.main.async {
            self.messageTimer?.invalidate()
            withAnimation { self.floatingMessage = text }
            self.messageTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                withAnimation { self.floatingMessage = nil }
            }
        }
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func checkPermissions() {
        let videoStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        
        if videoStatus == .authorized && audioStatus == .authorized {
            setupCamera()
        } else {
            AVCaptureDevice.requestAccess(for: .video) { videoGranted in
                AVCaptureDevice.requestAccess(for: .audio) { audioGranted in
                    if videoGranted {
                        DispatchQueue.main.async { self.setupCamera() }
                    }
                }
            }
        }
    }
    
    func requestPermissionsForOnboarding(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { videoGranted in
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                let handler: (PHAuthorizationStatus) -> Void = { status in
                    DispatchQueue.main.async {
                        if videoGranted {
                            self.setupCamera()
                            self.setupLocationManager()
                        }
                        completion(videoGranted && (status == .authorized || status == .limited))
                    }
                }
                
                PHPhotoLibrary.requestAuthorization(for: .readWrite, handler: handler)
            }
        }
    }
    
    private func applyOrientationConfiguration(uiOrientation: UIInterfaceOrientation, captureDeviceOrientation: UIDeviceOrientation) {
        let uiRotationAngle: CGFloat
        switch uiOrientation {
        case .portrait: uiRotationAngle = 90.0
        case .portraitUpsideDown: uiRotationAngle = 270.0
        case .landscapeLeft: uiRotationAngle = 180.0
        case .landscapeRight: uiRotationAngle = 0.0
        default: uiRotationAngle = 90.0
        }
        
        if let videoConnection = self.videoDataOutput.connection(with: .video), videoConnection.isVideoRotationAngleSupported(uiRotationAngle) {
            videoConnection.videoRotationAngle = uiRotationAngle
        }
        if let previewConnection = self.previewLayer.connection, previewConnection.isVideoRotationAngleSupported(uiRotationAngle) {
            previewConnection.videoRotationAngle = uiRotationAngle
        }
    }
    
    private func setupCamera() {
        let currentRatio = self.frameRatioIndex
        let currentQuality = self.qualityIndex
        let isAuto = self.isAutoFocusOn
        let expIndex = self.exposureIndex
        let currentFpsIndex = self.fpsIndex
        
        var currentDeviceOrientation = motionManager.isAccelerometerAvailable ? trueDeviceOrientation : UIDevice.current.orientation
        if currentDeviceOrientation == .faceUp || currentDeviceOrientation == .faceDown || currentDeviceOrientation == .unknown {
            currentDeviceOrientation = lastValidOrientation
        } else {
            lastValidOrientation = currentDeviceOrientation
        }
        var uiOrientation: UIInterfaceOrientation = .portrait
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            uiOrientation = scene.effectiveGeometry.interfaceOrientation
        }
        self.lastUIOrientation = uiOrientation
        let captureDeviceOrientation = currentDeviceOrientation
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            guard !self.captureSession.isRunning else { return }
            
            self.captureSession.automaticallyConfiguresApplicationAudioSession = false
            self.setupAudioSession()
            self.captureSession.beginConfiguration()
            
            guard let backCamera = self.getBestBackCamera(),
                  let videoInput = try? AVCaptureDeviceInput(device: backCamera) else {
                self.captureSession.commitConfiguration()
                return
            }
            
            self.videoDeviceInput = videoInput
            if self.captureSession.canAddInput(videoInput) { self.captureSession.addInput(videoInput) }
            
            self.applyQualityAndFrameRate(ratioIndex: currentRatio, qualityIndex: currentQuality, fpsIndex: currentFpsIndex)
            self.internalUpdateAutoFocus(isAuto: isAuto)
            self.internalApplyExposureBias(index: expIndex)
            
            let hasAudio = self.captureSession.inputs.contains { input in
                return input.ports.contains { $0.mediaType == .audio }
            }
            if !hasAudio, let audioDevice = AVCaptureDevice.default(for: .audio),
               let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
               self.captureSession.canAddInput(audioInput) {
                self.captureSession.addInput(audioInput)
            }
            
            let videoQueue = DispatchQueue(label: "videoQueue", qos: .userInteractive)
            self.videoDataOutput.setSampleBufferDelegate(self, queue: videoQueue)
            self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
            
            if self.captureSession.canAddOutput(self.videoDataOutput) { self.captureSession.addOutput(self.videoDataOutput) }
            
            self.audioDataOutput.setSampleBufferDelegate(self, queue: videoQueue)
            if self.captureSession.canAddOutput(self.audioDataOutput) { self.captureSession.addOutput(self.audioDataOutput) }
            
            if let videoConnection = self.videoDataOutput.connection(with: .video), videoConnection.isVideoStabilizationSupported {
                videoConnection.preferredVideoStabilizationMode = .off
            }
            
            self.applyOrientationConfiguration(uiOrientation: uiOrientation, captureDeviceOrientation: captureDeviceOrientation)
            
            self.captureSession.commitConfiguration()
            
            self.updateCameraZoomFactors(camera: backCamera)
            
            self.captureSession.startRunning()
        }
    }
    
    private func applyQualityAndFrameRate(ratioIndex: Int, qualityIndex: Int, fpsIndex: Int) {
        guard let device = videoDeviceInput?.device else { return }
        let targetFPS: Double = fpsIndex == 1 ? 60.0 : 30.0
        let isHighQuality = (qualityIndex == 1) && !(ratioIndex == 0 && fpsIndex == 1)
        let want4by3 = (ratioIndex != 0)
        
        var bestFormat: AVCaptureDevice.Format?
        var maxRes = 0
        
        for format in device.formats {
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            let width = Int(dimensions.width)
            let height = Int(dimensions.height)
            let ratio = Double(max(width, height)) / Double(min(width, height))
            
            let is16by9 = abs(ratio - (16.0 / 9.0)) < 0.1
            let is4by3 = abs(ratio - (4.0 / 3.0)) < 0.1
            
            if want4by3 && !is4by3 { continue }
            if !want4by3 && !is16by9 { continue }
            
            let supportsFPS = format.videoSupportedFrameRateRanges.contains { $0.maxFrameRate >= targetFPS }
            if !supportsFPS { continue }
            
            let resolution = width * height
            
            if isHighQuality {
                if resolution > maxRes {
                    maxRes = resolution
                    bestFormat = format
                }
            } else {
                if max(width, height) == 1920 {
                    bestFormat = format
                    break
                } else if bestFormat == nil {
                    bestFormat = format
                }
            }
        }
        
        if bestFormat == nil {
            for format in device.formats {
                let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                let width = Int(dimensions.width)
                let height = Int(dimensions.height)
                
                let supportsFPS = format.videoSupportedFrameRateRanges.contains { $0.maxFrameRate >= targetFPS }
                if !supportsFPS { continue }
                
                let resolution = width * height
                
                if isHighQuality {
                    if resolution > maxRes {
                        maxRes = resolution
                        bestFormat = format
                    }
                } else {
                    if max(width, height) == 1920 {
                        bestFormat = format
                        break
                    } else if bestFormat == nil {
                        bestFormat = format
                    }
                }
            }
        }
        
        if bestFormat != nil {
            if captureSession.canSetSessionPreset(.inputPriority) {
                captureSession.sessionPreset = .inputPriority
            }
        } else {
            if isHighQuality {
                if want4by3 && captureSession.canSetSessionPreset(.photo) {
                    captureSession.sessionPreset = .photo
                } else if captureSession.canSetSessionPreset(.hd4K3840x2160) {
                    captureSession.sessionPreset = .hd4K3840x2160
                } else if captureSession.canSetSessionPreset(.hd1920x1080) {
                    captureSession.sessionPreset = .hd1920x1080
                }
            } else {
                if captureSession.canSetSessionPreset(.hd1920x1080) {
                    captureSession.sessionPreset = .hd1920x1080
                }
            }
        }
        
        do {
            try device.lockForConfiguration()
            
            if let format = bestFormat {
                device.activeFormat = format
            }
            
            let activeFormat = device.activeFormat
            if let range = activeFormat.videoSupportedFrameRateRanges.first(where: { $0.maxFrameRate >= targetFPS }) ?? activeFormat.videoSupportedFrameRateRanges.last {
                let fps = min(targetFPS, range.maxFrameRate)
                device.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(fps))
                device.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(fps))
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Failed to set format: \(error)")
        }
    }
    
    private func updateCameraZoomFactors(camera: AVCaptureDevice) {
        var factors: [CGFloat] = []
        let isUltraWideBase = (camera.deviceType == .builtInTripleCamera || camera.deviceType == .builtInDualWideCamera)
        let baseZoom: CGFloat = isUltraWideBase ? 0.5 : 1.0
        
        let switchOvers = camera.virtualDeviceSwitchOverVideoZoomFactors

        if !switchOvers.isEmpty {
            factors.append(baseZoom)
            for switchOver in switchOvers {
                let avFactor = CGFloat(switchOver.floatValue)
                factors.append(avFactor * baseZoom)
            }
        } else {
            if camera.deviceType == .builtInTripleCamera {
                factors = [0.5, 1.0, 2.0]
            } else if camera.deviceType == .builtInDualWideCamera {
                factors = [0.5, 1.0]
            } else if camera.deviceType == .builtInDualCamera {
                factors = [1.0, 2.0]
            } else {
                factors = [1.0]
                if camera.maxAvailableVideoZoomFactor >= 2.0 {
                    factors.append(2.0)
                }
            }
        }
        
        let minAV = camera.minAvailableVideoZoomFactor
        let maxAV = camera.maxAvailableVideoZoomFactor
        
        factors = factors.filter {
            let avF = $0 / baseZoom
            return avF >= minAV && avF <= maxAV
        }
        
        if factors.isEmpty { factors = [1.0] }
        
        let initialUIZoom = factors.contains(1.0) ? 1.0 : factors[0]
        let initialAVZoom = initialUIZoom / baseZoom
        
        do {
            try camera.lockForConfiguration()
            camera.videoZoomFactor = initialAVZoom
            camera.unlockForConfiguration()
        } catch {}
        
        DispatchQueue.main.async {
            self.availableZoomFactors = factors
            self.currentZoomFactor = initialUIZoom
        }
    }
    
    func updateSessionPresetAsync() {
        guard !isRecording else { return }
        
        let currentRatioIndex = frameRatioIndex
        let currentQualityIndex = qualityIndex
        let currentFpsIndex = fpsIndex
        DispatchQueue.main.async { self.isChangingQuality = true }
        
        var currentDeviceOrientation = motionManager.isAccelerometerAvailable ? trueDeviceOrientation : UIDevice.current.orientation
        if currentDeviceOrientation == .faceUp || currentDeviceOrientation == .faceDown || currentDeviceOrientation == .unknown {
            currentDeviceOrientation = lastValidOrientation
        }
        var uiOrientation: UIInterfaceOrientation = .portrait
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            uiOrientation = scene.effectiveGeometry.interfaceOrientation
        }
        let captureDeviceOrientation = currentDeviceOrientation
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession.beginConfiguration()
            
            self.applyQualityAndFrameRate(ratioIndex: currentRatioIndex, qualityIndex: currentQualityIndex, fpsIndex: currentFpsIndex)
            self.applyOrientationConfiguration(uiOrientation: uiOrientation, captureDeviceOrientation: captureDeviceOrientation)
            
            self.captureSession.commitConfiguration()
            
            if let device = self.videoDeviceInput?.device {
                self.updateCameraZoomFactors(camera: device)
            }
            
            DispatchQueue.main.async {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.isChangingQuality = false }
            }
        }
    }
    
    func updateAutoFocus() {
        let isAuto = isAutoFocusOn
        sessionQueue.async { [weak self] in
            self?.internalUpdateAutoFocus(isAuto: isAuto)
        }
    }
    
    private func internalUpdateAutoFocus(isAuto: Bool) {
        guard let device = videoDeviceInput?.device else { return }
        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = isAuto ? .continuousAutoFocus : .locked
            }
            device.unlockForConfiguration()
        } catch {}
    }
    
    func cycleExposure() {
        exposureIndex = (exposureIndex + 1) % 5
        let index = exposureIndex
        sessionQueue.async { [weak self] in
            self?.internalApplyExposureBias(index: index)
        }
    }
    
    private func internalApplyExposureBias(index: Int) {
        let biases: [Float] = [-2.0, -1.0, 0.0, 1.0, 2.0]
        let bias = biases[index]
        guard let device = videoDeviceInput?.device else { return }
        do {
            try device.lockForConfiguration()
            device.setExposureTargetBias(bias, completionHandler: nil)
            device.unlockForConfiguration()
        } catch {}
    }
    
    func setTorch(_ on: Bool) {
        sessionQueue.async { [weak self] in
            guard let device = self?.videoDeviceInput?.device, device.hasTorch else { return }
            do {
                try device.lockForConfiguration()
                device.torchMode = on ? .on : .off
                device.unlockForConfiguration()
            } catch {}
        }
    }
    
    @objc func deviceOrientationDidChange() {
        var currentDeviceOrientation = motionManager.isAccelerometerAvailable ? trueDeviceOrientation : UIDevice.current.orientation
        if currentDeviceOrientation == .faceUp || currentDeviceOrientation == .faceDown || currentDeviceOrientation == .unknown {
            currentDeviceOrientation = lastValidOrientation
        } else {
            lastValidOrientation = currentDeviceOrientation
        }
        
        var uiOrientation: UIInterfaceOrientation = .portrait
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            uiOrientation = scene.effectiveGeometry.interfaceOrientation
        }
        self.lastUIOrientation = uiOrientation
        let captureDeviceOrientation = currentDeviceOrientation
        
        sessionQueue.async { [weak self] in
            self?.applyOrientationConfiguration(uiOrientation: uiOrientation, captureDeviceOrientation: captureDeviceOrientation)
        }
    }
    
    private func getDeviceAngle(orientation: UIDeviceOrientation) -> Int {
        switch orientation {
        case .portrait: return 0
        case .landscapeLeft: return 270
        case .landscapeRight: return 90
        case .portraitUpsideDown: return 180
        default: return 0
        }
    }
    
    private func getUIAngle(orientation: UIInterfaceOrientation) -> Int {
        switch orientation {
        case .portrait: return 0
        case .landscapeLeft: return 90
        case .landscapeRight: return 270
        case .portraitUpsideDown: return 180
        default: return 0
        }
    }
    
    func takePhoto() {
        if timerIndex > 0 && !isTimerRunning {
            HapticManager.shared.playTimerTick()
            startTimer { [weak self] in
                self?.triggerCaptureWithFlashIfNeeded()
            }
        } else if !isTimerRunning {
            triggerCaptureWithFlashIfNeeded()
        }
    }
    
    private func triggerCaptureWithFlashIfNeeded() {
        if flashMode == 1 && !isRecording {
            setTorch(true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                HapticManager.shared.playPhoto(isSoundOn: self.isShutterSoundOn)
                self.executeCapture()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.setTorch(false)
                }
            }
        } else {
            HapticManager.shared.playPhoto(isSoundOn: isShutterSoundOn)
            executeCapture()
        }
    }
    
    private func executeCapture() {
        isTakingPicture = true
        showFloatingAlert("📸 사진이 촬영되었습니다")
    }
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            if timerIndex > 0 && !isTimerRunning {
                HapticManager.shared.playTimerTick()
                startTimer { [weak self] in
                    guard let self = self else { return }
                    HapticManager.shared.playVideoStart(isSoundOn: self.isShutterSoundOn)
                    if self.flashMode == 1 { self.setTorch(true) }
                    self.executeStartRecording()
                }
            } else if !isTimerRunning {
                HapticManager.shared.playVideoStart(isSoundOn: isShutterSoundOn)
                if flashMode == 1 { setTorch(true) }
                executeStartRecording()
            }
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        HapticManager.shared.playVideoStop(isSoundOn: isShutterSoundOn)
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.beginSaveBackgroundTask()
            
            self.writerLock.lock()
            self.isWriting = false
            let writer = self.assetWriter
            let vInput = self.videoWriterInput
            let aInput = self.audioWriterInput
            self.writerLock.unlock()
            
            if let writer = writer, writer.status == .writing {
                vInput?.markAsFinished()
                aInput?.markAsFinished()
                writer.finishWriting {
                    guard let outputURL = self.currentVideoURL else {
                        self.endSaveBackgroundTask()
                        return
                    }
                    let error = writer.error
                    self.handleFinishedRecording(outputFileURL: outputURL, error: error)
                    
                    self.writerLock.lock()
                    if self.assetWriter == writer {
                        self.assetWriter = nil
                        self.videoWriterInput = nil
                        self.audioWriterInput = nil
                    }
                    self.writerLock.unlock()
                }
            } else {
                self.endSaveBackgroundTask()
            }
            
            DispatchQueue.main.async {
                UIApplication.shared.isIdleTimerDisabled = false
                self.stopRecordingTimer()
                self.showFloatingAlert("✅ 비디오가 저장되었습니다")
            }
        }
        
        isRecording = false
        if flashMode == 1 { setTorch(false) }
    }
    
    private func executeStartRecording() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.setupAudioSession()
            
            let tempDirectory = NSTemporaryDirectory()
            let filePath = tempDirectory + "video_\(UUID().uuidString).mp4"
            let fileURL = URL(fileURLWithPath: filePath)
            self.currentVideoURL = fileURL
            
            do {
                let newAssetWriter = try AVAssetWriter(outputURL: fileURL, fileType: .mp4)
                
                var videoSettings = self.videoDataOutput.recommendedVideoSettingsForAssetWriter(writingTo: .mp4)
                if videoSettings == nil {
                    videoSettings = [
                        AVVideoCodecKey: AVVideoCodecType.hevc,
                        AVVideoWidthKey: 1920,
                        AVVideoHeightKey: 1080
                    ]
                }
                
                let vInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                vInput.expectsMediaDataInRealTime = true
                
                let uiAngle = self.getUIAngle(orientation: self.lastUIOrientation)
                let physAngle = self.getDeviceAngle(orientation: self.lastValidOrientation)
                let correctionAngle = (physAngle - uiAngle + 360) % 360
                
                var transform = CGAffineTransform.identity
                if correctionAngle == 90 { transform = CGAffineTransform(rotationAngle: .pi / 2) }
                else if correctionAngle == 180 { transform = CGAffineTransform(rotationAngle: .pi) }
                else if correctionAngle == 270 { transform = CGAffineTransform(rotationAngle: -.pi / 2) }
                vInput.transform = transform
                
                if newAssetWriter.canAdd(vInput) {
                    newAssetWriter.add(vInput)
                }
                
                var audioSettings = self.audioDataOutput.recommendedAudioSettingsForAssetWriter(writingTo: .mp4)
                if audioSettings == nil {
                    audioSettings = [
                        AVFormatIDKey: kAudioFormatMPEG4AAC,
                        AVNumberOfChannelsKey: 2,
                        AVSampleRateKey: 44100.0,
                        AVEncoderBitRateKey: 128000
                    ]
                }
                let aInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
                aInput.expectsMediaDataInRealTime = true
                
                if newAssetWriter.canAdd(aInput) {
                    newAssetWriter.add(aInput)
                }
                
                if let location = self.currentLocation {
                    let item = AVMutableMetadataItem()
                    item.keySpace = .quickTimeMetadata
                    item.key = AVMetadataKey.quickTimeMetadataKeyLocationISO6709 as NSString
                    item.identifier = .quickTimeMetadataLocationISO6709
                    
                    let lat = location.coordinate.latitude
                    let lon = location.coordinate.longitude
                    let alt = location.altitude
                    
                    item.value = String(format: "%+08.4f%+09.4f%+08.3f/", lat, lon, alt) as NSString
                    item.dataType = "com.apple.metadata.datatype.UTF-8"
                    
                    newAssetWriter.metadata = [item]
                }
                
                newAssetWriter.startWriting()
                
                self.writerLock.lock()
                self.assetWriter = newAssetWriter
                self.videoWriterInput = vInput
                self.audioWriterInput = aInput
                self.sessionAtSourceTime = nil
                self.isWriting = true
                self.writerLock.unlock()
                
                DispatchQueue.main.async {
                    UIApplication.shared.isIdleTimerDisabled = true
                    self.startRecordingTimer()
                    self.showFloatingAlert("🔴 비디오 녹화 시작")
                }
            } catch {
                DispatchQueue.main.async {
                    self.isRecording = false
                }
            }
        }
        isRecording = true
    }
    
    private func startRecordingTimer() {
        recordingDuration = 0
        recordingTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.recordingDuration += 1
        }
        RunLoop.main.add(timer, forMode: .common)
        recordingTimer = timer
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    private func startTimer(completion: @escaping () -> Void) {
        isTimerRunning = true
        countdown = timerIndex == 1 ? 3 : 10
        showFloatingAlert("⏳ \(countdown)초")
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            self.countdown -= 1
            if self.countdown > 0 {
                self.showFloatingAlert("⏳ \(self.countdown)초")
                HapticManager.shared.playTimerTick()
            } else {
                timer.invalidate()
                self.isTimerRunning = false
                completion()
            }
        }
    }
    
    func switchCamera() {
        guard !isRecording else { return }
        
        let isAuto = self.isAutoFocusOn
        let expIndex = self.exposureIndex
        let currentFpsIndex = self.fpsIndex
        
        DispatchQueue.main.async { self.isChangingQuality = true }
        
        var currentDeviceOrientation = motionManager.isAccelerometerAvailable ? trueDeviceOrientation : UIDevice.current.orientation
        if currentDeviceOrientation == .faceUp || currentDeviceOrientation == .faceDown || currentDeviceOrientation == .unknown {
            currentDeviceOrientation = lastValidOrientation
        }
        var uiOrientation: UIInterfaceOrientation = .portrait
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            uiOrientation = scene.effectiveGeometry.interfaceOrientation
        }
        let captureDeviceOrientation = currentDeviceOrientation
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession.beginConfiguration()
            if let currentInput = self.videoDeviceInput {
                self.captureSession.removeInput(currentInput)
            }
            
            self.isBackCamera.toggle()
            let newCamera: AVCaptureDevice?
            if self.isBackCamera {
                newCamera = self.getBestBackCamera()
            } else {
                newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            }
            
            guard let validNewCamera = newCamera,
                  let newInput = try? AVCaptureDeviceInput(device: validNewCamera) else {
                self.captureSession.commitConfiguration()
                DispatchQueue.main.async {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.isChangingQuality = false }
                }
                return
            }
            
            self.videoDeviceInput = newInput
            if self.captureSession.canAddInput(newInput) { self.captureSession.addInput(newInput) }
            
            if let connection = self.videoDataOutput.connection(with: .video) {
                connection.isVideoMirrored = !self.isBackCamera
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .off
                }
            }
            
            self.applyQualityAndFrameRate(ratioIndex: self.frameRatioIndex, qualityIndex: self.qualityIndex, fpsIndex: currentFpsIndex)
            
            self.internalUpdateAutoFocus(isAuto: isAuto)
            self.internalApplyExposureBias(index: expIndex)
            
            self.applyOrientationConfiguration(uiOrientation: uiOrientation, captureDeviceOrientation: captureDeviceOrientation)
            
            self.captureSession.commitConfiguration()
            
            self.updateCameraZoomFactors(camera: validNewCamera)
            
            DispatchQueue.main.async {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.isChangingQuality = false }
            }
        }
    }
    
    func focus(at point: CGPoint) {
        let focusPointConverted = previewLayer.captureDevicePointConverted(fromLayerPoint: point)
        let isAuto = isAutoFocusOn
        
        DispatchQueue.main.async {
            self.focusPoint = point
            self.focusBoxScale = 1.3
            self.focusBoxOpacity = 1.0
            withAnimation(.easeOut(duration: 0.2)) { self.focusBoxScale = 1.0 }
            self.focusTimer?.invalidate()
            self.focusTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                withAnimation(.easeInOut(duration: 0.3)) { self.focusBoxOpacity = 0.0 }
            }
        }
        
        sessionQueue.async { [weak self] in
            guard let device = self?.videoDeviceInput?.device else { return }
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                    device.focusPointOfInterest = focusPointConverted
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose) {
                    device.exposurePointOfInterest = focusPointConverted
                    device.exposureMode = .autoExpose
                }
                device.isSubjectAreaChangeMonitoringEnabled = isAuto
                device.unlockForConfiguration()
            } catch {}
        }
    }
    
    func cycleZoom() {
        let factors = availableZoomFactors
        let current = currentZoomFactor
        guard !factors.isEmpty else { return }
        
        let nextIndex = ((factors.firstIndex(of: current) ?? 0) + 1) % factors.count
        let nextUIZoom = factors[nextIndex]
        
        setZoom(nextUIZoom)
    }
    
    func setZoom(_ factor: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self = self, let device = self.videoDeviceInput?.device else { return }
            let isUltraWideBase = (device.deviceType == .builtInTripleCamera || device.deviceType == .builtInDualWideCamera)
            let baseZoom: CGFloat = isUltraWideBase ? 0.5 : 1.0
            let targetAVZoom = factor / baseZoom
            
            do {
                try device.lockForConfiguration()
                device.ramp(toVideoZoomFactor: targetAVZoom, withRate: 10.0)
                
                if self.isAutoFocusOn {
                    if device.isFocusModeSupported(.continuousAutoFocus) {
                        device.focusMode = .continuousAutoFocus
                    }
                    if device.isExposureModeSupported(.continuousAutoExposure) {
                        device.exposureMode = .continuousAutoExposure
                    }
                }
                device.unlockForConfiguration()
                
                DispatchQueue.main.async {
                    self.currentZoomFactor = factor
                }
            } catch {}
        }
    }
    
    func zoom(with gesture: UIPinchGestureRecognizer) {
        let state = gesture.state
        let scale = gesture.scale
        
        guard let device = self.videoDeviceInput?.device else { return }
        
        let isUltraWideBase = (device.deviceType == .builtInTripleCamera || device.deviceType == .builtInDualWideCamera)
        let baseZoom: CGFloat = isUltraWideBase ? 0.5 : 1.0
        
        let maxAVZoom = min(device.activeFormat.videoMaxZoomFactor, 10.0)
        let minAVZoom = device.minAvailableVideoZoomFactor
        
        let maxUIZoom = maxAVZoom * baseZoom
        let minUIZoom = minAVZoom * baseZoom
        
        if state == .began {
            self.initialPinchZoomFactor = self.currentZoomFactor
        }
        
        let desiredUIZoom = self.initialPinchZoomFactor * scale
        let clampedUIZoom = max(minUIZoom, min(desiredUIZoom, maxUIZoom))
        let targetAVZoom = clampedUIZoom / baseZoom
        
        if state == .changed {
            self.currentZoomFactor = clampedUIZoom
            
            zoomLock.lock()
            _targetAVZoom = targetAVZoom
            let shouldApply = !_isApplyingZoom
            if shouldApply {
                _isApplyingZoom = true
            }
            zoomLock.unlock()
            
            if shouldApply {
                sessionQueue.async { [weak self] in
                    guard let self = self, let device = self.videoDeviceInput?.device else { return }
                    
                    while true {
                        self.zoomLock.lock()
                        guard let target = self._targetAVZoom else {
                            self._isApplyingZoom = false
                            self.zoomLock.unlock()
                            break
                        }
                        self._targetAVZoom = nil
                        self.zoomLock.unlock()
                        
                        do {
                            try device.lockForConfiguration()
                            device.videoZoomFactor = target
                            device.unlockForConfiguration()
                        } catch {}
                    }
                }
            }
        } else if state == .ended || state == .cancelled {
            sessionQueue.async { [weak self] in
                guard let self = self, let device = self.videoDeviceInput?.device else { return }
                do {
                    try device.lockForConfiguration()
                    if self.isAutoFocusOn {
                        if device.isFocusModeSupported(.continuousAutoFocus) {
                            device.focusMode = .continuousAutoFocus
                        }
                        if device.isExposureModeSupported(.continuousAutoExposure) {
                            device.exposureMode = .continuousAutoExposure
                        }
                    }
                    device.unlockForConfiguration()
                } catch {}
            }
        }
    }
    
    private func generateThumbnail(for url: URL, completion: @escaping (UIImage?) -> Void) {
        let asset = AVURLAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.generateCGImageAsynchronously(for: .zero) { cgImage, _, _ in
            if let cgImage = cgImage {
                completion(UIImage(cgImage: cgImage))
            } else {
                completion(nil)
            }
        }
    }
    
    private func generatePhotoThumbnail(from data: Data, fallback: UIImage) -> UIImage {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true as CFBoolean,
            kCGImageSourceCreateThumbnailWithTransform: true as CFBoolean,
            kCGImageSourceThumbnailMaxPixelSize: 300 as CFNumber
        ]
        if let source = CGImageSourceCreateWithData(data as CFData, nil),
           let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
            return UIImage(cgImage: cgImage)
        }
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 150, height: 150), format: format)
        return renderer.image { _ in
            fallback.draw(in: CGRect(x: 0, y: 0, width: 150, height: 150))
        }
    }
}

extension CameraManager: CXCallObserverDelegate {
    func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        DispatchQueue.main.async {
            self.isOnCall = callObserver.calls.contains { !$0.hasEnded }
        }
    }
}

extension CameraManager: CLLocationManagerDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        writerLock.lock()
        let currentlyWriting = isWriting
        let vWriter = videoWriterInput
        let aWriter = audioWriterInput
        let writerObj = assetWriter
        var sTime = sessionAtSourceTime
        writerLock.unlock()

        if currentlyWriting {
            let isVideo = (output == self.videoDataOutput)
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            
            if sTime == nil && isVideo {
                sTime = timestamp
                writerLock.lock()
                if sessionAtSourceTime == nil {
                    sessionAtSourceTime = timestamp
                    writerLock.unlock()
                    writerObj?.startSession(atSourceTime: timestamp)
                } else {
                    sTime = sessionAtSourceTime
                    writerLock.unlock()
                }
            }
            
            if let st = sTime {
                if isVideo {
                    if let vInput = vWriter, vInput.isReadyForMoreMediaData {
                        vInput.append(sampleBuffer)
                    }
                } else {
                    if let aInput = aWriter, aInput.isReadyForMoreMediaData, timestamp >= st {
                        aInput.append(sampleBuffer)
                    }
                }
            }
        }
        
        if output == self.videoDataOutput {
            guard isTakingPicture else { return }
            isTakingPicture = false
            
            guard let cvBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            
            var metadata = CMCopyDictionaryOfAttachments(allocator: kCFAllocatorDefault,
                                                         target: sampleBuffer,
                                                         attachmentMode: kCMAttachmentMode_ShouldPropagate) as? [CFString: Any] ?? [:]
            
            let loc = self.currentLocation
            let fIndex = self.filterIndex
            let rIndex = self.frameRatioIndex
            let sRatio = self.cachedScreenRatio
            let tsOn = self.isTimeStampOn
            let sOn = self.isShareOn
            let blkOn = self.isBlackoutMode
            let uiOri = self.lastUIOrientation
            let physOri = self.lastValidOrientation
            let dLens = "\(UIDevice.current.model) \(self.videoDeviceInput?.device.localizedName ?? "Camera")"
            let dFnum = self.videoDeviceInput?.device.lensAperture ?? 1.8
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                var ciImage = CIImage(cvImageBuffer: cvBuffer)
                
                if fIndex == 1 {
                    if let filter = CIFilter(name: "CIPhotoEffectMono") {
                        filter.setValue(ciImage, forKey: kCIInputImageKey)
                        if let output = filter.outputImage { ciImage = output }
                    }
                } else if fIndex == 2 {
                    if let filter = CIFilter(name: "CISepiaTone") {
                        filter.setValue(ciImage, forKey: kCIInputImageKey)
                        filter.setValue(0.8, forKey: kCIInputIntensityKey)
                        if let output = filter.outputImage { ciImage = output }
                    }
                }
                
                let uiAngle = self.getUIAngle(orientation: uiOri)
                let physAngle = self.getDeviceAngle(orientation: physOri)
                let correctionAngle = (physAngle - uiAngle + 360) % 360
                
                var orientationCorrection: CGImagePropertyOrientation = .up
                switch correctionAngle {
                case 90: orientationCorrection = .right
                case 180: orientationCorrection = .down
                case 270: orientationCorrection = .left
                default: orientationCorrection = .up
                }
                
                ciImage = ciImage.oriented(orientationCorrection)
                
                let width = ciImage.extent.width
                let height = ciImage.extent.height
                let isPortrait = height > width
                
                let longSide = max(width, height)
                let shortSide = min(width, height)
                let currentRatio = longSide / shortSide
                
                var targetRatio: CGFloat = 1.0
                if rIndex == 0 {
                    targetRatio = sRatio
                } else if rIndex == 1 {
                    targetRatio = 4.0 / 3.0
                } else {
                    targetRatio = 1.0
                }
                
                var cropRect = ciImage.extent
                if currentRatio > targetRatio {
                    if isPortrait {
                        let newHeight = width * targetRatio
                        let y = ciImage.extent.origin.y + (height - newHeight) / 2
                        cropRect = CGRect(x: ciImage.extent.origin.x, y: y, width: width, height: newHeight)
                    } else {
                        let newWidth = height * targetRatio
                        let x = ciImage.extent.origin.x + (width - newWidth) / 2
                        cropRect = CGRect(x: x, y: ciImage.extent.origin.y, width: newWidth, height: height)
                    }
                } else if currentRatio < targetRatio {
                    if isPortrait {
                        let newWidth = height / targetRatio
                        let x = ciImage.extent.origin.x + (width - newWidth) / 2
                        cropRect = CGRect(x: x, y: ciImage.extent.origin.y, width: newWidth, height: height)
                    } else {
                        let newHeight = width / targetRatio
                        let y = ciImage.extent.origin.y + (height - newHeight) / 2
                        cropRect = CGRect(x: ciImage.extent.origin.x, y: y, width: width, height: newHeight)
                    }
                }
                
                ciImage = ciImage.cropped(to: cropRect.integral)
                
                guard let baseCGImage = self.ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
                
                let uiImage = UIImage(cgImage: baseCGImage, scale: 1.0, orientation: .up)
                var finalCGImage = baseCGImage
                
                if tsOn {
                    let format = UIGraphicsImageRendererFormat()
                    format.scale = 1.0
                    
                    let renderer = UIGraphicsImageRenderer(size: uiImage.size, format: format)
                    let stampedUIImage = renderer.image { ctx in
                        uiImage.draw(at: .zero)
                        
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy.MM.dd HH:mm:ss"
                        let dateStr = dateFormatter.string(from: Date())
                        
                        let fontSize = max(uiImage.size.width, uiImage.size.height) * 0.025
                        let font = UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .bold)
                        
                        let shadow = NSShadow()
                        shadow.shadowColor = UIColor.black.withAlphaComponent(0.6)
                        shadow.shadowBlurRadius = 4
                        shadow.shadowOffset = CGSize(width: 2, height: 2)
                        
                        let attrs: [NSAttributedString.Key: Any] = [
                            .font: font,
                            .foregroundColor: UIColor.systemOrange,
                            .shadow: shadow
                        ]
                        
                        let textSize = dateStr.size(withAttributes: attrs)
                        let margin = fontSize
                        let rect = CGRect(x: uiImage.size.width - textSize.width - margin,
                                          y: uiImage.size.height - textSize.height - margin,
                                          width: textSize.width, height: textSize.height)
                        
                        dateStr.draw(in: rect, withAttributes: attrs)
                    }
                    
                    if let stampedCG = stampedUIImage.cgImage {
                        finalCGImage = stampedCG
                    }
                }
                
                let mutableData = NSMutableData()
                guard let destination = CGImageDestinationCreateWithData(mutableData, UTType.jpeg.identifier as CFString, 1, nil) else { return }
                
                var exifDict = (metadata[kCGImagePropertyExifDictionary] as? [CFString: Any]) ?? [:]
                var tiffDict = (metadata[kCGImagePropertyTIFFDictionary] as? [CFString: Any]) ?? [:]
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
                let currentDateString = dateFormatter.string(from: Date())
                
                tiffDict[kCGImagePropertyTIFFMake] = "Apple"
                tiffDict[kCGImagePropertyTIFFModel] = UIDevice.current.model
                
                exifDict[kCGImagePropertyExifDateTimeOriginal] = currentDateString
                exifDict[kCGImagePropertyExifDateTimeDigitized] = currentDateString
                exifDict[kCGImagePropertyExifLensModel] = dLens
                exifDict[kCGImagePropertyExifLensMake] = "Apple"
                exifDict[kCGImagePropertyExifFNumber] = dFnum
                
                metadata[kCGImagePropertyOrientation] = 1
                metadata[kCGImagePropertyTIFFDictionary] = tiffDict
                metadata[kCGImagePropertyExifDictionary] = exifDict
                
                if let location = loc {
                    let gpsTimeFormatter = DateFormatter()
                    gpsTimeFormatter.dateFormat = "HH:mm:ss"
                    gpsTimeFormatter.timeZone = TimeZone(abbreviation: "UTC")
                    
                    let gpsDateFormatter = DateFormatter()
                    gpsDateFormatter.dateFormat = "yyyy:MM:dd"
                    gpsDateFormatter.timeZone = TimeZone(abbreviation: "UTC")
                    
                    let altRef = location.altitude >= 0 ? 0 : 1
                    
                    metadata[kCGImagePropertyGPSDictionary] = [
                        kCGImagePropertyGPSLatitude: abs(location.coordinate.latitude),
                        kCGImagePropertyGPSLatitudeRef: location.coordinate.latitude >= 0 ? "N" : "S",
                        kCGImagePropertyGPSLongitude: abs(location.coordinate.longitude),
                        kCGImagePropertyGPSLongitudeRef: location.coordinate.longitude >= 0 ? "E" : "W",
                        kCGImagePropertyGPSAltitude: abs(location.altitude),
                        kCGImagePropertyGPSAltitudeRef: altRef,
                        kCGImagePropertyGPSTimeStamp: gpsTimeFormatter.string(from: location.timestamp),
                        kCGImagePropertyGPSDateStamp: gpsDateFormatter.string(from: location.timestamp)
                    ]
                }
                
                CGImageDestinationAddImage(destination, finalCGImage, metadata as CFDictionary)
                CGImageDestinationFinalize(destination)
                
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Captured_\(UUID().uuidString).jpg")
                try? mutableData.write(to: tempURL)
                
                let thumbnailImage = self.generatePhotoThumbnail(from: mutableData as Data, fallback: uiImage)
                let captureItem = CaptureItem(url: tempURL, isVideo: false, thumbnail: thumbnailImage)
                let targetUrl = tempURL
                
                DispatchQueue.main.async {
                    self.capturedItems.append(captureItem)
                    self.latestPhoto = captureItem.thumbnail
                    
                    if sOn && !blkOn {
                        self.shareURL = ShareItem(url: tempURL)
                    }
                }
                
                let savePhotoBlock = { [weak self] in
                    var placeholderLocalIdentifier: String?
                    PHPhotoLibrary.shared().performChanges({
                        let request = PHAssetCreationRequest.forAsset()
                        request.addResource(with: .photo, data: mutableData as Data, options: nil)
                        if let location = loc {
                            request.location = location
                        }
                        placeholderLocalIdentifier = request.placeholderForCreatedAsset?.localIdentifier
                    }) { [weak self] success, _ in
                        guard let self = self else { return }
                        if success, let localId = placeholderLocalIdentifier {
                            DispatchQueue.main.async {
                                self.assetIdentifiers[targetUrl] = localId
                                if let index = self.capturedItems.firstIndex(where: { $0.url == targetUrl }) {
                                    self.capturedItems[index].localIdentifier = localId
                                }
                            }
                        }
                    }
                }
                
                let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
                if status == .authorized || status == .limited {
                    savePhotoBlock()
                } else if status == .notDetermined {
                    PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                        if newStatus == .authorized || newStatus == .limited {
                            savePhotoBlock()
                        }
                    }
                }
            }
        }
    }
    
    private func handleFinishedRecording(outputFileURL: URL, error: Error?) {
        var recordingSuccessful = true
        if let error = error {
            recordingSuccessful = false
            print("AssetWriter Error: \(error)")
        }
        
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = false
            if self.isRecording {
                self.isRecording = false
                self.stopRecordingTimer()
            }
        }
        
        if !recordingSuccessful {
            self.endSaveBackgroundTask()
            return
        }
        
        let targetUrl = outputFileURL
        
        self.generateThumbnail(for: outputFileURL) { [weak self] thumbnail in
            guard let self = self else { return }
            DispatchQueue.main.async {
                var captureItem = CaptureItem(url: outputFileURL, isVideo: true, thumbnail: thumbnail)
                if let localId = self.assetIdentifiers[targetUrl] {
                    captureItem.localIdentifier = localId
                }
                self.capturedItems.append(captureItem)
                self.latestPhoto = thumbnail
                
                if self.isShareOn && !self.isBlackoutMode {
                    self.shareURL = ShareItem(url: outputFileURL)
                }
            }
        }
        
        let savedLocation = self.currentLocation
        let saveVideoBlock = { [weak self] in
            var placeholderLocalIdentifier: String?
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .video, fileURL: outputFileURL, options: nil)
                if let location = savedLocation {
                    request.location = location
                }
                placeholderLocalIdentifier = request.placeholderForCreatedAsset?.localIdentifier
            }) { [weak self] success, _ in
                guard let self = self else { return }
                if success, let localId = placeholderLocalIdentifier {
                    DispatchQueue.main.async {
                        self.assetIdentifiers[targetUrl] = localId
                        if let index = self.capturedItems.firstIndex(where: { $0.url == targetUrl }) {
                            self.capturedItems[index].localIdentifier = localId
                        }
                    }
                }
                self.endSaveBackgroundTask()
            }
        }
        
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .authorized || status == .limited {
            saveVideoBlock()
        } else if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                if newStatus == .authorized || newStatus == .limited {
                    saveVideoBlock()
                } else {
                    self.endSaveBackgroundTask()
                }
            }
        } else {
            self.endSaveBackgroundTask()
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct CameraPreview: UIViewRepresentable {
    var camera: CameraManager
    
    class VideoPreviewView: UIView {
        var previewLayer: AVCaptureVideoPreviewLayer
        
        init(previewLayer: AVCaptureVideoPreviewLayer) {
            self.previewLayer = previewLayer
            super.init(frame: .zero)
            self.layer.addSublayer(previewLayer)
        }
        
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func layoutSubviews() { super.layoutSubviews(); previewLayer.frame = self.bounds }
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = VideoPreviewView(previewLayer: camera.previewLayer)
        camera.previewLayer.videoGravity = .resizeAspectFill
        
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleTap(_:)))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        
        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handlePinch(_:)))
        pinch.cancelsTouchesInView = false
        view.addGestureRecognizer(pinch)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject {
        var parent: CameraPreview
        
        init(_ parent: CameraPreview) {
            self.parent = parent
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view else { return }
            parent.camera.focus(at: gesture.location(in: view))
        }
        
        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            parent.camera.zoom(with: gesture)
        }
    }
}

// MARK: - Local Session Preview Item View
struct LocalAssetPreviewItemView: View {
    let item: CaptureItem
    @State private var player: AVPlayer? = nil
    
    var body: some View {
        ZStack {
            if item.isVideo {
                if let player = player {
                    VideoPlayer(player: player)
                        .onAppear { player.play() }
                        .onDisappear { player.pause() }
                } else {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            } else {
                if let uiImage = UIImage(contentsOfFile: item.url.path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                } else if let thumb = item.thumbnail {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFit()
                } else {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            }
        }
        .onAppear {
            if item.isVideo {
                player = AVPlayer(url: item.url)
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}

// MARK: - Photo Preview Sheet
struct PhotoPreviewSheet: View {
    @ObservedObject var camera: CameraManager
    @Environment(\.dismiss) var dismiss
    
    @State private var currentIndex: Int = 0
    @State private var shareURLItem: ShareItem? = nil
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if camera.capturedItems.isEmpty {
                Text("촬영된 항목이 없습니다.")
                    .font(.headline)
                    .foregroundColor(.white)
            } else {
                TabView(selection: $currentIndex) {
                    ForEach(Array(camera.capturedItems.enumerated()), id: \.element.id) { index, item in
                        LocalAssetPreviewItemView(item: item)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .ignoresSafeArea()
            }
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .padding(.trailing, 16)
                    .padding(.top, 16)
                }
                
                Spacer()
                
                if !camera.capturedItems.isEmpty {
                    HStack(spacing: 40) {
                        Button(action: {
                            prepareShareItem()
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .circle)
                        
                        Button(action: {
                            deleteCurrentItem()
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.red)
                                .frame(width: 56, height: 56)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .circle)
                    }
                    .padding(.bottom, 32)
                }
            }
            .zIndex(100)
        }
        .sheet(item: $shareURLItem) { shareItem in
            ShareSheet(items: [shareItem.url])
        }
        .onAppear {
            if !camera.capturedItems.isEmpty {
                currentIndex = max(0, camera.capturedItems.count - 1)
            }
        }
    }
    
    private func prepareShareItem() {
        guard !camera.capturedItems.isEmpty, currentIndex >= 0, currentIndex < camera.capturedItems.count else { return }
        let item = camera.capturedItems[currentIndex]
        self.shareURLItem = ShareItem(url: item.url)
    }
    
    private func deleteCurrentItem() {
        guard !camera.capturedItems.isEmpty, currentIndex >= 0, currentIndex < camera.capturedItems.count else { return }
        let item = camera.capturedItems[currentIndex]
        
        let deleteLocalAndUI = {
            try? FileManager.default.removeItem(at: item.url)
            DispatchQueue.main.async {
                withAnimation {
                    if let index = self.camera.capturedItems.firstIndex(where: { $0.id == item.id }) {
                        self.camera.capturedItems.remove(at: index)
                        if self.camera.capturedItems.isEmpty {
                            self.camera.latestPhoto = nil
                            self.dismiss()
                        } else {
                            self.currentIndex = min(self.currentIndex, max(0, self.camera.capturedItems.count - 1))
                            self.camera.latestPhoto = self.camera.capturedItems[self.currentIndex].thumbnail
                        }
                    }
                }
            }
        }
        
        let localId = item.localIdentifier ?? camera.assetIdentifiers[item.url]
        
        if let localId = localId {
            PHPhotoLibrary.shared().performChanges({
                let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localId], options: nil)
                if let asset = assets.firstObject {
                    PHAssetChangeRequest.deleteAssets([asset] as NSArray)
                }
            }) { success, error in
                if success {
                    DispatchQueue.main.async {
                        self.camera.assetIdentifiers.removeValue(forKey: item.url)
                    }
                    deleteLocalAndUI()
                } else if let error = error {
                    print("Delete error: \(error)")
                }
            }
        } else {
            deleteLocalAndUI()
        }
    }
}

// MARK: - Onboarding
struct OnboardingOverlayView: View {
    @Binding var step: Int
    @ObservedObject var camera: CameraManager
    @State private var showOnboardingSoundAlert = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack {
                if step == 0 {
                    Spacer()
                    VStack(spacing: 24) {
                        Text("환영합니다! 📸")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        Text("앱 사용에 앞서 카메라, 마이크 및 사진 보관함 접근 권한이 필요합니다.\n모든 권한의 허용 여부는 선택적이며 추후 설정에서 변경할 수 있습니다.")
                            .multilineTextAlignment(.center)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                        Button(action: {
                            camera.requestPermissionsForOnboarding { _ in
                                withAnimation(.easeInOut) { step = 1 }
                            }
                        }) {
                            Text("다음")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
                    }
                    .padding(30)
                    .glassEffect(.regular, in: .rect(cornerRadius: 24))
                    .padding(.horizontal, 24)
                    Spacer()
                } else if step == 1 {
                    VStack(spacing: 24) {
                        Text("👆 상단 컨트롤")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        Text("이곳에서 타이머를 설정하거나\n설정으로 진입할 수 있습니다.")
                            .multilineTextAlignment(.center)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Toggle("카메라 셔터 사운드", isOn: $camera.isShutterSoundOn)
                            .tint(.accentColor)
                            .foregroundColor(.white)
                            .padding()
                            .glassEffect(.regular, in: .rect(cornerRadius: 12))
                        
                        Button(action: {
                            if camera.isShutterSoundOn {
                                showOnboardingSoundAlert = true
                            } else {
                                withAnimation(.easeInOut) { step = 2 }
                            }
                        }) {
                            Text("확인했어요")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
                        .alert("무음 모드 안내", isPresented: $showOnboardingSoundAlert) {
                            Button("계속 진행") {
                                withAnimation(.easeInOut) { step = 2 }
                            }
                            Button("무음 활성화") {
                                camera.isShutterSoundOn = false
                                withAnimation(.easeInOut) { step = 2 }
                            }
                        } message: {
                            Text("카메라 셔터 사운드가 켜져 있습니다. 무음 모드를 활성화하시겠습니까?")
                        }
                    }
                    .padding(30)
                    .glassEffect(.regular, in: .rect(cornerRadius: 24))
                    .padding(.horizontal, 24)
                    .padding(.top, 120)
                    Spacer()
                } else if step == 2 {
                    Spacer()
                    VStack(spacing: 24) {
                        Text("🔋 절전 블랙 스크린 모드")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        Text("화면이 꺼진 상태에서도 가볍게 탭하여 사진을,\n길게 눌러 영상을 촬영할 수 있습니다.\n위에서 아래로 스와이프하여 해제할 수 있습니다.")
                            .multilineTextAlignment(.center)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                        Button(action: {
                            withAnimation(.easeInOut) { step = 3 }
                        }) {
                            Text("다음")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
                    }
                    .padding(30)
                    .glassEffect(.regular, in: .rect(cornerRadius: 24))
                    .padding(.horizontal, 24)
                    Spacer()
                } else if step == 3 {
                    Spacer()
                    VStack(spacing: 24) {
                        Text("👇 하단 컨트롤")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        Text("지금 바로 버튼을 눌러 사진과 영상을 촬영하고,\n멋진 결과물을 만들어보세요!")
                            .multilineTextAlignment(.center)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                        Button(action: {
                            withAnimation(.easeInOut) { step = 4 }
                        }) {
                            Text("시작하기")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
                    }
                    .padding(30)
                    .glassEffect(.regular, in: .rect(cornerRadius: 24))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 150)
                }
            }
        }
        .transition(.opacity)
    }
}

// MARK: - Camera Settings
struct CameraSettingsView: View {
    @ObservedObject var camera: CameraManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.1)
                .glassEffect(.regular, in: .rect)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                HStack {
                    Text("카메라 설정")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Text("완료")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .glassEffect(.regular.interactive(), in: .capsule)
                    }
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("카메라 제어")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.leading)
                            
                            VStack(spacing: 0) {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("해상도").foregroundColor(.white)
                                    Picker("해상도", selection: $camera.qualityIndex) {
                                        Text("일반 화질").tag(0)
                                        Text("고화질 (원본)").tag(1)
                                    }
                                    .pickerStyle(.segmented)
                                }
                                .padding()
                                
                                Divider().background(Color.white.opacity(0.2))
                                
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("프레임").foregroundColor(.white)
                                    Picker("프레임", selection: $camera.fpsIndex) {
                                        Text("30 fps").tag(0)
                                        Text("60 fps").tag(1)
                                    }
                                    .pickerStyle(.segmented)
                                    
                                    if camera.fpsIndex == 1 {
                                        Text("기기 환경에 따라 60fps가 적용되지 않을 수 있으며 60fps 적용 시 iOS 시스템 제약으로 인해 화질 저하가 발생할 수 있습니다.")
                                            .font(.caption2)
                                            .foregroundColor(.yellow.opacity(0.8))
                                            .padding(.top, 2)
                                    }
                                }
                                .padding()
                                
                                Divider().background(Color.white.opacity(0.2))
                                settingToggle(title: "카메라 셔터 사운드", isOn: $camera.isShutterSoundOn)
                                Divider().background(Color.white.opacity(0.2))
                                settingToggle(title: "자동 초점", isOn: $camera.isAutoFocusOn)
                                Divider().background(Color.white.opacity(0.2))
                                settingRatioPicker()
                                Divider().background(Color.white.opacity(0.2))
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("볼륨 버튼 동작").foregroundColor(.white)
                                    Picker("", selection: $camera.volumeButtonAction) {
                                        Text("촬영").tag(0)
                                        Text("줌").tag(1)
                                        Text("사용 안 함").tag(2)
                                    }
                                    .pickerStyle(.segmented)
                                }
                                .padding()
                            }
                            .glassEffect(.regular, in: .rect(cornerRadius: 15))
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("인터페이스")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.leading)
                            
                            VStack(spacing: 0) {
                                settingToggle(title: "사진 날짜/시간 스탬프", isOn: $camera.isTimeStampOn)
                                Divider().background(Color.white.opacity(0.2))
                                settingToggle(title: "하단 사진 미리보기", isOn: $camera.showPreview)
                                Divider().background(Color.white.opacity(0.2))
                                settingToggle(title: "촬영 후 자동 공유", isOn: $camera.isShareOn)
                            }
                            .glassEffect(.regular, in: .rect(cornerRadius: 15))
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top, 20)
        }
        .presentationBackground(.clear)
        .presentationDetents([.medium, .large])
    }
    
    func settingToggle(title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .padding()
            .foregroundColor(.white)
            .tint(.accentColor)
    }
    
    func settingRatioPicker() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("촬영 비율").foregroundColor(.white)
            Picker("", selection: $camera.frameRatioIndex) {
                Text("전체 화면").tag(0)
                Text("4:3 (권장)").tag(1)
                Text("1:1").tag(2)
            }
            .pickerStyle(.segmented)
        }
        .padding()
    }
}

// MARK: - Hidden Volume
struct HiddenVolumeView: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let volumeView = MPVolumeView(frame: .zero)
        volumeView.clipsToBounds = true
        volumeView.alpha = 0.001
        return volumeView
    }
    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
