//
//  RootViewController.mm
//  TrollMemo
//
//  Created by Lessica on 2024/1/24.
//  Modify by Better on 2025/6/07.
//

#import <notify.h>

#import "HUDHelper.h"
#import "MainButton.h"
#import "MainApplication.h"
#import "RootViewController.h"
#import "UIApplication+Private.h"
#import "HUDRootViewController.h"
#import "EditTextSettingsViewController.h"

#define HUD_TRANSITION_DURATION 0.25

static BOOL _gShouldToggleHUDAfterLaunch = NO;
static const CGFloat _gTopButtonConstraintsConstantCompact = 46.f;
static const CGFloat _gTopButtonConstraintsConstantRegular = 28.f;
static const CGFloat _gTopButtonConstraintsConstantRegularPad = 46.f;
static const CGFloat _gAuthorLabelBottomConstraintConstantCompact = -20.f;
static const CGFloat _gAuthorLabelBottomConstraintConstantRegular = -80.f;

// 新增的用户默认设置键
static NSString *const HUDUserDefaultsKeyTextContent = @"HUDUserDefaultsKeyTextContent";
static NSString *const HUDUserDefaultsKeyTextColor = @"HUDUserDefaultsKeyTextColor";
static NSString *const HUDUserDefaultsKeyTextSize = @"HUDUserDefaultsKeyTextSize";
static NSString *const HUDUserDefaultsKeyTextAlignment = @"HUDUserDefaultsKeyTextAlignment";
static NSString *const HUDUserDefaultsKeyTextAlpha = @"HUDUserDefaultsKeyTextAlpha";
static NSString *const HUDUserDefaultsKeyBackgroundColor = @"HUDUserDefaultsKeyBackgroundColor";
static NSString *const HUDUserDefaultsKeyBackgroundAlpha = @"HUDUserDefaultsKeyBackgroundAlpha";

@interface RootViewController () <EditTextSettingsViewControllerDelegate>

@end

@implementation RootViewController {
    NSMutableDictionary *_userDefaults;
    MainButton *_mainButton;
    UIButton *_settingsButton;
    UIButton *_editTextButton;
    UILabel *_authorLabel;
    NSLayoutConstraint *_authorLabelBottomConstraint;
    BOOL _isRemoteHUDActive;
    HUDRootViewController *_localHUDRootViewController;  // Only for debugging
    UIImpactFeedbackGenerator *_impactFeedbackGenerator;
}

+ (void)setShouldToggleHUDAfterLaunch:(BOOL)flag
{
    _gShouldToggleHUDAfterLaunch = flag;
}

+ (BOOL)shouldToggleHUDAfterLaunch
{
    return _gShouldToggleHUDAfterLaunch;
}

- (BOOL)isHUDEnabled
{
    return IsHUDEnabled();
}

- (void)setHUDEnabled:(BOOL)enabled
{
    SetHUDEnabled(enabled);
}

- (void)registerNotifications
{
    int token;
    notify_register_dispatch(NOTIFY_RELOAD_APP, &token, dispatch_get_main_queue(), ^(int token) {
        [self loadUserDefaults:YES];
    });

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(toggleHUDNotificationReceived:) name:kToggleHUDAfterLaunchNotificationName object:nil];
}

