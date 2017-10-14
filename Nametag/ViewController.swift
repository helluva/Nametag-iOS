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

extension UIImage {
    func crop( percentageRect: CGRect) -> UIImage {
        let pixelRect = CGRect(
            x: percentageRect.origin.x * self.size.width,
            y: percentageRect.origin.y * self.size.height,
            width: percentageRect.width * self.size.height,
            height: percentageRect.height * self.size.width)
        
        let imageRef = self.cgImage!.cropping(to: pixelRect)
        let image = UIImage(cgImage: imageRef!, scale: self.scale, orientation: self.imageOrientation)
        return image
    }
    
    func rotate() -> UIImage {
        let rotatedSize = CGSize(width: self.size.height, height: self.size.width)
        // Create the bitmap context
        UIGraphicsBeginImageContext(rotatedSize)
        let bitmap = UIGraphicsGetCurrentContext()!
        
        // Move the origin to the middle of the image so we will rotate and scale around the center.
        bitmap.translateBy(x: rotatedSize.width / 2.0, y: rotatedSize.height / 2.0)
        
        //   // Rotate the image context
        bitmap.rotate(by: CGFloat.pi / 2)
        
        // Now, draw the rotated/scaled image into the context
        bitmap.scaleBy(x: 1.0, y: -1.0)
        bitmap.draw(self.cgImage!, in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage!
    }
}

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    var image: UIImage!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.delegate = self
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
        
        image = UIImage(cgImage: videoImage!)
        image = image.rotate()
        
        let faceLandmarksRequest = VNDetectFaceRectanglesRequest(completionHandler: self.handleFaceFeatures)
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        do {
            try requestHandler.perform([faceLandmarksRequest])
        } catch {
            print(error)
        }
    }

    func handleFaceFeatures(request: VNRequest, errror: Error?) {
        guard let observations = request.results as? [VNFaceObservation] else {
            fatalError("unexpected result type!")
        }
        
        print(observations)
        
        for face in observations {
            image = image.crop(percentageRect: face.boundingBox)
            print(image)
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
