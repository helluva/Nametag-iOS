//
//  FaceVectorDatabase.swift
//  Nametag
//
//  Created by Cal Stephens on 10/14/17.
//  Copyright © 2017 Helluva. All rights reserved.
//

import UIKit


let NTResetFaceDatabaseOnLaunch = false

let NTFaceDatabaseKey = "NTFaceDatabaseKey"
let NTFaceDatabase  = UserDefaults.standard.codedObjectForKey(NTFaceDatabaseKey) as? FaceDatabase ?? FaceDatabase()

class FaceDatabase: NSObject, NSCoding {
    
    fileprivate(set) var faces: [Face]
    
    override init() {
        self.faces = []
    }
    
    //MARK: - NSCoding Support
    
    required init?(coder decoder: NSCoder) {
        if NTResetFaceDatabaseOnLaunch {
            self.faces = []
        } else {
            self.faces = decoder.decodeObject(forKey: "faces") as? [Face] ?? []
        }
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(faces, forKey: "faces")
    }
    
    func save() {
        UserDefaults.standard.setCodedObject(self, forKey: NTFaceDatabaseKey)
        
        let totalVectors = faces.reduce(0, { sum, face in return sum + face.vectors.count })
        print("Saved \(faces.count) faces with \(totalVectors) total vectors")
    }
    
    func addFace(_ face: Face) {
        faces.append(face)
        save()
    }
    
    func removeFace(_ face: Face) {
        if let index = faces.index(of: face) {
            faces.remove(at: index)
            save()
        }
    }
    
    // MARK: Calculations
    
    func mostLikelyFaceMatch(for vector: FaceIdVector) -> Face? {
        
        let sortedFaces = faces.sorted(by: { left, right in
            return left.totalSimilarity(with: vector) < right.totalSimilarity(with: vector)
        })
        
        let stringArray = sortedFaces.map { face in
            return "\(face.name) has similarity \(face.totalSimilarity(with: vector))"
        }
        
        print(stringArray.description)
        
        return nil
    }
    
}

///Add dedicated NSCoding methods to cut down on boilerplate everywhere else
extension UserDefaults {
    
    func setCodedObject(_ value: NSCoding, forKey key: String) {
        let data = NSKeyedArchiver.archivedData(withRootObject: value)
        set(data, forKey: key)
    }
    
    func codedObjectForKey(_ key: String) -> AnyObject? {
        if let data = object(forKey: key) as? Data {
            return NSKeyedUnarchiver.unarchiveObject(with: data) as AnyObject
        }
        return nil
    }
    
}
