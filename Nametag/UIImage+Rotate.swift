//
//  UIImage+Rotate.swift
//  Nametag
//
//  Created by Cal Stephens on 10/14/17.
//  Copyright © 2017 Helluva. All rights reserved.
//

import UIKit

extension CGImage {
    func crop(rect: CGRect) -> CGImage {
        let scale = UIScreen.main.scale
        let scaleRect = CGRect(
            x: rect.origin.x * scale,
            y: rect.origin.y * scale,
            width: rect.size.width * scale,
            height: rect.size.height * scale)
        let imageRef = self.cropping(to: scaleRect)
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
