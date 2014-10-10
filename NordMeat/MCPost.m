//
//  NMeatPost.m
//  NordMeat
//
//  Created by Marcus Ramberg on 13.09.14.
//  Copyright (c) 2014 Nordaaker AS. All rights reserved.
//

#import "MCPost.h"
#import "NSDate+TimeAgo.h"


@implementation MCPost


-(id)initWithDictionary: (NSDictionary*)dict
{
  self = [super init];
  if(self) {
    self.postData=dict;
    self.attributedString=[self attributedBody];
    NSString *media=[[dict objectForKey: @"media"] substringFromIndex:22];
    NSData *videoData=[[NSData alloc] initWithBase64EncodedString: media options: NSDataBase64DecodingIgnoreUnknownCharacters];
    
    NSString *path;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSNumber *created=[dict objectForKey: @"created"];
    path = [[paths objectAtIndex:0] stringByAppendingPathComponent:[[created stringValue] stringByAppendingString: @".mp4"]];
    [videoData writeToFile: path atomically:NO];
    self.videoUrl=[NSURL fileURLWithPath: path];
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
  
  NSDictionary *options = @{NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType};
  
  NSError *error;
  NSDictionary *attributes;
  NSString *html=[NSString stringWithFormat: @"<html><p>%@</p></html>",text];
 NSAttributedString *string=[[NSAttributedString alloc] initWithData:[html dataUsingEncoding:NSUTF8StringEncoding] options:options documentAttributes:&attributes error:&error];
  return string;

  
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
