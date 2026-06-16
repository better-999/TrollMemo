//
//  HUDRootViewController.mm
//  TrollMemo
//
//  桌面 HUD 的根视图控制器，运行在独立 HUD 进程（-hud）中。
//  负责：在全局悬浮窗显示自定义文字、响应拖拽/点击、监听配置变更与锁屏状态。
//  文字样式从共享 plist 读取，由主 App 的 EditTextSettingsViewController 写入。
//

#import <notify.h>
#import <objc/runtime.h>
#import <mach/vm_param.h>
#import <Foundation/Foundation.h>

#import "HUDRootViewController.h"
#import "HUDHelper.h"
#import "TrollMemo-Swift.h"
#import "../supports/hudapp-bridging-header.h"

#pragma mark -

#import "FBSOrientationUpdate.h"
#import "FBSOrientationObserver.h"
#import "UIApplication+Private.h"
#import "LSApplicationProxy.h"
#import "LSApplicationWorkspace.h"
#import "SpringBoardServices.h"

#define NOTIFY_UI_LOCKSTATE    "com.apple.springboard.lockstate"
#define NOTIFY_LS_APP_CHANGED  "com.apple.LaunchServices.ApplicationsChanged"

// 主 App 被卸载时，HUD 进程自行退出（TrollSpeed 同款保活逻辑）
static void LaunchServicesApplicationStateChanged
(CFNotificationCenterRef center,
 void *observer,
 CFStringRef name,
 const void *object,
 CFDictionaryRef userInfo)
{
    /* Application installed or uninstalled */

    BOOL isAppInstalled = NO;

    for (LSApplicationProxy *app in [[objc_getClass("LSApplicationWorkspace") defaultWorkspace] allApplications])
    {
        if ([app.applicationIdentifier isEqualToString:@"ch.better.hudapp"])
        {
            isAppInstalled = YES;
            break;
        }
    }

    if (!isAppInstalled)
    {
        isAppInstalled = [[NSFileManager defaultManager] fileExistsAtPath:@"/Applications/TrollMemo.app"];
    }

    if (!isAppInstalled)
    {
        UIApplication *app = [UIApplication sharedApplication];
        [app terminateWithSuccess];
    }
}

// 锁屏时隐藏 HUD，解锁后重新显示
static void SpringBoardLockStatusChanged
(CFNotificationCenterRef center,
 void *observer,
 CFStringRef name,
 const void *object,
 CFDictionaryRef userInfo)
{
    HUDRootViewController *rootViewController = (__bridge HUDRootViewController *)observer;
    NSString *lockState = (__bridge NSString *)name;
    if ([lockState isEqualToString:@NOTIFY_UI_LOCKSTATE])
    {
        mach_port_t sbsPort = SBSSpringBoardServerPort();

        if (sbsPort == MACH_PORT_NULL)
            return;

        BOOL isLocked;
        BOOL isPasscodeSet;
        SBGetScreenLockStatus(sbsPort, &isLocked, &isPasscodeSet);

        if (!isLocked)
        {
            [rootViewController.view setHidden:NO];
            [rootViewController resetLoopTimer];
        }
        else
        {
            [rootViewController stopLoopTimer];
            [rootViewController.view setHidden:YES];
        }
    }
}

// 无操作若干秒后自动「虚化」HUD；失焦时的透明度
#define IDLE_INTERVAL 3.0
static const double HUD_MIN_FONT_SIZE = 9.0;
static const double HUD_MAX_FONT_SIZE = 10.0;
static const double HUD_MIN_CORNER_RADIUS = 4.5;
static const double HUD_MAX_CORNER_RADIUS = 5.0;
static double HUD_FONT_SIZE = 8.0;
static UIFontWeight HUD_FONT_WEIGHT = UIFontWeightRegular;
static CGFloat HUD_INACTIVE_OPACITY = 0.667;

@interface HUDRootViewController (Troll)
- (void)updateOrientation:(UIInterfaceOrientation)orientation animateWithDuration:(NSTimeInterval)duration;
@end

static const CACornerMask kCornerMaskBottom = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
static const CACornerMask kCornerMaskAll = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner | kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;

@implementation HUDRootViewController {
    NSMutableDictionary *_userDefaults;       // 从 USER_DEFAULTS_PATH plist 加载的配置
    NSMutableArray <NSLayoutConstraint *> *_constraints;
    UIBlurEffect *_blurEffect;
    UIVisualEffectView *_blurView;            // 毛玻璃背景容器
    ScreenshotInvisibleContainer *_containerView; // 截图时隐藏/显示 HUD 内容
    UIView *_contentView;                      // 可拖拽的整体 HUD 区域
    UIImageView *_lockedView;                  // 锁定位置时显示的锁图标
    UITapGestureRecognizer *_tapGestureRecognizer;
    UIPanGestureRecognizer *_panGestureRecognizer;
    UIImpactFeedbackGenerator *_impactFeedbackGenerator;
    UINotificationFeedbackGenerator *_notificationFeedbackGenerator;
    BOOL _isFocused;                           // YES=高亮聚焦，NO=半透明虚化
    NSLayoutConstraint *_topConstraint;        // 竖直位置（拖拽会改 constant）
    NSLayoutConstraint *_centerXConstraint;
    NSLayoutConstraint *_leadingConstraint;
    NSLayoutConstraint *_trailingConstraint;
    UIInterfaceOrientation _orientation;
    FBSOrientationObserver *_orientationObserver;
    BOOL _shouldKeepIdle;
    BOOL _canAdjustOrientation;
    BOOL _isPassthroughMode;
    BOOL _usesLargeFont;
    BOOL _usesRotation;
    BOOL _usesInvertedColor;
    BOOL _keepInPlace;
    BOOL _hideAtSnapshot;
    UITextView *_hudTextView;                  // 桌面显示文字的视图
    NSLayoutConstraint *_hudTextWidthConstraint;  // 随文字内容动态更新
    NSLayoutConstraint *_hudTextHeightConstraint;
    CGPoint _centerOffset;
    UIInterfaceOrientation _interfaceOrientation;
    BOOL _isLandscape;
    CGFloat _preferredPositionX;
    CGFloat _preferredPositionY;
    CGFloat _safeAreaTopInset;
    CGFloat _safeAreaBottomInset;
}

