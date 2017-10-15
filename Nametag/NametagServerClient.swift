//
//  NametagServerClient.swift
//  Nametag
//
//  Created by Cal Stephens on 10/14/17.
//  Copyright © 2017 Helluva. All rights reserved.
//

import UIKit

typealias FaceIdVector = [Double]

struct NametagServerClient {
    
    static let baseURL = URL(string: "http://server.calstephens.tech:8081")!
    
    static func fetchFaceAnalysisResult(image: UIImage, completion: @escaping (FaceIdVector?) -> Void) {
        
        let imageData = UIImagePNGRepresentation(image)!
        let base64Data = imageData.base64EncodedData()
        let base64String = String(data: base64Data, encoding: .utf8)!.replacingOccurrences(of: "\n", with: "")
        
        let bodyJson = "{\"image\": \"\(base64String)\"}"
        
        //post the data
        let url = NametagServerClient.baseURL.appendingPathComponent("/calculateVector")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = bodyJson.data(using: .utf8)
        request.setValue("application/json", forHTTPHeaderField:"Content-Type")
        
        URLSession.shared.dataTask(with: request, completionHandler: { (data, _, error) -> () in
            if let data = data,
                let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                let rawVectorString = json?["analysisOutput"] as? String
            {
                let vectorString = rawVectorString.replacingOccurrences(of: "[", with: "")
                    .replacingOccurrences(of: "]", with: "")
                    .replacingOccurrences(of: "\n", with: "")
                
                let vector = vectorString.components(separatedBy: "  ").map { (rawDoubleString: String) -> Double in
                    let doubleString = rawDoubleString.replacingOccurrences(of: " ", with: "")
                    return (doubleString as NSString).doubleValue
                }
                
                completion(vector)
            }
            
            else {
                //something went wrong
                completion(nil)
            }
        }).resume()
    }
    
}