- (void)loadView
{
    CGRect bounds = UIScreen.mainScreen.bounds;

    self.view = [[UIView alloc] initWithFrame:bounds];
    self.view.backgroundColor = [UIColor colorWithRed:0.0f / 255.0f green:0.0f / 255.0f blue:0.0f / 255.0f alpha:.580f / 1.0f];  // rgba(0, 0, 0, 0.580)

    self.backgroundView = [[UIView alloc] initWithFrame:bounds];
    self.backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.backgroundView.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        if ([traitCollection userInterfaceStyle] == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:28/255.0 green:74/255.0 blue:82/255.0 alpha:1.0];  // rgba(28, 74, 82, 1.0)
        } else {
            return [UIColor colorWithRed:26/255.0 green:188/255.0 blue:156/255.0 alpha:1.0];  // rgba(26, 188, 156, 1.0)
        }
    }];
    [self.view addSubview:self.backgroundView];

    // 初始化并设置编辑文字按钮
    _editTextButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_editTextButton setTintColor:[UIColor whiteColor]];
    [_editTextButton addTarget:self action:@selector(tapEditTextButton:) forControlEvents:UIControlEventTouchUpInside];
    // 根据当前语言设置按钮标题
    if ([[[NSLocale preferredLanguages] firstObject] hasPrefix:@"zh"]) {
        [_editTextButton setTitle:@"编辑文字" forState:UIControlStateNormal];
    } else {
        [_editTextButton setTitle:@"Edit Text" forState:UIControlStateNormal];
    }
    if (@available(iOS 15.0, *))
    {
        UIButtonConfiguration *config = [UIButtonConfiguration tintedButtonConfiguration];
        [config setTitleTextAttributesTransformer:^NSDictionary <NSAttributedStringKey, id> * _Nonnull(NSDictionary <NSAttributedStringKey, id> * _Nonnull textAttributes) {
            NSMutableDictionary *newAttributes = [textAttributes mutableCopy];
            [newAttributes setObject:[UIFont boldSystemFontOfSize:20.0] forKey:NSFontAttributeName];
            return newAttributes;
        }];
        [config setCornerStyle:UIButtonConfigurationCornerStyleLarge];
        [_editTextButton setConfiguration:config];
    }
    else
    {
        [_editTextButton.titleLabel setFont:[UIFont boldSystemFontOfSize:20.0]];
    }
    [self.backgroundView addSubview:_editTextButton];

    [_editTextButton setTranslatesAutoresizingMaskIntoConstraints:NO];
    UILayoutGuide *safeArea = self.backgroundView.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [_editTextButton.centerXAnchor constraintEqualToAnchor:safeArea.centerXAnchor],
        [_editTextButton.bottomAnchor constraintEqualToAnchor:_mainButton.topAnchor constant:-20.0f], // 放置在_mainButton正上方，留20pt间距
        [_editTextButton.widthAnchor constraintEqualToConstant:120.0f],
        [_editTextButton.heightAnchor constraintEqualToConstant:50.0f],
    ]];

    // 初始化并设置主按钮
    _mainButton = [MainButton buttonWithType:UIButtonTypeSystem];
    [_mainButton setTintColor:[UIColor whiteColor]];
    [_mainButton addTarget:self action:@selector(tapMainButton:) forControlEvents:UIControlEventTouchUpInside];
    if (@available(iOS 15.0, *))
    {
        UIButtonConfiguration *config = [UIButtonConfiguration tintedButtonConfiguration];
        [config setTitleTextAttributesTransformer:^NSDictionary <NSAttributedStringKey, id> * _Nonnull(NSDictionary <NSAttributedStringKey, id> * _Nonnull textAttributes) {
            NSMutableDictionary *newAttributes = [textAttributes mutableCopy];
            [newAttributes setObject:[UIFont boldSystemFontOfSize:32.0] forKey:NSFontAttributeName];
            return newAttributes;
        }];
        [config setCornerStyle:UIButtonConfigurationCornerStyleLarge];
        [_mainButton setConfiguration:config];
    }
    else
    {
        [_mainButton.titleLabel setFont:[UIFont boldSystemFontOfSize:32.0]];
    }
    [self.backgroundView addSubview:_mainButton];

    [_mainButton setTranslatesAutoresizingMaskIntoConstraints:NO];
    [NSLayoutConstraint activateConstraints:@[
        [_mainButton.centerXAnchor constraintEqualToAnchor:safeArea.centerXAnchor],
        [_mainButton.centerYAnchor constraintEqualToAnchor:self.backgroundView.centerYAnchor],
    ]];

    // 初始化并设置设置按钮
    _settingsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_settingsButton setTintColor:[UIColor whiteColor]];
    [_settingsButton addTarget:self action:@selector(tapSettingsButton:) forControlEvents:UIControlEventTouchUpInside];
    [_settingsButton setImage:[UIImage systemImageNamed:@"gear"] forState:UIControlStateNormal];
    [self.backgroundView addSubview:_settingsButton];
    if (@available(iOS 15.0, *))
    {
        UIButtonConfiguration *config = [UIButtonConfiguration tintedButtonConfiguration];
        [config setCornerStyle:UIButtonConfigurationCornerStyleLarge];
        [_settingsButton setConfiguration:config];
    }
    [_settingsButton setTranslatesAutoresizingMaskIntoConstraints:NO];
    [NSLayoutConstraint activateConstraints:@[
        [_settingsButton.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor constant:-20.0f],
        [_settingsButton.centerXAnchor constraintEqualToAnchor:safeArea.centerXAnchor],
        [_settingsButton.widthAnchor constraintEqualToConstant:40.0f],
        [_settingsButton.heightAnchor constraintEqualToConstant:40.0f],
    ]];

    // 初始化并设置作者标签
    _authorLabel = [[UILabel alloc] init];
    [_authorLabel setNumberOfLines:0];
    [_authorLabel setTextAlignment:NSTextAlignmentCenter];
    [_authorLabel setTextColor:[UIColor whiteColor]];
    [_authorLabel setFont:[UIFont systemFontOfSize:14.0]];
    [_authorLabel sizeToFit];
    [self.backgroundView addSubview:_authorLabel];

    _authorLabelBottomConstraint = [_authorLabel.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor constant:_gAuthorLabelBottomConstraintConstantRegular];
    [_authorLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
    [NSLayoutConstraint activateConstraints:@[
        _authorLabelBottomConstraint,
        [_authorLabel.centerXAnchor constraintEqualToAnchor:safeArea.centerXAnchor],
    ]];

    // 为作者标签添加点击手势识别器
    UITapGestureRecognizer *authorTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapAuthorLabel:)];
    [_authorLabel setUserInteractionEnabled:YES];
    [_authorLabel addGestureRecognizer:authorTapGesture];

    [self verticalSizeClassUpdated];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _impactFeedbackGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];

    // 注册通知
    [self registerNotifications];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    // 启动后切换HUD状态
    [self toggleHUDAfterLaunch];
}

