//
//  UncaughtExceptionHandler.m
//  UncaughtExceptionHandler
//
//  Created by sherwin.chen on 2018/2/1.
//  Copyright © 2018年 sherwin.chen. All rights reserved.
//

#import "UncaughtExceptionHandler.h"
#include <libkern/OSAtomic.h>
#include <execinfo.h>


NSString * const UncaughtExceptionHandlerSignalExceptionName = @"UncaughtExceptionHandlerSignalExceptionName";
NSString * const UncaughtExceptionHandlerSignalKey = @"UncaughtExceptionHandlerSignalKey";
NSString * const UncaughtExceptionHandlerAddressesKey = @"UncaughtExceptionHandlerAddressesKey";

volatile int32_t UncaughtExceptionCount = 0;
const int32_t UncaughtExceptionMaximum = 10;


static NSUncaughtExceptionHandler *_previousHandler;

void ueh_HandleException(NSException *exception);
void ueh_SignalHandler(int signal);
//NSString* getAppInfo();


@interface UncaughtExceptionHandler()

@property (assign, nonatomic) BOOL needCrashShowAlert;
@end

@implementation UncaughtExceptionHandler


/**
 设置异常处理句柄
 
 @param  crashShowAlert 是否需要在崩溃时弹提示框（YES Or NO）

 */

+ (void)installUncaughtExceptionHandler:(BOOL)crashShowAlert {
    
    if (crashShowAlert) {
        [[self alloc] alertView:crashShowAlert];
    }
    
    //获取已经设置过的异常句柄.
    _previousHandler = NSGetUncaughtExceptionHandler();
    
    // 设置自己处理异常的handler （ueh_HandleException 是自己处理异常的方法）
    NSSetUncaughtExceptionHandler(ueh_HandleException);
    
    signal(SIGABRT, ueh_SignalHandler);
    signal(SIGILL,  ueh_SignalHandler);
    signal(SIGSEGV, ueh_SignalHandler);
    signal(SIGFPE,  ueh_SignalHandler);
    signal(SIGBUS,  ueh_SignalHandler);
    signal(SIGPIPE, ueh_SignalHandler);
}

- (void)alertView:(BOOL)show {
    
    self.needCrashShowAlert = show;
}

//获取调用堆栈
+ (NSArray *)backtrace {
    
    //指针列表
    void* callstack[128];
    //backtrace用来获取当前线程的调用堆栈，获取的信息存放在这里的callstack中
    //128用来指定当前的buffer中可以保存多少个void*元素
    //返回值是实际获取的指针个数
    int frames = backtrace(callstack, 128);
    //backtrace_symbols将从backtrace函数获取的信息转化为一个字符串数组
    //返回一个指向字符串数组的指针
    //每个字符串包含了一个相对于callstack中对应元素的可打印信息，包括函数名、偏移地址、实际返回地址
    char **strs = backtrace_symbols(callstack, frames);
    
    int i;
    NSMutableArray *backtrace = [NSMutableArray arrayWithCapacity:frames];
    for (i = 0; i < frames; i++) {
        
        [backtrace addObject:[NSString stringWithUTF8String:strs[i]]];
    }
    free(strs);
    
    return backtrace;
}

//处理报错信息
- (void)validateAndSaveCriticalApplicationData:(NSException *)exception {
    
    NSString *exceptionInfo = [NSString stringWithFormat:@"\n--------Log Exception---------\n\nexception name      :%@\nexception reason    :%@\nexception userInfo  :%@\ncallStackSymbols    :%@\n\n--------End Log Exception-----",exception.name, exception.reason, exception.userInfo ? : @"no user info", [exception callStackSymbols]];
    
    NSLog(@"%@", exceptionInfo);
}

