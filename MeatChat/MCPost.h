//
//  NMeatPost.h
//  MeatChat
//
//  Created by Marcus Ramberg on 13.09.14.
//  Copyright (c) 2014 Nordaaker AS. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MCPost : NSObject

@property (nonatomic,strong) NSAttributedString *attributedString;
@property (nonatomic,strong) NSURL *videoUrl;
@property (nonatomic, strong) NSNumber *created;
@property (nonatomic, strong) NSString* fingerprint;

-(id)initWithDictionary: (NSDictionary*)dict;
- (NSAttributedString*)attributedBody;
- (NSString*)relativeTime;
- (BOOL)isObsolete;
- (void)cleanup;

@end
