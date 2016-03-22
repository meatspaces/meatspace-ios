//
//  NMeatViewController.m
//  MeatChat
//
//  Created by Marcus Ramberg on 14.01.14.
//  Copyright (c) 2014 Nordaaker AS. 
//

#import "MCPostListViewController.h"
#import "MCPostCell.h"
#import <AVFoundation/AVFoundation.h>
#import "Reachability.h"
#import "MeatChat2-Swift.h"


@interface MCPostListViewController ()

@property (retain,nonatomic) NSMutableArray *items;
@property (retain,nonatomic) NSMutableDictionary *blocked;
@property (assign,nonatomic) BOOL atBottom;
@property (strong, nonatomic) NSMutableDictionary *seen;
@property (strong,nonatomic) NSString *userId;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *containerBottom;
@property (weak, nonatomic) IBOutlet UIView *containerView;
@property (weak, nonatomic) IBOutlet UILabel *activeCount;
@property (weak, nonatomic) IBOutlet UIButton *blockButton;
@property (assign, nonatomic) BOOL acceptedEula;


- (void)setupReachability;
- (void)setupSocket;
- (void)teardownSocket;
- (void)addPost: (NSDictionary*)data;
- (void)handleDisconnect;

- (void)keyboardWillHide:(NSNotification *)sender;
- (void)keyboardDidShow:(NSNotification *)sender;

@end

@implementation MCPostListViewController

#pragma mark - UITableview subclass methods

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.blocked=[[[NSUserDefaults standardUserDefaults] dictionaryForKey: @"meatspaceBlocks"] mutableCopy];
    if([self.blocked count]) {
        self.blockButton.hidden=NO;
    }
    self.acceptedEula=[[NSUserDefaults standardUserDefaults] boolForKey: @"acceptedEula"];
    if(!self.acceptedEula) {
        UIAlertController *alertController = [UIAlertController
                                              alertControllerWithTitle: @"Welcome to MeatChat"
                                              message: @"This is a client for the real time chat service chat.meatspac.es. Please behave nicely, objectionable content is not accepted. If someone else posts objectionable content, you can remove current and future messages from them, by using the 'block' button next to their message."
                                              preferredStyle:UIAlertControllerStyleAlert];
        
        
        UIAlertAction *cancelAction = [UIAlertAction
                                       actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel action")
                                       style:UIAlertActionStyleCancel
                                       handler:^(UIAlertAction *action)
                                       {
                                           exit(0);
                                       }];
        
        UIAlertAction *okAction = [UIAlertAction
                                   actionWithTitle:NSLocalizedString(@"OK", @"OK action")
                                   style:UIAlertActionStyleDefault
                                   handler:^(UIAlertAction *action)
                                   {
                                       self.acceptedEula=YES;
                                       [[NSUserDefaults standardUserDefaults] setBool: self.acceptedEula forKey: @"acceptedEula"];
                                       
                                   }];
        [alertController addAction:cancelAction];
        [alertController addAction:okAction];
        
        [self presentViewController: alertController animated:YES completion:nil];
    }
    
    // The most pleasing inset 
    [self.tableView setContentInset:UIEdgeInsetsMake(42, 0, 0, 0)];
    
    self.items=[NSMutableArray array];
    self.seen=[NSMutableDictionary dictionary];
    [self setupReachability];
    
    // Keyboard handling
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
                                   initWithTarget:self
                                   action:@selector(dismissKeyboard)];
    
    [self.view addGestureRecognizer:tap];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidShow:) name:UIKeyboardDidShowNotification object:nil];
    
    // Tableview
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight=75;
    self.atBottom=YES;
}


