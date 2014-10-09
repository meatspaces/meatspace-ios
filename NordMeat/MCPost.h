//
//  NMeatPost.h
//  NordMeat
//
//  Created by Marcus Ramberg on 13.09.14.
//  Copyright (c) 2014 Nordaaker AS. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MCPost : NSObject

@property (nonatomic,strong) NSDictionary *postData;
@property (nonatomic,strong) NSAttributedString *attributedString;

-(id)initWithDictionary: (NSDictionary*)dict;
- (NSAttributedString*)attributedBody;
- (NSString*)relativeTime;

@end
