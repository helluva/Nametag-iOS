//
//  SpeechController.swift
//  Nametag
//
//  Created by Nate Thompson on 10/14/17.
//  Copyright © 2017 Helluva. All rights reserved.
//

import Foundation
import AVFoundation
import Speech

protocol SpeechControllerDelegate: class {
    func speechController(_ controller: SpeechController, didDetectIntroductionWithName name: String)
    func speechController(_ controller: SpeechController, updatedTextTo spokenText: String)
}

class SpeechController: NSObject, SFSpeechRecognizerDelegate {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    weak var delegate: SpeechControllerDelegate?
    
    func setup() {
        speechRecognizer?.delegate = self
        
        SFSpeechRecognizer.requestAuthorization { (authStatus) in
            switch authStatus {
            case .authorized:
                print("Speech recognition authorized!")
                self.startListening()
                
            case .denied:
                print("User denied access to speech recognition")
                
            case .restricted:
                print("Speech recognition restricted on this device")
                
            case .notDetermined:
                print("Speech recognition not yet authorized")
            }
        }
    }
    
    func startListening() {
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSessionCategoryRecord)
            try audioSession.setMode(AVAudioSessionModeMeasurement)
            try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        } catch {
            print("audioSession properties weren't set because of an error.")
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = audioEngine.inputNode
        
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in
            
            var isFinal = false
            
            if result != nil {
                isFinal = (result?.isFinal)!
            }
            
            guard let bestTranscription = result?.bestTranscription.formattedString else {
                return
            }
            
            let resultString = bestTranscription as NSString
            let resultStringLowercased = bestTranscription.lowercased() as NSString
            
            self.delegate?.speechController(self, updatedTextTo: "\(resultString)")
            
            let keywords = ["hi i'm", "hello i'm", "hey i'm", "i am"]
            let existingKeywordRange = keywords.flatMap { keyword -> NSRange? in
                let range = resultStringLowercased.range(of: keyword)
                guard range.location != NSNotFound else { return nil }
                return range
            }.first
            
            if let existingKeywordRange = existingKeywordRange {
                let index = existingKeywordRange.location + existingKeywordRange.length
                if index < resultString.length {
                    let name = resultString.substring(from: index).trimmingCharacters(in: .whitespaces)
                    print("NAME: \(name)")
                    isFinal = true
                    
                    self.delegate?.speechController(self, didDetectIntroductionWithName: name)
                }
            }
            
            if resultStringLowercased.length > 20 {
                let words = resultStringLowercased.components(separatedBy: " ")
                let lastWord = words.last
                let allPossibleKeywords = keywords.flatMap { $0.components(separatedBy: " ") }
                if !allPossibleKeywords.contains(lastWord ?? "--") {
                    isFinal = true
                }
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                isFinal = false
                self.startListening()
            }
        })
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            print("audioEngine couldn't start because of an error.")
        }
    }
}
