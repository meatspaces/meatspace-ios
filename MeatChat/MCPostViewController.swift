//
//  MCPostViewController.swift
//  MeatChat2
//
//  Created by Marcus Ramberg on 22/03/16.
//  Copyright © 2016 Nordaaker AS. All rights reserved.
//

import UIKit

class MCPostViewController : UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate,UITextFieldDelegate {

    @IBOutlet weak var textfield:UITextField!
    @IBOutlet weak var characterCount:UILabel!
    @IBOutlet weak var imageButton:UIButton!
    @IBOutlet weak var flashButton:UIButton!
    @IBOutlet weak var countLabel:UILabel!

    var session:AVCaptureSession?
    var frames:NSMutableArray = []
    var capturing:Bool = false
    var frameProperties:NSDictionary = [:]
    var skipFrames:Int = 0
    var captureLayer:AVCaptureVideoPreviewLayer?

    let MAXLENGTH=250
    let CAPTURE_FRAMES_PER_SECOND:Int32=5
    
    let titles = [
        "What's up?",
        "What do you say?",
        "Anything on your mind?",
        "Hello?",
        "A field you can type in.",
        "I take letters.",
        "Tap and meat!",
        "250 chars or less."
    ]

    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.setupCaptureSession();
        self.orientationChanged();
   
    }
    
    func setRandomPlaceholder() {
        let index=arc4random_uniform(UInt32(titles.count))
        self.setPlaceHolder(titles[Int(index)])
    }
    
    func setPlaceHolder(title:String) {
        self.textfield.attributedPlaceholder = NSAttributedString(string: title, attributes: [NSForegroundColorAttributeName: UIColor.darkGrayColor()])

    }
    
    func setupCaptureSession() {
        let session = AVCaptureSession()
        
        // Configure the session to produce lower resolution video frames, if your
        // processing algorithm can cope. We'll specify medium quality for the
        // chosen device.
        session.sessionPreset = AVCaptureSessionPresetMedium
        
        // Find a suitable AVCaptureDevice
        let device = self.cameraWithPosition(AVCaptureDevicePosition.Front);
        
      
        do {
            try device.lockForConfiguration()
            device.activeVideoMinFrameDuration = CMTimeMake(1, CAPTURE_FRAMES_PER_SECOND)
            device.activeVideoMaxFrameDuration = CMTimeMake(1, CAPTURE_FRAMES_PER_SECOND)
        
            device.unlockForConfiguration()
            // Create a device input with the device and add it to the session.
            let input = try AVCaptureDeviceInput(device: device)

            session.addInput(input)
            
        } catch {
            print(error)
        }
        


        // Create a VideoDataOutput and add it to the session
        let output = AVCaptureVideoDataOutput()
        
        session.addOutput(output)
        self.switchCameraTapped(self);
        let captureLayer = AVCaptureVideoPreviewLayer(session: session)
        captureLayer.frame = self.imageButton.bounds
        captureLayer.videoGravity=AVLayerVideoGravityResizeAspectFill
        
        self.imageButton.layer.addSublayer(captureLayer)
        self.captureLayer=captureLayer;
        
        // Configure your output.
        let queue = dispatch_queue_create("myQueue", nil);
        output.setSampleBufferDelegate(self, queue: queue)
        
        // Specify the pixel format
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey:  NSNumber(unsignedInt: kCVPixelFormatType_32BGRA)]
        
        
        // Assign session to an ivar.
        self.session=session
    }
    
    
    // Find a camera with the specified AVCaptureDevicePosition, returning nil if one is not found
    func cameraWithPosition(position:AVCaptureDevicePosition) -> AVCaptureDevice {
        let devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
        for device in devices {
            if let avdev = device as? AVCaptureDevice {
                if avdev.position == position {
                    return avdev
                }
            }
        }
        return AVCaptureDevice()
    }
    
    @IBAction func switchCameraTapped(sender:AnyObject) {
        if (session != nil) {
            
            //Indicate that some changes will be made to the session
            session!.beginConfiguration()
            
            //Remove existing input
            let currentCameraInput = session!.inputs[0]
            let camera=currentCameraInput as? AVCaptureDeviceInput
            var newCamera:AVCaptureDevice? = nil
            
            session!.removeInput(camera)
            
            //Get new input
            if camera!.device.position == AVCaptureDevicePosition.Back {
            
                do {
                    flashButton.selected=false;

                    try camera!.device.lockForConfiguration()
                    if camera!.device.isTorchModeSupported(AVCaptureTorchMode.Off) {
                        camera!.device.torchMode=AVCaptureTorchMode.Off;
                    }
                    camera!.device.unlockForConfiguration();
                    newCamera =  self.cameraWithPosition(AVCaptureDevicePosition.Front);
                } catch {
                    print(error)
                }
            }
            else
            {
                newCamera = self.cameraWithPosition(AVCaptureDevicePosition.Back);
            }
            
            //Add input to session
            do {
                if(newCamera != nil) {
                    let newVideoInput = try AVCaptureDeviceInput(device: newCamera);
                    session!.addInput(newVideoInput);
                    session!.commitConfiguration()
                }
            } catch {
                print(error)
            }
        }

    }

    func updateCount() {
        self.countLabel.text=String(format: "%u", 9-self.frames.count)

    }

    func closePostWithPosted(posted:Bool) {
        self.textfield.resignFirstResponder()
        if(posted) {
            self.textfield.text=""
            self.characterCount.text="250 left"
            self.setRandomPlaceholder()
        }
        self.countLabel.hidden=true;
        self.countLabel.text="9";
        self.characterCount.hidden=true;
        UIView.animateWithDuration(0.5) {
            self.imageButton.alpha=0;
        }
        session?.stopRunning()
    }
    
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        
        if self.capturing {
            // FIXME: This is a dirty hack, because CAPTURE_FRAMES_PER_SECOND above doesn't seem to work.
            if(self.skipFrames>0) {
                self.skipFrames -= 1;
                return;
            }
            dispatch_async(dispatch_get_main_queue(), { self.updateCount() })
            
            self.skipFrames=5;
            self.frames.addObject(self.imageFromSampleBuffer(sampleBuffer));
            if self.frames.count == 10 {
                let encodedImages=NSMutableArray()
                for i in 0 ..< self.frames.count {
                    var image=self.frames[i] as? UIImage
                    image=image!.imageByScalingAndCroppingForSize(CGSizeMake(200, 150))
                    
                    
                    let imageData = UIImageJPEGRepresentation(image!, 0.6);
                    let encodedString = imageData!.base64EncodedStringWithOptions(NSDataBase64EncodingOptions.Encoding64CharacterLineLength)
                    encodedImages.addObject(String(format: "data:image/jpeg;base64,%@", encodedString))
                }
                self.capturing=false
                self.frames.removeAllObjects()
                let parentViewController=self.parentViewController as? MCPostListViewController
                
                var uuid:String = UIDevice.currentDevice().identifierForVendor!.UUIDString
                uuid=uuid.stringByReplacingOccurrencesOfString("-", withString: "", options: NSStringCompareOptions.LiteralSearch, range: nil)
                let index = uuid.startIndex.advancedBy(15)
                uuid=uuid.substringToIndex(index).lowercaseString
                let message = [
                    "fingerprint": uuid,
                    "message": self.textfield.text!,
                    "media": encodedImages
                ]
                dispatch_async(dispatch_get_main_queue(), {
                    parentViewController!.socket!.emit("message", args: [message])
                    self.closePostWithPosted(true)
                })
            }
        }

    }
    
    func imageFromSampleBuffer(sampleBuffer:CMSampleBufferRef) -> UIImage {
        // Get a CMSampleBuffer's Core Video image buffer for the media data
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        // Lock the base address of the pixel buffer
        CVPixelBufferLockBaseAddress(imageBuffer!, 0);
        
        // Get the number of bytes per row for the pixel buffer
        let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer!)
        
        // Get the number of bytes per row for the pixel buffer
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer!)
        // Get the pixel buffer width and height
        let width = CVPixelBufferGetWidth(imageBuffer!)
        let height = CVPixelBufferGetHeight(imageBuffer!)
        
        // Create a device-dependent RGB color space
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        // Create a bitmap graphics context with the sample buffer data
   
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.PremultipliedFirst.rawValue | CGBitmapInfo.ByteOrder32Little.rawValue)

        let context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                     bytesPerRow, colorSpace, bitmapInfo.rawValue)

        let quartzImage = CGBitmapContextCreateImage(context)
        // Unlock the pixel buffer
        CVPixelBufferUnlockBaseAddress(imageBuffer!,0)
        
        
        // Create an image object from the Quartz image
        let currentCameraInput = session!.inputs[0]
        let camera=currentCameraInput as? AVCaptureDeviceInput
        let frontcamera:Bool = camera!.device.position == AVCaptureDevicePosition.Front
        let image = UIImage(CGImage: quartzImage!, scale:1.0, orientation: self.currentImageOrientationWithMirroring(frontcamera))
        
        
        return (image);

    }

    func currentImageOrientationWithMirroring(isUsingFrontCamera:Bool) -> UIImageOrientation {
        switch UIDevice.currentDevice().orientation {
            case UIDeviceOrientation.Portrait:
                return isUsingFrontCamera ? UIImageOrientation.Right : UIImageOrientation.LeftMirrored
            case UIDeviceOrientation.PortraitUpsideDown:
                return isUsingFrontCamera ? UIImageOrientation.Left :UIImageOrientation.RightMirrored
            case UIDeviceOrientation.LandscapeLeft:
                return isUsingFrontCamera ? UIImageOrientation.Down :  UIImageOrientation.UpMirrored
            case UIDeviceOrientation.LandscapeRight:
                return isUsingFrontCamera ? UIImageOrientation.Up : UIImageOrientation.DownMirrored
            default:
                return  UIImageOrientation.Up
    }
        
        
    }
    
    
    func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
        let oldLength = textField.text?.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)
        let replacementLength = string.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)
        let rangeLength = range.length
        
        let newLength = oldLength! - rangeLength + replacementLength
        
        let returnKey:Bool = string.containsString("\n")
        if( newLength <= MAXLENGTH) {
            self.characterCount.text=String(format: "%lu left",MAXLENGTH-newLength)
        }
        return newLength <= MAXLENGTH || returnKey;
    }

    
    func textFieldShouldBeginEditing(textField: UITextField) -> Bool {
        session!.startRunning()
        UIView.animateWithDuration(0.5, animations: { 
            self.imageButton.alpha=1
            }) { (finished) in
                self.textfield.becomeFirstResponder()
        }
        return true;

    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        self.countLabel.hidden=false
        self.capturing=true
        return true

    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        self.orientationChanged()
        
    }
    
    func orientationChanged() {
        // get the new orientation from device
        let newOrientation = self.videoOrientationFromDeviceOrientation(UIDevice.currentDevice().orientation);
        
        // set the orientation of preview layer :( which will be displayed in the device )
        self.captureLayer!.connection.videoOrientation = newOrientation
    }
    
    func videoOrientationFromDeviceOrientation(deviceOrientation:UIDeviceOrientation) -> AVCaptureVideoOrientation {
        var orientation:AVCaptureVideoOrientation
        switch (deviceOrientation) {
            case UIDeviceOrientation.Unknown:
                orientation = AVCaptureVideoOrientation.Portrait;
                break
            case UIDeviceOrientation.Portrait:
                orientation = AVCaptureVideoOrientation.Portrait
                break;
            case UIDeviceOrientation.PortraitUpsideDown:
                orientation = AVCaptureVideoOrientation.PortraitUpsideDown;
                break;
            case UIDeviceOrientation.LandscapeLeft:
                orientation = AVCaptureVideoOrientation.LandscapeRight
                break;
            case UIDeviceOrientation.LandscapeRight:
                orientation = AVCaptureVideoOrientation.LandscapeLeft;
                break;
            case UIDeviceOrientation.FaceUp:
                orientation = AVCaptureVideoOrientation.Portrait;
                break;
            case UIDeviceOrientation.FaceDown:
                orientation = AVCaptureVideoOrientation.Portrait;
        }
    return orientation;
    }
    

    
}