- (void)handleException:(NSException *)exception {
    
    //错误日志先给自己处理  再给友盟
    [self validateAndSaveCriticalApplicationData:exception];
    
    //将错误日志传递给其它监听者.
    _previousHandler(exception);
    
    if ( !self.needCrashShowAlert) {
        return;
    }
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    UIAlertView *alert =
    [[UIAlertView alloc]
     initWithTitle:UEH_CrashAlertTitle
     message:[NSString stringWithFormat:UEH_CrashAlertContent]
     delegate:self
     cancelButtonTitle:UEH_CrashAlertButtonName
     otherButtonTitles:nil];
    [alert show];
#pragma clang diagnostic pop
    
    
    CFRunLoopRef runLoop = CFRunLoopGetCurrent();
    CFArrayRef allModes = CFRunLoopCopyAllModes(runLoop);
    
//    while (!self.dismissed) {
        //点击继续
        for (NSString *mode in (__bridge NSArray *)allModes) {
            //快速切换Mode
            CFRunLoopRunInMode((CFStringRef)mode, 0.001, false);
        }
//    }
    
    //点击退出
    CFRelease(allModes);
    
    NSSetUncaughtExceptionHandler(NULL);
    
    signal(SIGABRT, SIG_DFL);
    signal(SIGILL, SIG_DFL);
    signal(SIGSEGV, SIG_DFL);
    signal(SIGFPE, SIG_DFL);
    signal(SIGBUS, SIG_DFL);
    signal(SIGPIPE, SIG_DFL);
    
    if ([[exception name] isEqual:UncaughtExceptionHandlerSignalExceptionName]) {
        
        kill(getpid(), [[[exception userInfo] objectForKey:UncaughtExceptionHandlerSignalKey] intValue]);
        
    } else {
        
//        [exception raise];
    }
}
@end


void ueh_HandleException(NSException *exception) {
    
    int32_t exceptionCount = OSAtomicIncrement32(&UncaughtExceptionCount);
    // 如果太多不用处理
    if (exceptionCount > UncaughtExceptionMaximum) {
        return;
    }
    
    //获取调用堆栈
    NSArray *callStack = [exception callStackSymbols];
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:[exception userInfo]];
    [userInfo setObject:callStack forKey:UncaughtExceptionHandlerAddressesKey];
    
    //在主线程中，执行制定的方法, withObject是执行方法传入的参数
    [[[UncaughtExceptionHandler alloc] init]
     performSelectorOnMainThread:@selector(handleException:)
     withObject:
     [NSException exceptionWithName:[exception name]
                             reason:[exception reason]
                           userInfo:userInfo]
     waitUntilDone:YES];
}

//处理signal报错
void ueh_SignalHandler(int signal) {
    
    int32_t exceptionCount = OSAtomicIncrement32(&UncaughtExceptionCount);
    // 如果太多不用处理
    if (exceptionCount > UncaughtExceptionMaximum) {
        return;
    }
    
    NSString* description = nil;
    switch (signal) {
        case SIGABRT:
            description = [NSString stringWithFormat:@"Signal SIGABRT was raised!\n"];
            break;
        case SIGILL:
            description = [NSString stringWithFormat:@"Signal SIGILL was raised!\n"];
            break;
        case SIGSEGV:
            description = [NSString stringWithFormat:@"Signal SIGSEGV was raised!\n"];
            break;
        case SIGFPE:
            description = [NSString stringWithFormat:@"Signal SIGFPE was raised!\n"];
            break;
        case SIGBUS:
            description = [NSString stringWithFormat:@"Signal SIGBUS was raised!\n"];
            break;
        case SIGPIPE:
            description = [NSString stringWithFormat:@"Signal SIGPIPE was raised!\n"];
            break;
        default:
            description = [NSString stringWithFormat:@"Signal %d was raised!",signal];
    }
    
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    NSArray *callStack = [UncaughtExceptionHandler backtrace];
    [userInfo setObject:callStack forKey:UncaughtExceptionHandlerAddressesKey];
    [userInfo setObject:[NSNumber numberWithInt:signal] forKey:UncaughtExceptionHandlerSignalKey];
    
    //在主线程中，执行指定的方法, withObject是执行方法传入的参数
    [[[UncaughtExceptionHandler alloc] init]
     performSelectorOnMainThread:@selector(handleException:)
     withObject:
     [NSException exceptionWithName:UncaughtExceptionHandlerSignalExceptionName
                             reason: description
                           userInfo: userInfo]
     waitUntilDone:YES];
}

NSString* getAppInfo() {
    
    NSString *appInfo = [NSString stringWithFormat:@"App : %@ %@(%@)\nDevice : %@\nOS Version : %@ %@\n",
                         [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"],
                         [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
                         [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"],
                         [UIDevice currentDevice].model,
                         [UIDevice currentDevice].systemName,
                         [UIDevice currentDevice].systemVersion];
    return appInfo;
}