// 注册 Darwin 通知与 KVO：主 App 改配置 / 锁屏 / 偏移字号变更时刷新 HUD
- (void)registerNotifications
{
    int token;
    // 主 App 保存文字或设置后 post 此通知
    notify_register_dispatch(NOTIFY_RELOAD_HUD, &token, dispatch_get_main_queue(), ^(int token) {
        [self reloadUserDefaults];
    });

    CFNotificationCenterRef darwinCenter = CFNotificationCenterGetDarwinNotifyCenter();

    CFNotificationCenterAddObserver(
        darwinCenter,
        (__bridge const void *)self,
        LaunchServicesApplicationStateChanged,
        CFSTR(NOTIFY_LS_APP_CHANGED),
        NULL,
        CFNotificationSuspensionBehaviorCoalesce
    );

    CFNotificationCenterAddObserver(
        darwinCenter,
        (__bridge const void *)self,
        SpringBoardLockStatusChanged,
        CFSTR(NOTIFY_UI_LOCKSTATE),
        NULL,
        CFNotificationSuspensionBehaviorCoalesce
    );

    // 仅监听偏移/字号（存在 GetStandardUserDefaults）；文字配置走 plist + NOTIFY_RELOAD_HUD
    NSUserDefaults *userDefaults = GetStandardUserDefaults();
    [userDefaults addObserver:self forKeyPath:HUDUserDefaultsKeyUsesCustomFontSize options:NSKeyValueObservingOptionNew context:nil];
    [userDefaults addObserver:self forKeyPath:HUDUserDefaultsKeyRealCustomFontSize options:NSKeyValueObservingOptionNew context:nil];
    [userDefaults addObserver:self forKeyPath:HUDUserDefaultsKeyUsesCustomOffset options:NSKeyValueObservingOptionNew context:nil];
    [userDefaults addObserver:self forKeyPath:HUDUserDefaultsKeyRealCustomOffsetX options:NSKeyValueObservingOptionNew context:nil];
    [userDefaults addObserver:self forKeyPath:HUDUserDefaultsKeyRealCustomOffsetY options:NSKeyValueObservingOptionNew context:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:HUDUserDefaultsKeyUsesCustomFontSize] ||
        [keyPath isEqualToString:HUDUserDefaultsKeyRealCustomFontSize] ||
        [keyPath isEqualToString:HUDUserDefaultsKeyUsesCustomOffset] ||
        [keyPath isEqualToString:HUDUserDefaultsKeyRealCustomOffsetX] ||
        [keyPath isEqualToString:HUDUserDefaultsKeyRealCustomOffsetY])
    {
        [self reloadUserDefaults];
    }
}

// 从共享 plist 文件加载配置到内存
- (void)loadUserDefaults:(BOOL)forceReload
{
    if (forceReload || !_userDefaults)
        _userDefaults = [[NSDictionary dictionaryWithContentsOfFile:HUDResolvedPath(USER_DEFAULTS_PATH)] mutableCopy] ?: [NSMutableDictionary dictionary];
}

// HUD 侧修改配置（如拖拽保存 Y 坐标）时写回 plist，并通知主 App
- (void)saveUserDefaults
{
    BOOL wroteSucceed = [_userDefaults writeToFile:HUDResolvedPath(USER_DEFAULTS_PATH) atomically:YES];
    if (wroteSucceed) {
        [[NSFileManager defaultManager] setAttributes:@{
            NSFileOwnerAccountID: @501,
            NSFileGroupOwnerAccountID: @501,
        } ofItemAtPath:HUDResolvedPath(USER_DEFAULTS_PATH) error:nil];
        notify_post(NOTIFY_RELOAD_APP);
    }
}

