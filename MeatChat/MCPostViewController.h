//
//  NMPostMeatViewController.h
//  MeatChat
//
//  Created by Marcus Ramberg on 17.01.14.
//  Copyright (c) 2014 Nordaaker AS. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface MCPostViewController : UIViewController<AVCaptureVideoDataOutputSampleBufferDelegate,UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UITextField *textfield;
@property (weak, nonatomic) IBOutlet UILabel *characterCount;

- (AVCaptureDevice *) cameraWithPosition:(AVCaptureDevicePosition) position;
- (void)setPlaceholder: (NSString*)placeholder;
- (void)setRandomPlaceholder;
- (void)closePostWithPosted: (BOOL)posted;

@end
