//
//  NMeatViewController.m
//  MeatChat
//
//  Created by Marcus Ramberg on 14.01.14.
//  Copyright (c) 2014 Nordaaker AS. 
//

#import "MCPostListViewController.h"
#import "MCPostCell.h"
#import "MCPost.h"
#import <AVFoundation/AVFoundation.h>
#import "TestFlight.h"
#import "Reachability.h"


@interface MCPostListViewController ()

@property (retain,nonatomic) NSMutableArray *items;
@property (assign,nonatomic) BOOL atBottom;
@property (strong, nonatomic) NSMutableDictionary *seen;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *containerBottom;
@property (weak, nonatomic) IBOutlet UIView *containerView;


- (void)setupReachability;
- (void)setupSocket;
- (void)teardownSocket;
- (void)addPost: (NSDictionary*)data;
- (void)handleDisconnect;

- (void)keyboardWillHide:(NSNotification *)sender;
- (void)keyboardDidShow:(NSNotification *)sender;

- (void)playerItemDidReachEnd:(NSNotification *)notification;


@end

@implementation MCPostListViewController

#pragma mark - UITableview subclass methods

- (void)viewDidLoad
{
  [super viewDidLoad];
  

  self.items=[NSMutableArray array];
  [self setupReachability];
 
    // Keyboard handling
  UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
                                 initWithTarget:self
                                 action:@selector(dismissKeyboard)];
  
  [self.view addGestureRecognizer:tap];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil]
  ;
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidShow:) name:UIKeyboardDidShowNotification object:nil];;
  
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

- (void)endScroll: (UIScrollView*)scrollView
{
  for (MCPostCell *cell in self.tableView.visibleCells) {
    [cell.videoPlayer play];
  }
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
  Reachability* reach = [Reachability reachabilityWithHostname:@"chat.meatspac.es"];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(reachabilityChanged:)
                                               name:kReachabilityChangedNotification
                                             object:nil];
  
  [reach startNotifier];
  
}

- (void)reachabilityChanged: (NSNotification*)notif
{
  Reachability *reach=notif.object;
  reach.isReachable ? [self setupSocket] : [self teardownSocket];
}

- (void)setupSocket
{
   __weak typeof(self) weakSelf = self;
  [SIOSocket socketWithHost: @"https://chat.meatspac.es/" response: ^(SIOSocket *socket)
   {
   [self.postViewController setPlaceholder: @"Connecting to meatspace"];
   self.socket = socket;
   self.socket.onConnect = ^()
     {
     [weakSelf.socket emit: @"join",@"mp4", nil];
     dispatch_async(dispatch_get_main_queue(), ^{
       weakSelf.postViewController.textfield.enabled=YES;
       [weakSelf.postViewController setRandomPlaceholder];
       [weakSelf flushItems];
     });
     };
   self.socket.onDisconnect= ^()
   {
   dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf handleDisconnect]; });
   };
   [self.socket on: @"message"  callback:^(id data) {
     dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf addPost: data]; });
   }];
   [self.socket on: @"messageack"  callback:^(id data) {
     dispatch_async(dispatch_get_main_queue(), ^{
       if(![[data class] isSubclassOfClass: [NSNull class]]) {
         NSLog(@"failed: %@",data);
       };
     });
   }];
   self.socket.onError = ^(NSDictionary *errorInfo) {
     NSLog(@"Oops: %@",errorInfo);
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
  self.socket=NULL;
  [self.postViewController setPlaceholder: @"Get the internet, bae."];
}


-(void)handleDisconnect
{
   [self.postViewController.textfield resignFirstResponder];
   self.postViewController.textfield.enabled=NO;
   [self.postViewController setPlaceholder: @"Disconnected, please hold"];
  
}

- (void)flushItems
{
  for (MCPost *item in self.items) {
    [item cleanup];
  }
  [self.items removeAllObjects];
  [self.tableView reloadData];
}

- (void)addPost: (NSDictionary*)data
{
  [self.tableView beginUpdates];
  for( int i = (int)[self.items count]-1; i >=0; --i)
  {
  MCPost *post=[self.items objectAtIndex: i];
    if ([post isObsolete]) {
      [post cleanup];
      [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForItem:i inSection:0]]  withRowAnimation:UITableViewRowAnimationAutomatic];
      [self.items removeObjectAtIndex: i];
    }
  }
  [self.tableView endUpdates];
  
  NSString *key=[data objectForKey: @"fingerprint"];
  if (key) [self.seen setObject: @"1" forKey: key];
  MCPost *post=[[MCPost alloc] initWithDictionary: data];
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
      self.atBottom=YES;
    }
  }];
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
  AVPlayerItem *item=[AVPlayerItem playerItemWithURL: post.videoUrl];

  [cell.videoPlayer replaceCurrentItemWithPlayerItem: item];
  
  if(([self.items count]-1)==[self.tableView.visibleCells count]) {
    [cell.videoPlayer play];
  }
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(playerItemDidReachEnd:)
                                               name:AVPlayerItemDidPlayToEndTimeNotification
                                             object:item];
  return cell;
}

- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
  [[(MCPostCell*)cell videoPlayer] pause];
}


#pragma mark - AVPlayer delegate


- (void)playerItemDidReachEnd:(NSNotification *)notification
{
  AVPlayerItem *p = [notification object];
  [p seekToTime:kCMTimeZero];
}



#pragma mark - UITextView delegate for cells

- (BOOL)textView:(UITextView *)textView shouldInteractWithURL:(NSURL *)URL inRange:(NSRange)characterRange
{
  return YES;
}

@end