- (void)toggleHUDNotificationReceived:(NSNotification *)notification {
    NSString *toggleAction = notification.userInfo[kToggleHUDAfterLaunchNotificationActionKey];
    if (!toggleAction) {
        [self toggleHUDAfterLaunch];
    } else if ([toggleAction isEqualToString:kToggleHUDAfterLaunchNotificationActionToggleOn]) {
        [self toggleOnHUDAfterLaunch];
    } else if ([toggleAction isEqualToString:kToggleHUDAfterLaunchNotificationActionToggleOff]) {
        [self toggleOffHUDAfterLaunch];
    }
}

- (void)toggleHUDAfterLaunch {
    // 如果应该在启动后切换HUD
    if ([RootViewController shouldToggleHUDAfterLaunch]) {
        [RootViewController setShouldToggleHUDAfterLaunch:NO]; // 重置标志
        [self tapMainButton:_mainButton]; // 模拟点击主按钮以切换HUD
        [[UIApplication sharedApplication] suspend]; // 暂停应用
    }
}

- (void)toggleOnHUDAfterLaunch {
    // 如果应该在启动后切换HUD
    if ([RootViewController shouldToggleHUDAfterLaunch]) {
        [RootViewController setShouldToggleHUDAfterLaunch:NO]; // 重置标志
        // 如果远程HUD未激活，则模拟点击主按钮打开HUD
        if (!_isRemoteHUDActive) {
            [self tapMainButton:_mainButton];
        }
        [[UIApplication sharedApplication] suspend]; // 暂停应用
    }
}

