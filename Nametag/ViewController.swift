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

extension UIFont {
    static let detectionResult = UIFont.systemFont(ofSize: 30, weight: .bold)
    static let notableResultText = UIFont.systemFont(ofSize: 24, weight: .semibold)
    static let progressText = UIFont.systemFont(ofSize: 13, weight: .medium)
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
    var mostRecentUploadDate = Date.distantPast
    
    var overlayView: OverlayView?
    
    var alertTextForOverlayView: (text: String, font: UIFont)?
    
    
    var waitingForIntroductionResponse = false
    var waitingForDetectionResponse = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.delegate = self
        
        faceRectView.isHidden = true
        faceRectView.layer.borderColor = UIColor.white.cgColor
        faceRectView.alpha = 0.8
        faceRectView.layer.borderWidth = 3
        faceRectView.layer.cornerRadius = 15

        speechController.setup()
        speechController.delegate = self
        
        generateOverlayView()
    }
    
    @IBAction func swipeGestureRecognizer(_ sender: UISwipeGestureRecognizer) {
        let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "CollectionViewController") as! CollectionViewController
        viewController.modalPresentationStyle = .overCurrentContext
        self.present(viewController, animated: false, completion: nil)
    }
    
    @IBAction func pinchGestureRecognizer(_ sender: UIPinchGestureRecognizer) {
        guard let faceVisibleWhenAlertPresented = self.mostRecentFaceImage?.image,
            let faceImageDate = self.mostRecentFaceImage?.date,
            Date().timeIntervalSince(faceImageDate) < 0.5 else
        {
            let alert = UIAlertController(
                title: "No Face Found",
                message: "Could not find face.",
                preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
            return
        }
        
        let alert = UIAlertController(
            title: "Add Face",
            message: "Add a new face to the library.",
            preferredStyle: UIAlertControllerStyle.alert)
        alert.addTextField { (textField) in
            textField.placeholder = "Name"
        }
        alert.addAction(UIAlertAction(title: "Done", style: UIAlertActionStyle.default, handler: { _ in
            let name = alert.textFields?.first?.text
            self.mostRecentFaceImage = (Date(), faceVisibleWhenAlertPresented)
            self.saveNameAndMostRecentFace(name: name!)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
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
            
            let croppedImage = image.crop(rect: facebounds, padding: 50)
            self.mostRecentFaceImage = (Date(), UIImage(cgImage: croppedImage))
            
            if Date().timeIntervalSince(self.mostRecentUploadDate) > 2,
                !self.waitingForIntroductionResponse,
                !self.waitingForDetectionResponse
            {
                //upload image to azure
                self.mostRecentUploadDate = Date()
                self.compareFaceToKnownFaces(image: UIImage(cgImage: croppedImage))
            }
        }
    }
    
    func compareFaceToKnownFaces(image: UIImage) {
        
        let overlayIsNameText = NTFaceDatabase.faces.map({ $0.name }).contains(alertTextForOverlayView?.text ?? "----")
        if !overlayIsNameText {
            alertTextForOverlayView = ("Checking face...", .progressText)
        }
        
        waitingForDetectionResponse = true
        
        AzureClient.compareFaceToKnownFaces(image: image, completion: { comparisonResult in
            guard !self.waitingForIntroductionResponse else {
                self.waitingForDetectionResponse = false
                return
            }
            
            if let successfulResult = comparisonResult {
                self.alertTextForOverlayView = (successfulResult.0.name, .detectionResult)
                print(successfulResult.1)
            } else {
                self.alertTextForOverlayView = ("Unknown", .progressText)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1), execute: {
                self.waitingForDetectionResponse = false
            })
        })
    }
    
    // MARK: AR Overlays
    
    func updateDisplayLabels() {
        self.faceRectView.isHidden = (self.frameHistory.count < 2)

        let faceText = self.alertTextForOverlayView
        
        //reset existing matches when the face is gone
        if (self.frameHistory.count < 2) {
            self.alertTextForOverlayView = nil
        }
        
        self.updateOverlayView(
            faceBounds: averageBounds,
            name: faceText?.text,
            font: faceText?.font,
            display: self.frameHistory.count > 2)
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
    
    func updateOverlayView(faceBounds: CGRect?, name: String?, font: UIFont?, display: Bool) {
        
        guard let faceBounds = faceBounds,
            let overlayView = overlayView else
        {
            return
        }
        
        overlayView.isHidden = !display || name == nil
        if display {
            overlayView.label.text = name ?? "--"
            overlayView.label.font = font ?? overlayView.label.font
            overlayView.layoutSubviews()
            
            let widthDifference = abs(overlayView.frame.size.width - faceBounds.size.width) / 4
            overlayView.transform = CGAffineTransform(
                translationX: faceBounds.origin.x + widthDifference,
                y: faceBounds.origin.y - overlayView.frame.height - 35)
        }
    }    
}

// MARK: SpeechControllerDelegate

extension ViewController: SpeechControllerDelegate {
    
    func speechController(_ controller: SpeechController, didDetectIntroductionWithName name: String) {
       saveNameAndMostRecentFace(name: name)
    }
    
    func saveNameAndMostRecentFace(name: String) {
        DispatchQueue.main.async {
            if let mostRecentFaceImage = self.mostRecentFaceImage,
                Date().timeIntervalSince(mostRecentFaceImage.date) < 1.0,
                !self.waitingForIntroductionResponse
            {
                let newFace = Face(name: name, image: mostRecentFaceImage.image)
                NTFaceDatabase.addFace(newFace)
                
                
                self.alertTextForOverlayView = ("Uploading \(name)", .progressText)
                self.waitingForIntroductionResponse = true
                AzureClient.uploadFaceToAzureList(image: mostRecentFaceImage.image, completion: { faceId in
                    DispatchQueue.main.async {
                        self.alertTextForOverlayView = ("Saved \(name)!", .notableResultText)
                        
                        newFace.azureFaceId = faceId
                        print("\(name) >> \(faceId ?? "n/a")")
                        NTFaceDatabase.save()
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1), execute: {
                            self.waitingForIntroductionResponse = false
                            self.alertTextForOverlayView = nil
                        })
                    }
                })
                
            }
        }
    }
    
    func speechController(_ controller: SpeechController, updatedTextTo spokenText: String) {
        DispatchQueue.main.async {
            self.spokenTextLabel.text = spokenText
        }
    }
    
}
