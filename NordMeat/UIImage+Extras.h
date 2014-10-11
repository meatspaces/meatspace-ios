//
//  UIImage+Extras.h
//  MeatChat
//
//  Created by Marcus Ramberg on 11.10.14.
//  Copyright (c) 2014 Nordaaker AS. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (Extras)

- (UIImage*)imageByScalingAndCroppingForSize:(CGSize)targetSize;
@end
