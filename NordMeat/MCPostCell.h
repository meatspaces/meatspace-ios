//
//  NMeatCell.h
//  NordMeat
//
//  Created by Marcus Ramberg on 14.01.14.
//  Copyright (c) 2014 Nordaaker AS. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface MCPostCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UIImageView *video;
@property (weak, nonatomic) IBOutlet UILabel *timeLabel;
@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (strong,nonatomic) AVPlayer *videoPlayer;


@end
