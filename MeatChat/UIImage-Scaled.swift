//
//  UIImage-Scaled.swift
//  MeatChat2
//
//  Created by Marcus Ramberg on 25/03/16.
//  Copyright © 2016 Nordaaker AS. All rights reserved.
//

import Foundation

extension UIImage {
    func imageByScalingAndCroppingForSize(targetSize:CGSize) -> UIImage {
     
        let sourceImage = self
        let imageSize = sourceImage.size
        let width = imageSize.width
        let height = imageSize.height
        let targetWidth = targetSize.width
        let targetHeight = targetSize.height
        var thumbnailPoint = CGPointMake(0.0,0.0)
        var scaleFactor = 0.0;
        var scaledWidth = targetWidth
        var scaledHeight = targetHeight
        
        if CGSizeEqualToSize(imageSize, targetSize) == false {
            let widthFactor = Double(targetWidth / width)
            let heightFactor = Double(targetHeight / height)
            
            if (widthFactor > heightFactor)
            {
                scaleFactor = widthFactor // scale to fit height
            } else {
                scaleFactor = heightFactor // scale to fit width
            }
            
            scaledWidth  = width * CGFloat(scaleFactor)
            scaledHeight = height * CGFloat(scaleFactor)
            
            // center the image
            if (widthFactor > heightFactor)
            {
                thumbnailPoint.y = (targetHeight - scaledHeight) * 0.5;
            }
            else
            {
                if (widthFactor < heightFactor)
                {
                    thumbnailPoint.x = (targetWidth - scaledWidth) * 0.5;
                }
            }
        }
        
        UIGraphicsBeginImageContext(targetSize) // this will crop
        
        var thumbnailRect = CGRectZero
        thumbnailRect.origin = thumbnailPoint
        thumbnailRect.size.width  = scaledWidth
        thumbnailRect.size.height = scaledHeight
        
        sourceImage.drawInRect(thumbnailRect)
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
    
        
        //pop the context to get back to the default
        UIGraphicsEndImageContext()
        
        return newImage
    }
}