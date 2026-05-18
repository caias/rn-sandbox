//
//  LifePlusApp.mm
//  SandboxApp
//

#import "LifePlusApp.h"

#import <UIKit/UIKit.h>
#import <React/RCTLog.h>

@implementation LifePlusApp

// NativeModules.LifePlusApp 키.
RCT_EXPORT_MODULE(LifePlusApp);

// 모든 UI 조작은 main thread.
+ (BOOL)requiresMainQueueSetup
{
  return YES;
}

- (dispatch_queue_t)methodQueue
{
  return dispatch_get_main_queue();
}

#pragma mark - back

// JS: `back()` (params 없음, Promise<void>)
//
// sandbox 의 `RNContainerViewController` 가 push 된 상태에서 호출되면
// 직전 화면(보통 DevTool)으로 pop. nav stack 비어있으면 noop + reject 대신 resolve(no-op).
// 본 앱 host shell 통합 시 NavBridge 로 일반화.
//
// `params` arg 는 sdk-native.ts 의 `call(command, params?)` 가 항상 `fn(undefined)` 로
// 호출하기 때문에 시그니처에 자리만 잡아둔다 (사용 안 함).
RCT_REMAP_METHOD(back,
                 backWithParams:(NSDictionary *)params
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  UIWindow *window = [self keyWindow];
  if (window == nil) {
    reject(@"E_NO_WINDOW", @"no key window", nil);
    return;
  }

  UINavigationController *nav = [self findNavigationController:window.rootViewController];
  if (nav == nil) {
    reject(@"E_NO_NAV", @"no UINavigationController in hierarchy", nil);
    return;
  }

  if (nav.viewControllers.count <= 1) {
    // 뿌리 (DevTool) 만 남은 상태 → no-op resolve.
    RCTLogInfo(@"[LifePlusApp] back: nav stack root, noop");
    resolve([NSNull null]);
    return;
  }

  [nav popViewControllerAnimated:YES];
  RCTLogInfo(@"[LifePlusApp] back: popped to %@", NSStringFromClass([nav.topViewController class]));
  resolve([NSNull null]);
}

#pragma mark - share

// JS: `share({ url, text? })` (params 있음, Promise<void>)
//
// ShareParams (native-bridge):
//   - url:  string         (필수)
//   - text: string?        (옵션) — title 또는 본문 prefix
RCT_REMAP_METHOD(share,
                 shareWithParams:(NSDictionary *)params
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  NSString *urlString = params[@"url"];
  NSString *text = params[@"text"];

  NSMutableArray *items = [NSMutableArray array];
  if ([text isKindOfClass:[NSString class]] && text.length > 0) {
    [items addObject:text];
  }
  if ([urlString isKindOfClass:[NSString class]] && urlString.length > 0) {
    NSURL *url = [NSURL URLWithString:urlString];
    if (url != nil) {
      [items addObject:url];
    } else {
      [items addObject:urlString];
    }
  }

  if (items.count == 0) {
    reject(@"E_EMPTY", @"share requires url or text", nil);
    return;
  }

  UIWindow *window = [self keyWindow];
  UIViewController *presenter = window.rootViewController;
  while (presenter.presentedViewController != nil) {
    presenter = presenter.presentedViewController;
  }
  if (presenter == nil) {
    reject(@"E_NO_PRESENTER", @"no view controller to present share sheet", nil);
    return;
  }

  UIActivityViewController *avc = [[UIActivityViewController alloc] initWithActivityItems:items
                                                                    applicationActivities:nil];
  // iPad: popover source 지정 안 하면 크래시. center 로 적당히.
  if (avc.popoverPresentationController != nil) {
    avc.popoverPresentationController.sourceView = presenter.view;
    avc.popoverPresentationController.sourceRect = CGRectMake(presenter.view.bounds.size.width / 2,
                                                              presenter.view.bounds.size.height / 2,
                                                              0, 0);
    avc.popoverPresentationController.permittedArrowDirections = 0;
  }

  avc.completionWithItemsHandler = ^(UIActivityType _Nullable activityType,
                                     BOOL completed,
                                     NSArray * _Nullable returnedItems,
                                     NSError * _Nullable activityError) {
    if (activityError != nil) {
      RCTLogWarn(@"[LifePlusApp] share error: %@", activityError);
    }
    RCTLogInfo(@"[LifePlusApp] share completed=%d activity=%@", completed, activityType);
  };

  [presenter presentViewController:avc animated:YES completion:nil];
  resolve([NSNull null]);
}

#pragma mark - helpers

- (UIWindow *)keyWindow
{
  for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
    if (![scene isKindOfClass:[UIWindowScene class]]) continue;
    UIWindowScene *ws = (UIWindowScene *)scene;
    for (UIWindow *w in ws.windows) {
      if (w.isKeyWindow) return w;
    }
    // foreground active scene 의 첫 window 라도 fallback.
    if (ws.activationState == UISceneActivationStateForegroundActive && ws.windows.count > 0) {
      return ws.windows.firstObject;
    }
  }
  return nil;
}

- (UINavigationController *)findNavigationController:(UIViewController *)vc
{
  if (vc == nil) return nil;
  if ([vc isKindOfClass:[UINavigationController class]]) {
    return (UINavigationController *)vc;
  }
  for (UIViewController *child in vc.childViewControllers) {
    UINavigationController *found = [self findNavigationController:child];
    if (found != nil) return found;
  }
  return [self findNavigationController:vc.presentedViewController];
}

@end