- (void)toggleOffHUDAfterLaunch {
    // 如果应该在启动后切换HUD
    if ([RootViewController shouldToggleHUDAfterLaunch]) {
        [RootViewController setShouldToggleHUDAfterLaunch:NO]; // 重置标志
        // 如果远程HUD激活，则模拟点击主按钮关闭HUD
        if (_isRemoteHUDActive) {
            [self tapMainButton:_mainButton];
        }
        [[UIApplication sharedApplication] suspend]; // 暂停应用
    }
}

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    if (motion == UIEventSubtypeMotionShake) {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Developer Area", nil) message:NSLocalizedString(@"Choose an action below.", nil) preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Dismiss", nil) style:UIAlertActionStyleCancel handler:nil]];
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Reset Settings", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self resetUserDefaults];
        }]];
#if DEBUG && !TARGET_OS_SIMULATOR
        [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Memory Pressure", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            SimulateMemoryPressure();
        }]];
#endif
        [self presentViewController:alertController animated:YES completion:nil];
    }
}

- (void)resetUserDefaults
{
    // 重置标准用户默认设置
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    if (bundleIdentifier) {
        [GetStandardUserDefaults() removePersistentDomainForName:bundleIdentifier];
        [GetStandardUserDefaults() synchronize];
    }

    // 重置自定义用户默认设置
    BOOL removed = [[NSFileManager defaultManager] removeItemAtPath:(JBROOT_PATH_NSSTRING(USER_DEFAULTS_PATH)) error:nil];
    if (removed)
    {
        // 终止HUD
        [self setHUDEnabled:NO];

        // 终止应用
        [[UIApplication sharedApplication] terminateWithSuccess];
    }
}

- (void)loadUserDefaults:(BOOL)forceReload
{
    // 如果强制重新加载或用户默认设置为空，则从文件加载用户默认设置
    if (forceReload || !_userDefaults) {
        _userDefaults = [[NSDictionary dictionaryWithContentsOfFile:(JBROOT_PATH_NSSTRING(USER_DEFAULTS_PATH))] mutableCopy] ?: [NSMutableDictionary dictionary];
    }
}

- (void)saveUserDefaults
{
    // 将用户默认设置保存到文件并通知HUD重新加载
    [_userDefaults writeToFile:(JBROOT_PATH_NSSTRING(USER_DEFAULTS_PATH)) atomically:YES];
    notify_post(NOTIFY_RELOAD_HUD);
}

- (BOOL)isLandscapeOrientation
{
    UIInterfaceOrientation orientation;
    orientation = self.view.window.windowScene.interfaceOrientation;
    BOOL isLandscape;
    // 如果方向未知，则根据视图宽度和高度判断是否为横向
    if (orientation == UIInterfaceOrientationUnknown) {
        isLandscape = CGRectGetWidth(self.view.bounds) > CGRectGetHeight(self.view.bounds);
    } else {
        isLandscape = UIInterfaceOrientationIsLandscape(orientation); // 根据已知方向判断是否为横向
    }
    return isLandscape;
}

- (HUDUserDefaultsKey)selectedModeKeyForCurrentOrientation
{
    // 根据当前方向返回对应的用户默认设置键
    return [self isLandscapeOrientation] ? HUDUserDefaultsKeySelectedModeLandscape : HUDUserDefaultsKeySelectedMode;
}

- (void)setSelectedModeForCurrentOrientation:(NSInteger)selectedMode
{
    [self loadUserDefaults:NO];
    // 移除不持久化的位置键
    if ([self isLandscapeOrientation]) {
        [_userDefaults removeObjectForKey:HUDUserDefaultsKeyCurrentLandscapePositionY];
    } else {
        [_userDefaults removeObjectForKey:HUDUserDefaultsKeyCurrentPositionY];
    }
    // 设置当前方向的选择模式
    [_userDefaults setObject:@(selectedMode) forKey:[self selectedModeKeyForCurrentOrientation]];
    [self saveUserDefaults]; // 保存用户默认设置
}