// 配置变更后的总入口：更新样式、布局、文字，并安排自动虚化
- (void)reloadUserDefaults
{
    [self loadUserDefaults:YES];

    BOOL usesCustomFontSize = [self usesCustomFontSize];
    if (!usesCustomFontSize) {
        BOOL usesLargeFont = [self usesLargeFont];
        HUD_FONT_SIZE = (usesLargeFont ? HUD_MAX_FONT_SIZE : HUD_MIN_FONT_SIZE);
        [_blurView.layer setCornerRadius:(usesLargeFont ? HUD_MAX_CORNER_RADIUS : HUD_MIN_CORNER_RADIUS)];
    } else {
        CGFloat realCustomFontSize = MIN(MAX([self realCustomFontSize], 8), 12);
        HUD_FONT_SIZE = realCustomFontSize;
        [_blurView.layer setCornerRadius:realCustomFontSize / 2.0];
    }

    BOOL usesInvertedColor = [self usesInvertedColor];
    HUD_FONT_WEIGHT = (usesInvertedColor ? UIFontWeightMedium : UIFontWeightRegular);
    HUD_INACTIVE_OPACITY = (usesInvertedColor ? 1.0 : 0.667);
    [_blurView setEffect:(usesInvertedColor ? nil : _blurEffect)];
    [_lockedView setHidden:usesInvertedColor];

    BOOL hideAtSnapshot = [self hideAtSnapshot];
    if (hideAtSnapshot) {
        [_containerView setupContainerAsHideContentInScreenshots];
    } else {
        [_containerView setupContainerAsDisplayContentInScreenshots];
    }

    [self removeAllAnimations];
    [self resetGestureRecognizers];
    [self updateViewConstraints];

    if (!_isFocused) {
        [self onFocus:_contentView];
    } else {
        [self keepFocus:_contentView];
    }

    [self applyTextSettings];
    // 几秒无操作后进入半透明「虚化」状态
    [self performSelector:@selector(onBlur:) withObject:_contentView afterDelay:IDLE_INTERVAL];
}

+ (BOOL)passthroughMode
{
    return [[[NSDictionary dictionaryWithContentsOfFile:HUDResolvedPath(USER_DEFAULTS_PATH)] objectForKey:HUDUserDefaultsKeyPassthroughMode] boolValue];
}

- (BOOL)isLandscapeOrientation
{
    BOOL isLandscape;
    if (_orientation == UIInterfaceOrientationUnknown) {
        isLandscape = CGRectGetWidth(self.view.bounds) > CGRectGetHeight(self.view.bounds);
    } else {
        isLandscape = UIInterfaceOrientationIsLandscape(_orientation);
    }
    return isLandscape;
}

- (HUDUserDefaultsKey)selectedModeKeyForCurrentOrientation
{
    return [self isLandscapeOrientation] ? HUDUserDefaultsKeySelectedModeLandscape : HUDUserDefaultsKeySelectedMode;
}

- (BOOL)usesLargeFont
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyUsesLargeFont];
    return mode != nil ? [mode boolValue] : NO;
}

- (BOOL)usesRotation
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyUsesRotation];
    return mode != nil ? [mode boolValue] : NO;
}

- (BOOL)usesInvertedColor
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyUsesInvertedColor];
    return mode != nil ? [mode boolValue] : NO;
}

- (BOOL)keepInPlace
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyKeepInPlace];
    return mode != nil ? [mode boolValue] : NO;
}

- (BOOL)hideAtSnapshot
{
    [self loadUserDefaults:NO];
    NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyHideAtSnapshot];
    return mode != nil ? [mode boolValue] : NO;
}

- (CGFloat)currentPositionY
{
    [self loadUserDefaults:NO];
    NSNumber *positionY = [_userDefaults objectForKey:HUDUserDefaultsKeyCurrentPositionY];
    return positionY != nil ? [positionY doubleValue] : CGFLOAT_MAX;
}

- (void)setCurrentPositionY:(CGFloat)positionY
{
    [self loadUserDefaults:NO];
    [_userDefaults setObject:[NSNumber numberWithDouble:positionY] forKey:HUDUserDefaultsKeyCurrentPositionY];
    [self saveUserDefaults];
}

- (CGFloat)currentLandscapePositionY
{
    [self loadUserDefaults:NO];
    NSNumber *positionY = [_userDefaults objectForKey:HUDUserDefaultsKeyCurrentLandscapePositionY];
    return positionY != nil ? [positionY doubleValue] : CGFLOAT_MAX;
}

- (void)setCurrentLandscapePositionY:(CGFloat)positionY
{
    [self loadUserDefaults:NO];
    [_userDefaults setObject:[NSNumber numberWithDouble:positionY] forKey:HUDUserDefaultsKeyCurrentLandscapePositionY];
    [self saveUserDefaults];
}

#define PREFS_PATH "/var/mobile/Library/Preferences/ch.better.hudapp.prefs.plist"

- (NSDictionary *)extraUserDefaultsDictionary {
    static BOOL isJailbroken = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      isJailbroken = [[NSFileManager defaultManager]
          fileExistsAtPath:JBROOT_PATH_NSSTRING(@"/Library/PreferenceBundles/TrollMemoPrefs.bundle")];
    });
    if (!isJailbroken) {
        return nil;
    }
    return [NSDictionary dictionaryWithContentsOfFile:JBROOT_PATH_NSSTRING(@PREFS_PATH)];
}

- (BOOL)usesCustomFontSize {
    NSDictionary *extraUserDefaults = [self extraUserDefaultsDictionary];
    if (extraUserDefaults) {
        return [extraUserDefaults[HUDUserDefaultsKeyUsesCustomFontSize] boolValue];
    }
    return [GetStandardUserDefaults() boolForKey:HUDUserDefaultsKeyUsesCustomFontSize];
}

