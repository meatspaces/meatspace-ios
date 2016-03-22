//
//  MCPost.swift
//  MeatChat2
//
//  Created by Marcus Ramberg on 22/03/16.
//  Copyright © 2016 Nordaaker AS. All rights reserved.
//

import Foundation
import UIKit

class MCPost :NSObject {
    
    var postData: [String : AnyObject]
    var attributedString : NSAttributedString;
    var videoUrl : NSURL;
    var created :Int;
    var fingerprint :String;

    
    init(dict: NSDictionary ) {
        self.postData = dict.dictionaryWithValuesForKeys(["message","created"])
        self.created = (dict["created"] as? Int)!
        self.fingerprint = (dict["fingerprint"] as? String)!
        self.attributedString=NSAttributedString()
        let media: String = (dict["media"]!.substringFromIndex(22) as String)
        self.videoUrl=NSURL()
        super.init()
        self.setAttributedBody()
        let videoData: NSData = NSData(base64EncodedString: media, options: NSDataBase64DecodingOptions.IgnoreUnknownCharacters)!
            videoData.writeToURL(self.path()!, atomically: false)
        self.videoUrl = self.path()!
        do {
            try self.videoUrl.setResourceValue(true, forKey: NSURLIsExcludedFromBackupKey)
        } catch {
            print(error)
        }
        return
    }
    
    func path() -> NSURL? {

        let fileManager = NSFileManager.defaultManager()
        
        let urls = fileManager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        
       let documentDirectory: NSURL = urls.first!
        let finalPath = documentDirectory.URLByAppendingPathComponent(String(self.created)+".mp4")
        return finalPath
    }
    
        
        
    func relativeTime() -> String {
        let epoch: NSTimeInterval = Double(created)/1000
        let postDate: NSDate = NSDate(timeIntervalSince1970: epoch)
        return postDate.dateTimeAgo()
    }
    
    func cleanup() {
        do {
            try NSFileManager.defaultManager().removeItemAtURL(self.path()!)
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
             let string:NSMutableAttributedString = try NSMutableAttributedString(data: html.dataUsingEncoding(NSUTF8StringEncoding)!, options: [NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType, NSCharacterEncodingDocumentAttribute: NSUTF8StringEncoding ], documentAttributes: nil)
            string.addAttribute(NSBackgroundColorAttributeName, value: UIColor.whiteColor(), range: NSMakeRange(0,string.length))
            string.addAttribute(NSForegroundColorAttributeName, value: UIColor(white: 0.23, alpha: 1.0), range: NSMakeRange(0,string.length))
            string.addAttribute(NSFontAttributeName, value: UIFont.systemFontOfSize(17), range: NSMakeRange(0,string.length))
            string.addAttribute(NSParagraphStyleAttributeName, value: paragraphStyle, range: NSMakeRange(0,string.length))
            self.attributedString=string

        } catch {
            print(error)
        }
    }
    
}
