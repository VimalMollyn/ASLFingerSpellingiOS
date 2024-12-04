//
//  ContentView.swift
//  HandsOn
//
//  Created by Vimal Mollyn on 11/28/24.
//

//import SwiftUI

//struct ContentView: View {
//    @State var chirality: String = ""
//    @State var mpJoints: [CGPoint] = []
//    @State var videoQuality: String = "Medium"
//    @State var prediction: String = ""
//    @State var predictionConfidence: Double = 0.0
//    @State private var hostedViewController: HostedViewController?
//    private let coordinator: HostedViewController.Coordinator?
//    
//    init() {
//        let _hostedViewController = HostedViewController(chirality: $chirality, mpJoints: $mpJoints, videoQuality: $videoQuality, prediction: $prediction, predictionConfidence: $predictionConfidence)
//        hostedViewController = _hostedViewController
//        coordinator = _hostedViewController.makeCoordinator()
//    }
//    
//    let screenWidth = UIScreen.main.bounds.width
//    let screenHeight = UIScreen.main.bounds.height
//    
//    var body: some View {
//        // HostedViewController(chirality: $chirality, mpJoints: $mpJoints, videoQuality: $videoQuality, prediction: $prediction, predictionConfidence: $predictionConfidence)
//            // .ignoresSafeArea()
//        hostedViewController
//        // Displaying the joints with circles
//        GeometryReader { proxy in
//                ForEach(0..<mpJoints.count, id: \.self) { index in
//                    Circle()
//                        .stroke(Color.green, lineWidth: 10)
//                        .frame(width: 1, height: 1)
//                        .position(CGPoint(x: mpJoints[index].x + 0.5, y: mpJoints[index].y + 0.5))
//                }
//
//                // draw another circle on the top left of the screen
//                Circle()
//                    .stroke(Color.red, lineWidth: 2)
//                    .frame(width: 10, height: 10)
//                    .position(CGPoint(x: 10, y: 10))
//                
//                // draw another circle on the top right of the screen
//                Circle()
//                    .stroke(Color.green, lineWidth: 2)
//                    .frame(width: 10, height: 10)
//                    .position(CGPoint(x: screenWidth - 10, y: 10))
//                
//                // draw another circle on the bottom left of the screen
//                Circle()
//                    .stroke(Color.blue, lineWidth: 2)
//                    .frame(width: 10, height: 10)
//                    .position(CGPoint(x: 10, y: screenHeight - 10))
//
//                // draw another circle on the bottom right of the screen
//                Circle()
//                    .stroke(Color.black, lineWidth: 2)
//                    .frame(width: 10, height: 10)
//                    .position(CGPoint(x: screenWidth - 10, y: screenHeight - 10))
//        }
//        Text("Chirality: \(chirality)")
//        Text("Prediction: \(prediction)")
//            .foregroundColor(.white)
//        Text("Confidence: \(predictionConfidence)")
//            .foregroundColor(.white)
//        // make a menu for the user to select video quality
//        Menu {
//            Button("High") {
//                videoQuality = "High"
//                hostedViewController?.updateVariable(videoQuality, for: \.currentQuality, coordinator: coordinator!)
//            }
//            Button("Medium") {
//                videoQuality = "Medium"
//                hostedViewController?.updateVariable(videoQuality, for: \.currentQuality, coordinator: coordinator!)
//            }
//            Button("Low") {
//                videoQuality = "Low"
//                hostedViewController?.updateVariable(videoQuality, for: \.currentQuality, coordinator: coordinator!)
//            }
//        } label: {
//            Label("Quality: \(videoQuality)", systemImage: "video")
//        }
//    }
//}
//
//#Preview {
//    ContentView()
//}
import SwiftUI
import AVFoundation
import Vision
import MediaPipeTasksVision
import CoreImage
import UIKit
import VideoToolbox
import CoreML
import Darwin

