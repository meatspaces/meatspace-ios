//
//  NMeatPost.m
//  NordMeat
//
//  Created by Marcus Ramberg on 13.09.14.
//  Copyright (c) 2014 Nordaaker AS. All rights reserved.
//

#import "NMeatPost.h"
#import "UIImage+animatedGIF.h"
#import "NSDate+TimeAgo.h"


@implementation NMeatPost


-(id)initWithDictionary: (NSDictionary*)dict
{
  self = [super init];
  if(self) {
    self.postData=dict;
    self.image=[UIImage animatedImageWithAnimatedGIFURL: [NSURL URLWithString: [dict objectForKey: @"media"]]];
  }

  return self;
}

- (NSString*)relativeTime
{
  NSDate *postDate=[NSDate dateWithTimeIntervalSince1970: [[self.postData objectForKey: @"created"] integerValue]/1000];
 return [postDate dateTimeAgo];
}

- (NSAttributedString*)attributedBody {
  NSString *text=[self.postData objectForKey: @"message"];
  // Let's make an NSAttributedString first
  if(!text) {
    return [[NSAttributedString alloc] init];
  }
  NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:text];
  // Add Background Color for Smooth rendering
  [attributedString setAttributes:@{NSBackgroundColorAttributeName:[UIColor whiteColor]} range:NSMakeRange(0, attributedString.length)];
  // Add Main Font Color
  [attributedString setAttributes:@{NSForegroundColorAttributeName:[UIColor colorWithWhite:0.23 alpha:1.0]} range:NSMakeRange(0, attributedString.length)];
  // Add paragraph style
  NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
  [paragraphStyle setLineBreakMode:NSLineBreakByWordWrapping];
  [attributedString setAttributes:@{NSParagraphStyleAttributeName:paragraphStyle} range:NSMakeRange(0, attributedString.length)];
  // Add Font
  [attributedString setAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:17]} range:NSMakeRange(0, attributedString.length)];
  // And finally set the text on the label to use this
  return attributedString;
  
}


@end