- (CGFloat)realCustomFontSize {
    NSDictionary *extraUserDefaults = [self extraUserDefaultsDictionary];
    if (extraUserDefaults) {
        return [extraUserDefaults[HUDUserDefaultsKeyRealCustomFontSize] doubleValue];
    }
    return [GetStandardUserDefaults() doubleForKey:HUDUserDefaultsKeyRealCustomFontSize];
}

- (BOOL)usesCustomOffset {
    NSDictionary *extraUserDefaults = [self extraUserDefaultsDictionary];
    if (extraUserDefaults) {
        return [extraUserDefaults[HUDUserDefaultsKeyUsesCustomOffset] boolValue];
    }
    return [GetStandardUserDefaults() boolForKey:HUDUserDefaultsKeyUsesCustomOffset];
}

- (CGFloat)realCustomOffsetX {
    NSDictionary *extraUserDefaults = [self extraUserDefaultsDictionary];
    if (extraUserDefaults) {
        return [extraUserDefaults[HUDUserDefaultsKeyRealCustomOffsetX] doubleValue];
    }
    return [GetStandardUserDefaults() doubleForKey:HUDUserDefaultsKeyRealCustomOffsetX];
}

- (CGFloat)realCustomOffsetY {
    NSDictionary *extraUserDefaults = [self extraUserDefaultsDictionary];
    if (extraUserDefaults) {
        return [extraUserDefaults[HUDUserDefaultsKeyRealCustomOffsetY] doubleValue];
    }
    return [GetStandardUserDefaults() doubleForKey:HUDUserDefaultsKeyRealCustomOffsetY];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _constraints = [NSMutableArray array];
        [self registerNotifications];
        _orientationObserver = [[objc_getClass("FBSOrientationObserver") alloc] init];
        __weak HUDRootViewController *weakSelf = self;
        [_orientationObserver setHandler:^(FBSOrientationUpdate *orientationUpdate) {
            HUDRootViewController *strongSelf = weakSelf;
            dispatch_async(dispatch_get_main_queue(), ^{
                [strongSelf updateOrientation:(UIInterfaceOrientation)orientationUpdate.orientation animateWithDuration:orientationUpdate.duration];
            });
        }];
    }
    return self;
}

- (void)dealloc
{
    [_orientationObserver invalidate];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // 视图层级：contentView → 截图容器 → 毛玻璃 blurView → hudTextView（文字）
    _contentView = [[UIView alloc] init];
    _contentView.backgroundColor = [UIColor clearColor];
    _contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_contentView];

    _blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    _blurView = [[UIVisualEffectView alloc] initWithEffect:_blurEffect];
    _blurView.layer.cornerRadius = HUD_MIN_CORNER_RADIUS;
    _blurView.layer.masksToBounds = YES;
    _blurView.translatesAutoresizingMaskIntoConstraints = NO;
    _containerView = [[ScreenshotInvisibleContainer alloc] initWithContent:_blurView];
    _containerView.hiddenContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [_contentView addSubview:_containerView.hiddenContainer];

    // 初始化 hudTextView
    self.hudTextView = [[UITextView alloc] initWithFrame:CGRectZero];
    self.hudTextView.translatesAutoresizingMaskIntoConstraints = NO;
    self.hudTextView.editable = NO; // 禁止编辑
    self.hudTextView.scrollEnabled = NO; // 禁止滚动
    self.hudTextView.backgroundColor = [UIColor clearColor]; // 背景透明
    self.hudTextView.textContainerInset = UIEdgeInsetsZero; // 移除默认内边距
    self.hudTextView.textContainer.lineFragmentPadding = 0; // 移除行片段填充
    self.hudTextView.layer.cornerRadius = HUD_MAX_CORNER_RADIUS; // 设置圆角
    self.hudTextView.layer.masksToBounds = YES; // 裁剪子视图到圆角
    [_blurView.contentView addSubview:self.hudTextView];

    // 文字居中；宽高约束在 applyTextSettings 里按内容动态调整
    _hudTextWidthConstraint = [_hudTextView.widthAnchor constraintEqualToConstant:100];
    _hudTextHeightConstraint = [_hudTextView.heightAnchor constraintEqualToConstant:44];
    [NSLayoutConstraint activateConstraints:@[
        [_hudTextView.centerXAnchor constraintEqualToAnchor:_blurView.contentView.centerXAnchor],
        [_hudTextView.centerYAnchor constraintEqualToAnchor:_blurView.contentView.centerYAnchor],
        _hudTextWidthConstraint,
        _hudTextHeightConstraint,
        [_blurView.widthAnchor constraintEqualToAnchor:_hudTextView.widthAnchor],
        [_blurView.heightAnchor constraintEqualToAnchor:_hudTextView.heightAnchor],
        [_containerView.hiddenContainer.widthAnchor constraintEqualToAnchor:_blurView.widthAnchor],
        [_containerView.hiddenContainer.heightAnchor constraintEqualToAnchor:_blurView.heightAnchor],
        [_contentView.widthAnchor constraintEqualToAnchor:_blurView.widthAnchor],
        [_contentView.heightAnchor constraintEqualToAnchor:_blurView.heightAnchor],
    ]];

    _lockedView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"lock.fill"]];
    _lockedView.tintColor = [UIColor whiteColor];
    _lockedView.translatesAutoresizingMaskIntoConstraints = NO;
    _lockedView.contentMode = UIViewContentModeScaleAspectFit;
    _lockedView.alpha = 0.0;
    [_lockedView setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisVertical];
    [_lockedView setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisVertical];
    [_blurView.contentView addSubview:_lockedView];

    _tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGestureRecognized:)];
    _tapGestureRecognizer.numberOfTapsRequired = 1;
    _tapGestureRecognizer.numberOfTouchesRequired = 1;
    [_contentView addGestureRecognizer:_tapGestureRecognizer];

    _panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGestureRecognized:)];
    _panGestureRecognizer.minimumNumberOfTouches = 1;
    _panGestureRecognizer.maximumNumberOfTouches = 1;
    [_contentView addGestureRecognizer:_panGestureRecognizer];

    [_contentView setUserInteractionEnabled:YES];

    [self reloadUserDefaults];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    notify_post(NOTIFY_LAUNCHED_HUD); // 通知主 App：HUD 已就绪
}

