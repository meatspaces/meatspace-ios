//
//  NMeatViewController.m
//  NordMeat
//
//  Created by Marcus Ramberg on 14.01.14.
//  Copyright (c) 2014 Nordaaker AS. 
//

#import "MCPostListViewController.h"
#import "MCPostCell.h"
#import "MCPostViewController.h"
#import "MCPost.h"



@interface MCPostListViewController ()

@property (retain,nonatomic) NSMutableArray *items;
@property (assign,nonatomic) BOOL atBottom;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *containerBottom;
@property (weak, nonatomic) IBOutlet UIView *containerView;
@property (strong, nonatomic) NSMutableDictionary *seen;
@property (strong, nonatomic) AVPlayer *avplayer;
@property (nonatomic,assign) BOOL socketIsConnected;


- (void)addPost: (NSDictionary*)data;
- (void)setupAVPlayer;
- (void)playerItemDidReachEnd:(NSNotification *)notification;
- (void)keyboardWillHide:(NSNotification *)sender;
- (void)keyboardDidShow:(NSNotification *)sender;


@end

@implementation MCPostListViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
  self.ip=@"127.0.0.1";
  [self setupAVPlayer];
  self.seen=[NSMutableDictionary dictionary];
  self.items=[NSMutableArray array];
    [SIOSocket socketWithHost: @"https://chat.meatspac.es/" response: ^(SIOSocket *socket)
     // [SIOSocket socketWithHost: @"http://mrbook.local:3000/" response: ^(SIOSocket *socket)
   {
   self.socket = socket;
   __weak typeof(self) weakSelf = self;
   self.socket.onConnect = ^()
     {
     weakSelf.socketIsConnected = YES;
     [weakSelf.socket emit: @"join",@"mp4", nil];
     };
   [self.socket on: @"message"  callback:^(id data) {
     [weakSelf performSelectorOnMainThread:@selector(addPost:) withObject:data waitUntilDone:NO];
   }];
   [self.socket on: @"ip" callback:^(id data) {
     NSLog(@"ip: %@",data);
     self.ip=data;
   }];
   self.socket.onError = ^(NSDictionary *errorInfo) {
     NSLog(@"Oops: %@",errorInfo);
   };
   self.socket.onReconnect = ^(NSInteger numberOfAttempts) {
     NSLog(@"Reconnect %ld", (long)numberOfAttempts);
   };
   self.socket.onReconnectionAttempt =^(NSInteger numberOfAttempts) {
     NSLog(@"Attempt %ld", (long)numberOfAttempts);
   };
   self.socket.onReconnectionError=^(NSDictionary *errorInfo) {
     NSLog(@"Oops: %@",errorInfo);
   };
   }];
  
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil]
  ;
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidShow:) name:UIKeyboardDidShowNotification object:nil];;
  self.tableView.rowHeight = UITableViewAutomaticDimension;
  self.tableView.estimatedRowHeight=75;
  self.atBottom=YES;
}

-(void)setupAVPlayer
{
  self.avplayer=[[AVPlayer alloc] init];
  self.avplayer.actionAtItemEnd = AVPlayerActionAtItemEndNone;
  
  
}

- (void)playerItemDidReachEnd:(NSNotification *)notification
{
  AVPlayerItem *p = [notification object];
  [p seekToTime:kCMTimeZero];
}



- (void)addPost: (NSDictionary*)data
{
  
  NSString *key=[data objectForKey: @"fingerprint"];
    //  if(![self.seen valueForKey: key]) {
    if (key) [self.seen setObject: @"1" forKey: key];
    MCPost *post=[[MCPost alloc] initWithDictionary: data];
    [self.items addObject: post];
    NSIndexPath *newRow=[NSIndexPath indexPathForItem:[self.items count]-1 inSection:0];
    [self.tableView beginUpdates];
    [self.tableView insertRowsAtIndexPaths:@[newRow] withRowAnimation: UITableViewRowAnimationFade];
    [self.tableView endUpdates];
    if (self.atBottom) {
      [self.tableView scrollToRowAtIndexPath: newRow atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    }
    // }
}

#pragma mark - Keyboard handling


- (void)keyboardDidShow:(NSNotification *)sender {
  CGRect frame = [sender.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
  self.containerBottom.constant = frame.size.height;
  [self.containerView setNeedsUpdateConstraints];
}

- (void)keyboardWillHide:(NSNotification *)sender {
  self.containerBottom.constant = 0;
  [self.view setNeedsUpdateConstraints];
}


- (void)post: (id)sender
{
  MCPostViewController *post=[[MCPostViewController alloc] init];
  [self presentViewController: post animated:YES completion:^{
    NSLog(@"Presentmodal");
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
  CGRect frame=cell.frame;
  frame.size = [cell.textView sizeThatFits:CGSizeMake(cell.textView.frame.size.width, 800)];
  cell.textView.frame=frame;
  cell.timeLabel.text=[post relativeTime];
  AVPlayerItem *item=[AVPlayerItem playerItemWithURL: post.videoUrl];
  
  
  AVPlayer *avplayer=[AVPlayer playerWithPlayerItem: item];
  avplayer.actionAtItemEnd=AVPlayerActionAtItemEndNone;
  AVPlayerLayer *layer=[AVPlayerLayer playerLayerWithPlayer: avplayer];
  layer.frame=CGRectMake(0, 0, 100, 75);
  layer.videoGravity=AVLayerVideoGravityResizeAspectFill;
  [cell.video.layer addSublayer: layer];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(playerItemDidReachEnd:)
                                               name:AVPlayerItemDidPlayToEndTimeNotification
                                             object:[self.avplayer currentItem]];
  
  [avplayer play];
  return cell;
}

-(void)scrollViewDidScroll:(UIScrollView *)scrollView
{
  CGFloat height = scrollView.frame.size.height;
  
  CGFloat contentYoffset = scrollView.contentOffset.y;
  
  CGFloat distanceFromBottom = scrollView.contentSize.height - contentYoffset;
  
  self.atBottom = (distanceFromBottom <= height);
}

- (BOOL)textView:(UITextView *)textView shouldInteractWithURL:(NSURL *)URL inRange:(NSRange)characterRange
{
  return YES;
}



@end