enum HandJoint: Int, CaseIterable {
    case wrist = 0
    case thumbCMC = 1
    case thumbMCP = 2
    case thumbIP = 3
    case thumbTIP = 4
    case indexMCP = 5
    case indexPIP = 6
    case indexDIP = 7
    case indexTIP = 8
    case middleMCP = 9
    case middlePIP = 10
    case middleDIP = 11
    case middleTIP = 12
    case ringMCP = 13
    case ringPIP = 14
    case ringDIP = 15
    case ringTIP = 16
    case pinkyMCP = 17
    case pinkyPIP = 18
    case pinkyDIP = 19
    case pinkyTIP = 20
}

let joint_connections = [
    (HandJoint.wrist, HandJoint.thumbCMC),
    (HandJoint.thumbCMC, HandJoint.thumbMCP),
    (HandJoint.thumbMCP, HandJoint.thumbIP),
    (HandJoint.thumbIP, HandJoint.thumbTIP),
    (HandJoint.wrist, HandJoint.indexMCP),
    (HandJoint.indexMCP, HandJoint.indexPIP),
    (HandJoint.indexPIP, HandJoint.indexDIP),
    (HandJoint.indexDIP, HandJoint.indexTIP),
    (HandJoint.middleMCP, HandJoint.middlePIP),
    (HandJoint.middlePIP, HandJoint.middleDIP),
    (HandJoint.middleDIP, HandJoint.middleTIP),
    (HandJoint.ringMCP, HandJoint.ringPIP),
    (HandJoint.ringPIP, HandJoint.ringDIP),
    (HandJoint.ringDIP, HandJoint.ringTIP),
    (HandJoint.wrist, HandJoint.pinkyMCP),
    (HandJoint.pinkyMCP, HandJoint.pinkyPIP),
    (HandJoint.pinkyPIP, HandJoint.pinkyDIP),
    (HandJoint.pinkyDIP, HandJoint.pinkyTIP),
    (HandJoint.indexMCP, HandJoint.middleMCP),
    (HandJoint.middleMCP, HandJoint.ringMCP),
    (HandJoint.ringMCP, HandJoint.pinkyMCP),
]

let predictionToChar = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]

func cpuUsage() -> Double {
  var totalUsageOfCPU: Double = 0.0
  var threadsList = UnsafeMutablePointer(mutating: [thread_act_t]())
  var threadsCount = mach_msg_type_number_t(0)
  let threadsResult = withUnsafeMutablePointer(to: &threadsList) {
    return $0.withMemoryRebound(to: thread_act_array_t?.self, capacity: 1) {
      task_threads(mach_task_self_, $0, &threadsCount)
    }
  }
  
  if threadsResult == KERN_SUCCESS {
    for index in 0..<threadsCount {
      var threadInfo = thread_basic_info()
      var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
      let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
          thread_info(threadsList[Int(index)], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
        }
      }
      
      guard infoResult == KERN_SUCCESS else {
        break
      }
      
      let threadBasicInfo = threadInfo as thread_basic_info
      if threadBasicInfo.flags & TH_FLAGS_IDLE == 0 {
        totalUsageOfCPU = (totalUsageOfCPU + (Double(threadBasicInfo.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0))
      }
    }
  }
  
  vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threadsList)), vm_size_t(Int(threadsCount) * MemoryLayout<thread_t>.stride))
  return totalUsageOfCPU
}

func memoryUsage() -> Int {
    var taskInfo = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size) / 4
    let result: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }
    
    var used: Int = 0
    if result == KERN_SUCCESS {
        used = Int(taskInfo.phys_footprint) / 1024 / 1024
    }
    return used
}

struct CameraView: UIViewControllerRepresentable {
    @Binding var mediapipeFps: Int
    @Binding var charPred: String
    @Binding var charConf: Double
    @Binding var aslModelFps: Int
    @Binding var trackingFrameRate: Int
    @Binding var charString: String
    @Binding var gptDecodedString: String

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = CameraViewController()
        viewController.trackingFrameRate = trackingFrameRate
        