// 原 TrollSpeed 用于刷新网速的定时器；文字模式无需轮询，保留空实现以兼容锁屏回调
- (void)resetLoopTimer
{
}

- (void)stopLoopTimer
{
}

- (void)viewSafeAreaInsetsDidChange
{
    [super viewSafeAreaInsetsDidChange];
    [self removeAllAnimations];
    [self resetGestureRecognizers];
    [self updateViewConstraints];
}

// 根据横竖屏、安全区、用户拖拽记录的位置，计算 HUD 在屏幕上的约束
- (void)updateViewConstraints
{
    [NSLayoutConstraint deactivateConstraints:_constraints];
    [_constraints removeAllObjects];

    BOOL isLandscape;
    if (_orientation == UIInterfaceOrientationUnknown) {
        isLandscape = CGRectGetWidth(self.view.bounds) > CGRectGetHeight(self.view.bounds);
    } else {
        isLandscape = UIInterfaceOrientationIsLandscape(_orientation);
    }

    BOOL isCentered = false;
    BOOL isCenteredMost = false;
    BOOL isPad = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad);

    [_lockedView setImage:[UIImage systemImageNamed:(isCentered ? @"hand.raised.slash.fill" : @"lock.fill")]];
    [_blurView.layer setMaskedCorners:((isCenteredMost && !isLandscape) ? kCornerMaskBottom : kCornerMaskAll)];

    BOOL usesCustomOffset = [self usesCustomOffset];
    CGFloat realCustomOffsetX = 0;
    CGFloat realCustomOffsetY = 0;

    if (usesCustomOffset)
    {
        realCustomOffsetX = [self realCustomOffsetX] * (-1);
        realCustomOffsetY = [self realCustomOffsetY];
    }

    UILayoutGuide *layoutGuide = self.view.safeAreaLayoutGuide;
    if (isLandscape)
    {
        CGFloat notchHeight;
        CGFloat paddingNearNotch;
        CGFloat paddingFarFromNotch;

        notchHeight = CGRectGetMinY(layoutGuide.layoutFrame);
        paddingNearNotch = (notchHeight > 30) ? notchHeight - 16 : 4;
        paddingFarFromNotch = (notchHeight > 30) ? -24 : -4;

        paddingNearNotch += realCustomOffsetX;
        paddingFarFromNotch += realCustomOffsetX;

        [_constraints addObjectsFromArray:@[
            [_contentView.leadingAnchor constraintEqualToAnchor:layoutGuide.leadingAnchor constant:(_orientation == UIInterfaceOrientationLandscapeLeft ? -paddingFarFromNotch : paddingNearNotch)],
            [_contentView.trailingAnchor constraintEqualToAnchor:layoutGuide.trailingAnchor constant:(_orientation == UIInterfaceOrientationLandscapeLeft ? -paddingNearNotch : paddingFarFromNotch)],
        ]];

        CGFloat minimumLandscapeTopConstant = 0;
        CGFloat minimumLandscapeBottomConstant = 0;

        minimumLandscapeTopConstant = (isPad ? 30 : 10);
        minimumLandscapeBottomConstant = (isPad ? -34 : -14);

        minimumLandscapeTopConstant += realCustomOffsetY;
        minimumLandscapeBottomConstant += realCustomOffsetY;

        /* Fixed Constraints */
        [_constraints addObjectsFromArray:@[
            [_contentView.topAnchor constraintGreaterThanOrEqualToAnchor:self.view.topAnchor constant:minimumLandscapeTopConstant],
            [_contentView.bottomAnchor constraintLessThanOrEqualToAnchor:self.view.bottomAnchor constant:minimumLandscapeBottomConstant],
        ]];

        /* Flexible Constraint */
        _topConstraint = [_contentView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:minimumLandscapeTopConstant];
        if (!isCentered) {
            CGFloat currentPositionY = [self currentLandscapePositionY];
            if (currentPositionY < CGFLOAT_MAX) {
                _topConstraint.constant = currentPositionY;
            }
        }
        _topConstraint.priority = UILayoutPriorityDefaultLow;

        [_constraints addObject:_topConstraint];
    }
    else
    {
        [_constraints addObjectsFromArray:@[
            [_contentView.leadingAnchor constraintEqualToAnchor:layoutGuide.leadingAnchor constant:realCustomOffsetX],
            [_contentView.trailingAnchor constraintEqualToAnchor:layoutGuide.trailingAnchor constant:realCustomOffsetX],
        ]];

        if (isCenteredMost && !isPad) {
            [_constraints addObject:[_contentView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:0]];
        }
        else
        {
            CGFloat minimumTopConstraintConstant = 0;
            CGFloat minimumBottomConstraintConstant = 0;

            if (CGRectGetMinY(layoutGuide.layoutFrame) >= 51) {
                minimumTopConstraintConstant = -8;
                minimumBottomConstraintConstant = -4;
            }
            else if (CGRectGetMinY(layoutGuide.layoutFrame) > 30) {
                minimumTopConstraintConstant = -12;
                minimumBottomConstraintConstant = -4;
            } else {
                minimumTopConstraintConstant = (isPad ? 30 : 20);
                minimumBottomConstraintConstant = -20;
            }

            minimumTopConstraintConstant += realCustomOffsetY;
            minimumBottomConstraintConstant += realCustomOffsetY;

            /* Fixed Constraints */
            [_constraints addObjectsFromArray:@[
                [_contentView.topAnchor constraintGreaterThanOrEqualToAnchor:layoutGuide.topAnchor constant:minimumTopConstraintConstant],
                [_contentView.bottomAnchor constraintLessThanOrEqualToAnchor:layoutGuide.bottomAnchor constant:minimumBottomConstraintConstant],
            ]];

            /* Flexible Constraint */
            _topConstraint = [_contentView.topAnchor constraintEqualToAnchor:layoutGuide.topAnchor constant:minimumTopConstraintConstant];
            if (!isCentered) {
                CGFloat currentPositionY = [self currentPositionY];
                if (currentPositionY < CGFLOAT_MAX) {
                    _topConstraint.constant = currentPositionY;
                }
            }
            _topConstraint.priority = UILayoutPriorityDefaultLow;

            [_constraints addObject:_topConstraint];
        }
    }

    [_constraints addObjectsFromArray:@[
        [_lockedView.topAnchor constraintGreaterThanOrEqualToAnchor:_blurView.topAnchor constant:2],
        [_lockedView.centerXAnchor constraintEqualToAnchor:_blurView.centerXAnchor],
        [_lockedView.centerYAnchor constraintEqualToAnchor:_blurView.centerYAnchor],
    ]];

    [NSLayoutConstraint activateConstraints:_constraints];
    [super updateViewConstraints];
}