- (BOOL)passthroughMode
{
    [self loadUserDefaults:NO];
    // 从用户默认设置中获取穿透模式，如果不存在则默认为 NO
    NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyPassthroughMode];
    return mode != nil ? [mode boolValue] : NO;
}

- (void)setPassthroughMode:(BOOL)passthroughMode
{
    [self loadUserDefaults:NO];
    // 设置穿透模式并保存用户默认设置
    [_userDefaults setObject:@(passthroughMode) forKey:HUDUserDefaultsKeyPassthroughMode];
    [self saveUserDefaults];
}

- (BOOL)usesLargeFont
{
    [self loadUserDefaults:NO];
    // 从用户默认设置中获取是否使用大字体，如果不存在则默认为 NO
    NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyUsesLargeFont];
    return mode != nil ? [mode boolValue] : NO;
}

- (void)setUsesLargeFont:(BOOL)usesLargeFont
{
    [self loadUserDefaults:NO];
    // 设置是否使用大字体并保存用户默认设置
    [_userDefaults setObject:@(usesLargeFont) forKey:HUDUserDefaultsKeyUsesLargeFont];
    [self saveUserDefaults];
}

- (BOOL)usesRotation
{
    [self loadUserDefaults:NO];
    // 从用户默认设置中获取是否使用旋转，如果不存在则默认为 NO
    NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyUsesRotation];
    return mode != nil ? [mode boolValue] : NO;
}

- (void)setUsesRotation:(BOOL)usesRotation
{
    [self loadUserDefaults:NO];
    // 设置是否使用旋转并保存用户默认设置
    [_userDefaults setObject:@(usesRotation) forKey:HUDUserDefaultsKeyUsesRotation];
    [self saveUserDefaults];
}

- (BOOL)usesInvertedColor
{
    [self loadUserDefaults:NO];
    // 从用户默认设置中获取是否使用反转颜色，如果不存在则默认为 NO
    NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyUsesInvertedColor];
    return mode != nil ? [mode boolValue] : NO;
}

- (void)setUsesInvertedColor:(BOOL)usesInvertedColor
{
    [self loadUserDefaults:NO];
    // 设置是否使用反转颜色并保存用户默认设置
    [_userDefaults setObject:@(usesInvertedColor) forKey:HUDUserDefaultsKeyUsesInvertedColor];
    [self saveUserDefaults];
}

- (BOOL)keepInPlace
{
    [self loadUserDefaults:NO];
    // 从用户默认设置中获取是否保持在位，如果不存在则默认为 NO
    NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyKeepInPlace];
    return mode != nil ? [mode boolValue] : NO;
}

- (void)setKeepInPlace:(BOOL)keepInPlace
{
    [self loadUserDefaults:NO];
    // 设置是否保持在位并保存用户默认设置
    [_userDefaults setObject:@(keepInPlace) forKey:HUDUserDefaultsKeyKeepInPlace];
    [self saveUserDefaults];
}

- (BOOL)hideAtSnapshot
{
    [self loadUserDefaults:NO];
    // 从用户默认设置中获取是否在快照时隐藏，如果不存在则默认为 NO
    NSNumber *mode = [_userDefaults objectForKey:HUDUserDefaultsKeyHideAtSnapshot];
    return mode != nil ? [mode boolValue] : NO;
}

- (void)setHideAtSnapshot:(BOOL)hideAtSnapshot
{
    [self loadUserDefaults:NO];
    // 设置是否在快照时隐藏并保存用户默认设置
    [_userDefaults setObject:@(hideAtSnapshot) forKey:HUDUserDefaultsKeyHideAtSnapshot];
    [self saveUserDefaults];
}

