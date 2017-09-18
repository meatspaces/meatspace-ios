//
//  MCPost.swift
//  MeatChat2
//
//  Created by Marcus Ramberg on 22/03/16.
//  Copyright © 2016 Nordaaker AS. All rights reserved.
//

import Foundation
import UIKit
import DateToolsSwift

class MCPost :NSObject {
    
    var postData: [String : AnyObject]
    var attributedString : NSAttributedString;
    var videoUrl : URL;
    var created :Int;
    var fingerprint :String;

    
    init(dict: NSDictionary ) {
        self.postData = dict.dictionaryWithValues(forKeys: ["message","created"]) as [String : AnyObject]
        self.created = (dict["created"] as? Int)!
        self.fingerprint = (dict["fingerprint"] as? String)!
        self.attributedString=NSAttributedString()
        let media: String = ((dict["media"]! as AnyObject).substring(from: 22) as String)
        self.videoUrl=URL(string: "")!
        super.init()
        self.setAttributedBody()
        let videoData: Data = Data(base64Encoded: media, options: NSData.Base64DecodingOptions.ignoreUnknownCharacters)!
            try? videoData.write(to: self.path()!, options: [])
        self.videoUrl = self.path()!
        do {
            try (self.videoUrl as NSURL).setResourceValue(true, forKey: URLResourceKey.isExcludedFromBackupKey)
        } catch {
            print(error)
        }
        return
    }
    
    func path() -> URL? {

        let fileManager = FileManager.default
        
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        
       let documentDirectory: URL = urls.first!
        let finalPath = documentDirectory.appendingPathComponent(String(self.created)+".mp4")
        return finalPath
    }
    
        
        
    func relativeTime() -> String {
        let epoch: TimeInterval = Double(created)/1000
        let postDate: Date = Date(timeIntervalSince1970: epoch)
        return postDate.timeAgoSinceNow
    }
    
    func cleanup() {
        do {
            try FileManager.default.removeItem(at: self.path()!)
        } catch {
            print(error)
        }
    }
    
    func isObsolete() -> Bool {
        return false
    }
    
    func setAttributedBody()  {
        let text: String = (self.postData["message"] as? String)!
        
        
        let html = "<html><head><style>* { margin: 0; padding:0; }p,body { font-family: Helvetica Neue;margin: 0;padding: 0; font-size:12px;} a { background-color: #95f7f1; color: #2d7470; text-decoration: none }</style></head><body><span>\(text)</span></body></html>"
        
        let paragraphStyle: NSMutableParagraphStyle = NSMutableParagraphStyle()
        

        do {
             let string:NSMutableAttributedString = try NSMutableAttributedString(data: html.data(using: String.Encoding.utf8)!, options: [NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType, NSCharacterEncodingDocumentAttribute: String.Encoding.utf8 ], documentAttributes: nil)
            string.addAttribute(NSBackgroundColorAttributeName, value: UIColor.white, range: NSMakeRange(0,string.length))
            string.addAttribute(NSForegroundColorAttributeName, value: UIColor(white: 0.23, alpha: 1.0), range: NSMakeRange(0,string.length))
            string.addAttribute(NSFontAttributeName, value: UIFont.systemFont(ofSize: 17), range: NSMakeRange(0,string.length))
            string.addAttribute(NSParagraphStyleAttributeName, value: paragraphStyle, range: NSMakeRange(0,string.length))
            self.attributedString=string

        } catch {
            print(error)
        }
    }
    
}