#pragma mark - 聚焦 / 虚化动画（点击 HUD 高亮，闲置后半透明）

- (void)keepFocus:(UIView *)view
{
    [self onFocus:view duration:0];
}

- (void)onFocus:(UIView *)view
{
    [self onFocus:view duration:0.2];
}

- (void)onFocus:(UIView *)view duration:(NSTimeInterval)duration
{
    [self onFocus:view scaleFactor:0.1 duration:duration beginFromInitialState:YES blurWhenDone:YES];
}

- (void)onFocus:(UIView *)view scaleFactor:(CGFloat)scaleFactor duration:(NSTimeInterval)duration beginFromInitialState:(BOOL)beginFromInitialState blurWhenDone:(BOOL)blurWhenDone
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(onBlur:) object:view];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(onFocus:) object:view];

    _isFocused = YES;
    [self applyTextSettings]; // 聚焦时以完整透明度显示文字

    BOOL isCentered = false;

    CGFloat topTrans = CGRectGetHeight(view.bounds) * (scaleFactor / 2);
    CGFloat leadingTrans = (isCentered ? 0 : -CGRectGetWidth(view.bounds) * (scaleFactor / 2));

    if (beginFromInitialState)
        [view setTransform:CGAffineTransformIdentity];

    [UIView animateWithDuration:duration delay:0.0 usingSpringWithDamping:1.0 initialSpringVelocity:1.0 options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState animations:^{
        if (ABS(leadingTrans) > 1e-6 || ABS(topTrans) > 1e-6)
        {
            CGAffineTransform transform = CGAffineTransformMakeTranslation(leadingTrans, topTrans);
            view.transform = CGAffineTransformScale(transform, 1.0 + scaleFactor, 1.0 + scaleFactor);
        }

        view.alpha = 1.0;
    } completion:^(BOOL finished) {
        if (blurWhenDone) {
            [self performSelector:@selector(onBlur:) withObject:view afterDelay:IDLE_INTERVAL];
        }
    }];
}

- (void)onBlur:(UIView *)view
{
    [self onBlur:view duration:0.6];
}

- (void)onBlur:(UIView *)view duration:(NSTimeInterval)duration
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(onBlur:) object:view];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(onFocus:) object:view];

    _isFocused = NO;
    [self applyTextSettings]; // 虚化时仍刷新文字，但整体 alpha 降为 HUD_INACTIVE_OPACITY

    [UIView animateWithDuration:duration delay:0.0 usingSpringWithDamping:1.0 initialSpringVelocity:1.0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
        view.transform = CGAffineTransformIdentity;
        view.alpha = HUD_INACTIVE_OPACITY;
    } completion:nil];
}

- (void)removeAllAnimations
{
    [_contentView.layer removeAllAnimations];
}

