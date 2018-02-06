//
//  UncaughtExceptionHandler.h
//  UncaughtExceptionHandler
//
//  Created by sherwin.chen on 2018/2/1.
//  Copyright © 2018年 sherwin.chen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#

/**
 读取本地异常列表信息的回调.
 @param exceptionStr 已组装好的异常信息字符串，如需修改可去拼接函数进行更改.
                     如果为nil，则无崩溃信息.
 */
typedef void(^GetExceptionBlock)(NSString *exceptionStr);


@interface UncaughtExceptionHandler : NSObject

//信息写
//信息读
/** 信息上传
 1.读取异常文件列表
 2.合成String串给block处理.
 3.处理好后，清空崩溃本地数据.
 */



/**
   注册异常的监控
 */
+ (void)installUncaughtException:(GetExceptionBlock) getExceptionInfo;

/**
 本地已存在的崩溃日志文件列表.\n
 每一次崩溃都会产生一个崩溃日志文件.
 @return NSArray  如无数据，返回nil
 */
+ (NSArray<NSString*> *) exceptionFileList;

// 崩溃日志文件夹目录
+ (NSString*) exceptionDocumentsDirectory;

/**
 清空本地数据崩溃数据。
 在崩溃数据上传成功后，调用此方法清空所有的崩溃文件。
 */
+ (void) exceptionDocumentsClear;

@end