- (void)reloadMainButtonState
{
    // 获取当前HUD是否启用
    _isRemoteHUDActive = [self isHUDEnabled];

    static NSAttributedString *hintAttributedString = nil; // 提示文本
    static NSAttributedString *creditsAttributedString = nil; // 制作人员文本
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 默认属性
        NSDictionary *defaultAttributes = @{
            NSForegroundColorAttributeName: [UIColor whiteColor],
            NSFontAttributeName: [UIFont systemFontOfSize:14],
        };

        // 制作人员文本段落样式
        NSMutableParagraphStyle *creditsParaStyle = [[NSMutableParagraphStyle alloc] init];
        creditsParaStyle.lineHeightMultiple = 1.2;
        creditsParaStyle.alignment = NSTextAlignmentCenter;

        // 制作人员文本属性
        NSDictionary *creditsAttributes = @{
            NSForegroundColorAttributeName: [UIColor whiteColor],
            NSFontAttributeName: [UIFont systemFontOfSize:14],
            NSParagraphStyleAttributeName: creditsParaStyle,
        };

        // 提示文本内容
        NSString *hintText = NSLocalizedString(@"You can quit this app now.\nThe HUD will persist on your screen.", nil);
        hintAttributedString = [[NSAttributedString alloc] initWithString:hintText attributes:defaultAttributes];

        // GitHub图标附件
        NSTextAttachment *githubIcon = [NSTextAttachment textAttachmentWithImage:[UIImage imageNamed:@"github-mark-white"]];
        [githubIcon setBounds:CGRectMake(0, 0, 14, 14)];

        // 国际化图标附件
        NSTextAttachment *i18nIcon = [NSTextAttachment textAttachmentWithImage:[UIImage systemImageNamed:@"character.bubble.fill"]];
        [i18nIcon setBounds:CGRectMake(0, 0, 14, 14)];

        // GitHub图标文本
        NSAttributedString *githubIconText = [NSAttributedString attributedStringWithAttachment:githubIcon];
        NSMutableAttributedString *githubIconTextFull = [[NSMutableAttributedString alloc] initWithAttributedString:githubIconText];
        [githubIconTextFull appendAttributedString:[[NSAttributedString alloc] initWithString:@" " attributes:creditsAttributes]];

        // 国际化图标文本
        NSAttributedString *i18nIconText = [NSAttributedString attributedStringWithAttachment:i18nIcon];
        NSMutableAttributedString *i18nIconTextFull = [[NSMutableAttributedString alloc] initWithAttributedString:i18nIconText];
        [i18nIconTextFull appendAttributedString:[[NSAttributedString alloc] initWithString:@" " attributes:creditsAttributes]];

        // 制作人员文本内容
        NSString *creditsText = NSLocalizedString(@"Made by @better, Base on @GITHUB@Lessica and @GITHUB@jmpews\nTranslation @TRANSLATION@", nil);
        NSMutableAttributedString *creditsAttributedText = [[NSMutableAttributedString alloc] initWithString:creditsText attributes:creditsAttributes];

        // 替换 "@GITHUB@" 为 GitHub 图标
        NSRange atRange;

        atRange = [creditsAttributedText.string rangeOfString:@"@GITHUB@"];
        while (atRange.location != NSNotFound) {
            [creditsAttributedText replaceCharactersInRange:atRange withAttributedString:githubIconTextFull];
            atRange = [creditsAttributedText.string rangeOfString:@"@GITHUB@"];
        }

        // 替换 "@TRANSLATION@" 为国际化图标
        atRange = [creditsAttributedText.string rangeOfString:@"@TRANSLATION@"];
        while (atRange.location != NSNotFound) {
            [creditsAttributedText replaceCharactersInRange:atRange withAttributedString:i18nIconTextFull];
            atRange = [creditsAttributedText.string rangeOfString:@"@TRANSLATION@"];
        }

        creditsAttributedString = creditsAttributedText;
    });

    __weak typeof(self) weakSelf = self;
    // 过渡动画
    [UIView transitionWithView:self.backgroundView duration:HUD_TRANSITION_DURATION options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        // 根据HUD是否激活设置主按钮标题和作者标签文本
        [strongSelf->_mainButton setTitle:(strongSelf->_isRemoteHUDActive ? NSLocalizedString(@"Exit HUD", nil) : NSLocalizedString(@"Open HUD", nil)) forState:UIControlStateNormal];
        [strongSelf->_authorLabel setAttributedText:(strongSelf->_isRemoteHUDActive ? hintAttributedString : creditsAttributedString)];
    } completion:nil];
}

