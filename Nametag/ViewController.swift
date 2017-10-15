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

enum FaceMode {
    case waitingForInput
    case analyzingIntroduction(Face)
    case detectPeople(detected: Face?)
    
    var faceBeingBuilt: Face? {
        switch self {
        case .analyzingIntroduction(let face):
            return face
        default:
            return nil
        }
    }
    
    var isWaitingForInput: Bool {
        switch self {
        case .waitingForInput: return true
        default: return false
        }
    }
    
    var isAnalyzingIntroduction: Bool {
        switch(self) {
        case .analyzingIntroduction(_): return true
        default: return false
        }
    }
    
    var isDetectingPeople: Bool {
        switch(self) {
        case .detectPeople(_): return true
        default: return false
        }
    }
    
}

class ViewController: UIViewController, ARSCNViewDelegate {
    
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var faceRectView: UIView!
    @IBOutlet weak var spokenTextLabel: UILabel!
    @IBOutlet weak var detectPeopleButton: UIButton!
    
    let speechController = SpeechController()
    
    var frameHistory = [CGRect]()
    var averageBounds: CGRect!
    
    var mostRecentFaceImage: (date: Date, image: UIImage)?
    
    var overlayView: OverlayView?
    
    var mode = FaceMode.waitingForInput
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.delegate = self
        
        faceRectView.isHidden = true
        faceRectView.layer.borderColor = UIColor.red.cgColor
        faceRectView.layer.borderWidth = 5
        
        speechController.setup()
        speechController.delegate = self
        
        generateOverlayView()
    }
    
    @IBAction func swipeGestureRecognizer(_ sender: UISwipeGestureRecognizer) {
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "CollectionViewController") as! CollectionViewController
        viewController.modalPresentationStyle = .overCurrentContext
        self.present(viewController, animated: false, completion: nil)
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
        guard let pixelBuffer = sceneView.session.currentFrame?.capturedImage else {
            return
        }
        
        //DispatchQueue.global(qos: .background).async {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let temporaryContext = CIContext(options: nil)
        let videoImage = temporaryContext.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer)))
        
        guard let imageFromFeed = videoImage?.rotate() else {
            return
        }
        
        let request = VNDetectFaceRectanglesRequest(completionHandler: self.bindImageToFaceDetectionHandler(imageFromFeed))
        let requestHandler = VNImageRequestHandler(cgImage: imageFromFeed, orientation: .up, options: [:])
        try? requestHandler.perform([request])
        //}
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
                self.updateDisplayLabels()
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
            
            self.mostRecentFaceImage = (Date(), UIImage(cgImage: image.crop(rect: facebounds, padding: 50)))
        }
        
    }
    
    // MARK: AR Overlays
    
    func updateDisplayLabels() {
        self.faceRectView.isHidden = (self.frameHistory.count <= 4)
        self.detectPeopleButton.isHidden = (!self.mode.isWaitingForInput)
        self.spokenTextLabel.isHidden = (self.mode.isDetectingPeople)

        let faceText = "Name"
        
        self.updateOverlayView(faceBounds: averageBounds, name: faceText, display: self.frameHistory.count > 2)
        print(self.frameHistory.count)
    }
    
    // MARK: Static overlays
    
    func generateOverlayView() {
        let indicator = OverlayView(
            text: "Testing",
            showLoadingIndicator: false,
            textColor: .black,
            textSize: 20)
        
        self.overlayView = indicator
        
        view.addSubview(indicator)
        overlayView?.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 20).isActive = true
        overlayView?.topAnchor.constraint(equalTo: view.topAnchor, constant: 20).isActive = true
        
        overlayView?.isHidden = true
    }
    
    func updateOverlayView(faceBounds: CGRect?, name: String, display: Bool) {
        
        guard let faceBounds = faceBounds,
            let overlayView = overlayView else
        {
            return
        }
        
        overlayView.isHidden = !display
        if display {
            let widthDifference = abs(overlayView.frame.size.width - faceBounds.size.width) / 4
            overlayView.transform = CGAffineTransform(translationX: faceBounds.origin.x + widthDifference, y: faceBounds.origin.y - 75)
            overlayView.label.text = name
        }
    }
    
    // MARK: Buttons
    
    @IBAction func userTappedDetectPeopleButton() {
        if self.mode.isWaitingForInput {
            self.mode = .detectPeople(detected: nil)
            self.detectPeopleButton.setImage(#imageLiteral(resourceName: "cancel"), for: .normal)
        } else if self.mode.isDetectingPeople {
            self.mode = .waitingForInput
            self.detectPeopleButton.setImage(#imageLiteral(resourceName: "who"), for: .normal)
        }
    }
    
    
}

// MARK: SpeechControllerDelegate

extension ViewController: SpeechControllerDelegate {
    
    func speechController(_ controller: SpeechController, didDetectIntroductionWithName name: String) {
        
        guard mode.isWaitingForInput else {
            return
        }
        
        DispatchQueue.main.async {
            if let mostRecentFaceImage = self.mostRecentFaceImage,
                Date().timeIntervalSince(mostRecentFaceImage.date) < 1.0
            {                
                let newFace = Face(name: name, image: mostRecentFaceImage.image)
                self.mode = .analyzingIntroduction(newFace)
                NTFaceDatabase.addFace(newFace)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2), execute: {
                    self.mode = .waitingForInput
                })
            } else {
                print(Date().timeIntervalSince((self.mostRecentFaceImage?.date)!))
            }
        }
    }
    
    func speechController(_ controller: SpeechController, updatedTextTo spokenText: String) {
        DispatchQueue.main.async {
            self.spokenTextLabel.text = spokenText
        }
    }
    
}
