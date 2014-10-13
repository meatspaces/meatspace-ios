//
//  MCPostListView.m
//  MeatChat
//
//  Created by Marcus Ramberg on 13.10.14.
//  Copyright (c) 2014 Nordaaker AS. All rights reserved.
//

#import "MCPostListView.h"

@implementation MCPostListView

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
  if([self.postListViewController.postViewController.view pointInside:point withEvent:event])
    return NO;
  
  return [super pointInside:point withEvent:event];
}

@end
