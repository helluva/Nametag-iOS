//
//  [CGRect]+Average.swift
//  Nametag
//
//  Created by Cal Stephens on 10/14/17.
//  Copyright © 2017 Helluva. All rights reserved.
//

import UIKit

// MARK: Add a protocol to CGFloat so it can be used in an Array extension

protocol Rectangle {
    var rect: CGRect { get }
}

extension CGRect: Rectangle {
    var rect: CGRect {
        return self
    }
}

// MARK: Calculate average frame from a [CGRect]

extension Array where Element: Rectangle {
    
    var average: CGRect {
        var cumX = CGFloat(0)
        var cumY = CGFloat(0)
        var cumWidth = CGFloat(0)
        var cumHeight = CGFloat(0)
        
        for item in self {
            cumX += item.rect.origin.x
            cumY += item.rect.origin.y
            cumWidth += item.rect.size.width
            cumHeight += item.rect.size.height
        }
        
        return CGRect(
            x: cumX / CGFloat(self.count),
            y: cumY / CGFloat(self.count),
            width: cumWidth / CGFloat(self.count),
            height: cumHeight / CGFloat(self.count))
    }
    
}
