  //
  //  NMPostMeatViewController.m
  //  NordMeat
  //
  //  Created by Marcus Ramberg on 17.01.14.
  //  Copyright (c) 2014 Nordaaker AS. All rights reserved.
  //

#import "NMPostMeatViewController.h"
#import "NMeatViewController.h"


@interface NMPostMeatViewController ()
@property (retain,nonatomic) AVCaptureSession *session;
@property (weak, nonatomic) IBOutlet UITextField *textfield;
@property (weak, nonatomic) IBOutlet UIButton *imageButton;
@property (weak, nonatomic) IBOutlet UIButton *postButton;
@end

@implementation NMPostMeatViewController

const int CAPTURE_FRAMES_PER_SECOND=5;

- (void)viewDidLoad
{
  [super viewDidLoad];
    // Do any additional setup after loading the view.
  [self setupCaptureSession];
}


- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)setupCaptureSession
{
  NSError *error = nil;
  
    // Create the session
  AVCaptureSession *session = [[AVCaptureSession alloc] init];
  
    // Configure the session to produce lower resolution video frames, if your
    // processing algorithm can cope. We'll specify medium quality for the
    // chosen device.
  session.sessionPreset = AVCaptureSessionPresetMedium;
  
    // Find a suitable AVCaptureDevice
  AVCaptureDevice *device = [AVCaptureDevice
                             defaultDeviceWithMediaType:AVMediaTypeVideo];

  
    // Create a device input with the device and add it to the session.
  AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device
                                                                      error:&error];
  if (!input) {
      // Handling the error appropriately.
    return;
  }
  [session addInput:input];
  
    // Create a VideoDataOutput and add it to the session
  AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
  AVCaptureConnection *conn = [output connectionWithMediaType:AVMediaTypeVideo];
  if (conn.isVideoMinFrameDurationSupported)
    conn.videoMinFrameDuration = CMTimeMake(1, CAPTURE_FRAMES_PER_SECOND);
  if (conn.isVideoMaxFrameDurationSupported)
    conn.videoMaxFrameDuration = CMTimeMake(1, CAPTURE_FRAMES_PER_SECOND);

  [session addOutput:output];
  AVCaptureVideoPreviewLayer *captureLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
  captureLayer.frame = self.imageButton.bounds;
  captureLayer.videoGravity=AVLayerVideoGravityResizeAspectFill;
  
  [self.imageButton.layer addSublayer:captureLayer];

    // Configure your output.
  dispatch_queue_t queue = dispatch_queue_create("myQueue", NULL);
  [output setSampleBufferDelegate:self queue:queue];
  
    // Specify the pixel format
  output.videoSettings =
  [NSDictionary dictionaryWithObject:
   [NSNumber numberWithInt:kCVPixelFormatType_32BGRA]
                              forKey:(id)kCVPixelBufferPixelFormatTypeKey];
  
  
  
    // Start the session running to start the flow of data
  
    // Assign session to an ivar.
  [self setSession:session];
}

  // Delegate routine that is called when a sample buffer was written
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
  ;    // Create a UIImage from the sample buffer data
  
    // [self.imageButton setImage: [self imageFromSampleBuffer:sampleBuffer] forState: UIControlStateNormal];
  
  
}

-(IBAction)switchCameraTapped:(id)sender
{
    //Change camera source
  if(_session) {
      //Indicate that some changes will be made to the session
    [_session beginConfiguration];
    
      //Remove existing input
    AVCaptureInput* currentCameraInput = [_session.inputs objectAtIndex:0];
    [_session removeInput:currentCameraInput];
    
      //Get new input
    AVCaptureDevice *newCamera = nil;
    if(((AVCaptureDeviceInput*)currentCameraInput).device.position == AVCaptureDevicePositionBack)
      {
      newCamera = [self cameraWithPosition:AVCaptureDevicePositionFront];
      }
    else
      {
      newCamera = [self cameraWithPosition:AVCaptureDevicePositionBack];
      }
    
      //Add input to session
    AVCaptureDeviceInput *newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:newCamera error:nil];
    [_session addInput:newVideoInput];
    
      //Commit all the configuration changes at once
    [_session commitConfiguration];
    }
}

  // Find a camera with the specified AVCaptureDevicePosition, returning nil if one is not found
- (AVCaptureDevice *) cameraWithPosition:(AVCaptureDevicePosition) position
{
  NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
  for (AVCaptureDevice *device in devices)
    {
    if ([device position] == position) return device;
    }
  return nil;
}

  // Create a UIImage from sample buffer data
- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
{
    // Get a CMSampleBuffer's Core Video image buffer for the media data
  CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
  CVPixelBufferLockBaseAddress(imageBuffer, 0);
  
    // Get the number of bytes per row for the pixel buffer
  void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
  
    // Get the number of bytes per row for the pixel buffer
  size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
  size_t width = CVPixelBufferGetWidth(imageBuffer);
  size_t height = CVPixelBufferGetHeight(imageBuffer);
  
    // Create a device-dependent RGB color space
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  
    // Create a bitmap graphics context with the sample buffer data
  CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                               bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    // Create a Quartz image from the pixel data in the bitmap graphics context
  CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // Unlock the pixel buffer
  CVPixelBufferUnlockBaseAddress(imageBuffer,0);
  
    // Free up the context and color space
  CGContextRelease(context);
  CGColorSpaceRelease(colorSpace);
  
    // Create an image object from the Quartz image
  UIImage *image = [UIImage imageWithCGImage:quartzImage];
  
    // Release the Quartz image
  CGImageRelease(quartzImage);
  
  return (image);
}


- (IBAction)callPost:(id)sender
{
  [_session startRunning];
  NMeatViewController *meat= (NMeatViewController*)self.parentViewController;
  meat.containerHeight.constant=101;
  [meat.view setNeedsUpdateConstraints];
  [UIView animateWithDuration:0.5f animations:^{
    self.imageButton.alpha=1;
    self.textfield.alpha=1;
    self.postButton.alpha=0;
    [meat.view layoutIfNeeded];
  } completion:^(BOOL finished) {
    [self.textfield becomeFirstResponder];
  }];
}

- (IBAction)closePost:(id)sender {
  [_session stopRunning];
  [self.textfield resignFirstResponder];
  NMeatViewController *meat= (NMeatViewController*)self.parentViewController;
  meat.containerHeight.constant=42;
  [meat.view setNeedsUpdateConstraints];
  [UIView animateWithDuration:0.5f animations:^{
    [meat.view layoutIfNeeded];
    self.imageButton.alpha=0;
    self.textfield.alpha=0;
    self.postButton.alpha=1;
  }];
}


-(BOOL)textFieldShouldEndEditing:(UITextField *)textField
{
  NSLog(@"Posting %@",textField.text);
  [self closePost: textField];
  return YES;
}


@end
