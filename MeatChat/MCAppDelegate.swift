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
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryAmbient)
        } catch {
            print(error)
        }
        
        let defaultDefaults = NSDictionary(contentsOfFile: Bundle.main.path(forResource: "DefaultDefaults", ofType: "plist")!) as? Dictionary<String,AnyObject>
        UserDefaults.standard.register(defaults: defaultDefaults!)
        
        return true
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        if let nc=self.window?.rootViewController as? UINavigationController {
            if let vc=nc.topViewController as? MCPostListViewController {
                vc.postViewController?.closePostWithPosted(false)
            }
        }
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        if let nc=self.window?.rootViewController as? UINavigationController {
            if let vc=nc.topViewController as? MCPostListViewController {
                vc.resumePlay()
            }
        }
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        if let nc=self.window?.rootViewController as? UINavigationController {
            if let vc=nc.topViewController as? MCPostListViewController {
                vc.flushItems()
            }
        }
    }
}
