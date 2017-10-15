//
//  AzureClient.swift
//  Nametag
//
//  Created by Cal Stephens on 10/15/17.
//  Copyright © 2017 Helluva. All rights reserved.
//

import UIKit

typealias FaceId = String
typealias Confidence = Double

class AzureClient {
    
    static let baseURL = URL(string: "https://eastus.api.cognitive.microsoft.com/face/v1.0/")!
    static let subscriptionID = "7c620381ab224348bff450e2cef84ea3"
    static let faceListID = "nametag"
    
    static func endpoint(named name: String) -> URL {
        return baseURL.appendingPathComponent(name)
    }
    
    // MARK: Azure requests
    
    static func uploadFaceToAzureList(image: UIImage, completion: @escaping (FaceId?) -> Void) {
        hostImageOnServer(image: image, completion: { hostedUrl in
            guard let hostedUrl = hostedUrl else {
                completion(nil)
                return
            }
            
            print("hosted new image at \(hostedUrl)")
            uploadFace(at: hostedUrl, completion: completion)
        })
    }
    
    static func compareFaceToKnownFaces(image: UIImage, completion: @escaping ((Face, Confidence)?) -> Void) {
        hostImageOnServer(image: image) { url in
            guard let hostedUrl = url else {
                completion(nil)
                return
            }
            
            uploadFace(at: hostedUrl, completion: { faceId in
                guard let faceId = faceId else {
                    completion(nil)
                    return
                }
                
                let allFaceIds = NTFaceDatabase.allFaceIds
                guard allFaceIds.count != 0 else {
                    completion(nil)
                    return
                }
                
                compareFaceId(faceId, to: allFaceIds, completion: completion)
            })
            
        }
    }
    
    private static func uploadFace(at imageUrl: String, completion: @escaping (FaceId?) -> Void) {
        
        let body = [
            "url": imageUrl
        ]
        
        request(to: "detect", method: "POST", with: body) { (json) in
            guard let json = json as? [[String: Any]],
                let faceId = json.first?["faceId"] as? String else
            {
                completion(nil)
                return
            }
            
            completion(faceId)
        }
    }
    
    private static func compareFaceId(_ faceId: FaceId, to others: [FaceId], completion: @escaping ((Face, Confidence)?) -> Void) {
        
        let body: [String: Any] = [
            "faceId": faceId,
            "faceIds": others
        ]
        
        request(to: "findsimilars", method: "POST", with: body) { (jsonResponse) in
            guard let json = jsonResponse as? [[String: Any]] else {
                print(jsonResponse)
                completion(nil)
                return
            }
            
            let possibleMostLikelyFaceInfo = json.max(by: {
                ($0["confidence"] as? Double ?? -1) < ($1["confidence"] as? Double ?? -1)
            })
            
            guard let mostLikelyFaceInfo = possibleMostLikelyFaceInfo,
                let mostLikelyFaceId = mostLikelyFaceInfo["faceId"] as? String,
                let confidence = mostLikelyFaceInfo["confidence"] as? Double,
                let mostLikelyFace = NTFaceDatabase.faces.first(where: { $0.azureFaceId == mostLikelyFaceId }) else
            {
                completion(nil)
                return
            }
            
            completion((mostLikelyFace, confidence))
        }
        
    }
    
    static func request(
        to endpointName: String,
        method: String,
        with body: [String: Any],
        completion: @escaping (Any?) -> Void)
    {
        let request = NSMutableURLRequest(url: endpoint(named: endpointName))
        request.addValue(subscriptionID, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let jsonData = try? JSONSerialization.data(withJSONObject: body, options: [])
        request.httpBody = jsonData
        request.httpMethod = method
        
        URLSession.shared.dataTask(with: request as URLRequest, completionHandler: { (data: Data?, response: URLResponse?, error: Error?) in
            if let data = data,
                let jsonObject = try? JSONSerialization.jsonObject(with: data, options: [])
            {
                completion(jsonObject)
            } else {
                completion(nil)
            }
        }).resume()
    }
    
    // MARK: server.calstephens.tech requests
    
    static let imageServerBaseURL = URL(string: "http://server.calstephens.tech:8081/hostImage")!
    
    static func hostImageOnServer(image: UIImage, completion: @escaping (String?) -> Void) {
        
        let imageData = UIImagePNGRepresentation(image)!
        let base64Data = imageData.base64EncodedData()
        let base64String = String(data: base64Data, encoding: .utf8)!.replacingOccurrences(of: "\n", with: "")
        
        let bodyJson = "{\"image\": \"\(base64String)\", \"imageName\": \"\(UUID().uuidString)\"}"
        
        //post the data
        var request = URLRequest(url: imageServerBaseURL)
        request.httpMethod = "POST"
        request.httpBody = bodyJson.data(using: .utf8)
        request.setValue("application/json", forHTTPHeaderField:"Content-Type")
        
        URLSession.shared.dataTask(with: request, completionHandler: { (data, _, error) -> () in
            if let data = data,
                let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                let url = json?["url"] as? String
            {
                    completion(url)
            }
                
            else {
                //something went wrong
                completion(nil)
            }
        }).resume()
    }
    
}