- (void)presentTopCenterMostHints
{
    // 如果远程HUD未激活，则不显示提示
    if (!_isRemoteHUDActive) {
        return;
    }
    // 设置作者标签文本为提示信息
    [_authorLabel setText:NSLocalizedString(@"Tap that button on the center again,\nto toggle ON/OFF "Dynamic Island" mode.", nil)];
}

- (BOOL)settingHighlightedWithKey:(NSString * _Nonnull)key
{
    [self loadUserDefaults:NO];
    // 根据键从用户默认设置中获取高亮状态
    NSNumber *mode = [_userDefaults objectForKey:key];
    return mode != nil ? [mode boolValue] : NO;
}

- (void)settingDidSelectWithKey:(NSString * _Nonnull)key
{
    BOOL highlighted = [self settingHighlightedWithKey:key];
    // 切换设置的高亮状态并保存用户默认设置
    [_userDefaults setObject:@(!highlighted) forKey:key];
    [self saveUserDefaults];
}

- (void)tapAuthorLabel:(UITapGestureRecognizer *)sender
{
    // 如果远程HUD激活，则不执行任何操作
    if (_isRemoteHUDActive) {
        return;
    }
    NSString *repoURLString = @"https://TrollMemo.app";
    NSURL *repoURL = [NSURL URLWithString:repoURLString];
    // 打开仓库URL
    [[UIApplication sharedApplication] openURL:repoURL options:@{} completionHandler:nil];
}

- (void)tapMainButton:(UIButton *)sender
{
    log_debug(OS_LOG_DEFAULT, "- [RootViewController tapMainButton:%{public}@]", sender);

    BOOL isNowEnabled = [self isHUDEnabled];
    [self setHUDEnabled:!isNowEnabled]; // 切换HUD启用状态
    isNowEnabled = !isNowEnabled;

    if (isNowEnabled) // 如果HUD现在已启用
    {
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

        [_impactFeedbackGenerator prepare]; // 准备触觉反馈
        int anyToken;
        __weak typeof(self) weakSelf = self;
        notify_register_dispatch(NOTIFY_LAUNCHED_HUD, &anyToken, dispatch_get_main_queue(), ^(int token) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            notify_cancel(token);
            [strongSelf->_impactFeedbackGenerator impactOccurred]; // 发生触觉反馈
            dispatch_semaphore_signal(semaphore); // 发送信号
        });

        [self.backgroundView setUserInteractionEnabled:NO]; // 禁用背景视图用户交互
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            intptr_t timedOut = dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC))); // 等待信号或超时
            dispatch_async(dispatch_get_main_queue(), ^{
                if (timedOut) {
                    log_error(OS_LOG_DEFAULT, "Timed out waiting for HUD to launch"); // 记录HUD启动超时错误
                }
                [self.backgroundView setUserInteractionEnabled:YES]; // 启用背景视图用户交互
            });
        });
    }
    else // 如果HUD现在已禁用
    {
        [self.backgroundView setUserInteractionEnabled:NO]; // 禁用背景视图用户交互
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.backgroundView setUserInteractionEnabled:YES]; // 启用背景视图用户交互
        });
    }
}