-(void)scrollToBottom
{
  NSIndexPath *indexPath=[NSIndexPath indexPathForItem:[self.items count]-1 inSection:0];
  [self.tableView scrollToRowAtIndexPath: indexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
}

-(void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
  self.atBottom = NO;
  for (MCPostCell *cell in self.tableView.visibleCells) {
    [cell.videoPlayer pause];
  }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
  [self endScroll: scrollView];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
  [self endScroll: scrollView];
}

- (void)resumePlay
{
  for (MCPostCell *cell in self.tableView.visibleCells) {
    [cell.videoPlayer play];
  }
}

- (void)endScroll: (UIScrollView*)scrollView
{
  [self resumePlay];
  CGFloat height = scrollView.frame.size.height;
  CGFloat contentYoffset = scrollView.contentOffset.y;
  CGFloat distanceFromBottom = scrollView.contentSize.height - contentYoffset;
  self.atBottom = (distanceFromBottom <= height);
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
  for (MCPostCell *cell in self.tableView.visibleCells) {
    [cell.videoPlayer play];
  }
  [self resumePlay];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
  if ([segue.identifier isEqualToString:@"postViewSegue"]) {
    // can't assign the view controller from an embed segue via the storyboard, so capture here
    _postViewController = (MCPostViewController*)segue.destinationViewController;
  }
}


#pragma mark - Socket handling

- (void)setupReachability;
{
  NSURL *server_url=[NSURL URLWithString: [[NSUserDefaults standardUserDefaults] objectForKey: @"server_url"]];
  Reachability* reach = [Reachability reachabilityWithHostname:[server_url host]];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(reachabilityChanged:)
                                               name:kReachabilityChangedNotification
                                             object:nil];
  [reach startNotifier];
  [self setupSocket];
  
}

- (void)reachabilityChanged: (NSNotification*)notif
{
  Reachability *reach=notif.object;
  reach.isReachable ? [self setupSocket] : [self teardownSocket];
}

- (void)setupSocket
{
   __weak typeof(self) weakSelf = self;
  NSLog(@"%@",[[NSUserDefaults standardUserDefaults] objectForKey: @"server_url"]);
  [self.postViewController setPlaceholder: @"Connecting to meatspace"];
  [SIOSocket socketWithHost: [[NSUserDefaults standardUserDefaults] objectForKey: @"server_url"]
                   response: ^(SIOSocket *socket)
   {
     self.socket = socket;
     self.socket.onConnect = ^() {
       [weakSelf.socket emit: @"join" args: @[ @"mp4" ]];
       dispatch_async(dispatch_get_main_queue(), ^{
         weakSelf.postViewController.textfield.enabled = YES;
         [weakSelf.postViewController setRandomPlaceholder];
       });
     };
     self.socket.onDisconnect= ^() {
       dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf handleDisconnect]; });
     };
     [self.socket on: @"message" callback:^(id data) {
       dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf addPost: data]; });
     }];
     [self.socket on: @"messageack" callback:^(NSArray *data) {
       NSString *message=data[0];
       dispatch_async(dispatch_get_main_queue(), ^{
         if([[message class] isSubclassOfClass: [NSString class]]) {
           [weakSelf.postViewController setPlaceholder: message];
         };
         self.userId=[data[1] objectForKey: @"userId"];
       });
     }];
     [self.socket on: @"active" callback:^(NSArray *args) {
       dispatch_async(dispatch_get_main_queue(), ^{
         self.activeCount.text=[args[0] stringValue];
         self.activeCount.hidden=NO;
       });
     }];
     self.socket.onError = ^(NSDictionary *errorInfo) {
       NSLog(@"Oops: %@",errorInfo);
       dispatch_async(dispatch_get_main_queue(), ^{
         [weakSelf.postViewController setPlaceholder: [NSString stringWithFormat: @"An error occured: %@",errorInfo]];
       });
     };
     self.socket.onReconnect = ^(NSInteger numberOfAttempts) {
       NSLog(@"Reconnect %ld", (long)numberOfAttempts);
     };
     self.socket.onReconnectionAttempt =^(NSInteger numberOfAttempts) {
       NSLog(@"Attempt %ld", (long)numberOfAttempts);
       dispatch_async(dispatch_get_main_queue(), ^{
         [weakSelf.postViewController setPlaceholder: @"Reconnecting to meatspace."];
       });
     };
     self.socket.onReconnectionError=^(NSDictionary *errorInfo) {
       NSLog(@"Oops: %@",errorInfo);
       dispatch_async(dispatch_get_main_queue(), ^{
         [weakSelf.postViewController setPlaceholder: [NSString stringWithFormat: @"Could not connect: %@", errorInfo]];
       });
     };
   }];
}

