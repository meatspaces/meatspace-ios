//
//  NMAppDelegate.m
//  MeatChat
//
//  Created by Marcus Ramberg on 14.01.14.
//  Copyright (c) 2014 Nordaaker AS. All rights reserved.
//

#import "MCAppDelegate.h"
#import "TestFlight.h"
#import <AVFoundation/AVFoundation.h>
#import "MCPostListViewController.h"

@implementation MCAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  // Override point for customization after application launch.
  [TestFlight takeOff:@"15b86d3f-cf9f-4729-b1be-d4263f01d8ab"];

  [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient error:nil];

  NSDictionary *defaultDefaults = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"DefaultDefaults" ofType:@"plist"]];
  [[NSUserDefaults standardUserDefaults] registerDefaults:defaultDefaults];
  
  return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
  // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
  // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
  // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
  // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
  MCPostListViewController *vc=(MCPostListViewController*)[(UINavigationController*)self.window.rootViewController topViewController];
  [vc.postViewController closePostWithPosted: NO];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
  // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
  MCPostListViewController *vc=(MCPostListViewController*)[(UINavigationController*)self.window.rootViewController topViewController];
  [vc resumePlay];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
  // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
  // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
  MCPostListViewController *vc=(MCPostListViewController*)[(UINavigationController*)self.window.rootViewController topViewController];
  [vc flushItems];
}

@end