        // set up tie with the mediapipe fps
        viewController.mediapipeFps = { newFps in
            self.mediapipeFps = newFps
        }
        viewController.aslModelFps = { newFps in
            self.aslModelFps = newFps
        }
        viewController.charPred = { newCharPred in
            self.charPred = newCharPred
        }
        viewController.charConf = { newCharConf in
            self.charConf = newCharConf
        }
        viewController.charString = { newCharString in
            self.charString = newCharString
        }
        viewController.gptDecodedString = { newGptDecodedString in
            self.gptDecodedString = newGptDecodedString
        }
        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if let cameraVC = uiViewController as? CameraViewController {
            cameraVC.trackingFrameRate = trackingFrameRate

            if charString == "" {
                cameraVC.localCharString = ""
            }
        }
    }
}

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, HandLandmarkerLiveStreamDelegate {
    var permissionGranted = false
    let captureSession = AVCaptureSession()
    var previewLayer = AVCaptureVideoPreviewLayer()
    let sessionQueue = DispatchQueue(label: "cameraSessionQueue")
    let handPoseRequest = VNDetectHumanHandPoseRequest()
    
    var screenRect: CGRect! = nil // For view dimensions
    
    var videoOutput = AVCaptureVideoDataOutput()
    let leftPointsLayer = CAShapeLayer()
    let rightPointsLayer = CAShapeLayer()
    let linesLayer = CAShapeLayer()

    let options = HandLandmarkerOptions()
    var handLandmarker: HandLandmarker?
    
    var ciContext: CIContext!
    var edgeDetectionFilter: CIFilter!
    var processedImage: CGImage?
    var pixelBuffer: CVPixelBuffer?
    var mediapipeFps: ((Int) -> Void)?
    var aslModelFps: ((Int) -> Void)?
    var charPred: ((String) -> Void)?
    var charConf: ((Double) -> Void)?
    var charString: ((String) -> Void)?
    var gptDecodedString: ((String) -> Void)?
    var localCharString: String = ""
    
    var imageWidth: Double = 1080.0
    var imageHeight: Double = 1920.0
    var screenWidth: Double = 390.0
    var screenHeight: Double = 844.0
    var aslmodel: svc_model_moredata?
    var globalFrameCount: Int = 0
    var trackingFrameRate: Int = 30

    var prevLetter: String = ""
    var charCounter: Int = 0

    var request: URLRequest?

    override func viewDidLoad() {
        checkPermission()

        sessionQueue.async { [unowned self] in
            guard permissionGranted else { return }
            self.setupCaptureSession()
            
            self.captureSession.startRunning()
        }
        
        handPoseRequest.maximumHandCount = 2 // we want to detect 2 hands (Vision Hands)
        
        // mediapipe options
        let modelPath = Bundle.main.path(forResource: "hand_landmarker", ofType: "task")
        options.baseOptions.modelAssetPath = modelPath!
        // options.runningMode = .liveStream // .image
        // options.runningMode = .image
        options.runningMode = .video
        options.minHandDetectionConfidence = 0.5
        options.minHandPresenceConfidence = 0.5
        options.minTrackingConfidence = 0.5
        options.numHands = 1
        
        // CPU or GPU
        options.baseOptions.delegate = .GPU
        // options.handLandmarkerLiveStreamDelegate = self

        do {
            handLandmarker = try HandLandmarker(options: options)
        } catch {
            print("mediapipe hand landmarker couldn't be initialized")
        }
        
        // set up the touch model
        let config = MLModelConfiguration()
        config.computeUnits = .all
        
        // load aslmodel
        aslmodel = try? svc_model_moredata(configuration: .init())

        // set up openai
        // get api key from keys.plist
        let keys = NSDictionary(contentsOfFile: Bundle.main.path(forResource: "keys", ofType: "plist")!)
        let apiKey = keys?["openai"] as? String
        request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request?.httpMethod = "POST"
        request?.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey = apiKey {
            request?.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
    }
    
    func sendMessageToGPT(message: String) {
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "user", "content": "You are a spelling correcting bot. Convert this string of characters into a words. some of the characters may be wrong. Sometimes characters are missing or extra or in the wrong order. Sometimes spaces are missing. Don't explain, just give me the answer. \n\(message)"]
            ]
        ]
        let jsonData = try? JSONSerialization.data(withJSONObject: body)
        request?.httpBody = jsonData


        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request!)
                let statusCode = (response as! HTTPURLResponse).statusCode
                print(statusCode)
                
                if statusCode == 200 {
                    // Handle success
                    let json = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
                    if let choices = json["choices"] as? [[String: Any]],
                       let firstChoice = choices.first,
                       let message = firstChoice["message"] as? [String: Any],
                       let content = message["content"] as? String {
                       self.gptDecodedString?(content)
                    }
                }
            } catch {
                print("Failed to send request: \(error)")
            }
        }
    }

    func processJoints(joints: [CGPoint], chirality: String) {
        // joints are in image space, keys Left and Right
        // drawing
        DispatchQueue.main.async {
            let (pointsPath, linesPath) = self.drawPoints(points: joints)

            CATransaction.begin()
            CATransaction.setDisableActions(true)
            if chirality == "Left" {
                self.leftPointsLayer.path = pointsPath.cgPath
                self.rightPointsLayer.path = nil
            } else {
                self.rightPointsLayer.path = pointsPath.cgPath
                self.leftPointsLayer.path = nil
            }
            self.linesLayer.path = linesPath.cgPath
            CATransaction.commit()
        }
        
    }
    
    public func preprocessJoints(rawJoints: [CGPoint], chirality: String) -> MLMultiArray {
        // if the chirality is left, then we need to flip the x coordinates
        var joints: [CGPoint] = []
        if chirality == "Left" {
            joints = rawJoints.map { CGPoint(x: 1 - $0.x, y: $0.y) }
        } else {
            joints = rawJoints
        }

        // center joints about idx 9
        let centerJoint = joints[9]
        let centeredJoints = joints.map { CGPoint(x: $0.x - centerJoint.x, y: $0.y - centerJoint.y) }

        // normalize by the length between idx 0 and 9
        let length = sqrt(pow(centeredJoints[0].x - centeredJoints[9].x, 2) + pow(centeredJoints[0].y - centeredJoints[9].y, 2))

        // convert to multiarray array of size 42, x,y pairs
        let multiArray = try! MLMultiArray(shape: [42], dataType: .double)
        for i in 0..<21  {
            multiArray[2*i] = NSNumber(value: centeredJoints[i].x / length)
            multiArray[2*i+1] = NSNumber(value: centeredJoints[i].y / length)
        }
        return multiArray
    }

    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            // Permission has been granted before
        case .authorized:
            permissionGranted = true
            
            // Permission has not been requested yet
        case .notDetermined:
            self.sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video) { granted in
                self.permissionGranted = granted
                self.sessionQueue.resume()
            }
        case .denied, .restricted:
            print("camera access denied")
            showSettingsAlert()
            
        default:
            fatalError("unkown authorization status")
        }
    }
    
    // this shows a pop up to go to the settings page
    func showSettingsAlert() {
        let alert = UIAlertController(
            title: "Camera Access Needed",
            message: "Please enable camera access in Settings",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(appSettings, options: [:], completionHandler: nil)
            }
        })
        
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        if let rootViewController = windowScene?.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true, completion: nil)
        }
    }
    
    func setupCaptureSession() {
        // Camera input
//         guard let videoDevice = AVCaptureDevice.default(.builtInUltraWideCamera,for: .video, position: .back) else { return }
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera,for: .video, position: .front) else { return }

        do {
            try videoDevice.lockForConfiguration()
            for format in videoDevice.formats {
                let frameRates = format.videoSupportedFrameRateRanges
                // set max framerate = 120
                if let frameRateRange = frameRates.first, frameRateRange.maxFrameRate == 30 {
                    videoDevice.activeFormat = format
                    videoDevice.activeVideoMinFrameDuration = frameRateRange.minFrameDuration
                    videoDevice.activeVideoMaxFrameDuration = frameRateRange.maxFrameDuration
                    print(format)
                    break
                }
            }
            videoDevice.unlockForConfiguration()
        } catch {
            print("Could not set active format: \(error)")
        }
        
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else { return }
        
        guard captureSession.canAddInput(videoDeviceInput) else { return }
        captureSession.addInput(videoDeviceInput)
        
        
        // captureSession.sessionPreset = .photo
        // captureSession.sessionPreset = .low
        // captureSession.sessionPreset = .medium

        // Preview layer
        screenRect = UIScreen.main.bounds
        screenWidth = Double(screenRect.width)
        screenHeight = Double(screenRect.height)

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        // 1128 x 1504
        // obtained by looking at the frame size
