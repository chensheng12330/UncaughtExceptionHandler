//
//  LTBaseWebViewController.m
//  BusinessPlatform
//
//  Created by huanyu.li on 2017/12/4.
//  Copyright © 2017年 billionsfinance. All rights reserved.
//

#import "LTBaseWebViewController.h"

typedef NSString * LTObserverKey;
static LTObserverKey const kEstimatedProgressKey = @"estimatedProgress";
static LTObserverKey const kTitleKey = @"title";
static LTObserverKey const kContentSize = @"contentSize";

static JSMethod const kSetTitleMethod = @"setTitle"; // 设置标题

@interface LTBaseWebViewController () <WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, UIScrollViewDelegate>

@end

@implementation LTBaseWebViewController


#pragma mark - 生命周期
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setupUI];
    
    [self loadHomeURL];
}



- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self removeObserverWebView];
}


#pragma mark - NSKeyValueObserving
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == LTObserverWebViewContext)
    {
        if (object == self.webView)
        {
            if ([keyPath isEqualToString:kEstimatedProgressKey])
            {
                [self.progressView setAlpha:1.0f];
                [self.progressView setProgress:self.webView.estimatedProgress animated:YES];
                
                if (self.webView.estimatedProgress >= 1.0f)
                {
                    [UIView animateWithDuration:0.3 delay:0.3 options:UIViewAnimationOptionCurveEaseOut animations:^{
                        [self.progressView setAlpha:0.0f];
                    } completion:^(BOOL finished) {
                        [self.progressView setProgress:0.0f animated:NO];
                    }];
                }
                return;
            }
            else if ([keyPath isEqualToString:kTitleKey])
            {
                self.webTitle = self.webView.title;
                return;
            }
        }
        else if (object == self.webView.scrollView)
        {
            if ([keyPath isEqualToString:kContentSize])
            {
                //跟document.body.scrollHeight的值一致
                //CGFloat height = self.webView.scrollView.contentSize.height;
                //                NSLog(@"%@", NSStringFromValue(height));
                return;
            }
        }
    }
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

#pragma mark - UI处理
- (void)setupUI
{
    [self setupWebView];

}
/**  上下文  */
static void *LTObserverWebViewContext = &LTObserverWebViewContext;
- (void)setupWebView
{
    WKUserContentController *userContentController = [[WKUserContentController alloc] init];
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.userContentController = userContentController;
    config.processPool = self.processPool;
    
    WKWebView *webView = [[WKWebView alloc] initWithFrame:self.view.frame configuration:config];
    self.webView = webView;
    webView.navigationDelegate = self;
    webView.UIDelegate = self;
    [self.view addSubview:webView];
    webView.scrollView.backgroundColor = UIColorClear;
    webView.scrollView.delegate = self;
    
    //添加观察webView的进度与标题
    [webView addObserver:self forKeyPath:kEstimatedProgressKey options:NSKeyValueObservingOptionNew context:LTObserverWebViewContext];
    [webView addObserver:self forKeyPath:kTitleKey options:NSKeyValueObservingOptionNew context:LTObserverWebViewContext];
    [webView.scrollView addObserver:self forKeyPath:kContentSize options:NSKeyValueObservingOptionNew context:LTObserverWebViewContext];
}



- (void)setupUIBarButtonItem
{
//    // 右边
//    UIBarButtonItem *reloadItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reload)];
//    self.navigationItem.rightBarButtonItems = [NSArray arrayWithObjects:reloadItem, nil];
}

- (void)leftBarButtonAction:(UIButton *)sender
{
    
    [self.webView goBack];
    
}
#pragma mark - 事件处理
- (void)loadHomeURL
{
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:self.homeURL]];

    [self.webView loadRequest:req];
}


/**  移除监听WebView  */
- (void)removeObserverWebView
{
    //为了避免取消订阅时造成的crash，可以把取消订阅代码放在@try-@catch语句
    @try {
        if (!_webView) return;
        [_webView removeObserver:self forKeyPath:kEstimatedProgressKey context:LTObserverWebViewContext];
        [_webView removeObserver:self forKeyPath:kTitleKey context:LTObserverWebViewContext];
        [_webView.scrollView removeObserver:self forKeyPath:kContentSize context:LTObserverWebViewContext];
        //_webView.scrollView.delegate = nil;
        
    } @catch (NSException *exception) {
        
    } @finally {
        
    }
}

- (void)adjustSourceLabel:(NSURL *)sourceURL
{
    _sourceLabel.text = [NSString stringWithFormat:@"此网页由 %@ 提供",sourceURL.host];
    [_sourceLabel sizeToFit];
}

#pragma mark - UIScrollViewDelegate
- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGFloat y = scrollView.contentOffset.y;
    if (self.isShowSourceLabel) _sourceLabel.hidden = (y >= -1.f);
}