- (void)teardownSocket
{
  [self.socket close];
  self.socket=nil;
  [self.postViewController setPlaceholder: @"Get the internet, bae."];
}


-(void)handleDisconnect
{
   [self.postViewController.textfield resignFirstResponder];
   self.postViewController.textfield.enabled=NO;
   [self.postViewController setPlaceholder: @"Disconnected, please hold"];
   self.activeCount.hidden=YES;
  
}

- (void)flushItems
{
  for (MCPost *item in self.items) {
    [item cleanup];
  }
  [self.items removeAllObjects];
  [self.tableView reloadData];
}

- (void)addPost: (NSArray*)args
{
  NSDictionary *data=args[0];
  if([self.blocked objectForKey: [data objectForKey: @"fingerprint"]]) { return; }
  
  // Flush old posts
  [self.tableView beginUpdates];
  for( int i = (int)[self.items count] - 1; i >= 0; --i) {
    MCPost *post=[self.items objectAtIndex: i];
    if ([post isObsolete]) {
      [post cleanup];
      [self.items removeObjectAtIndex: i];
      [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForItem:i inSection:0]]  withRowAnimation:UITableViewRowAnimationAutomatic];
    }
  }
  [self.tableView endUpdates];
  
  NSString *key=[data objectForKey: @"key"];
  if (key) {
    if([self.seen objectForKey: key] ) { return; }
    [self.seen setObject: @"1" forKey: key];
  };
  MCPost *post=[[MCPost alloc] initWithDict: data];
  [self.items addObject: post];
  NSIndexPath *newRow=[NSIndexPath indexPathForItem:[self.items count]-1 inSection:0];
  [CATransaction begin];
  [CATransaction setCompletionBlock:^{
    if (self.atBottom) {
      [self scrollToBottom];
    }
  }];
  [self.tableView beginUpdates];
  [self.tableView insertRowsAtIndexPaths:@[newRow] withRowAnimation: UITableViewRowAnimationFade];
  [self.tableView endUpdates];
  [CATransaction commit];
}



#pragma mark - Keyboard handling

-(void)dismissKeyboard {
  [self.postViewController closePostWithPosted: NO];
}