//        let video_w = 1128.0
//        let video_h = 1504.0
        // previewLayer.bounds = CGRect(x: 0, y: 0, width: screenWidth, height: screenWidth*imageHeight/imageWidth) // 390 * 219.375
        previewLayer.bounds = CGRect(x: 0, y: 0, width: imageWidth * screenHeight/imageHeight, height: screenHeight) // 390 * 219.375
        // previewLayer.bounds = CGRect(x: 0, y: 0, width: screenWidth, height: screenHeight) // 390 * 219.375
        previewLayer.position = CGPoint(x: screenWidth/2, y: screenHeight/2)
        previewLayer.backgroundColor = UIColor(red: 1, green: 0, blue: 0, alpha: 0.4).cgColor
        previewLayer.connection?.videoRotationAngle =  90
        previewLayer.contentsGravity = .resizeAspectFill
        
        // now set up points layer
        leftPointsLayer.bounds = previewLayer.bounds
        leftPointsLayer.position = CGPoint(x: screenWidth/2, y: screenHeight/2)
        leftPointsLayer.strokeColor = #colorLiteral(red: 0.9254902005, green: 0.2352941185, blue: 0.1019607857, alpha: 0.5).cgColor
        leftPointsLayer.fillColor = #colorLiteral(red: 0.9254902005, green: 0.2352941185, blue: 0.1019607857, alpha: 0.5).cgColor

        rightPointsLayer.bounds = previewLayer.bounds
        rightPointsLayer.position = CGPoint(x: screenWidth/2, y: screenHeight/2)
        rightPointsLayer.strokeColor = #colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 0.5).cgColor
        rightPointsLayer.fillColor = #colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 0.5).cgColor

        // another layer for the lines
        linesLayer.bounds = previewLayer.bounds
        linesLayer.position = CGPoint(x: screenWidth/2, y: screenHeight/2)
        linesLayer.strokeColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 0.5).cgColor
        linesLayer.fillColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 0.5).cgColor
        linesLayer.lineWidth = 2.5
        
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sampleBufferQueue"))
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [ String(kCVPixelBufferPixelFormatTypeKey) : kCMPixelFormat_32BGRA]

        captureSession.addOutput(videoOutput)
        
        // TODO: setup rotation coordinator
        videoOutput.connection(with: .video)?.videoRotationAngle = 90
        // videoOutput.connection(with: .video)?.preferredVideoStabilizationMode = .standard
        videoOutput.connection(with: .video)?.isVideoMirrored = true // mirror for front camera // NOTE:


        // Updates to UI must be on main queue
        DispatchQueue.main.async { [weak self] in
            self!.view.layer.addSublayer(self!.previewLayer)
            self!.view.layer.addSublayer(self!.linesLayer)
            self!.view.layer.addSublayer(self!.leftPointsLayer)
            self!.view.layer.addSublayer(self!.rightPointsLayer)
        }
        
        ciContext = CIContext()
    }
    
    public func VisionHands(sampleBuffer: CMSampleBuffer) -> [String: [CGPoint]] {
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .left, options: [:])
        var allJoints: [String: [CGPoint]] = ["Left": [], "Right": []]

        do {
            // Perform VNDetectHumanHandPoseRequest
            try handler.perform([handPoseRequest])
            
            guard let results = handPoseRequest.results else {
                return allJoints
            }
            
            for result in results {
                let chirality = result.chirality.toString()
                for point in try result.recognizedPoints(.all) {
                    
                    let imageSpaceJoint = CGPoint(x: point.value.location.x, y: 1-point.value.location.y)
                    allJoints[chirality]?.append(imageSpaceJoint)
                }
            }
        } catch {
            return allJoints
        }
        
        return allJoints
    }
    
    public func drawPoints(points: [CGPoint]) -> (UIBezierPath, UIBezierPath) {
        let pointsPath = UIBezierPath()
        let linesPath = UIBezierPath()
        if points.count < 1 {
            return (pointsPath, linesPath)
        }

        // scale all the points
        // let scaleFactor = screenWidth / imageWidth
        let scaleFactor = screenHeight / imageHeight
        let scaledPoints = points.map { CGPoint(x: $0.x * imageWidth * scaleFactor, y: $0.y * imageHeight * scaleFactor) }
        
        // for point in points {
        for scaledPoint in scaledPoints {
            // let ogscaledPoint = self.previewLayer.layerPointConverted(fromCaptureDevicePoint: point)
            // let scaledPoint = CGPoint(x: (point.x) * imageWidth * screenWidth / imageWidth, y: point.y * imageHeight * screenWidth / imageWidth)
            pointsPath.move(to: scaledPoint)
            pointsPath.addArc(withCenter: scaledPoint, radius: 5, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        }

        // draw connections
        for connection in joint_connections {
            let startPoint = scaledPoints[connection.0.rawValue]
            let endPoint = scaledPoints[connection.1.rawValue]
            linesPath.move(to: startPoint)
            linesPath.addLine(to: endPoint)
        }

        return (pointsPath, linesPath)
    }
    
    public func mediapipeHandsAsync(sampleBuffer: CMSampleBuffer) {
        do {
            let image = try MPImage(sampleBuffer: sampleBuffer)
            try handLandmarker?.detectAsync(image: image, timestampInMilliseconds: Int(Date().timeIntervalSince1970 * 1000))
        } catch {
            print("An error occurred: \(error)")
        }
    }

    public func mediapipeHands(sampleBuffer: CMSampleBuffer) -> (joints: [CGPoint], chirality: String) {
        // var allJoints: [String: [CGPoint]] = ["Left": [], "Right": []]
        var allJoints: [CGPoint] = []
        var chirality: String = ""
        do {
            let image = try MPImage(sampleBuffer: sampleBuffer)
            let startTime = Int(Date().timeIntervalSince1970 * 1000)
            // guard let result = try handLandmarker?.detect(image: image) else { return allJoints }
            guard let result = try handLandmarker?.detect(videoFrame: image, timestampInMilliseconds: startTime) else { return (allJoints, chirality) }
            self.mediapipeFps?(1000/(Int(Date().timeIntervalSince1970 * 1000) - startTime))
            let landmarks = result.landmarks
            let handedness = result.handedness
            
            for i in 0..<landmarks.count {
                let handLandmarks = landmarks[i]
                chirality = handedness[i][0].categoryName!

                var transformedHandLandmarks: [CGPoint]!
                // transformedHandLandmarks = handLandmarks.map({CGPoint(x: CGFloat($0.y), y: 1 - CGFloat($0.x))})
                transformedHandLandmarks = handLandmarks.map({CGPoint(x: CGFloat($0.x), y: CGFloat($0.y))})
                
                for point in transformedHandLandmarks {
                    let imageSpaceJoint = CGPoint(x: point.x, y: point.y)
                    allJoints.append(imageSpaceJoint)
                }
            }
        } catch {
            print("An error occurred: \(error)")
        }
        return (allJoints, chirality)

    }
    
    public func convert2CIImageSpace(cgpoints: [CGPoint]) -> [[Float]] {
        var floats: [[Float]] = []
        for point in cgpoints {
            floats.append([(1-Float(point.y))*Float(imageWidth), (1-Float(point.x))*Float(imageHeight)])
        }
        return floats
    }

    public func processChar(char: String) {
        if prevLetter == "" {
            prevLetter = char
        }
        else if prevLetter != char {
            prevLetter = char
            charCounter = 0
        }
        else if charCounter == Int(40.0 / 30.0 * Float(trackingFrameRate)) {
            localCharString += char
            charString?(localCharString)
            charCounter = 0
            prevLetter = ""

            Task {
                sendMessageToGPT(message: localCharString)
            }
        }
        charCounter += 1
    }

    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//        self.pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
//        
//        self.imageWidth = Double(CVPixelBufferGetWidth(pixelBuffer!))
//        self.imageHeight = Double(CVPixelBufferGetHeight(pixelBuffer!))
        
        // print("Frame size: \(imageWidth) x \(imageHeight)")
        
        // Other hand pose implementations would go here, make sure to output an dict of Left and Right CGPoints in pixel space
        // also need to ensure that the ordering of joints is the same as mediapipe
        // let joints = VisionHands(sampleBuffer: sampleBuffer)

        globalFrameCount += 1

        if globalFrameCount % (Int(30 / trackingFrameRate)) != 0 {
            return
        }

        // if globalFrameCount % 90 == 0 {
        //     if localCharString != "" {
        //         print(localCharString)
        //         sendMessageToGPT(message: localCharString)
        //     }
        // }

        // now do mediapipe
        let (joints, chirality) = mediapipeHands(sampleBuffer: sampleBuffer)
        processJoints(joints: joints, chirality: chirality)

        // preprocess joints
        // there's only one hand, so find the non-empty hand and it's chirality
        if chirality != "" {
            let startTime = Int(Date().timeIntervalSince1970 * 1000)
            let preprocessedJoints = preprocessJoints(rawJoints: joints, chirality: chirality)
            let prediction = try! aslmodel?.prediction(input: preprocessedJoints)
            let classLabel = Int(prediction!.classLabel)
            let char = predictionToChar[classLabel - 1]
            self.charPred?(char)
            self.charConf?(prediction?.classProbability[Int64(classLabel)] ?? 0.0)
            self.aslModelFps?(1000/(Int(Date().timeIntervalSince1970 * 1000) - startTime))

            processChar(char: char)
        }
        else {
            self.aslModelFps?(0)
            self.charPred?("NA")
            self.charConf?(0.0)
        }

        // globalFrameCount = 0
    }
}

