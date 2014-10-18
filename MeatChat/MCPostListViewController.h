//
//  MCPostListViewController.h
//  MeatChat
//
//  Created by Marcus Ramberg on 14.01.14.
//  Copyright (c) 2014 Nordaaker AS. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <SIOSocket/SIOSocket.h>
#import <AVFoundation/AVAssetResourceLoader.h>
#import "MCPostViewController.h"

@interface MCPostListViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UITextViewDelegate, AVAssetResourceLoaderDelegate>

@property (weak, nonatomic)IBOutlet NSLayoutConstraint *containerHeight;
@property (strong, nonatomic)IBOutlet UITableView *tableView;
@property (retain,nonatomic) SIOSocket *socket;
@property (nonatomic,weak) MCPostViewController *postViewController;

- (void)flushItems;
-(void)scrollToBottom;

@end
