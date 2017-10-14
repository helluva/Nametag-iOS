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
    var vectors: [FaceIdVector]
    
    // MARK: Initialize
    
    init(name: String, vectors: [FaceIdVector]) {
        self.name = name
        self.vectors = vectors
    }
    
    // MARK: NSCoding
    
    func encode(with encoder: NSCoder) {
        encoder.encode(name, forKey: "name")
        encoder.encode(vectors, forKey: "vectors")
    }
    
    required init?(coder decoder: NSCoder) {
        guard let name = decoder.decodeObject(forKey: "name") as? String,
            let vectors = decoder.decodeObject(forKey: "vectors") as? [FaceIdVector] else
        {
            return nil
        }
        
        self.name = name
        self.vectors = vectors
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
