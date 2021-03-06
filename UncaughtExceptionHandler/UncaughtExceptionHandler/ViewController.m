//
//  ViewController.m
//  UncaughtExceptionHandler
//
//  Created by sherwin.chen on 2018/2/1.
//  Copyright © 2018年 sherwin.chen. All rights reserved.
//

/*
 NSInvalidArgumentException
 NSRangeException
 NSGenericException
 NSInternalInconsistencyException
 NSFileHandleOperationException
 NSInvalidArgumentException

 */



#import "ViewController.h"


#import "LTBaseWebViewController.h"

#define IMG_COL(color) [UIImage qmui_imageWithColor:color size:CGSizeMake(40, 40) cornerRadius:3.f]

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self setupUI];
    
}

-(void) setupUI {
    
    //self.view.backgroundColor = UIColorGrayDarken;
    
}



- (void)initDataSource {
    
    self.dataSource = [[QMUIOrderedDictionary alloc] initWithKeysAndObjects:
                       @"数组越界", [UIImage qmui_imageWithColor:UIColorBlue size:CGSizeMake(40, 40) cornerRadius:3.f],
                       @"野指针", [UIImage qmui_imageWithColor:UIColorYellow size:CGSizeMake(40, 40) cornerRadius:3.f],
                       @"其它", [UIImage qmui_imageWithColor:UIColorGreen size:CGSizeMake(40, 40) cornerRadius:3.f],
                       nil
                       ];
    
}


- (void)setNavigationItemsIsInEditMode:(BOOL)isInEditMode animated:(BOOL)animated {
    [super setNavigationItemsIsInEditMode:isInEditMode animated:animated];
    self.title = @"UncaughtExceptionHandler";
}


- (void)didSelectCellWithTitle:(NSString *)title {
    if ([title isEqualToString:@"数组越界"]) {
        NSArray *ar =@[@"1"];
        ar[2];
    }
    else if([title isEqualToString:@"野指针"]) {
        LTBaseWebViewController *webView = [[LTBaseWebViewController alloc] init];
        webView.homeURL = @"https://github.com/chensheng12330/UncaughtExceptionHandler";
        [self.navigationController pushViewController:webView animated:YES];
    }
    else if([title isEqualToString:@"title"]) {
        
    }
}
@end
