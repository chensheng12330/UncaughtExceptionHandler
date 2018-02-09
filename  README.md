> ## 业务场景描述
- 收集APP崩溃信息，上传到服务器，用于分析统计.
- 一些特殊场景，集成了某个第三方库，但不想它收集我们APP的崩溃信息.


> ## 技术分析
- 收集APP崩溃信息<br>
  
```
//苹果提供异常捕获相关函数

/** 获取异常捕获句柄
A pointer to the top-level error-handling function where you can perform last-minute logging before the program terminates.
*/
NSUncaughtExceptionHandler * _Nullable NSGetUncaughtExceptionHandler(void);

/** 设置异常捕获句柄
Changes the top-level error handler.
Sets the top-level error-handling function where you can perform last-minute logging before the program terminates.
*/
void NSSetUncaughtExceptionHandler(NSUncaughtExceptionHandler * _Nullable);
```

1. ) 处理流程
```

设置异常捕获句柄-->处理异常句柄回调-->收集崩溃信息-->存入本地文件系统-->

等待下次启动-->收集本地崩溃文件列表-->上传服务器-->清空本地崩溃文件列表

```
2. ) 异常处理代码块

```
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
}

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

// 异常处理入口
- (void)handleException:(NSException *)exception {
    
    //存储日志
    [[self class] saveDataWithException:exception];
    
    //将错误日志传递给其它监听者.
    if (_previousHandler) {
        _previousHandler(exception);
    }
}

```




- 拒绝第三方库收集崩溃
1. ) 正常情况下，如果想要拒绝第三方库的收集，只需要在初使化第三方库后，设置<br>

```
NSSetUncaughtExceptionHandler(ueh_HandleException);

//在处理 ueh_HandleException() 时，不传递异常事件即可。
```
    

2. ) 特别情况处理

 第三方初使化时，由于未知原因并不会马上调用NSSetUncaughtExceptionHandler(), 而我们在APP内调用NSSetUncaughtExceptionHandler()后，第三方可能在这之后才会调用此方法，即第三方在我们注册之后才注册了他们自己的监听回调函数,因此我们无法控制他们的行为.
 
 ###### 解决方案
 
 Objective-C 作为基于 Runtime的语言，它有非常强大的动态特性，可以在运行期间自省、进行方法调剂、为类增加属性、修改消息转发链路，在代码运行期间通过 Runtime 几乎可以修改 Objecitve-C 层的一切类、方法以及属性。
 
 对于runtime提供的API，我们只能操作NS体系的方法或函数 ，并不能去hook C的API函数。针对此情况，facebook开源三方框架 [fishhook](http://note.youdao.com/) ,其主要作用就是动态修改 C 语言函数实现。其详细介绍可进github查询，现在我们来实现拒绝第三方库收集异常的业务.
 
 实现的方式很简单：
 
-  0x01 注册我们自己的异常句柄函数
-  0x02 获取NSSetUncaughtExceptionHandler的函数地址.
-  0x03 声明属于我们自己的ext_NSSetUncaughtExceptionHandler函数.
-  0x04 使用rebind_symbols()方法，交换两个方法.
-  0x05 完成，如何额外处理某些三方库捕获异常，可在自定义的函数进行相关的处理操作即可.

++代码示例：++
```
/**
  交互捕获异常函数声明
 */
static void ext_NSSetUncaughtExceptionHandler(NSUncaughtExceptionHandler * handler);
///////////////////////////////

/**
  捕获异常函数地址声明
 */
static void (*original_NSSetUncaughtExceptionHandler)(NSUncaughtExceptionHandler* __nullable handler);



void installUncaughtException() {
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
}

void ext_NSSetUncaughtExceptionHandler() {
    //对第三方库想监听异常信号的处理.
    //...
}

```

 

> ## 深入思考

1.随着苹果对ARC优化的越来越好，一般情况下不会出现崩溃异常（数组越界频率是最高的也最易排查. KVO问题是最难定位的）。但要出现了异常，经验不足的iOS开发人员很难定位到代码问题.

2.如果项目是基于Swift开发，线上版本如出现了异常也更难去定位具体的代码块，因为捕获堆栈内容，我们看到的并不是swift内的函数名，而是apple给我们混淆后的函数名，比较难去定位.但根据关键字函数名，还是可以定位到问题，这就需要iOS开发人员具有深厚的经验和能力了.


###### 此文所演示的代码已放到Github，可到 [UncaughtExceptionHandler](https://github.com/chensheng12330/UncaughtExceptionHandler) 进行查阅.

