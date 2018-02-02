//
//  UncaughtExceptionHandler.h
//  UncaughtExceptionHandler
//
//  Created by sherwin.chen on 2018/2/1.
//  Copyright © 2018年 sherwin.chen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define UEH_CrashAlertTitle   (@"出错啦")
#define UEH_CrashAlertContent (@"非常报歉,APP遇到意外无法运行,请您重新启动.")
#define UEH_CrashAlertButtonName  (@"退出重启")

@interface UncaughtExceptionHandler : NSObject

/*!
 *  异常的处理方法
 *
 *  @param install   是否开启捕获异常
 *  @param showAlert 是否在发生异常时弹出alertView
 */
+ (void)installUncaughtExceptionHandler:(BOOL)install showAlert:(BOOL)showAlert;

//处理报错信息
- (void)validateAndSaveCriticalApplicationData:(NSException *)exception;

@end