- (void)keyboardDidShow:(NSNotification *)sender {
  CGRect frame = [sender.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
  self.containerBottom.constant = frame.size.height;
  [self.containerView setNeedsUpdateConstraints];
  [UIView animateWithDuration:0.25f animations:^{
    [self.containerView layoutIfNeeded];
    self.containerHeight.constant = 75.0;
    self.postViewController.characterCount.hidden=NO;
  } completion:^(BOOL finished) {
    if([self.items count]) {
      [self scrollToBottom];
      self.atBottom=YES;
    }
  }];
}

- (void)keyboardWillHide:(NSNotification *)sender
{
  self.containerBottom.constant = 0;
  [self.containerView setNeedsUpdateConstraints];
  [UIView animateWithDuration:0.25f animations:^{
    [self.containerView layoutIfNeeded];
    self.containerHeight.constant = 35.0;
  } completion:^(BOOL finished) {
    if([self.items count]) {
      [self scrollToBottom];
      [self.tableView reloadRowsAtIndexPaths: @[[NSIndexPath indexPathForItem:[self.items count]-1 inSection:0]]
                            withRowAnimation: UITableViewRowAnimationNone];
      self.atBottom=YES;
    }
  }];
}


- (IBAction)unblockClicked:(id)sender {
  [self.blocked removeAllObjects];
  [[NSUserDefaults standardUserDefaults] setObject: self.blocked forKey:@"meatspaceBlocks"];
  self.blockButton.hidden=YES;
}

- (IBAction)blockClicked:(UIButton*)sender {
  MCPost *blockPost=[self.items objectAtIndex: sender.tag];
  [self.blocked setObject: @"1" forKey: blockPost.fingerprint];
  self.blockButton.hidden=NO;
  [[NSUserDefaults standardUserDefaults] setObject: self.blocked forKey:@"meatspaceBlocks"];
  for( int i = (int)[self.items count]-1; i >=0; --i) {
    MCPost *post=[self.items objectAtIndex: i];
    if([post.fingerprint isEqualToString: blockPost.fingerprint] ) {
      [self.items removeObject: post];
    }
    [self.tableView reloadData];
  }
  __weak __typeof(self)weakSelf = self;
    UIAlertController *alertController = [UIAlertController
                                          alertControllerWithTitle: @"Report abuse?"
                                          message: @"You have just chosen to block another meatspacer. Would you like to report this user for objectionable content?"
                                          preferredStyle:UIAlertControllerStyleAlert];
    
    
    UIAlertAction *cancelAction = [UIAlertAction
                                   actionWithTitle:NSLocalizedString(@"No", @"No")
                                   style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction *action)
                                   {
                                   }];
    
    UIAlertAction *okAction = [UIAlertAction
                               actionWithTitle:NSLocalizedString(@"Yes", @"Yes")
                               style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction *action)
                               {
                                 MFMailComposeViewController *mf=[[MFMailComposeViewController alloc] init];
                                 [mf setToRecipients: @[@"report@meatspac.es"]];
                                 mf.mailComposeDelegate=weakSelf;
                                 [mf setSubject: [NSString stringWithFormat: @"Abuse from user fingerprint %@",blockPost.fingerprint]];
                                [weakSelf presentViewController: mf animated: YES completion:^{
                                }];
                                   
                               }];
    [alertController addAction:cancelAction];
    [alertController addAction:okAction];
    
    [self presentViewController: alertController animated:YES completion:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return [self.items count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  static NSString *CellIdentifier = @"MeatCell";
  MCPostCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
  
  // Configure the cell...
  MCPost *post=[self.items objectAtIndex:indexPath.row];
  cell.textView.attributedText=post.attributedString;
  cell.timeLabel.text=[post relativeTime];
  if([self.userId isEqualToString: post.fingerprint]) {
    self.blockButton.hidden=YES;
  }
  else {
    cell.blockButton.hidden=NO;
    cell.blockButton.tag=indexPath.row;
  }
  AVPlayerItem *item=[AVPlayerItem playerItemWithURL: post.videoUrl];

  [cell.videoPlayer replaceCurrentItemWithPlayerItem: item];
  
  if(([self.items count]-1)==[self.tableView.visibleCells count]) {
    [cell.videoPlayer play];
  }
  [[NSNotificationCenter defaultCenter] addObserver: cell
                                           selector:@selector(playerItemDidReachEnd:)
                                               name:AVPlayerItemDidPlayToEndTimeNotification
                                             object:item];
  return cell;
}

- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
  [[(MCPostCell*)cell videoPlayer] pause];
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
  MCPostCell *cell = (MCPostCell*)[tableView cellForRowAtIndexPath:indexPath];
  cell.blockButton.hidden=YES;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  MCPostCell *cell = (MCPostCell*)[tableView cellForRowAtIndexPath:indexPath];
  cell.blockButton.hidden=NO;
}


#pragma mark - AVPlayer delegate




#pragma mark - UITextView delegate for cells

- (BOOL)textView:(UITextView *)textView shouldInteractWithURL:(NSURL *)URL inRange:(NSRange)characterRange
{
  return YES;
}

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
  [self dismissViewControllerAnimated: YES completion:^{
    
  }];
}

@end
