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
#include <sys/utsname.h>

#include <mach-o/dyld.h>
#include <mach-o/loader.h>

#include <dlfcn.h>
#include "fishhook.h"


NSString * const UncaughtExceptionHandlerSignalExceptionName = @"UncaughtExceptionHandlerSignalExceptionName";
NSString * const UncaughtExceptionHandlerSignalKey    = @"UncaughtExceptionHandlerSignalKey";
NSString * const UncaughtExceptionHandlerAddressesKey = @"UncaughtExceptionHandlerAddressesKey";

#define ExceptionDirectoryName (@"Exception")
#define SH_F ([NSFileManager defaultManager])

//volatile int32_t UncaughtExceptionCount = 0;
//const int32_t UncaughtExceptionMaximum = 10;


static NSUncaughtExceptionHandler *_previousHandler;
static NSString* gob_ExceptionPath=nil;

///////////////全局方法(C 函数接口)////////////////
/**
 Exception 类型
 */
void ueh_HandleException(NSException *exception);

/**
 信号异常类型
 */
void ueh_SignalHandler(int signal);

/**
  交互捕获异常函数声明
 */
static void ext_NSSetUncaughtExceptionHandler(NSUncaughtExceptionHandler * handler);
///////////////////////////////

/**
  捕获异常函数地址声明
 */
static void (*original_NSSetUncaughtExceptionHandler)(NSUncaughtExceptionHandler* __nullable handler);

@interface UncaughtExceptionHandler()

@property (assign, nonatomic) BOOL needCrashShowAlert;
@property (assign, nonatomic) BOOL dismissed;

@end

@implementation UncaughtExceptionHandler


/**
 设置异常处理句柄
 */

+ (void)installUncaughtException:(GetExceptionBlock) getExceptionInfo{
    
    //获取已经设置过的异常句柄.
    _previousHandler = NSGetUncaughtExceptionHandler();
    
    // 设置自己处理异常的handler （ueh_HandleException 是自己处理异常的方法）
    NSSetUncaughtExceptionHandler(ueh_HandleException);
    
    
    // 系统异常信号
    signal(SIGABRT, ueh_SignalHandler);
    signal(SIGILL,  ueh_SignalHandler);
    signal(SIGSEGV, ueh_SignalHandler);
    signal(SIGFPE,  ueh_SignalHandler);
    signal(SIGBUS,  ueh_SignalHandler);
    signal(SIGPIPE, ueh_SignalHandler);

    //如需要启动时返回已存的crash信息，则输出相关日志.
    if(getExceptionInfo){
        NSString *exceptionLog = [[self class] readDataFromLocal];
        if (exceptionLog.length>0) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                getExceptionInfo(exceptionLog);
            });
        }
    }

    // 获取函数地址，并保存起来，用来进行交换.
    original_NSSetUncaughtExceptionHandler = dlsym(RTLD_DEFAULT, "NSSetUncaughtExceptionHandler");
    
    
    // 初始化一个 rebinding 结构体
    struct rebinding open_rebinding =
    {
        "NSSetUncaughtExceptionHandler",
        ext_NSSetUncaughtExceptionHandler,
        (void *)& original_NSSetUncaughtExceptionHandler
    };
    
    // 将结构体包装成数组，并传入数组的大小，对原符号 open_rebinding 进行重绑定
    rebind_symbols((struct rebinding[1]){open_rebinding}, 1);
    
    return;
}