- (void)tapSettingsButton:(UIButton *)sender
{
    // 如果主按钮未启用，则不执行任何操作
    if (![_mainButton isEnabled]) return;
    log_debug(OS_LOG_DEFAULT, "- [RootViewController tapSettingsButton:%{public}@]", sender);

    TSSettingsController *settingsViewController = [[TSSettingsController alloc] init];
    settingsViewController.delegate = self;
    settingsViewController.alreadyLaunched = _isRemoteHUDActive;

    SPLarkTransitioningDelegate *transitioningDelegate = [[SPLarkTransitioningDelegate alloc] init];
    settingsViewController.transitioningDelegate = transitioningDelegate;
    settingsViewController.modalPresentationStyle = UIModalPresentationCustom;
    settingsViewController.modalPresentationCapturesStatusBarAppearance = YES;
    // 显示设置视图控制器
    [self presentViewController:settingsViewController animated:YES completion:nil];
}

- (void)verticalSizeClassUpdated
{
    UIUserInterfaceSizeClass verticalClass = self.traitCollection.verticalSizeClass;
    BOOL isPad = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad);
    // 如果垂直尺寸类别为紧凑型
    if (verticalClass == UIUserInterfaceSizeClassCompact) {
        CGFloat topConstant = _gTopButtonConstraintsConstantCompact;
        [_settingsButton setHidden:YES]; // 隐藏设置按钮
        [_authorLabelBottomConstraint setConstant:_gAuthorLabelBottomConstraintConstantCompact]; // 设置作者标签底部约束
    } else {
        CGFloat topConstant = isPad ? _gTopButtonConstraintsConstantRegularPad : _gTopButtonConstraintsConstantRegular;
        [_settingsButton setHidden:NO]; // 显示设置按钮
        [_authorLabelBottomConstraint setConstant:_gAuthorLabelBottomConstraintConstantRegular]; // 设置作者标签底部约束
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [self verticalSizeClassUpdated]; // 垂直尺寸类别改变时更新视图
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

    // 协调器动画完成时重新加载模式按钮状态
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        // No action needed here as reloadModeButtonState is removed
    } completion:nil];
}

- (void)tapEditTextButton:(UIButton *)sender
{
    log_debug(OS_LOG_DEFAULT, "- [RootViewController tapEditTextButton:%{public}@]", sender);

    EditTextSettingsViewController *settingsViewController = [[EditTextSettingsViewController alloc] init];
    settingsViewController.delegate = self;
    settingsViewController.modalPresentationStyle = UIModalPresentationPageSheet;
    if (@available(iOS 15.0, *)) {
        if ([settingsViewController respondsToSelector:@selector(setSheetPresentationController:)]) {
            UISheetPresentationController *sheet = settingsViewController.sheetPresentationController;
            if (sheet) {
                sheet.detents = @[UISheetPresentationControllerDetent.mediumDetent, UISheetPresentationControllerDetent.largeDetent];
                sheet.prefersScrollingExpandsWhenScrolledToEdge = NO;
                sheet.prefersEdgeAttachedInCompactHeight = YES;
                sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = YES;
            }
        }
    }
    [self presentViewController:settingsViewController animated:YES completion:nil];
}

#pragma mark - EditTextSettingsViewControllerDelegate

- (void)editTextSettingsDidSave {
    log_debug(OS_LOG_DEFAULT, "EditText settings saved, notifying HUD to reload.");
    // 通知HUD重新加载，以便应用新的文本设置
    notify_post(NOTIFY_RELOAD_HUD);
    // 重新加载主按钮状态，以防万一文本设置影响到主按钮（尽管目前没有）
    [self reloadMainButtonState]; 
}

- (void)editTextSettingsDidCancel {
    log_debug(OS_LOG_DEFAULT, "EditText settings cancelled.");
    // 用户取消了设置，无需保存或刷新
}

@end
