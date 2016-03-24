//
//  MCAppDelegate.swift
//  MeatChat2
//
//  Created by Marcus Ramberg on 24/03/16.
//  Copyright © 2016 Nordaaker AS. All rights reserved.
//

import UIKit
import AVFoundation

class MCAppDelegate : UIResponder, UIApplicationDelegate {
    
    var window:UIWindow?
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
        
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryAmbient)
        } catch {
            print(error)
        }
        
        let defaultDefaults = NSDictionary(contentsOfFile: NSBundle.mainBundle().pathForResource("DefaultDefaults", ofType: "plist")!) as? Dictionary<String,AnyObject>
        NSUserDefaults.standardUserDefaults().registerDefaults(defaultDefaults!)
        
        return true
    }
    
    func applicationDidEnterBackground(application: UIApplication) {
        if let nc=self.window?.rootViewController as? UINavigationController {
            if let vc=nc.topViewController as? MCPostListViewController {
                vc.postViewController?.closePostWithPosted(false)
            }
        }
    }
    
    func applicationWillEnterForeground(application: UIApplication) {
        if let nc=self.window?.rootViewController as? UINavigationController {
            if let vc=nc.topViewController as? MCPostListViewController {
                vc.resumePlay()
            }
        }
    }
    
    func applicationWillTerminate(application: UIApplication) {
        if let nc=self.window?.rootViewController as? UINavigationController {
            if let vc=nc.topViewController as? MCPostListViewController {
                vc.flushItems()
            }
        }
    }
}
