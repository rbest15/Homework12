import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController {
    
    private let captureSession = AVCaptureSession()
    private lazy var previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
    
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private var drawings: [CAShapeLayer] = []
    
    private var firebutton = UIButton()
    private var rocket = UIImageView()
    private var faceCenter = CGPoint()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.addCameraInput()
        self.showCameraFeed()
        self.getCameraFrames()
        
        firebutton = createButton()
        rocket = createRocket(center: firebutton.center)
        firebutton.addTarget(self, action: #selector(fireButtonPressed), for: .touchUpInside)
        
        self.view.addSubview(rocket)
        self.view.addSubview(firebutton)
        
        self.captureSession.startRunning()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.previewLayer.frame = self.view.frame
    }

    private func addCameraInput() {
        guard let device = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera],
            mediaType: .video,
                position: .front).devices.first else {
               fatalError("No camera device found, please make sure to run in an iOS device and not a simulator")
        }
        let cameraInput = try! AVCaptureDeviceInput(device: device)
        self.captureSession.addInput(cameraInput)
    }
    
    private func showCameraFeed() {
        self.previewLayer.videoGravity = .resizeAspectFill
        self.view.layer.addSublayer(self.previewLayer)
        self.previewLayer.frame = self.view.frame
    }
    
    func createButton() -> UIButton{
        let fireButton = UIButton(frame: CGRect(x: self.view.frame.width / 2 - 75, y: self.view.frame.height - 125, width: 150, height: 75))
        fireButton.backgroundColor = .black
        fireButton.layer.cornerRadius = 25
        fireButton.setTitle("Fire", for: .normal)
        fireButton.setTitleColor(.darkGray, for: .highlighted)
        
        return fireButton
    }
    
    @objc func fireButtonPressed() {
        self.rocket.stopAnimating()
        self.rocket.alpha = 1
        self.rocket.center = self.firebutton.center
        reloadRocketTarget()
        
    }
    
    func createRocket(center: CGPoint) -> UIImageView{
        let rocket = UIImageView(image: UIImage(named: "spaceship"))
        rocket.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        rocket.center = center
        rocket.alpha = 0
        
        return rocket
    }
    
    func reloadRocketTarget(){
        UIView.animate(withDuration: 3) {
            self.rocket.center = self.faceCenter
        }
    }
    
    private func getCameraFrames() {
        self.videoDataOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString) : NSNumber(value: kCVPixelFormatType_32BGRA)] as [String : Any]
        self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
        self.videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera_frame_processing_queue"))
        self.captureSession.addOutput(self.videoDataOutput)
        guard let connection = self.videoDataOutput.connection(with: AVMediaType.video),
            connection.isVideoOrientationSupported else { return }
        connection.videoOrientation = .portrait
    }
    
    private func detectFace(in image: CVPixelBuffer) {
        let faceDetectionRequest = VNDetectFaceLandmarksRequest(completionHandler: { (request: VNRequest, error: Error?) in
            DispatchQueue.main.async {
                if let results = request.results as? [VNFaceObservation] {
                    self.handleFaceDetectionResults(results)
                } else {
                    self.clearDrawings()
                }
            }
        })
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: image, orientation: .leftMirrored, options: [:])
        try? imageRequestHandler.perform([faceDetectionRequest])
    }
    
    private func handleFaceDetectionResults(_ observedFaces: [VNFaceObservation]) {
        self.clearDrawings()
        if !observedFaces.isEmpty {
            self.faceCenter = CGPoint(x: observedFaces[0].boundingBox.midY * self.view.bounds.width, y: observedFaces[0].boundingBox.midX * self.view.bounds.height)
            self.reloadRocketTarget()
        }
        
        let facesBoundingBoxes: [CAShapeLayer] = observedFaces.map({ (observedFace: VNFaceObservation) -> CAShapeLayer in
            let faceBoundingBoxOnScreen = self.previewLayer.layerRectConverted(fromMetadataOutputRect: observedFace.boundingBox)
            let faceBoundingBoxPath = CGPath(rect: faceBoundingBoxOnScreen, transform: nil)
            let faceBoundingBoxShape = CAShapeLayer()
            faceBoundingBoxShape.path = faceBoundingBoxPath
            faceBoundingBoxShape.fillColor = UIColor.clear.cgColor
            faceBoundingBoxShape.strokeColor = UIColor.green.cgColor
            return faceBoundingBoxShape
        })
//        facesBoundingBoxes.forEach({ faceBoundingBox in self.view.layer.addSublayer(faceBoundingBox) })
        self.drawings = facesBoundingBoxes
    }
    
    private func clearDrawings() {
        self.drawings.forEach { $0.removeFromSuperlayer()}
    }

}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let frame = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            debugPrint("unable to get image from sample buffer")
            return
        }
        self.detectFace(in: frame)
    }
}
