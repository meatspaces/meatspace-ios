//
//  MCPostListViewController.swift
//  MeatChat2
//
//  Created by Marcus Ramberg on 22/03/16.
//  Copyright © 2016 Nordaaker AS. All rights reserved.
//

import UIKit
import MessageUI.MFMailComposeViewController
import SocketIO
import ReachabilitySwift

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

    var  socket:SocketIOClient?
    var  postViewController:MCPostViewController?
    var acceptedEula:Bool!
    
    override func viewDidLoad() {
        if let blockList=UserDefaults.standard.dictionary(forKey: "meatspaceBlocks") {
            blocked=blockList as [String : AnyObject]
        }
        if((blocked.count) > 0) {
            blockButton.isHidden=false
        }
        acceptedEula=UserDefaults.standard.bool(forKey: "acceptedEula");
        if(!self.acceptedEula) {
            let eulaAlert = UIAlertController(title: "Welcome to MeatChat", message: "This is a client for the real time chat service chat.meatspac.es. Please behave nicely, objectionable content is not accepted. If someone else posts objectionable content, you can remove current and future messages from them, by using the 'block' button next to their message.", preferredStyle: UIAlertControllerStyle.alert)
            let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: { (UIAlertAction) -> Void in
                exit(0);
            })
            eulaAlert.addAction(cancelAction)
            let OKAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: { (UIAlertAction) -> Void in
                self.acceptedEula=true;
                UserDefaults.standard.set(self.acceptedEula, forKey: "acceptedEula")
            })
            eulaAlert.addAction(OKAction)
            self.present(eulaAlert, animated: true, completion: nil)
        }
        
        tableView.contentInset = UIEdgeInsetsMake(42, 0, 0, 0);
        
        self.setupReachability()
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(UIInputViewController.dismissKeyboard))
        self.view.addGestureRecognizer(tap)
        NotificationCenter.default.addObserver(self, selector: #selector(MCPostListViewController.keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(MCPostListViewController.keyboardDidShow(_:)), name: NSNotification.Name.UIKeyboardDidShow, object: nil)
        
        self.tableView.rowHeight = UITableViewAutomaticDimension;
        self.tableView.estimatedRowHeight=75;

    }
    
    func scrollToBottom() {
        let indexPath=IndexPath(item: (self.items.count-1), section: 0)
        self.tableView.scrollToRow(at: indexPath, at: UITableViewScrollPosition.bottom, animated: true)
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
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
    
    func endScroll(_ scrollView:UIScrollView) {
        self.resumePlay();
        let height = scrollView.frame.size.height;
        let contentYoffset = scrollView.contentOffset.y;
        let distanceFromBottom = scrollView.contentSize.height - contentYoffset;
        self.atBottom = (distanceFromBottom <= height);

    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        self.endScroll(scrollView)
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.endScroll(scrollView)
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        self.resumePlay()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let ctrl=segue.destination as? MCPostViewController {
            self.postViewController=ctrl
        }
    }
    
    func setupReachability() {
        let server_url=URL(string: UserDefaults.standard.object(forKey: "server_url") as! String);
        let reach = Reachability(hostname: server_url!.host!)!
        NotificationCenter.default.addObserver(self, selector: #selector(MCPostListViewController.reachabilityChanged(_:)), name: ReachabilityChangedNotification, object: nil)
        do {
            try reach.startNotifier()
        } catch {
            print("could not start reachability notifier")
        }
        // self.setupSocket();
    }
    
    func reachabilityChanged(_ notif:Notification) {
        let reach=notif.object as! Reachability;
        reach.isReachable ? self.setupSocket() : self.teardownSocket();
    }
    

        
    func teardownSocket() {
        
        self.socket!.disconnect()
        self.socket=nil;
        self.postViewController!.setPlaceHolder("Get the internet, bae.")
    }
    
    func handleDisconnect() {
        self.postViewController!.textfield.resignFirstResponder()
        self.postViewController!.textfield.isEnabled=false
        self.postViewController!.setPlaceHolder("Disconnected, please hold")
        self.activeCount.isHidden = true 

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
        
    func addPost(_ args:NSArray) {
        if let fingerprint=(args[0] as! NSDictionary)["fingerprint"] as? String {
            if(self.blocked.keys.contains(fingerprint)) { return; }
        
            self.tableView.beginUpdates()
            if self.items.count > 0 {
                for  i in 0 ... (self.items.count - 1)  {
                    if let post=self.items.object(at: i) as? MCPost {
                        if post.isObsolete() {
                            post.cleanup()
                            self.items.removeObject(at: i)
                            let indexPath=IndexPath(item: i, section: 0)
                            self.tableView.deleteRows(at: [indexPath], with:UITableViewRowAnimation.automatic)
                        }
                    }
                }
            }
            self.tableView.endUpdates()
        
            if let key = (args[0] as! NSDictionary)["key"] as? String {
                if((self.seen[key] ) != nil) { return; }
                self.seen[key]="1" as AnyObject?
            }
        }
        let post=MCPost(dict: args[0] as! NSDictionary)
        self.items.add(post)
        let newRow=IndexPath(item: self.items.count-1, section: 0)

        CATransaction.begin()
        CATransaction.setCompletionBlock({
            if (self.atBottom != true) {
                self.scrollToBottom()
            }
        })
        self.tableView.beginUpdates()
        self.tableView.insertRows(at: [newRow], with: UITableViewRowAnimation.fade)
        self.tableView.endUpdates()
        CATransaction.commit()
    }

    func dismissKeyboard() {
        self.postViewController!.closePostWithPosted(false)
    }

    func keyboardDidShow(_ sender:Notification) {

        let frame = (sender.userInfo![UIKeyboardFrameEndUserInfoKey]! as AnyObject).cgRectValue
        self.containerBottom.constant = (frame?.size.height)!
        self.containerView.setNeedsUpdateConstraints()
        UIView.animate(withDuration: 0.25, animations: {
            self.containerView.layoutIfNeeded()
            self.containerHeight.constant = 75.0
            self.postViewController!.characterCount.isHidden=false
        }, completion: { (finished) in
            if self.items.count > 0 {
                self.scrollToBottom()
                self.atBottom=true
            }
        }) 
        
    }
    func keyboardWillHide(_ sender:Notification) {
        self.containerBottom.constant = 0;
        self.containerView.setNeedsUpdateConstraints()
        UIView.animate(withDuration: 0.25, animations: {
            self.containerView.layoutIfNeeded()
            self.containerHeight.constant = 35.0
        }, completion: { (finished) in
            if self.items.count > 0 {
                self.scrollToBottom()
                let indexPath=IndexPath(item: self.items.count-1, section: 0)
                self.tableView.reloadRows( at: [indexPath], with: UITableViewRowAnimation.none )
                self.atBottom=true
            }
        }) 
    }
     
    @IBAction func unblockClicked(_ sender:AnyObject) {
        self.blocked=[:]
        UserDefaults.standard.set(self.blocked, forKey:"meatspaceBlocks")
        self.blockButton.isHidden=true

    }
    
    @IBAction func blockClicked(_ sender:AnyObject) {
        if let blockPost=self.items.object(at: sender.tag) as? MCPost {
            self.blocked[blockPost.fingerprint]="1" as AnyObject
            self.blockButton.isHidden=false
            UserDefaults.standard.set(self.blocked, forKey: "meatspaceBlocks")
            for i in 0 ... self.items.count-1{
                if let post = self.items.object(at: i) as? MCPost {
                    if post.fingerprint == blockPost.fingerprint {
                        self.items.remove(post)
                        self.tableView.reloadData()
                    }
                }
            }
            weak var weakSelf=self
            let alertController = UIAlertController(title: "Report abuse?", message: "You have just chosen to block another meatspacer. Would you like to report this user for objectionable content?", preferredStyle: UIAlertControllerStyle.alert)
            let cancelAction=UIAlertAction(title: "No", style: UIAlertActionStyle.cancel) { (action) in
                
            }
            
            let okAction=UIAlertAction(title: "Yes", style: UIAlertActionStyle.default) { (action) in
                let mf=MFMailComposeViewController()
                mf.setToRecipients(["report@meatspac.es"]);
                mf.mailComposeDelegate=weakSelf;
                mf.setSubject(String(format: "Abuse from user fingerprint %@",blockPost.fingerprint));
                weakSelf!.present(mf, animated: true, completion: {})
                
            }
            alertController.addAction(cancelAction)
            alertController.addAction(okAction)
            
            self.present(alertController, animated:true, completion:nil);
        }

        
        

    }

    func setupSocket() {
        weak var weakSelf=self
        self.postViewController!.setPlaceHolder("Connecting to meatspace")

        
        print("setupSocket")
        self.socket = SocketIOClient(socketURL: URL(string: UserDefaults.standard.object(forKey: "server_url") as! String)!)

        self.socket!.on(clientEvent: .connect) { data, ack in
            print("join")
            weakSelf?.socket!.emit("join", ["mp4"])
            DispatchQueue.main.async(execute: {
                weakSelf?.postViewController!.textfield.isEnabled=true
                weakSelf?.postViewController!.setRandomPlaceholder()
            })
            ack.with("connected")
        }
        self.socket!.on(clientEvent: .disconnect) { data, ack in
            DispatchQueue.main.async(execute: {
                weakSelf?.handleDisconnect()
            })
        }
        self.socket!.on("chat") { data, ack in
            let arr = data as NSArray
            print(arr.count)
            DispatchQueue.main.async(execute: {
                print(arr[0] as! NSDictionary)
//                print(data[1] as! NSDictionary)
            })
            
//            DispatchQueue.main.async(execute: {
//                if let arr = data as NSArray? {
//                    weakSelf!.addPost(arr)
//                }
//            })
        }
        self.socket!.on("message") { data, ack in
            print(data)
            DispatchQueue.main.async(execute: {
                let arr = data as NSArray
                weakSelf!.addPost(arr)
            })
        }
        self.socket!.on("messageack") { data, ack in
            if let message = (data as NSArray)[0] as? String {
                DispatchQueue.main.async(execute: {
                    weakSelf?.postViewController!.setPlaceHolder(message)
                    if let uid=((data as NSArray)[1] as! NSDictionary)["userId"] as? String {
                        self.userId=uid
                    }
                })
            }
        }
        self.socket!.on("userid") { data, ack in
            print(data)
            DispatchQueue.main.async(execute: {
                if let uid=((data as NSArray)[1] as! NSDictionary)["userId"] as? String {
                    self.userId=uid
                }
            })
        }
        self.socket!.on("active") { args, ack in
            DispatchQueue.main.async(execute: {
                self.activeCount.text=((args as NSArray)[0] as AnyObject).stringValue
                self.activeCount.isHidden=false
            })
            
        }
        self.socket!.on(clientEvent: .error) { (errorInfo, ack) in
            print(errorInfo)
            DispatchQueue.main.async(execute: {
                weakSelf?.postViewController!.setPlaceHolder(String(format: "An error occured: %@", errorInfo))
            })
        }
        self.socket!.on(clientEvent: .reconnect) { numberOfAttempts, ack in
            print(String(format: "Reconnect %ld",numberOfAttempts))
        }
        self.socket!.on(clientEvent: .reconnectAttempt) { numberOfAttempts, ack in
            print(String(format: "Attempt %ld",numberOfAttempts))
            DispatchQueue.main.async(execute: {
                weakSelf?.postViewController!.setPlaceHolder("Reconnecting to meatspace.")
            })
        }
//        self.socket!.onReconnectionError={ (errorInfo) in
//            print(errorInfo)
//            DispatchQueue.main.async(execute: {
//                weakSelf!.postViewController!.setPlaceHolder(String(format: "Could not connect: %@", errorInfo!))
//            })
//        }
        
        self.socket!.connect()
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell=tableView.dequeueReusableCell(withIdentifier: "MeatCell", for: indexPath) as? MCPostCell {
            if let post=self.items.object(at: indexPath.row) as? MCPost {
                cell.textView.attributedText=post.attributedString
                cell.timeLabel.text=post.relativeTime()
                if self.userId == post.fingerprint {
                    self.blockButton.isHidden=true
                } else {
                    cell.blockButton.isHidden=false
                    cell.blockButton.tag=indexPath.row
                }
                let item=AVPlayerItem(url: post.videoUrl as URL)
                cell.videoPlayer?.replaceCurrentItem(with: item)
                if self.items.count-1 == self.tableView.visibleCells.count {
                    cell.videoPlayer?.play()
                }
                NotificationCenter.default.addObserver(cell, selector: #selector(cell.playerItemDidReachEnd(_:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: item)
            }
        return cell
        }
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let postCell=cell as? MCPostCell {
            postCell.videoPlayer!.pause()
        }
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if let cell=tableView.cellForRow(at: indexPath) as? MCPostCell {
            cell.blockButton.isHidden=true
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let cell=tableView.cellForRow(at: indexPath) as? MCPostCell {
            cell.blockButton.isHidden=false
        }
    }
    
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange) -> Bool {
        return true
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        self.dismiss(animated: true) {}
    }

}

