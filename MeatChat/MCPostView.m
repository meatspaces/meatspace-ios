//
//  MCPostView.m
//  MeatChat
//
//  Created by Marcus Ramberg on 13.10.14.
//  Copyright (c) 2014 Nordaaker AS. All rights reserved.
//

#import "MCPostView.h"

@implementation MCPostView


- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
  NSLog(@"Looking for %@ in %@",NSStringFromCGPoint(point),NSStringFromCGRect(self.postButton.bounds));
  if ( CGRectContainsPoint(self.postButton.bounds, point) )
    return YES;
  
  return [super pointInside:point withEvent:event];
}



@end