#pragma mark - SH 异常存储目录
+ (NSString*) exceptionDocumentsDirectory {
    
    if (gob_ExceptionPath.length>0) {
        //如果已设置，直接返回文件夹路径.
        return gob_ExceptionPath;
    }
    
    NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *exceptionPath = [docPath stringByAppendingPathComponent:ExceptionDirectoryName];
    
    if(![SH_F fileExistsAtPath:exceptionPath isDirectory:nil]) {
        //创建文件夹
        [SH_F createDirectoryAtPath:exceptionPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    gob_ExceptionPath = exceptionPath;
    return gob_ExceptionPath;
}

+ (NSArray<NSString*> *) exceptionFileList {
    
    NSArray * arExceptionFiles = [SH_F contentsOfDirectoryAtPath:[UncaughtExceptionHandler exceptionDocumentsDirectory] error:nil];
    
    NSMutableArray *filterArry = [NSMutableArray new];
    
    for (NSString *fileName in arExceptionFiles) {
        if ([fileName hasPrefix:@"UE_"]) {
            [filterArry addObject:fileName];
        }
    }
    //
    return filterArry;
}

#pragma mark - SH 异常信息 读/写

//写
+ (void) saveDataWithException:(NSException *)exception {
    
    NSString *strDate = [[self class] getLocalDate];
    
    NSString *exceptionInfo = [NSString stringWithFormat:
                               @"\n--------\tLog Exception\t--------\n\n  Time   : [%@]\n  %@\n  exception name      :%@\n  exception reason    :%@\n  exception userInfo  :%@\n  callStackSymbols    :%@\n\n--------\tEnd Log Exception\t--------",
                               strDate,
                               [UncaughtExceptionHandler getAppInfo],
                               exception.name,
                               exception.reason,
                               exception.userInfo ? : @"no user info", [exception callStackSymbols]
                               
                               ];
    
    NSString *strCrashPath = [[[self class] exceptionDocumentsDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"UE_%@",strDate]];
    
    [exceptionInfo writeToFile:strCrashPath atomically:YES encoding:4 error:nil];

#if DEBUG
    NSLog(@"%@",exceptionInfo);
#endif
    return;
}

//读
+(NSString*) readDataFromLocal {
    
    NSMutableString *strAllLog = [[NSMutableString alloc] init];
    
    NSArray * arCrashFiles = [[self class] exceptionFileList];
    
    for (NSString *crashFileName in arCrashFiles) {
        NSString *crashFilePath  = [[[self class] exceptionDocumentsDirectory] stringByAppendingPathComponent:crashFileName];
        
        NSString *strCrashLog = [NSString stringWithContentsOfFile:crashFilePath encoding:4 error:nil];
        
        if (strCrashLog.length>0) {
            [strAllLog appendFormat:@"\n %@", strCrashLog];
        }
    }
    
    return strAllLog.length>0?strAllLog:nil;
}

+ (void) exceptionDocumentsClear {
    
    NSArray * arCrashFiles = [[self class] exceptionFileList];
    
    for (NSString *crashFileName in arCrashFiles) {
        NSString *crashFilePath  = [[[self class] exceptionDocumentsDirectory] stringByAppendingPathComponent:crashFileName];
        
        [SH_F removeItemAtPath:crashFilePath error:nil];
    }
    
    return;
}

#pragma mark - SH 核心-异常信息处理
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

// 异常处理入口
- (void)handleException:(NSException *)exception {
    
    //存储日志
    [[self class] saveDataWithException:exception];
    
    //将错误日志传递给其它监听者.
    if (_previousHandler) {
        _previousHandler(exception);
    }

    original_NSSetUncaughtExceptionHandler(nil);

    signal(SIGABRT, SIG_DFL);
    signal(SIGILL, SIG_DFL);
    signal(SIGSEGV, SIG_DFL);
    signal(SIGFPE, SIG_DFL);
    signal(SIGBUS, SIG_DFL);
    signal(SIGPIPE, SIG_DFL);
    
    if ([[exception name] isEqual:UncaughtExceptionHandlerSignalExceptionName]) {
        
        kill(getpid(), [[[exception userInfo] objectForKey:UncaughtExceptionHandlerSignalKey] intValue]);
        
    } else {
        
        [exception raise];
    }
    return;
}

#pragma mark - SH 工具函数

+(NSString*) getLocalDate {
    return  [[NSDate date] description];
}

+(NSString*) getAppInfo {
    
    struct utsname systemInfo;
    uname(&systemInfo);
    
    NSString *appInfo = [NSString stringWithFormat:
                         @"App    : %@ %@(%@)\n  Device : %@(%@)\n  Version: %@ %@\n  dSYM_ID: %@ \n",
                         
                         [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"],
                         [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
                         [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"],
                         [UIDevice currentDevice].model,
                         [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding],
                         [UIDevice currentDevice].systemName,[UIDevice currentDevice].systemVersion,[[self class] dSYM_UUID] ];
    return appInfo;
}

+ (NSString *) dSYM_UUID {
    
    const struct mach_header *executableHeader = NULL;
    
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const struct mach_header *header = _dyld_get_image_header(i);
        
        if (header->filetype == MH_EXECUTE) {
            executableHeader = header;
            break;
        }
    }
    
    if (!executableHeader) return nil;
    
    BOOL is64bit = executableHeader->magic == MH_MAGIC_64 || executableHeader->magic == MH_CIGAM_64;
    uintptr_t cursor = (uintptr_t)executableHeader + (is64bit ? sizeof(struct mach_header_64) : sizeof(struct mach_header));
    
    const struct segment_command *segmentCommand = NULL;
    for (uint32_t i = 0; i < executableHeader->ncmds; i++, cursor += segmentCommand->cmdsize) {
        segmentCommand = (struct segment_command *)cursor;
        
        if (segmentCommand->cmd == LC_UUID) {
            const struct uuid_command *uuidCommand = (const struct uuid_command *)segmentCommand;
            return [[NSUUID alloc] initWithUUIDBytes:uuidCommand->uuid].UUIDString;
        }
    }
    
    return nil;
}
@end


void ueh_HandleException(NSException *exception) {
    
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


void ext_NSSetUncaughtExceptionHandler(NSUncaughtExceptionHandler * handler) {
    printf("成功. 我被调用了...");
}

