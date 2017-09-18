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
    
    func setPlaceHolder(_ title:String) {
        self.textfield.attributedPlaceholder = NSAttributedString(string: title, attributes: [NSForegroundColorAttributeName: UIColor.darkGray])

    }
    
    func setupCaptureSession() {
        let session = AVCaptureSession()
        
        // Configure the session to produce lower resolution video frames, if your
        // processing algorithm can cope. We'll specify medium quality for the
        // chosen device.
        session.sessionPreset = AVCaptureSessionPresetMedium
        
        // Find a suitable AVCaptureDevice
        let device = self.cameraWithPosition(AVCaptureDevicePosition.front);
        
      
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
        captureLayer?.frame = self.imageButton.bounds
        captureLayer?.videoGravity=AVLayerVideoGravityResizeAspectFill
        
        self.imageButton.layer.addSublayer(captureLayer!)
        self.captureLayer=captureLayer;
        
        // Configure your output.
        let queue = DispatchQueue(label: "myQueue", attributes: []);
        output.setSampleBufferDelegate(self, queue: queue)
        
        // Specify the pixel format
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable:  NSNumber(value: kCVPixelFormatType_32BGRA as UInt32)]
        
        
        // Assign session to an ivar.
        self.session=session
    }
    
    
    // Find a camera with the specified AVCaptureDevicePosition, returning nil if one is not found
    func cameraWithPosition(_ position:AVCaptureDevicePosition) -> AVCaptureDevice {
        let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo)
        for device in devices! {
            if let avdev = device as? AVCaptureDevice {
                if avdev.position == position {
                    return avdev
                }
            }
        }
        return AVCaptureDevice()
    }
    
    @IBAction func switchCameraTapped(_ sender:AnyObject) {
        if (session != nil) {
            
            //Indicate that some changes will be made to the session
            session!.beginConfiguration()
            
            //Remove existing input
            let currentCameraInput = session!.inputs[0]
            let camera=currentCameraInput as? AVCaptureDeviceInput
            var newCamera:AVCaptureDevice? = nil
            
            session!.removeInput(camera)
            
            //Get new input
            if camera!.device.position == AVCaptureDevicePosition.back {
            
                do {
                    flashButton.isSelected=false;

                    try camera!.device.lockForConfiguration()
                    if camera!.device.isTorchModeSupported(AVCaptureTorchMode.off) {
                        camera!.device.torchMode=AVCaptureTorchMode.off;
                    }
                    camera!.device.unlockForConfiguration();
                    newCamera =  self.cameraWithPosition(AVCaptureDevicePosition.front);
                } catch {
                    print(error)
                }
            }
            else
            {
                newCamera = self.cameraWithPosition(AVCaptureDevicePosition.back);
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

    func closePostWithPosted(_ posted:Bool) {
        self.textfield.resignFirstResponder()
        if(posted) {
            self.textfield.text=""
            self.characterCount.text="250 left"
            self.setRandomPlaceholder()
        }
        self.countLabel.isHidden=true;
        self.countLabel.text="9";
        self.characterCount.isHidden=true;
        UIView.animate(withDuration: 0.5, animations: {
            self.imageButton.alpha=0;
        }) 
        session?.stopRunning()
    }
    
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        
        if self.capturing {
            // FIXME: This is a dirty hack, because CAPTURE_FRAMES_PER_SECOND above doesn't seem to work.
            if(self.skipFrames>0) {
                self.skipFrames -= 1;
                return;
            }
            DispatchQueue.main.async(execute: { self.updateCount() })
            
            self.skipFrames=5;
            self.frames.add(self.imageFromSampleBuffer(sampleBuffer));
            if self.frames.count == 10 {
                let encodedImages=NSMutableArray()
                for i in 0 ..< self.frames.count {
                    var image=self.frames[i] as? UIImage
                    image=image!.imageByScalingAndCroppingForSize(CGSize(width: 200, height: 150))
                    
                    
                    let imageData = UIImageJPEGRepresentation(image!, 0.6);
                    let encodedString = imageData!.base64EncodedString(options: NSData.Base64EncodingOptions.lineLength64Characters)
                    encodedImages.add(String(format: "data:image/jpeg;base64,%@", encodedString))
                }
                self.capturing=false
                self.frames.removeAllObjects()
                let parentViewController=self.parent as? MCPostListViewController
                
                var uuid:String = UIDevice.current.identifierForVendor!.uuidString
                uuid=uuid.replacingOccurrences(of: "-", with: "", options: NSString.CompareOptions.literal, range: nil)
                print("uuid: \(uuid)")
                let index = uuid.characters.index(uuid.startIndex, offsetBy: 32)
                print("index: \(index)")
                uuid=uuid.substring(to: index).lowercased()
                print("uuid: \(uuid)")
                let message = [
                    "fingerprint": uuid,
                    "message": self.textfield.text!,
                    "media": encodedImages
                ] as [String : Any]
                DispatchQueue.main.async(execute: {
                    parentViewController!.socket!.emit("message", [message])
                    self.closePostWithPosted(true)
                })
            }
        }

    }
    
    func imageFromSampleBuffer(_ sampleBuffer:CMSampleBuffer) -> UIImage {
        // Get a CMSampleBuffer's Core Video image buffer for the media data
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        // Lock the base address of the pixel buffer
        CVPixelBufferLockBaseAddress(imageBuffer!, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)));
        
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
   
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)

        let context = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8,
                                                     bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)

        let quartzImage = context!.makeImage()
        // Unlock the pixel buffer
        CVPixelBufferUnlockBaseAddress(imageBuffer!,CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
        
        
        // Create an image object from the Quartz image
        let currentCameraInput = session!.inputs[0]
        let camera=currentCameraInput as? AVCaptureDeviceInput
        let frontcamera:Bool = camera!.device.position == AVCaptureDevicePosition.front
        let image = UIImage(cgImage: quartzImage!, scale:1.0, orientation: self.currentImageOrientationWithMirroring(frontcamera))
        
        
        return (image);

    }

    func currentImageOrientationWithMirroring(_ isUsingFrontCamera:Bool) -> UIImageOrientation {
        switch UIDevice.current.orientation {
            case UIDeviceOrientation.portrait:
                return isUsingFrontCamera ? UIImageOrientation.right : UIImageOrientation.leftMirrored
            case UIDeviceOrientation.portraitUpsideDown:
                return isUsingFrontCamera ? UIImageOrientation.left :UIImageOrientation.rightMirrored
            case UIDeviceOrientation.landscapeLeft:
                return isUsingFrontCamera ? UIImageOrientation.down :  UIImageOrientation.upMirrored
            case UIDeviceOrientation.landscapeRight:
                return isUsingFrontCamera ? UIImageOrientation.up : UIImageOrientation.downMirrored
            default:
                return  UIImageOrientation.up
    }
        
        
    }
    
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let oldLength = textField.text?.lengthOfBytes(using: String.Encoding.utf8)
        let replacementLength = string.lengthOfBytes(using: String.Encoding.utf8)
        let rangeLength = range.length
        
        let newLength = oldLength! - rangeLength + replacementLength
        
        let returnKey:Bool = string.contains("\n")
        if( newLength <= MAXLENGTH) {
            self.characterCount.text=String(format: "%lu left",MAXLENGTH-newLength)
        }
        return newLength <= MAXLENGTH || returnKey;
    }

    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        session!.startRunning()
        UIView.animate(withDuration: 0.5, animations: { 
            self.imageButton.alpha=1
            }, completion: { (finished) in
                self.textfield.becomeFirstResponder()
        }) 
        return true;

    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.countLabel.isHidden=false
        self.capturing=true
        return true

    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        self.orientationChanged()
        
    }
    
    func orientationChanged() {
        // get the new orientation from device
        let newOrientation = self.videoOrientationFromDeviceOrientation(UIDevice.current.orientation);
        
        // set the orientation of preview layer :( which will be displayed in the device )
        self.captureLayer!.connection.videoOrientation = newOrientation
    }
    
    func videoOrientationFromDeviceOrientation(_ deviceOrientation:UIDeviceOrientation) -> AVCaptureVideoOrientation {
        var orientation:AVCaptureVideoOrientation
        switch (deviceOrientation) {
            case UIDeviceOrientation.unknown:
                orientation = AVCaptureVideoOrientation.portrait;
                break
            case UIDeviceOrientation.portrait:
                orientation = AVCaptureVideoOrientation.portrait
                break;
            case UIDeviceOrientation.portraitUpsideDown:
                orientation = AVCaptureVideoOrientation.portraitUpsideDown;
                break;
            case UIDeviceOrientation.landscapeLeft:
                orientation = AVCaptureVideoOrientation.landscapeRight
                break;
            case UIDeviceOrientation.landscapeRight:
                orientation = AVCaptureVideoOrientation.landscapeLeft;
                break;
            case UIDeviceOrientation.faceUp:
                orientation = AVCaptureVideoOrientation.portrait;
                break;
            case UIDeviceOrientation.faceDown:
                orientation = AVCaptureVideoOrientation.portrait;
        }
    return orientation;
    }
    

    
}
