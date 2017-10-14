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

extension CGImage {
    func crop( percentageRect: CGRect) -> CGImage {
        let pixelRect = CGRect(
            x: percentageRect.origin.x * CGFloat(self.width),
            y: percentageRect.origin.y * CGFloat(self.height),
            width: percentageRect.width * CGFloat(self.width),
            height: percentageRect.height * CGFloat(self.height))
        let imageRef = self.cropping(to: pixelRect)
        return imageRef!
    }
    
    func rotate() -> CGImage {
        let rotatedSize = CGSize(width: self.height, height: self.width)
        // Create the bitmap context
        UIGraphicsBeginImageContext(rotatedSize)
        let bitmap = UIGraphicsGetCurrentContext()!
        
        // Move the origin to the middle of the image so we will rotate and scale around the center.
        bitmap.translateBy(x: rotatedSize.width / 2.0, y: rotatedSize.height / 2.0)
        
        //   // Rotate the image context
        bitmap.rotate(by: CGFloat.pi / 2)
        
        // Now, draw the rotated/scaled image into the context
        bitmap.scaleBy(x: 1.0, y: -1.0)
        bitmap.draw(self, in: CGRect(x: -width / 2, y: -height / 2, width: width, height: height))
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()?.cgImage
        UIGraphicsEndImageContext()
        
        return newImage!
    }
}

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var faceRectView: UIView!
    
    var image: CGImage!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.delegate = self
        
        faceRectView.isHidden = true
        faceRectView.layer.borderColor = UIColor.red.cgColor
        faceRectView.layer.borderWidth = 5
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard let pixelBuffer = sceneView.session.currentFrame?.capturedImage else {return}
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let temporaryContext = CIContext(options: nil)
        let videoImage = temporaryContext.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer)))
        
        image = videoImage!.rotate()
        
        let faceLandmarksRequest = VNDetectFaceRectanglesRequest(completionHandler: self.bindImageToFaceDetectionHandler(image))
        let requestHandler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        do {
            try requestHandler.perform([faceLandmarksRequest])
        } catch {
            print(error)
        }
    }

    func bindImageToFaceDetectionHandler(_ image: CGImage) -> ((VNRequest, Error?) -> Void) {
        
        return { (request: VNRequest, error: Error?) -> Void in
            guard let observations = request.results as? [VNFaceObservation] else {
                fatalError("unexpected result type!")
            }
            
            let largestFace = observations.max(by: { (face1: VNFaceObservation, face2: VNFaceObservation) -> Bool in
                let face1Area = face1.boundingBox.size.height * face1.boundingBox.size.width
                let face2Area = face2.boundingBox.size.height * face2.boundingBox.size.width
                return face1Area < face2Area
            })
            
            if let largestFace = largestFace {
                if largestFace.boundingBox.size.width >= 0.33 {
                    let faceImage = image.crop(percentageRect: largestFace.boundingBox)
                    
                    DispatchQueue.main.async {
                        let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -self.view.frame.height)
                        let translate = CGAffineTransform.identity.scaledBy(x: self.view.frame.width, y: self.view.frame.height)
                        let facebounds = largestFace.boundingBox.applying(translate).applying(transform)
                        self.faceRectView.frame = facebounds
                        self.faceRectView.isHidden = false
                    }
                } else {
                    DispatchQueue.main.async {
                        self.faceRectView.isHidden = true
                    }
                }
            }
            if observations.count == 0 {
                DispatchQueue.main.async {
                    self.faceRectView.isHidden = true
                }
            }
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}
