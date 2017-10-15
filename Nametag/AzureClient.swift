//
//  AzureClient.swift
//  Nametag
//
//  Created by Cal Stephens on 10/15/17.
//  Copyright © 2017 Helluva. All rights reserved.
//

import UIKit

typealias FaceId = String

class AzureClient {
    
    static let baseURL = URL(string: "https://eastus.api.cognitive.microsoft.com/face/v1.0/")!
    static let subscriptionID = "7c620381ab224348bff450e2cef84ea3"
    static let faceListID = "nametag"
    
    static func endpoint(named name: String) -> URL {
        return baseURL.appendingPathComponent(name)
    }
    
    // MARK: Azure requests
    
    static func uploadFaceToAzure(image: UIImage, completion: @escaping (FaceId?) -> Void) {
        hostImageOnServer(image: image, completion: { hostedUrl in
            guard let hostedUrl = hostedUrl else {
                completion(nil)
                return
            }
            
            print("hosted new image at \(hostedUrl)")
            addFaceToList(from: hostedUrl, completion: completion)
        })
    }
    
    static func addFaceToList(from imageUrl: String, completion: @escaping (FaceId?) -> Void) {
        
        let body = [
            "url": imageUrl
        ]
        
        request(to: "facelists/\(faceListID)/persistedFaces", method: "POST", with: body) { (json) in
            guard let json = json as? [String: Any],
                let faceId = json["persistedFaceId"] as? String else
            {
                completion(nil)
                return
            }
            
            completion(faceId)
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
