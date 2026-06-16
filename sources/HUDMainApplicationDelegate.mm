//
//  HUDMainApplicationDelegate.mm
//  TrollMemo
//
//  Created by Lessica on 2024/1/24.
//

#import <objc/runtime.h>

#import "HUDMainApplicationDelegate.h"
#import "HUDMainWindow.h"
#import "HUDRootViewController.h"

#import "SBSAccessibilityWindowHostingController.h"
#import "UIWindow+Private.h"

@implementation HUDMainApplicationDelegate {
    HUDRootViewController *_rootViewController;
    SBSAccessibilityWindowHostingController *_windowHostingController;
}

- (instancetype)init
{
    if (self = [super init])
    {
        log_debug(OS_LOG_DEFAULT, "- [HUDMainApplicationDelegate init]");
    }
    return self;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary <UIApplicationLaunchOptionsKey, id> *)launchOptions
{
    log_debug(OS_LOG_DEFAULT, "- [HUDMainApplicationDelegate application:%{public}@ didFinishLaunchingWithOptions:%{public}@]", application, launchOptions);

    _rootViewController = [[HUDRootViewController alloc] init];

    self.window = [[HUDMainWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    [self.window setRootViewController:_rootViewController];
    
    [self.window setWindowLevel:10000010.0];
    [self.window setHidden:NO];
    [self.window makeKeyAndVisible];

    Class hostingControllerClass = objc_getClass("SBSAccessibilityWindowHostingController");
    if (hostingControllerClass) {
        _windowHostingController = [[hostingControllerClass alloc] init];
        unsigned int contextId = [self.window _contextId];
        double windowLevel = [self.window windowLevel];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:"v@:Id"];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        [invocation setTarget:_windowHostingController];
        [invocation setSelector:NSSelectorFromString(@"registerWindowWithContextID:atLevel:")];
        [invocation setArgument:&contextId atIndex:2];
        [invocation setArgument:&windowLevel atIndex:3];
        [invocation invoke];
#pragma clang diagnostic pop
    } else {
        log_debug(OS_LOG_DEFAULT, "SBSAccessibilityWindowHostingController unavailable");
    }

    return YES;
}

@end
