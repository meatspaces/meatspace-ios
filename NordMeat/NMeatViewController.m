//
//  NMeatViewController.m
//  NordMeat
//
//  Created by Marcus Ramberg on 14.01.14.
//  Copyright (c) 2014 Nordaaker AS. All rights reserved.
//

#import "NMeatViewController.h"
#import "NMeatCell.h"
#import "SocketIOPacket.h"
#import "SBJson4Parser.h"
#import "NMPostMeatViewController.h"
#import "NMeatPost.h"



@interface NMeatViewController ()

@property (retain,nonatomic) NSMutableArray *items;
@property (retain,nonatomic) SocketIO *socket;
@property (assign,nonatomic) BOOL atBottom;

@end

@implementation NMeatViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
  self.items=[NSMutableArray array];
  self.socket = [[SocketIO alloc] initWithDelegate:self];

  [self.socket connectToHost:@"localhost"
                   onPort:3000
               withParams:[NSDictionary dictionaryWithObjectsAndKeys:@"1234", @"auth_token", nil]
   ];
  

  self.tableView.estimatedRowHeight=120;
  self.tableView.rowHeight = UITableViewAutomaticDimension;
  self.atBottom=YES;
}


- (void)socketIO:(SocketIO *)socket didReceiveEvent:(SocketIOPacket *)packet
{
  NSDictionary *data=[packet dataAsJSON];
  NSDictionary *chat=[[[[data objectForKey: @"args"] objectAtIndex:0] objectForKey: @"chat"] objectForKey: @"value"];
  NMeatPost *post=[[NMeatPost alloc] initWithDictionary: chat];
  //  NSLog(@"%@",[chat allKeys]);
   [self.items addObject: post];
    NSIndexPath *newRow=[NSIndexPath indexPathForItem:[self.items count]-1 inSection:0];
    [self.tableView insertRowsAtIndexPaths:@[newRow] withRowAnimation: UITableViewRowAnimationAutomatic];
   if (self.atBottom) {
    [self.tableView scrollToRowAtIndexPath: newRow atScrollPosition:UITableViewScrollPositionBottom animated:YES];
   }

}


- (void)post: (id)sender
{
  NMPostMeatViewController *post=[[NMPostMeatViewController alloc] init];
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
    NMeatCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    // Configure the cell...
    NMeatPost *post=[self.items objectAtIndex:indexPath.row];
    cell.postLabel.attributedText=[post attributedBody];
    cell.postImage.image=[post image];
    cell.timeLabel.text=[post relativeTime];
 
    return cell;
}



-(void)scrollViewDidScroll:(UIScrollView *)scrollView
{
  CGFloat height = scrollView.frame.size.height;
  
  CGFloat contentYoffset = scrollView.contentOffset.y;
  
  CGFloat distanceFromBottom = scrollView.contentSize.height - contentYoffset;
  
  self.atBottom = (distanceFromBottom <= height);
}



@end
