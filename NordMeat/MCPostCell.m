//
//  NMeatCell.m
//  NordMeat
//
//  Created by Marcus Ramberg on 14.01.14.
//  Copyright (c) 2014 Nordaaker AS. All rights reserved.
//

#import "MCPostCell.h"

@implementation MCPostCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

-(void)awakeFromNib
{
      self.videoPlayer=[[AVPlayer alloc] init];
  AVPlayerLayer *layer=[AVPlayerLayer playerLayerWithPlayer: self.videoPlayer];
  self.videoPlayer.actionAtItemEnd=AVPlayerActionAtItemEndNone;
  layer.frame=CGRectMake(0, 0, 100, 75);
  layer.videoGravity=AVLayerVideoGravityResizeAspectFill;
  [self.video.layer addSublayer: layer];
}


- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}


@end
