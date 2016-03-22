//
//  MCPostCell.swift
//  MeatChat2
//
//  Created by Marcus Ramberg on 22/03/16.
//  Copyright © 2016 Nordaaker AS. All rights reserved.
//

import UIKit
import AVFoundation
import AVFoundation.AVPlayer
import AVKit

class MCPostCell : UITableViewCell {
    @IBOutlet weak var video :UIView!
    @IBOutlet weak var timeLabel :UILabel!
    @IBOutlet weak var textView :UITextView!
    @IBOutlet weak var blockButton :UIButton!

    var videoPlayer :AVPlayer?

    
    override func awakeFromNib() {
        self.videoPlayer=AVPlayer();
        let layer:AVPlayerLayer=AVPlayerLayer(player: self.videoPlayer)
        self.videoPlayer!.actionAtItemEnd=AVPlayerActionAtItemEnd.None
        layer.frame=CGRectMake(0, 0, 100, 75);
        layer.videoGravity=AVLayerVideoGravityResizeAspectFill;
        self.video?.layer.addSublayer(layer)
    }
    
    func playerItemDidReachEnd(notification:NSNotification)
    {
        let p:AVPlayerItem = notification.object as! AVPlayerItem
        p.seekToTime(kCMTimeZero)
    }

}