#pragma mark - WKNavigationDelegate
#pragma mark - --导航监听--
// 在发送请求之前，决定是否跳转
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    //允许跳转
    
    decisionHandler(WKNavigationActionPolicyAllow);
}
// 对于HTTPS的都会触发此代理，如果不要求验证，传默认就行
// 如果需要证书验证，与使用AFN进行HTTPS证书验证是一样的
- (void)webView:(WKWebView *)webView didReceiveAuthenticationChallenge:(nonnull NSURLAuthenticationChallenge *)challenge completionHandler:(nonnull void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler
{
    //    NSLog(@"%s", __FUNCTION__);
    completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    if (/* DISABLES CODE */ (0))
    {
        // 1.从服务器返回的受保护空间中拿到证书的类型
        // 2.判断服务器返回的证书是否是服务器信任的
        if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
            NSLog(@"是服务器信任的证书");
            // 3.根据服务器返回的受保护空间创建一个证书
            // void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *)
            // 代理方法的completionHandler block接收两个参数:
            // 第一个参数: 代表如何处理证书
            // 第二个参数: 代表需要处理哪个证书
            //创建证书
            NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
            // 4.安装证书
            completionHandler(NSURLSessionAuthChallengeUseCredential , credential);
        }
    }
}
// 在收到响应后，决定是否跳转
- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler
{
    //    NSLog(@"%@",navigationResponse.response.URL.absoluteString);
    //允许跳转
    decisionHandler(WKNavigationResponsePolicyAllow);
    //不允许跳转
    //decisionHandler(WKNavigationResponsePolicyCancel);
  
}
// 接收到服务器跳转请求之后调用
- (void)webView:(WKWebView *)webView didReceiveServerRedirectForProvisionalNavigation:(WKNavigation *)navigation
{
    
}
//WKNavigation导航错误之后调用
- (void)webView:(WKWebView *)webView didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error
{
    
}
// 9.0才能使用，web内容处理中断时会触发
//- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView
//{
//
//}
#pragma mark - --网页监听--
// 页面开始加载时调用
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation
{
//    NSLog(@"\n页面开始加载时调用:%lu", (unsigned long)self.backListCount);
    //是否隐藏tabBar
}
// 当内容开始返回时调用
- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation
{
//    NSLog(@"\n当内容开始返回时调用:%lu", (unsigned long)self.backListCount);
}
// 页面加载完成之后调用
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    //可以在页面加载完成后发送消息给JS
    // 通知 h5 是 app登录
//    [webView evaluateJavaScript:@"fromApp()" completionHandler:nil];
//    [webView evaluateJavaScript:@"fromIOSApp()" completionHandler:nil];
    
    NSLog(@"\n页面加载完成之后调用:%@", self.webView.URL);

    //更新网页来源label
    [self adjustSourceLabel:self.webView.URL];
}
// 页面加载失败时调用
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation
{
    
}
#pragma mark - WKScriptMessageHandler   接收JS消息
// 接收到JS发送消息时调用
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message
{
    if ([message.name isEqualToString:kSetTitleMethod]) {
        if (message.body) {
            self.title = message.body;
        }
    }
}
#pragma mark - JS消息解析
- (NSDictionary *)dictionaryWithJsonString:(NSString *)jsonString
{
    if (jsonString == nil) {
        return nil;
    }
    
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *err;
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData
                                                        options:NSJSONReadingMutableContainers
                                                          error:&err];
    if(err)
    {
        NSLog(@"json解析失败：%@",err);
        return nil;
    }
    return dic;
}
#pragma mark - WKUIDelegate
// 创建一个新的WebView
- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures
{
    //当前页面加载
    if (!navigationAction.targetFrame.isMainFrame) {
        [webView loadRequest:navigationAction.request];
    }
    return nil;
}
//// 9.0后可使用,关闭WKWebView
//- (void)webViewDidClose:(WKWebView *)webView
//{
//
//}
// 警告框
// 对应js的Alert方法
/**
 *  web界面中有弹出警告框时调用
 *
 *  @param webView           实现该代理的webview
 *  @param message           警告框中的内容
 *  @param frame             主窗口
 *  @param completionHandler 警告框消失调用
 */
- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler
{
    NSLog(@"%@",message);
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:webView.title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                              style:UIAlertActionStyleCancel
                                            handler:^(UIAlertAction * _Nonnull action) {
                                                completionHandler();
                                            }]];
    //[kCurrentViewController presentViewController:alert animated:YES completion:nil];
}
// 输入框
- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(nullable NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString * __nullable result))completionHandler
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:webView.title
                                                                   message:prompt
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = defaultText;
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle: @"确定"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
                                                NSString *input = ((UITextField *)alert.textFields.firstObject).text;
                                                completionHandler(input);
                                            }]];
    [alert addAction:[UIAlertAction actionWithTitle: @"取消"
                                              style:UIAlertActionStyleCancel
                                            handler:^(UIAlertAction *action) {
                                                completionHandler(nil);
                                            }]];
    //[kCurrentViewController presentViewController:alert animated:YES completion:nil];
}
// 确认框
- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL result))completionHandler
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:webView.title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
                                                completionHandler(YES);
                                            }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消"
                                              style:UIAlertActionStyleCancel
                                            handler:^(UIAlertAction * _Nonnull action) {
                                                completionHandler(NO);
                                            }]];
    //[kCurrentViewController presentViewController:alert animated:YES completion:nil];
}

#pragma mark - setter and getter
- (NSString *)currentURL
{
    return self.webView.URL.absoluteString;
}
- (LTWKProcessPool *)processPool
{
    return [LTWKProcessPool sharedInstance];
}

@end

@implementation  LTWKProcessPool : WKProcessPool

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static LTWKProcessPool *instance = nil;
    dispatch_once(&onceToken,^{
        instance = [[super allocWithZone:NULL] init];
    });
    return instance;
}

+ (id)allocWithZone:(struct _NSZone *)zone{
    return [self sharedInstance];
}

@end
