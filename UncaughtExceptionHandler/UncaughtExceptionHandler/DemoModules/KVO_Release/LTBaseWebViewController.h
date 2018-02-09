//
//  LTBaseWebViewController.h
//  BusinessPlatform
//
//  Created by huanyu.li on 2017/12/4.
//  Copyright © 2017年 billionsfinance. All rights reserved.
//

@import UIKit;

@import WebKit;

typedef NSString * JSMethod;

typedef NS_ENUM(NSUInteger, LTWebViewLoadDataType) {
    LTWebViewLoadDataTypeURLRequest,    //URL请求
    LTWebViewLoadDataTypeLocalFile,   //本地文件
};

@interface LTWKProcessPool : WKProcessPool

+ (instancetype)sharedInstance;

@end

@interface LTBaseWebViewController : UIViewController

/**  webView  */
@property(nonatomic, weak) WKWebView *webView;
/**  网页来源,如:此网页由 xxx 提供  */
@property (nonatomic, weak) UILabel *sourceLabel;
/**  是否显示网页来源label,默认不显示  */
@property (nonatomic, assign, getter=isShowSourceLabel) BOOL showSourceLabel;
/**  进度条  */
@property (nonatomic, weak) UIProgressView *progressView;
/**  进展池  */
@property (nonatomic, strong) LTWKProcessPool *processPool;
/**  当前显示的URL  */
@property (nonatomic, copy) NSString *currentURL;
/**  当前web的title  */
@property (nonatomic, copy) NSString *webTitle;
/** JavaScriptMethodName */
@property (nonatomic, strong) NSMutableArray<NSString *> *jsMethodsArray;
/**  是否添加js方法  */
@property (nonatomic, assign, getter=isAddJSMethod) BOOL addJSMethod;
/**  当前显示的URL全路径  */
@property (nonatomic, copy) NSString *HTML5FullPath;
/** 是否是H5全路径 */
@property (nonatomic, assign, readonly) BOOL isHTML5FullPath;
/** 是否是H5路径 */
@property (nonatomic, assign, readonly) BOOL isHTML5Path;
/** 是否已经加载过了 */
@property (nonatomic, assign, readonly) BOOL isLoaded;

/**  webview加载方式,默认为LTWebViewLoadDataTypeURLRequest  */
@property (nonatomic, assign) LTWebViewLoadDataType loadDataType;
/**  首页URL,如果为本地文件,必须为全路径,如果是请求链接,可带baseURL,也可不带  */
@property (nonatomic, copy) NSString *homeURL;

@end


