//
//  Face.swift
//  Nametag
//
//  Created by Cal Stephens on 10/14/17.
//  Copyright © 2017 Helluva. All rights reserved.
//

import UIKit 

import UIKit

class Face: NSObject, NSCoding {
    
    let name: String
    let imageName: String
    var vectors: [FaceIdVector]
    
    var image: UIImage? {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last,
            let imageData = try? Data(contentsOf: documents.appendingPathComponent(imageName)),
            let image = UIImage(data: imageData) else
        {
            return nil
        }
        
        return image
    }
    
    // MARK: Initialize
    
    init(name: String, image: UIImage) {
        self.name = name
        self.vectors = []
        
        let imageName = UUID().uuidString
        self.imageName = imageName
        
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last else {
            return
        }
        
        let imagePath = documents.appendingPathComponent(imageName)
        
        if let jpeg = UIImageJPEGRepresentation(image, 0.8) {
            try? jpeg.write(to: imagePath)
        }
    }
    
    // MARK: NSCoding
    
    func encode(with encoder: NSCoder) {
        encoder.encode(name, forKey: "name")
        encoder.encode(vectors, forKey: "vectors")
        encoder.encode(imageName, forKey: "imageName")
    }
    
    required init?(coder decoder: NSCoder) {
        guard let name = decoder.decodeObject(forKey: "name") as? String,
            let vectors = decoder.decodeObject(forKey: "vectors") as? [FaceIdVector],
            let imageName = decoder.decodeObject(forKey: "imageName") as? String else
        {
            return nil
        }
        
        self.name = name
        self.vectors = vectors
        self.imageName = imageName
    }
    
    func addVector(_ vector: FaceIdVector) {
        vectors.append(vector)
        NTFaceDatabase.save()
    }
    
    // MARK: Calculations
    
    func totalSimilarity(with comparisonVector: FaceIdVector) -> Double {
        guard vectors.count > 0 else { return .greatestFiniteMagnitude }
        
        let similaritySum = vectors.reduce(Double(0), { sum, vector in
            return similarity(between: vector, and: comparisonVector)
        })
        
        return similaritySum / Double(vectors.count)
    }
    
    private func similarity(between vector: FaceIdVector, and otherVector: FaceIdVector) -> Double {
        let zippedVectors = zip(vector, otherVector)
        
        let sum = zippedVectors.reduce(Double(0), { sum, items in
            return sum + pow(items.0 - items.1, 2)
        })
        
        return sum
    }
}
