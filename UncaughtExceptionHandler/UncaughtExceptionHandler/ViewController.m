//
//  ViewController.m
//  UncaughtExceptionHandler
//
//  Created by sherwin.chen on 2018/2/1.
//  Copyright © 2018年 sherwin.chen. All rights reserved.
//

#import "ViewController.h"

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
                       @"数组越界", [UIImage qmui_imageWithColor:UIColorYellow size:CGSizeMake(40, 40) cornerRadius:3.f],
                       @"野指针", [UIImage qmui_imageWithColor:UIColorYellow size:CGSizeMake(40, 40) cornerRadius:3.f],nil
                       ];
    
}


- (void)setNavigationItemsIsInEditMode:(BOOL)isInEditMode animated:(BOOL)animated {
    [super setNavigationItemsIsInEditMode:isInEditMode animated:animated];
    self.title = @"UncaughtExceptionHandler";
}


- (void)didSelectCellWithTitle:(NSString *)title {
    
}
@end
