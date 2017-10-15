//
//  UIImage+Rotate.swift
//  Nametag
//
//  Created by Cal Stephens on 10/14/17.
//  Copyright © 2017 Helluva. All rights reserved.
//

import UIKit

extension CGImage {
    func crop(rect: CGRect, padding: CGFloat = 0) -> CGImage {
        let scale = UIScreen.main.scale
        
        var scaleRect = CGRect(
            x: rect.origin.x * scale,
            y: rect.origin.y * scale,
            width: rect.size.width * scale,
            height: rect.size.height * scale)
        
        let unpadded = self.cropping(to: scaleRect)
        
        if padding != 0 {
            scaleRect.origin.x = max(0, scaleRect.origin.x - padding)
            scaleRect.origin.y = max(0, scaleRect.origin.y - padding)
            scaleRect.size.width = min(scaleRect.width + (padding*2), CGFloat(self.width) - scaleRect.origin.x)
            scaleRect.size.height = min(scaleRect.height + (padding*2), CGFloat(self.height) - scaleRect.origin.y)
        }
        
        
        let paddedImage = self.cropping(to: scaleRect)
        return paddedImage!
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
