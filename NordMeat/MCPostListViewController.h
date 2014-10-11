//
//  NMeatViewController.h
//  NordMeat
//
//  Created by Marcus Ramberg on 14.01.14.
//  Copyright (c) 2014 Nordaaker AS. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <SIOSocket/SIOSocket.h>
#import <AVFoundation/AVAssetResourceLoader.h>

@interface MCPostListViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UITextViewDelegate, AVAssetResourceLoaderDelegate>


@property (weak, nonatomic)IBOutlet NSLayoutConstraint *containerHeight;
@property (strong, nonatomic)IBOutlet UITableView *tableView;
@property (retain,nonatomic) SIOSocket *socket;
@property (strong, nonatomic) NSString *ip;


@end