struct ContentView: View {
    @State var processedImage: CGImage? = nil
    @State var processedPixelBuffer: CVPixelBuffer? = nil
    @State var fps: Int = 0
    @State var charPred: String = ""
    @State var charConf: Double = 0.0
    @State var aslModelFps: Int = 0
    @State var trackingFrameRate: Int = 30
    @State var charString: String = ""
    @State var gptDecodedString: String = ""
    @State var showLLMCorrectedText: Bool = false
    let totalMemory: Int = Int(ProcessInfo.processInfo.physicalMemory / 1024 / 1024)
    
    var body: some View {
        ZStack {
            CameraView(mediapipeFps: $fps, charPred: $charPred, charConf: $charConf, aslModelFps: $aslModelFps, trackingFrameRate: $trackingFrameRate, charString: $charString, gptDecodedString: $gptDecodedString)
                .ignoresSafeArea(.all)
            VStack {
                Text("Char Pred: \(charPred), \(charConf, specifier: "%.1f")")
                    .font(.title)
                    .bold()
                    .foregroundColor(.white)
                    .padding(.bottom, 10)
                Text(charString)
                    .font(.title)
                    .bold()
                    .foregroundColor(.white)
                    .padding(10)
                    .frame(minHeight: 70)
                HStack {
                    Button(action: {
                        charString = ""
                        gptDecodedString = ""
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("Clear")
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.2))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .foregroundColor(.white)
                    .padding(10)
                    // button to hide/show the LLM Corrected Text
                    Button(action: {
                        showLLMCorrectedText.toggle()
                    }) {
                        HStack {
                            Image(systemName: showLLMCorrectedText ? "eye.slash.fill" : "eye.fill")
                            Text(showLLMCorrectedText ? "Hide Corrected" : "Show Corrected")
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.2))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .foregroundColor(.white)
                }
                if showLLMCorrectedText {
                    Text("LLM Corrected:")
                        .font(.title)
                        .bold()
                        .foregroundColor(.white)
                        .padding(.bottom, 10)
                    Text(gptDecodedString)
                        .font(.title)
                        .bold()
                        .foregroundColor(.green)
                        .padding(10)
                        .frame(minHeight: 70)
                }
                Spacer()
                HStack {
                    VStack (alignment: .leading) {
                        Text("Mediapipe: \(fps) FPS")
                        Text("ASL Model: \(aslModelFps) FPS")
                        Text("CPU: \(cpuUsage(), specifier: "%.1f")%")
                        Text("Memory: \(memoryUsage()) MB / \(totalMemory) MB")
                        
                        Menu {
                            Button("30 FPS") { trackingFrameRate = 30 }
                            Button("15 FPS") { trackingFrameRate = 15 }
                            Button("10 FPS") { trackingFrameRate = 10 }
                            Button("3 FPS") { trackingFrameRate = 3 }
                            Button("1 FPS") { trackingFrameRate = 1 }
                        } label: {
                            HStack {
                                Image(systemName: "speedometer")
                                Text("Tracking Rate: \(trackingFrameRate) FPS")
                                Image(systemName: "chevron.down")
                            }
                            .padding(8)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(8)
                        }
                        .foregroundColor(.white)
                    }
                    .bold()
                    .foregroundColor(.white)
                    .padding()
                    Spacer()
                }
                Text("HandsOn ASL FingerSpelling")
                    .foregroundColor(.white)
                    .italic()
            }
        }
    }
}