- (void)resetGestureRecognizers
{
    for (UIGestureRecognizer *recognizer in _contentView.gestureRecognizers)
    {
        [recognizer setEnabled:NO];
        [recognizer setEnabled:YES];
    }
}

- (void)tapGestureRecognized:(UITapGestureRecognizer *)sender
{
    log_info(OS_LOG_DEFAULT, "TAPPED");
    if (!_isFocused) {
        [self onFocus:sender.view];
    } else {
        [self keepFocus:sender.view];
    }
}

- (void)cancelPreviousPerformRequestsWithTarget:(UIView *)view
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(onBlur:) object:view];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(onFocus:) object:view];
}

- (void)flashLockedViewWithDuration:(NSTimeInterval)duration
{
    [_lockedView.layer removeAllAnimations];
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    animation.fromValue = [NSNumber numberWithFloat:0.0];
    animation.toValue = [NSNumber numberWithFloat:1.0];
    animation.duration = duration;
    animation.autoreverses = YES;
    animation.repeatCount = 1;
    animation.removedOnCompletion = YES;
    animation.fillMode = kCAFillModeForwards;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [_lockedView.layer addAnimation:animation forKey:@"opacity"];

    [_hudTextView.layer removeAllAnimations];
    CABasicAnimation *animationReverse = [CABasicAnimation animationWithKeyPath:@"opacity"];
    animationReverse.fromValue = [NSNumber numberWithFloat:1.0];
    animationReverse.toValue = [NSNumber numberWithFloat:0.0];
    animationReverse.duration = duration;
    animationReverse.autoreverses = YES;
    animationReverse.repeatCount = 1;
    animationReverse.removedOnCompletion = YES;
    animationReverse.fillMode = kCAFillModeForwards;
    animationReverse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [_hudTextView.layer addAnimation:animationReverse forKey:@"opacity"];
}

// 拖拽改变 HUD 垂直位置；若开启「固定位置」则震动并闪锁图标
- (void)panGestureRecognized:(UIPanGestureRecognizer *)sender
{
    if (!_isFocused)
        return;

    BOOL isCentered = false;
    if (isCentered || [self keepInPlace])
    {
        if (sender.state == UIGestureRecognizerStateBegan)
            [self cancelPreviousPerformRequestsWithTarget:sender.view];
        else if (sender.state == UIGestureRecognizerStateFailed || sender.state == UIGestureRecognizerStateEnded || sender.state == UIGestureRecognizerStateCancelled)
            [self performSelector:@selector(onBlur:) withObject:sender.view afterDelay:IDLE_INTERVAL];

        if (sender.state == UIGestureRecognizerStateBegan)
        {
            if (!_notificationFeedbackGenerator)
                _notificationFeedbackGenerator = [[UINotificationFeedbackGenerator alloc] init];

            [_notificationFeedbackGenerator prepare];
            [_notificationFeedbackGenerator notificationOccurred:UINotificationFeedbackTypeError];

            [self flashLockedViewWithDuration:0.2];
        }

        return;
    }

    static CGFloat beginConstantY = 0.0;
    if (sender.state == UIGestureRecognizerStatePossible || sender.state == UIGestureRecognizerStateBegan)
    {
        beginConstantY = _topConstraint.constant;
        [self onFocus:sender.view scaleFactor:0.2 duration:0.1 beginFromInitialState:NO blurWhenDone:NO];
    }
    else
    {
        if (sender.state == UIGestureRecognizerStateChanged || sender.state == UIGestureRecognizerStateEnded)
        {
            CGFloat currentOffsetY = [sender translationInView:sender.view.superview].y;
            [_topConstraint setConstant:beginConstantY + currentOffsetY];
        }

        if (sender.state == UIGestureRecognizerStateEnded)
        {
            if (UIInterfaceOrientationIsLandscape(_orientation))
                [self setCurrentLandscapePositionY:_topConstraint.constant];
            else
                [self setCurrentPositionY:_topConstraint.constant];
        }

        if (sender.state != UIGestureRecognizerStateChanged)
        {
            [self onFocus:sender.view scaleFactor:0.1 duration:0.1 beginFromInitialState:NO blurWhenDone:NO];
            [self reloadUserDefaults];
        }
    }

    if (!_impactFeedbackGenerator)
    {
        _impactFeedbackGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    }

    if (sender.state == UIGestureRecognizerStateBegan || sender.state == UIGestureRecognizerStateEnded || sender.state == UIGestureRecognizerStateCancelled)
    {
        [_impactFeedbackGenerator prepare];
        [_impactFeedbackGenerator impactOccurred];
    }
}

#pragma mark - 文字样式（从 plist 读取并应用到 hudTextView）

