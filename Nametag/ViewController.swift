//
//  ViewController.swift
//  Nametag
//
//  Created by Cal Stephens on 10/14/17.
//  Copyright © 2017 Helluva. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Vision

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var faceRectView: UIView!
    @IBOutlet weak var faceLabel: UILabel!
    
    var frameHistory = [CGRect]()
    var averageBounds: CGRect!
    var captureImage = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.delegate = self
                
        faceRectView.isHidden = true
        faceRectView.layer.borderColor = UIColor.red.cgColor
        faceRectView.layer.borderWidth = 5
        faceLabel.isHidden = true
        
        SpeechController().setup()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let configuration = AROrientationTrackingConfiguration()
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }

    // MARK: - VNDetectFaceRectanglesRequest
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard let pixelBuffer = sceneView.session.currentFrame?.capturedImage else {return}
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let temporaryContext = CIContext(options: nil)
        let videoImage = temporaryContext.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer)))
        
        guard let imageFromFeed = videoImage?.rotate() else {
            return
        }
        
        let request = VNDetectFaceRectanglesRequest(completionHandler: self.bindImageToFaceDetectionHandler(imageFromFeed))
        let requestHandler = VNImageRequestHandler(cgImage: imageFromFeed, orientation: .up, options: [:])
        try? requestHandler.perform([request])
    }

    func bindImageToFaceDetectionHandler(_ image: CGImage) -> ((VNRequest, Error?) -> Void) {
        
        return { (request: VNRequest, error: Error?) -> Void in
            guard let observations = request.results as? [VNFaceObservation] else {
                fatalError("unexpected result type!")
            }
            
            self.averageBounds = self.frameHistory.average
            
            let largestFace = observations.max(by: { (face1: VNFaceObservation, face2: VNFaceObservation) -> Bool in
                let face1Area = face1.boundingBox.size.height * face1.boundingBox.size.width
                let face2Area = face2.boundingBox.size.height * face2.boundingBox.size.width
                return face1Area < face2Area
            })
            
            if let largestFace = largestFace {
                self.updateForFace(largestFace, in: image)
            } else if self.frameHistory.count > 0 {
                self.frameHistory.remove(at: 0)
            }
            
            DispatchQueue.main.async {
                self.setDisplayLabels()
            }
        }
    }
    
    func updateForFace(_ face: VNFaceObservation, in image: CGImage) {
        
        //make sure face is large enough to be in foreground
        guard face.boundingBox.size.width >= 0.33 else {
            if self.frameHistory.count > 0 {
                self.frameHistory.remove(at: 0)
            }
            
            return
        }
        
        DispatchQueue.main.async {
            let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -self.view.frame.height)
            let translate = CGAffineTransform.identity.scaledBy(x: self.view.frame.width, y: self.view.frame.height)
            let facebounds = face.boundingBox.applying(translate).applying(transform)
            
            self.frameHistory.append(facebounds)
            
            if self.frameHistory.count > 5 {
                self.frameHistory.remove(at: 0)
            }
            
            if self.frameHistory.count > 4 {
                self.faceRectView.frame = self.averageBounds
            }
            
            if self.captureImage {
                let faceImage = image.crop(rect: self.averageBounds)
            }
        }
        
    }
    
    // Mark: Update Overlays
    
    func setDisplayLabels() {
        self.faceRectView.isHidden = self.frameHistory.count <= 4
        self.renderFaceLabel(faceBounds: averageBounds, name: "Cal", display: self.frameHistory.count > 2)
    }
    
    func renderFaceLabel(faceBounds: CGRect?, name: String?, display: Bool) {
        faceLabel.isHidden = !display
        if display {
            faceLabel.text = name
            let labelBounds = CGRect(
                x: faceBounds!.origin.x,
                y: faceBounds!.origin.y - faceBounds!.size.height,
                width: faceBounds!.size.width,
                height: faceBounds!.size.width)
            faceLabel.frame = labelBounds
        }
    }
}