#Preview {
    ContentView()
}

extension VNChirality {
    func toString() -> String {
        if self == .left {
            return "Left"
        }
        else if self == .right {
            return "Right"
        }
        else {
            return "Unknown"
        }
    }
}

extension UIImage {
    public convenience init?(pixelBuffer: CVPixelBuffer) {
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)
        guard let unwrappedCGImage = cgImage else {
            return nil
        }
        self.init(cgImage: unwrappedCGImage)
    }
}

extension CIImage {
    func toCVPixelBuffer() -> CVPixelBuffer? {
        let width = Int(extent.width)
        let height = Int(extent.height)
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, nil, &pixelBuffer)
        guard status == kCVReturnSuccess, let pixelBuffer = pixelBuffer else {
            return nil
        }
        
        let context = CIContext()
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        context.render(self, to: pixelBuffer)
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        
        return pixelBuffer
    }
}

func CGImage2CVPixelBuffer(forImage image:CGImage) -> CVPixelBuffer? {
    let frameSize = CGSize(width: image.width, height: image.height)
    
    var pixelBuffer:CVPixelBuffer? = nil
    let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(frameSize.width), Int(frameSize.height), kCVPixelFormatType_32BGRA , nil, &pixelBuffer)
    
    if status != kCVReturnSuccess {
        return nil
        
    }
    
    CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags.init(rawValue: 0))
    let data = CVPixelBufferGetBaseAddress(pixelBuffer!)
    let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
    let context = CGContext(data: data, width: Int(frameSize.width), height: Int(frameSize.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: bitmapInfo.rawValue)
    
    
    context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
    
    return pixelBuffer
}

func sigmoid(z: Float) -> Float {
    return 1.0 / (1.0 + exp(-z))
}