// 读取 EditTextSettingsViewController 保存的配置，渲染到桌面文字视图
- (void)applyTextSettings {
    [self loadUserDefaults:NO];

    // --- 文字内容 ---
    NSString *textContent = [_userDefaults objectForKey:HUDUserDefaultsKeyTextContent];
    if (!textContent) {
        textContent = NSLocalizedString(@"Hello World!", nil);
    }
    self.hudTextView.text = textContent;

    // --- 文字颜色（plist 里存的是 NSKeyedArchiver 序列化的 NSData）---
    NSData *textColorData = [_userDefaults objectForKey:HUDUserDefaultsKeyTextColor];
    if (textColorData) {
        UIColor *textColor = [NSKeyedUnarchiver unarchivedObjectOfClass:[UIColor class] fromData:textColorData error:nil];
        self.hudTextView.textColor = textColor ?: [UIColor whiteColor];
    } else {
        self.hudTextView.textColor = [UIColor whiteColor];
    }

    NSNumber *textSizeNumber = [_userDefaults objectForKey:HUDUserDefaultsKeyTextSize];
    CGFloat textSize = textSizeNumber ? [textSizeNumber floatValue] : 10.0;
    if (textSize < 5.0 || textSize > 50.0) {
        textSize = 10.0;
    }
    self.hudTextView.font = [UIFont systemFontOfSize:textSize];

    NSNumber *textAlignmentNumber = [_userDefaults objectForKey:HUDUserDefaultsKeyTextAlignment];
    self.hudTextView.textAlignment = textAlignmentNumber ? (NSTextAlignment)[textAlignmentNumber integerValue] : NSTextAlignmentCenter;

    NSNumber *textAlphaNumber = [_userDefaults objectForKey:HUDUserDefaultsKeyTextAlpha];
    CGFloat textAlpha = textAlphaNumber ? [textAlphaNumber floatValue] : 1.0;
    if (textAlpha < 0.0 || textAlpha > 1.0) {
        textAlpha = 1.0;
    }
    self.hudTextView.alpha = textAlpha;

    // --- 背景色与背景透明度（与文字透明度分开控制）---
    NSData *bgColorData = [_userDefaults objectForKey:HUDUserDefaultsKeyBackgroundColor];
    UIColor *bgColor = [UIColor blackColor];
    if (bgColorData) {
        UIColor *decodedBgColor = [NSKeyedUnarchiver unarchivedObjectOfClass:[UIColor class] fromData:bgColorData error:nil];
        if (decodedBgColor) {
            bgColor = decodedBgColor;
        }
    }

    NSNumber *backgroundAlphaNumber = [_userDefaults objectForKey:HUDUserDefaultsKeyBackgroundAlpha];
    CGFloat backgroundAlpha = backgroundAlphaNumber ? [backgroundAlphaNumber floatValue] : 0.0;
    if (backgroundAlpha < 0.0 || backgroundAlpha > 1.0) {
        backgroundAlpha = 0.0;
    }
    self.hudTextView.backgroundColor = [bgColor colorWithAlphaComponent:backgroundAlpha];

    // 按文字实际尺寸更新容器大小，避免每次新建约束
    CGSize newSize = [self.hudTextView sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)];
    _hudTextWidthConstraint.constant = newSize.width;
    _hudTextHeightConstraint.constant = newSize.height;

    [self.view layoutIfNeeded];
}

@end

#pragma mark - 屏幕旋转（TrollSpeed 遗留扩展）

@implementation HUDRootViewController (Troll)

static inline CGFloat orientationAngle(UIInterfaceOrientation orientation)
{
    switch (orientation) {
        case UIInterfaceOrientationPortraitUpsideDown:
            return M_PI;
        case UIInterfaceOrientationLandscapeLeft:
            return -M_PI_2;
        case UIInterfaceOrientationLandscapeRight:
            return M_PI_2;
        default:
            return 0;
    }
}

static inline CGRect orientationBounds(UIInterfaceOrientation orientation, CGRect bounds)
{
    switch (orientation) {
        case UIInterfaceOrientationLandscapeLeft:
        case UIInterfaceOrientationLandscapeRight:
            return CGRectMake(0, 0, bounds.size.height, bounds.size.width);
        default:
            return bounds;
    }
}

// 未开启「随屏幕旋转」时，横屏隐藏 HUD，竖屏恢复显示
- (void)updateOrientation:(UIInterfaceOrientation)orientation animateWithDuration:(NSTimeInterval)duration
{
    BOOL usesRotation = [self usesRotation];

    if (!usesRotation)
    {
        [self onBlur:_contentView duration:0];

        if (orientation == UIInterfaceOrientationPortrait)
        {
            __weak typeof(self) weakSelf = self;
            [UIView animateWithDuration:duration animations:^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                strongSelf->_contentView.alpha = strongSelf->_isFocused ? 1.0 : HUD_INACTIVE_OPACITY;
            }];
        }
        else
        {
            __weak typeof(self) weakSelf = self;
            [UIView animateWithDuration:duration animations:^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                strongSelf->_contentView.alpha = 0.0;
            }];
        }

        return;
    }

    if (orientation == _orientation) {
        return;
    }

    _orientation = orientation;
    [self cancelPreviousPerformRequestsWithTarget:_contentView];

    CGRect bounds = orientationBounds(orientation, [UIScreen mainScreen].bounds);
    [self.view setNeedsUpdateConstraints];
    [self.view setHidden:YES];
    [self.view setBounds:bounds];

    [self resetGestureRecognizers];
    [self onBlur:_contentView duration:duration];

    __weak typeof(self) weakSelf = self;
    [UIView animateWithDuration:duration animations:^{
        [weakSelf.view setTransform:CGAffineTransformMakeRotation(orientationAngle(orientation))];
    } completion:^(BOOL finished) {
        [weakSelf.view setHidden:NO];
    }];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

@end
