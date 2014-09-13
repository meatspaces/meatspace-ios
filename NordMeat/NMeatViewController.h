//
//  NMeatViewController.h
//  NordMeat
//
//  Created by Marcus Ramberg on 14.01.14.
//  Copyright (c) 2014 Nordaaker AS. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SocketIO.h"

@interface NMeatViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, SocketIODelegate>

@property (weak,nonatomic) UITableView IBOutlet *tableView;

@end
