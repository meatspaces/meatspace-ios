//
//  MCPostListViewController.swift
//  MeatChat2
//
//  Created by Marcus Ramberg on 22/03/16.
//  Copyright © 2016 Nordaaker AS. All rights reserved.
//

import UIKit
import MessageUI.MFMailComposeViewController


class MCPostListViewController : UIViewController, UITableViewDataSource, UITableViewDelegate, UITextViewDelegate, AVAssetResourceLoaderDelegate,MFMailComposeViewControllerDelegate {
    
   
    var items:NSMutableArray=[]
    var blocked:[String: AnyObject]=[:]
    var atBottom:Bool=false
    var seen:[String: AnyObject]=[:]
    var userId:String=""
    
    @IBOutlet weak var containerHeight:NSLayoutConstraint!
    @IBOutlet weak var tableView:UITableView!
    @IBOutlet weak var containerBottom:NSLayoutConstraint!
    @IBOutlet weak var containerView:UIView!
    @IBOutlet weak var activeCount:UILabel!
    @IBOutlet weak var blockButton:UIButton!

    var  socket:SIOSocket?
    var  postViewController:MCPostViewController?
    var acceptedEula:Bool!
    
    override func viewDidLoad() {
        if let blockList=NSUserDefaults.standardUserDefaults().dictionaryForKey("meatspaceBlocks") {
            blocked=blockList
        }
        if((blocked.count) > 0) {
            blockButton.hidden=false
        }
        acceptedEula=NSUserDefaults.standardUserDefaults().boolForKey("acceptedEula");
        if(!self.acceptedEula) {
            let eulaAlert = UIAlertController(title: "Welcome to MeatChat", message: "This is a client for the real time chat service chat.meatspac.es. Please behave nicely, objectionable content is not accepted. If someone else posts objectionable content, you can remove current and future messages from them, by using the 'block' button next to their message.", preferredStyle: UIAlertControllerStyle.Alert)
            let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Cancel, handler: { (UIAlertAction) -> Void in
                exit(0);
            })
            eulaAlert.addAction(cancelAction)
            let OKAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: { (UIAlertAction) -> Void in
                self.acceptedEula=true;
                NSUserDefaults.standardUserDefaults().setBool(self.acceptedEula, forKey: "acceptedEula")
            })
            eulaAlert.addAction(OKAction)
            self.presentViewController(eulaAlert, animated: true, completion: nil)
        }
        
        tableView.contentInset = UIEdgeInsetsMake(42, 0, 0, 0);
        
        self.setupReachability()
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(UIInputViewController.dismissKeyboard))
        self.view.addGestureRecognizer(tap)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(MCPostListViewController.keyboardWillHide(_:)), name: UIKeyboardWillHideNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(MCPostListViewController.keyboardDidShow(_:)), name: UIKeyboardDidShowNotification, object: nil)
        
        self.tableView.rowHeight = UITableViewAutomaticDimension;
        self.tableView.estimatedRowHeight=75;
        self.atBottom=true;

    }
    
    func scrollToBottom() {
        let indexPath=NSIndexPath(forItem: (self.items.count-1), inSection: 0)
        self.tableView.scrollToRowAtIndexPath(indexPath, atScrollPosition: UITableViewScrollPosition.Bottom, animated: true)
    }
    
    func scrollViewWillBeginDragging(scrollView: UIScrollView) {
        self.atBottom = false;
        for cell in self.tableView.visibleCells {
            if let postCell = cell as? MCPostCell {
                postCell.videoPlayer!.pause()
            }
        }

    }
   
    func resumePlay() {
        for cell in self.tableView.visibleCells {
            if let postCell = cell as? MCPostCell {
                postCell.videoPlayer!.play()
            }
        }
        
    }
    
    func endScroll(scrollView:UIScrollView) {
        self.resumePlay();
        let height = scrollView.frame.size.height;
        let contentYoffset = scrollView.contentOffset.y;
        let distanceFromBottom = scrollView.contentSize.height - contentYoffset;
        self.atBottom = (distanceFromBottom <= height);

    }
    
    func scrollViewDidEndDragging(scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        self.endScroll(scrollView)
    }
    
    func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
        self.endScroll(scrollView)
    }
    
    func scrollViewDidEndScrollingAnimation(scrollView: UIScrollView) {
        self.resumePlay()
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let ctrl=segue.destinationViewController as? MCPostViewController {
            self.postViewController=ctrl
        }
    }
    
    func setupReachability() {
        let server_url=NSURL(string: NSUserDefaults.standardUserDefaults().objectForKey("server_url") as! String);
        let reach = Reachability(hostname: server_url!.host);
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(MCPostListViewController.reachabilityChanged(_:)), name: kReachabilityChangedNotification, object: nil)
        reach.startNotifier()
        self.setupSocket();
    }
    
    func reachabilityChanged(notif:NSNotification) {
        let reach=notif.object as! Reachability;
        reach.isReachable() ? self.setupSocket() : self.teardownSocket();
    }
    

        
    func teardownSocket() {
        
        self.socket!.close()
        self.socket=nil;
        self.postViewController!.setPlaceHolder("Get the internet, bae.")
    }
    
    func handleDisconnect() {
        self.postViewController!.textfield.resignFirstResponder()
        self.postViewController!.textfield.enabled=false
        self.postViewController!.setPlaceHolder("Disconnected, please hold")
        self.activeCount.hidden = true 

    }
        
    func flushItems() {
        for item in self.items {
            if let postItem = item as? MCPost {
                postItem.cleanup()
            }
        }
        self.items.removeAllObjects()
        self.tableView.reloadData()
    }
        
    func addPost(args:NSArray) {
        if let fingerprint=args[0]["fingerprint"] as? String {
            if(self.blocked.keys.contains(fingerprint)) { return; }
        
            self.tableView.beginUpdates()
            if self.items.count > 0 {
                for  i in 0 ... (self.items.count - 1)  {
                    if let post=self.items.objectAtIndex(i) as? MCPost {
                        if post.isObsolete() {
                            post.cleanup()
                            self.items.removeObjectAtIndex(i)
                            let indexPath=NSIndexPath(forItem: i, inSection: 0)
                            self.tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation:UITableViewRowAnimation.Automatic)
                        }
                    }
                }
            }
            self.tableView.endUpdates()
        
            if let key = args[0]["key"] as? String {
                if((self.seen[key] ) != nil) { return; }
                self.seen[key]="1"
            }
        }
        let post=MCPost(dict: args[0] as! NSDictionary)
        self.items.addObject(post)
        let newRow=NSIndexPath(forItem: self.items.count-1, inSection: 0)

        CATransaction.begin()
        CATransaction.setCompletionBlock({
            if (self.atBottom != true) {
                self.scrollToBottom()
            }
        })
        self.tableView.beginUpdates()
        self.tableView.insertRowsAtIndexPaths([newRow], withRowAnimation: UITableViewRowAnimation.Fade)
        self.tableView.endUpdates()
        CATransaction.commit()
    }

    func dismissKeyboard() {
        self.postViewController!.closePostWithPosted(false)
    }

    func keyboardDidShow(sender:NSNotification) {

        let frame = sender.userInfo![UIKeyboardFrameEndUserInfoKey]!.CGRectValue
        self.containerBottom.constant = frame.size.height
        self.containerView.setNeedsUpdateConstraints()
        UIView.animateWithDuration(0.25, animations: {
            self.containerView.layoutIfNeeded()
            self.containerHeight.constant = 75.0
            self.postViewController!.characterCount.hidden=false
        }) { (finished) in
            if self.items.count > 0 {
                self.scrollToBottom()
                self.atBottom=true
            }
        }
        
    }
    func keyboardWillHide(sender:NSNotification) {
        self.containerBottom.constant = 0;
        self.containerView.setNeedsUpdateConstraints()
        UIView.animateWithDuration(0.25, animations: {
            self.containerView.layoutIfNeeded()
            self.containerHeight.constant = 35.0
        }) { (finished) in
            if self.items.count > 0 {
                self.scrollToBottom()
                let indexPath=NSIndexPath(forItem: self.items.count-1, inSection: 0)
                self.tableView.reloadRowsAtIndexPaths( [indexPath], withRowAnimation: UITableViewRowAnimation.None )
                self.atBottom=true
            }
        }
    }
     
    @IBAction func unblockClicked(sender:AnyObject) {
        self.blocked=[:]
        NSUserDefaults.standardUserDefaults().setObject(self.blocked, forKey:"meatspaceBlocks")
        self.blockButton.hidden=true

    }
    
    @IBAction func blockClicked(sender:AnyObject) {
        if let blockPost=self.items.objectAtIndex(sender.tag) as? MCPost {
            self.blocked[blockPost.fingerprint]="1"
            self.blockButton.hidden=false
            NSUserDefaults.standardUserDefaults().setObject(self.blocked, forKey: "meatspaceBlocks")
            for i in 0 ... self.items.count-1{
                if let post = self.items.objectAtIndex(i) as? MCPost {
                    if post.fingerprint == blockPost.fingerprint {
                        self.items.removeObject(post)
                        self.tableView.reloadData()
                    }
                }
            }
            weak var weakSelf=self
            let alertController = UIAlertController(title: "Report abuse?", message: "You have just chosen to block another meatspacer. Would you like to report this user for objectionable content?", preferredStyle: UIAlertControllerStyle.Alert)
            let cancelAction=UIAlertAction(title: "No", style: UIAlertActionStyle.Cancel) { (action) in
                
            }
            
            let okAction=UIAlertAction(title: "Yes", style: UIAlertActionStyle.Default) { (action) in
                let mf=MFMailComposeViewController()
                mf.setToRecipients(["report@meatspac.es"]);
                mf.mailComposeDelegate=weakSelf;
                mf.setSubject(String(format: "Abuse from user fingerprint %@",blockPost.fingerprint));
                weakSelf!.presentViewController(mf, animated: true, completion: {})
                
            }
            alertController.addAction(cancelAction)
            alertController.addAction(okAction)
            
            self.presentViewController(alertController, animated:true, completion:nil);
        }

        
        

    }

    func setupSocket() {
        weak var weakSelf=self
        self.postViewController!.setPlaceHolder("Connecting to meatspace")

        
        SIOSocket.socketWithHost(NSUserDefaults.standardUserDefaults().objectForKey("server_url") as? String, response: { (sock) in

            self.socket=sock
            self.socket!.onConnect = {
                weakSelf?.socket!.emit("join", args: ["mp4"])
                dispatch_async(dispatch_get_main_queue(), {
                    weakSelf?.postViewController!.textfield.enabled=true
                    weakSelf?.postViewController!.setRandomPlaceholder()
                })
            }
            self.socket!.onDisconnect = {
                dispatch_async(dispatch_get_main_queue(), {
                    weakSelf?.handleDisconnect()
                })
            }
            self.socket!.on("message", callback: { (data) in
                dispatch_async(dispatch_get_main_queue(), {
                    weakSelf!.addPost(data)
                })
            })
            self.socket!.on("messageack", callback: { (data) in
                if let message=data[0] as? String {
                    dispatch_async(dispatch_get_main_queue(), {
                        weakSelf?.postViewController!.setPlaceHolder(message)
                        if let uid=data[1]["userId"] as? String {
                            self.userId=uid
                        }
                    })
                }
            })
            self.socket!.onError = { (errorInfo) in
                print(errorInfo)
                dispatch_async(dispatch_get_main_queue(), {
                    weakSelf?.postViewController!.setPlaceHolder(String(format: "An error occured: %@",errorInfo))
                    })
            }
            self.socket!.onReconnect = { (numberOfAttempts) in
                print(String(format: "Reconnect %ld",numberOfAttempts))
            }
            self.socket!.onReconnectionAttempt = { (numberOfAttempts) in
                print(String(format: "Attempt %ld",numberOfAttempts))
                dispatch_async(dispatch_get_main_queue(), {
                    weakSelf?.postViewController!.setPlaceHolder("Reconnecting to meatspace.")
                })
            }
            self.socket!.onReconnectionError={ (errorInfo) in
                print(errorInfo)
                dispatch_async(dispatch_get_main_queue(), {
                    weakSelf!.postViewController!.setPlaceHolder(String(format: "Could not connect: %@",errorInfo))
                })
            }
        })
        
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.items.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if let cell=tableView.dequeueReusableCellWithIdentifier("MeatCell", forIndexPath: indexPath) as? MCPostCell {
            if let post=self.items.objectAtIndex(indexPath.row) as? MCPost {
                cell.textView.attributedText=post.attributedString
                cell.timeLabel.text=post.relativeTime()
                if self.userId == post.fingerprint {
                    self.blockButton.hidden=true
                } else {
                    cell.blockButton.hidden=false
                    cell.blockButton.tag=indexPath.row
                }
                let item=AVPlayerItem(URL: post.videoUrl)
                cell.videoPlayer?.replaceCurrentItemWithPlayerItem(item)
                if self.items.count-1 == self.tableView.visibleCells.count {
                    cell.videoPlayer?.play()
                }
                NSNotificationCenter.defaultCenter().addObserver(cell, selector: #selector(cell.playerItemDidReachEnd(_:)), name: AVPlayerItemDidPlayToEndTimeNotification, object: item)
            }
        return cell
        }
        return UITableViewCell()
    }
    
    func tableView(tableView: UITableView, didEndDisplayingCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        if let postCell=cell as? MCPostCell {
            postCell.videoPlayer!.pause()
        }
    }
    
    func tableView(tableView: UITableView, didDeselectRowAtIndexPath indexPath: NSIndexPath) {
        if let cell=tableView.cellForRowAtIndexPath(indexPath) as? MCPostCell {
            cell.blockButton.hidden=true
        }
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if let cell=tableView.cellForRowAtIndexPath(indexPath) as? MCPostCell {
            cell.blockButton.hidden=false
        }
    }
    
    func textView(textView: UITextView, shouldInteractWithURL URL: NSURL, inRange characterRange: NSRange) -> Bool {
        return true
    }
    
    func mailComposeController(controller: MFMailComposeViewController, didFinishWithResult result: MFMailComposeResult, error: NSError?) {
        self.dismissViewControllerAnimated(true) {}
    }

}

