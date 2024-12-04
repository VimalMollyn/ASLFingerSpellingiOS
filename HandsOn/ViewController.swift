//
//  ViewController.swift
//  HandsOn
//
//  Created by Vimal Mollyn on 11/28/24.
//

//import UIKit
//import SwiftUI
//import AVFoundation
//import MediaPipeTasksVision
//import CoreML
//
//enum HandJoint: Int, CaseIterable {
//    case wrist = 0
//    case thumbCMC = 1
//    case thumbMCP = 2
//    case thumbIP = 3
//    case thumbTIP = 4
//    case indexMCP = 5
//    case indexPIP = 6
//    case indexDIP = 7
//    case indexTIP = 8
//    case middleMCP = 9
//    case middlePIP = 10
//    case middleDIP = 11
//    case middleTIP = 12
//    case ringMCP = 13
//    case ringPIP = 14
//    case ringDIP = 15
//    case ringTIP = 16
//    case pinkyMCP = 17
//    case pinkyPIP = 18
//    case pinkyDIP = 19
//    case pinkyTIP = 20
//}
//
//// make a mapping from prediction to char, prediction is an int from 1 to 26
//let predictionToChar = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"]
//
//class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, HandLandmarkerLiveStreamDelegate  {
//    private var permissionGranted = false // Flag for permission
//    private let captureSession = AVCaptureSession()
//    private let sessionQueue = DispatchQueue(label: "sessionQueue")
//    private var previewLayer = AVCaptureVideoPreviewLayer()
//    var screenRect: CGRect! = nil // For view dimensions
//    
//    // for hand tracking
//    private var videoOutput = AVCaptureVideoDataOutput()
//    let options = HandLandmarkerOptions()
//    var handLandmarker: HandLandmarker?
//    var chirality: ((String) -> Void)?
//    var prediction: ((String) -> Void)?
//    var predictionConfidence: ((Double) -> Void)?
//    var mpJoints: (([CGPoint]) -> Void)?
//
//    var imageWidth: Float = 0
//    var imageHeight: Float = 0
//    var screenWidth: Float = 0
//    var screenHeight: Float = 0
//    
//    var aslmodel: svc_model_moredata?
//    
//    // Add property to store current quality
//    var currentQuality: String = "low" {
//        didSet {
//            updateVideoQuality(quality: currentQuality)
//        }
//    }
//
//    func convertPredictionToChar(pred: Int) -> String {
//        return predictionToChar[pred-1]
//    }
//    
//    // Add method to update quality
//    public func updateVideoQuality(quality: String) {
//        sessionQueue.async { [weak self] in
//            guard let self = self else { return }
//            if self.captureSession.isRunning {
//                self.captureSession.beginConfiguration()
//                switch quality.lowercased() {
//                    case "high":
//                        self.captureSession.sessionPreset = .high
//                    case "medium":
//                        self.captureSession.sessionPreset = .medium
//                    default:
//                        self.captureSession.sessionPreset = .low
//                }
//                self.captureSession.commitConfiguration()
//                print("Updated video quality to \(quality)")
//                imageWidth = 0
//                imageHeight = 0
//            }
//        }
//    }
//    
//    override func viewDidLoad() {
//        checkPermission()
//        
//        sessionQueue.async { [unowned self] in
//            guard permissionGranted else { return }
//            self.setupCaptureSession()
//            self.captureSession.startRunning()
//        }
//
//        // mediapipe options
//        let modelPath = Bundle.main.path(forResource: "hand_landmarker", ofType: "task")
//        options.baseOptions.modelAssetPath = modelPath!
//        // options.runningMode = .liveStream // .image
//        // options.runningMode = .image
//        options.runningMode = .video
//        options.minHandDetectionConfidence = 0.5
//        options.minHandPresenceConfidence = 0.5
//        options.minTrackingConfidence = 0.1
//        options.numHands = 1
//        
//        // CPU or GPU
//        options.baseOptions.delegate = .GPU
//        // options.handLandmarkerLiveStreamDelegate = self
//
//        do {
//            handLandmarker = try HandLandmarker(options: options)
//        } catch {
//            print("mediapipe hand landmarker couldn't be initialized")
//        }
//        
//        // load aslmodel
//        aslmodel = try? svc_model_moredata(configuration: .init())
//
//    }
//    
//    public func mediapipeHands(sampleBuffer: CMSampleBuffer) -> (joints: [CGPoint], chirality: String) {
//        var joints: [CGPoint] = []
//        do {
//            let image = try MPImage(sampleBuffer: sampleBuffer)
//            let startTime = Int(Date().timeIntervalSince1970 * 1000)
//            // guard let result = try handLandmarker?.detect(image: image) else { return allJoints }
//            guard let result = try handLandmarker?.detect(videoFrame: image, timestampInMilliseconds: startTime) else { return (joints: [], chirality: "") }
//            
//            let landmarks = result.landmarks
//            let handedness = result.handedness
//            
//            if landmarks.isEmpty {
//                return (joints: joints, chirality: "")
//            }
//            
//            // self.mediapipeFps?(Int(Date().timeIntervalSince1970 * 1000) - startTime)
//            
//            // assumes 1 hand
//            let handLandmarks = landmarks[0]
//            let chirality = handedness[0][0].categoryName!
//
//            var transformedHandLandmarks: [CGPoint]!
//            transformedHandLandmarks = handLandmarks.map({CGPoint(x: CGFloat($0.x), y: CGFloat($0.y))})
//            
//            for point in transformedHandLandmarks {
//                let imageSpaceJoint = CGPoint(x: point.x, y: point.y)
//                joints.append(imageSpaceJoint)
//            }
//            return (joints: joints, chirality: chirality)
//        } catch {
//            print("An error occurred: \(error)")
//        }
//        return (joints: joints, chirality: "")
//    }
//
//    public func processJoints(joints: [CGPoint]) -> [CGPoint] {
//        // multiply joints by width and height
//        // let processedJoints = joints.map { CGPoint(x: (1-$0.x) * CGFloat(imageWidth), y: $0.y * CGFloat(imageHeight)) }
//        let scaleFactor = screenHeight / imageHeight
//        let scaledWidth = imageWidth * scaleFactor
//        let scaledHeight = imageHeight * scaleFactor
//        let xOffset = (screenWidth - scaledWidth) / 2
//        let yOffset = (screenHeight - scaledHeight) / 2
//        let processedJoints = joints.map { CGPoint(x: ($0.x) * CGFloat(imageWidth * scaleFactor) + CGFloat(xOffset), y: ($0.y-0.5) * CGFloat(imageHeight * scaleFactor) + CGFloat(yOffset)) }
//        return processedJoints
//    }
//
//    public func preprocessJoints(joints: [CGPoint]) -> MLMultiArray {
//        // center joints about idx 9
//        let centerJoint = joints[9]
//        let centeredJoints = joints.map { CGPoint(x: $0.x - centerJoint.x, y: $0.y - centerJoint.y) }
//        print("Centered joints: \(centeredJoints)")
//
//        // normalize by the length between idx 0 and 9
//        let length = sqrt(pow(centeredJoints[0].x - centeredJoints[9].x, 2) + pow(centeredJoints[0].y - centeredJoints[9].y, 2))
//        print("Length: \(length)")
//
//        // convert to multiarray array of size 42, x,y pairs
//        let multiArray = try! MLMultiArray(shape: [42], dataType: .double)
//        for i in 0..<21  {
//            multiArray[2*i] = NSNumber(value: centeredJoints[i].x / length)
//            multiArray[2*i+1] = NSNumber(value: centeredJoints[i].y / length)
//        }
//        return multiArray
//    }
//
//    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//        if imageWidth == 0 && imageHeight == 0 {
//            let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
//            imageWidth = Float(CVPixelBufferGetWidth(pixelBuffer!))
//            imageHeight = Float(CVPixelBufferGetHeight(pixelBuffer!))
//        }   
//
//        // print("Frame size: \(imageWidth) x \(imageHeight), Screen size: \(screenWidth) x \(screenHeight)")
//        let (joints, chirality) = mediapipeHands(sampleBuffer: sampleBuffer)
//        self.chirality?(chirality)
//        let processedJoints = processJoints(joints: joints)
//        self.mpJoints?(processedJoints)
//
//        if chirality != ""{
//            // let model_input = preprocessJoints(joints: processedJoints)
//            let model_input = preprocessJoints(joints: joints)
//            let prediction = try! aslmodel!.prediction(input: model_input)
//            self.prediction?(convertPredictionToChar(pred: Int(prediction.classLabel)))
//
//            // get the max score
//            // let maxScore = prediction.classProbability.max()
//            // self.predictionConfidence?(maxScore)
//        }
//        
//        // print("Joints in CIImage space: \(jointsInCIImageSpace)")
//    }
//
//    func checkPermission() {
//        switch AVCaptureDevice.authorizationStatus(for: .video) {
//            // Permission has been granted before
//            case .authorized:
//                permissionGranted = true
//                
//            // Permission has not been requested yet
//            case .notDetermined:
//                requestPermission()
//                    
//            default:
//                permissionGranted = false
//            }
//    }
//    
//    func requestPermission() {
//        sessionQueue.suspend()
//        AVCaptureDevice.requestAccess(for: .video) { [unowned self] granted in
//            self.permissionGranted = granted
//            self.sessionQueue.resume()
//        }
//    }
//    
//    func setupCaptureSession() {
//        // Camera input
//        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera,for: .video, position: .front) else { return }
//        
//        do {
//            try videoDevice.lockForConfiguration()
//            for format in videoDevice.formats {
//                let frameRates = format.videoSupportedFrameRateRanges
//                // set max framerate = 120
//                if let frameRateRange = frameRates.first, frameRateRange.maxFrameRate == 30 {
//                    videoDevice.activeFormat = format
//                    videoDevice.activeVideoMinFrameDuration = frameRateRange.minFrameDuration
//                    videoDevice.activeVideoMaxFrameDuration = frameRateRange.maxFrameDuration
//                    break
//                }
//            }
//            videoDevice.unlockForConfiguration()
//        } catch {
//            print("Could not set active format: \(error)")
//        }
//        
//        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else { return }
//
//        guard captureSession.canAddInput(videoDeviceInput) else { return }
//        captureSession.addInput(videoDeviceInput)
//        
//                         
//        // Preview layer
//        screenRect = UIScreen.main.bounds
//        screenWidth = Float(screenRect.size.width)
//        screenHeight = Float(screenRect.size.height)
//        
//        captureSession.sessionPreset = .low
//
//        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
//        previewLayer.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)
//        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill // Fill screen
//        previewLayer.connection?.videoRotationAngle = 90 // Rotate to portrait mode
//        
//        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
//        videoOutput.alwaysDiscardsLateVideoFrames = true
//        videoOutput.videoSettings = [ String(kCVPixelBufferPixelFormatTypeKey) : kCMPixelFormat_32BGRA]
//        captureSession.addOutput(videoOutput)
//        videoOutput.connection(with: .video)?.videoRotationAngle = 90 // Rotate to portrait mode
//        videoOutput.connection(with: .video)?.isVideoMirrored = true // mirror for front camera // NOTE:
//        
//        // Updates to UI must be on main queue
//        DispatchQueue.main.async { [weak self] in
//            self!.view.layer.addSublayer(self!.previewLayer)
//        }
//    }
//}
//
//struct HostedViewController: UIViewControllerRepresentable {
//    
//    @Binding var chirality: String
//    @Binding var mpJoints: [CGPoint]
//    @Binding var videoQuality: String
//    @Binding var prediction: String
//    @Binding var predictionConfidence: Double
//    
//    // Add a coordinator to hold the reference to the ViewController
//    class Coordinator {
//        var viewController: ViewController?
//    }
//    
//    func makeCoordinator() -> Coordinator {
//        return Coordinator()
//    }
//    
//    func makeUIViewController(context: Context) -> UIViewController {
//        let viewController = ViewController()
//        // Store reference to the viewController
//        context.coordinator.viewController = viewController
//        
//        viewController.chirality = { newData in
//            self.chirality = newData
//        }
//        viewController.mpJoints = { newData in
//            self.mpJoints = newData
//        }
//        viewController.prediction = { newData in
//            self.prediction = newData
//        }
//        viewController.predictionConfidence = { newData in
//            self.predictionConfidence = newData
//        }
//        // Add initial quality setting
//        viewController.currentQuality = videoQuality
//        return viewController
//    }
//
//    // Method to update any variable in the ViewController
//    func updateVariable(_ value: Any, for keyPath: ReferenceWritableKeyPath<ViewController, String>, coordinator: Coordinator) {
//        if let viewController = coordinator.viewController {
//            viewController[keyPath: keyPath] = value as! String
//        }
//    }
//
//    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
//        // Add quality update
//        // TODO add this later - this might be taking too much resources
//        // (uiViewController as! ViewController).currentQuality = videoQuality
//    }
//}
