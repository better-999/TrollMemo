//
//  EditTextSettingsViewController.m
//  TrollMemo
//
//  主 App 内的「编辑文字」页面。
//  用户在弹窗里修改文字内容、颜色、大小等，保存后写入共享 plist，
//  再通过 Darwin 通知让桌面 HUD 进程（HUDRootViewController）刷新显示。
//

#import "EditTextSettingsViewController.h"
#import <notify.h>
#import "HUDHelper.h"
#import "TrollMemo-Swift.h"
#import "../supports/hudapp-bridging-header.h"

@interface EditTextSettingsViewController () <UITextViewDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UITextView *textViewPreview;
@property (nonatomic, strong) UIColorWell *textColorWell;
@property (nonatomic, strong) UIStepper *textSizeStepper;
@property (nonatomic, strong) UISegmentedControl *textAlignmentSegmentedControl;
@property (nonatomic, strong) UISlider *textAlphaSlider;
@property (nonatomic, strong) UIColorWell *backgroundColorWell;
@property (nonatomic, strong) UISlider *backgroundAlphaSlider;
@property (nonatomic, strong) UILabel *behaviorSectionLabel;
@property (nonatomic, strong) UIView *behaviorSettingsContainer;
@property (nonatomic, strong) TSSettingsController *behaviorSettingsController;
@property (nonatomic, strong) UIButton *saveButton;
@property (nonatomic, strong) UIButton *cancelButton;
@property (nonatomic, strong) NSMutableDictionary *currentSettings;

@end

@implementation EditTextSettingsViewController

// 从 plist 里读出的 NSData 还原为 UIColor
- (UIColor *)colorFromSettingsData:(NSData *)data fallback:(UIColor *)fallback
{
    if (!data) {
        return fallback;
    }
    UIColor *color = [NSKeyedUnarchiver unarchivedObjectOfClass:[UIColor class] fromData:data error:nil];
    return color ?: fallback;
}

- (void)loadView {
    self.view = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    _scrollView = [[UIScrollView alloc] init];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:_scrollView];

    _contentView = [[UIView alloc] init];
    _contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [_scrollView addSubview:_contentView];

    NSMutableDictionary *savedSettings = LoadHUDSettingsPlist();

    _textViewPreview = [[UITextView alloc] init];
    _textViewPreview.translatesAutoresizingMaskIntoConstraints = NO;
    _textViewPreview.font = [UIFont systemFontOfSize:17.0];
    _textViewPreview.textColor = [UIColor blackColor];
    _textViewPreview.backgroundColor = [UIColor systemGray5Color];
    _textViewPreview.layer.cornerRadius = 5.0;
    _textViewPreview.layer.borderColor = [UIColor systemGray2Color].CGColor;
    _textViewPreview.layer.borderWidth = 1.0;
    _textViewPreview.textAlignment = NSTextAlignmentCenter;
    _textViewPreview.delegate = self;
    _textViewPreview.text = [savedSettings objectForKey:HUDUserDefaultsKeyTextContent] ?: NSLocalizedString(@"Hello World!", nil);
    [_contentView addSubview:_textViewPreview];

    UILabel *textColorLabel = [[UILabel alloc] init];
    textColorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    textColorLabel.text = NSLocalizedString(@"文字颜色", nil);
    [_contentView addSubview:textColorLabel];

    _textColorWell = [[UIColorWell alloc] init];
    _textColorWell.translatesAutoresizingMaskIntoConstraints = NO;
    _textColorWell.selectedColor = [UIColor redColor];
    [_textColorWell addTarget:self action:@selector(colorWellDidChange:) forControlEvents:UIControlEventValueChanged];
    [_contentView addSubview:_textColorWell];

    UILabel *textSizeLabel = [[UILabel alloc] init];
    textSizeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    textSizeLabel.text = NSLocalizedString(@"文字大小", nil);
    [_contentView addSubview:textSizeLabel];

    _textSizeStepper = [[UIStepper alloc] init];
    _textSizeStepper.translatesAutoresizingMaskIntoConstraints = NO;
    _textSizeStepper.minimumValue = 5;
    _textSizeStepper.maximumValue = 50;
    _textSizeStepper.value = [[savedSettings objectForKey:HUDUserDefaultsKeyTextSize] floatValue] ?: 10.0;
    _textSizeStepper.stepValue = 1;
    [_textSizeStepper addTarget:self action:@selector(stepperDidChange:) forControlEvents:UIControlEventValueChanged];
    [_contentView addSubview:_textSizeStepper];

    UILabel *textAlignmentLabel = [[UILabel alloc] init];
    textAlignmentLabel.translatesAutoresizingMaskIntoConstraints = NO;
    textAlignmentLabel.text = NSLocalizedString(@"文字对齐", nil);
    [_contentView addSubview:textAlignmentLabel];

    _textAlignmentSegmentedControl = [[UISegmentedControl alloc] initWithItems:@[NSLocalizedString(@"左", nil), NSLocalizedString(@"中", nil), NSLocalizedString(@"右", nil)]];
    _textAlignmentSegmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    _textAlignmentSegmentedControl.selectedSegmentIndex = [[savedSettings objectForKey:HUDUserDefaultsKeyTextAlignment] integerValue] ?: NSTextAlignmentCenter;
    [_textAlignmentSegmentedControl addTarget:self action:@selector(segmentedControlDidChange:) forControlEvents:UIControlEventValueChanged];
    [_contentView addSubview:_textAlignmentSegmentedControl];

    UILabel *textAlphaLabel = [[UILabel alloc] init];
    textAlphaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    textAlphaLabel.text = NSLocalizedString(@"文字透明度", nil);
    [_contentView addSubview:textAlphaLabel];

    _textAlphaSlider = [[UISlider alloc] init];
    _textAlphaSlider.translatesAutoresizingMaskIntoConstraints = NO;
    _textAlphaSlider.minimumValue = 0.0;
    _textAlphaSlider.maximumValue = 1.0;
    _textAlphaSlider.value = [[savedSettings objectForKey:HUDUserDefaultsKeyTextAlpha] floatValue] ?: 1.0;
    [_textAlphaSlider addTarget:self action:@selector(sliderDidChange:) forControlEvents:UIControlEventValueChanged];
    [_textAlphaSlider addTarget:self action:@selector(sliderDidChange:) forControlEvents:UIControlEventTouchDragInside | UIControlEventTouchDragOutside];
    [_contentView addSubview:_textAlphaSlider];

    UILabel *backgroundColorLabel = [[UILabel alloc] init];
    backgroundColorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    backgroundColorLabel.text = NSLocalizedString(@"背景颜色", nil);
    [_contentView addSubview:backgroundColorLabel];

    _backgroundColorWell = [[UIColorWell alloc] init];
    _backgroundColorWell.translatesAutoresizingMaskIntoConstraints = NO;
    _backgroundColorWell.selectedColor = [UIColor blackColor];
    [_backgroundColorWell addTarget:self action:@selector(colorWellDidChange:) forControlEvents:UIControlEventValueChanged];
    [_contentView addSubview:_backgroundColorWell];

    UILabel *backgroundAlphaLabel = [[UILabel alloc] init];
    backgroundAlphaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    backgroundAlphaLabel.text = NSLocalizedString(@"背景透明度", nil);
    [_contentView addSubview:backgroundAlphaLabel];

    _backgroundAlphaSlider = [[UISlider alloc] init];
    _backgroundAlphaSlider.translatesAutoresizingMaskIntoConstraints = NO;
    _backgroundAlphaSlider.minimumValue = 0.0;
    _backgroundAlphaSlider.maximumValue = 1.0;
    _backgroundAlphaSlider.value = [[savedSettings objectForKey:HUDUserDefaultsKeyBackgroundAlpha] floatValue] ?: 0.0;
    [_backgroundAlphaSlider addTarget:self action:@selector(sliderDidChange:) forControlEvents:UIControlEventValueChanged];
    [_backgroundAlphaSlider addTarget:self action:@selector(sliderDidChange:) forControlEvents:UIControlEventTouchDragInside | UIControlEventTouchDragOutside];
    [_contentView addSubview:_backgroundAlphaSlider];

    _behaviorSectionLabel = [[UILabel alloc] init];
    _behaviorSectionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _behaviorSectionLabel.text = NSLocalizedString(@"Settings", nil);
    _behaviorSectionLabel.font = [UIFont boldSystemFontOfSize:18.0];
    [_contentView addSubview:_behaviorSectionLabel];

    _behaviorSettingsContainer = [[UIView alloc] init];
    _behaviorSettingsContainer.translatesAutoresizingMaskIntoConstraints = NO;
    _behaviorSettingsContainer.backgroundColor = [UIColor blackColor];
    _behaviorSettingsContainer.layer.cornerRadius = 12.0;
    _behaviorSettingsContainer.clipsToBounds = YES;
    [_contentView addSubview:_behaviorSettingsContainer];

    _behaviorSettingsController = [[TSSettingsController alloc] init];
    _behaviorSettingsController.embeddedInEditSheet = YES;
    _behaviorSettingsController.delegate = self.behaviorSettingsDelegate;
    _behaviorSettingsController.alreadyLaunched = self.hudAlreadyLaunched;
    [self addChildViewController:_behaviorSettingsController];
    [_behaviorSettingsContainer addSubview:_behaviorSettingsController.view];
    _behaviorSettingsController.view.translatesAutoresizingMaskIntoConstraints = NO;
    [_behaviorSettingsController didMoveToParentViewController:self];

    _saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _saveButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_saveButton setTitle:NSLocalizedString(@"保存", nil) forState:UIControlStateNormal];
    [_saveButton addTarget:self action:@selector(saveButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [_contentView addSubview:_saveButton];

    _cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_cancelButton setTitle:NSLocalizedString(@"取消", nil) forState:UIControlStateNormal];
    [_cancelButton addTarget:self action:@selector(cancelButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [_contentView addSubview:_cancelButton];

    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [_scrollView.topAnchor constraintEqualToAnchor:safeArea.topAnchor],
        [_scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [_contentView.topAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.topAnchor],
        [_contentView.leadingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.leadingAnchor],
        [_contentView.trailingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.trailingAnchor],
        [_contentView.bottomAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.bottomAnchor],
        [_contentView.widthAnchor constraintEqualToAnchor:_scrollView.frameLayoutGuide.widthAnchor],

        [_textViewPreview.topAnchor constraintEqualToAnchor:_contentView.topAnchor constant:20],
        [_textViewPreview.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:20],
        [_textViewPreview.trailingAnchor constraintEqualToAnchor:_contentView.trailingAnchor constant:-20],
        [_textViewPreview.heightAnchor constraintGreaterThanOrEqualToConstant:100],

        [textColorLabel.topAnchor constraintEqualToAnchor:_textViewPreview.bottomAnchor constant:20],
        [textColorLabel.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:20],
        [_textColorWell.centerYAnchor constraintEqualToAnchor:textColorLabel.centerYAnchor],
        [_textColorWell.trailingAnchor constraintEqualToAnchor:_contentView.trailingAnchor constant:-20],
        [_textColorWell.widthAnchor constraintEqualToConstant:44],
        [_textColorWell.heightAnchor constraintEqualToConstant:44],

        [textSizeLabel.topAnchor constraintEqualToAnchor:textColorLabel.bottomAnchor constant:20],
        [textSizeLabel.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:20],
        [_textSizeStepper.centerYAnchor constraintEqualToAnchor:textSizeLabel.centerYAnchor],
        [_textSizeStepper.trailingAnchor constraintEqualToAnchor:_contentView.trailingAnchor constant:-20],

        [textAlignmentLabel.topAnchor constraintEqualToAnchor:textSizeLabel.bottomAnchor constant:20],
        [textAlignmentLabel.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:20],
        [_textAlignmentSegmentedControl.centerYAnchor constraintEqualToAnchor:textAlignmentLabel.centerYAnchor],
        [_textAlignmentSegmentedControl.trailingAnchor constraintEqualToAnchor:_contentView.trailingAnchor constant:-20],
        [_textAlignmentSegmentedControl.leadingAnchor constraintGreaterThanOrEqualToAnchor:textAlignmentLabel.trailingAnchor constant:10],

        [textAlphaLabel.topAnchor constraintEqualToAnchor:textAlignmentLabel.bottomAnchor constant:20],
        [textAlphaLabel.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:20],
        [_textAlphaSlider.topAnchor constraintEqualToAnchor:textAlphaLabel.bottomAnchor constant:8],
        [_textAlphaSlider.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:20],
        [_textAlphaSlider.trailingAnchor constraintEqualToAnchor:_contentView.trailingAnchor constant:-20],

        [backgroundColorLabel.topAnchor constraintEqualToAnchor:_textAlphaSlider.bottomAnchor constant:20],
        [backgroundColorLabel.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:20],
        [_backgroundColorWell.centerYAnchor constraintEqualToAnchor:backgroundColorLabel.centerYAnchor],
        [_backgroundColorWell.trailingAnchor constraintEqualToAnchor:_contentView.trailingAnchor constant:-20],
        [_backgroundColorWell.widthAnchor constraintEqualToConstant:44],
        [_backgroundColorWell.heightAnchor constraintEqualToConstant:44],

        [backgroundAlphaLabel.topAnchor constraintEqualToAnchor:backgroundColorLabel.bottomAnchor constant:20],
        [backgroundAlphaLabel.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:20],
        [_backgroundAlphaSlider.topAnchor constraintEqualToAnchor:backgroundAlphaLabel.bottomAnchor constant:8],
        [_backgroundAlphaSlider.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:20],
        [_backgroundAlphaSlider.trailingAnchor constraintEqualToAnchor:_contentView.trailingAnchor constant:-20],

        [_behaviorSectionLabel.topAnchor constraintEqualToAnchor:_backgroundAlphaSlider.bottomAnchor constant:28],
        [_behaviorSectionLabel.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:20],

        [_behaviorSettingsContainer.topAnchor constraintEqualToAnchor:_behaviorSectionLabel.bottomAnchor constant:12],
        [_behaviorSettingsContainer.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:12],
        [_behaviorSettingsContainer.trailingAnchor constraintEqualToAnchor:_contentView.trailingAnchor constant:-12],
        [_behaviorSettingsContainer.heightAnchor constraintEqualToConstant:150],

        [_behaviorSettingsController.view.topAnchor constraintEqualToAnchor:_behaviorSettingsContainer.topAnchor],
        [_behaviorSettingsController.view.leadingAnchor constraintEqualToAnchor:_behaviorSettingsContainer.leadingAnchor],
        [_behaviorSettingsController.view.trailingAnchor constraintEqualToAnchor:_behaviorSettingsContainer.trailingAnchor],
        [_behaviorSettingsController.view.bottomAnchor constraintEqualToAnchor:_behaviorSettingsContainer.bottomAnchor],

        [_saveButton.topAnchor constraintEqualToAnchor:_behaviorSettingsContainer.bottomAnchor constant:28],
        [_saveButton.centerXAnchor constraintEqualToAnchor:_contentView.centerXAnchor constant:-60],
        [_cancelButton.centerYAnchor constraintEqualToAnchor:_saveButton.centerYAnchor],
        [_cancelButton.centerXAnchor constraintEqualToAnchor:_contentView.centerXAnchor constant:60],
        [_saveButton.bottomAnchor constraintEqualToAnchor:_contentView.bottomAnchor constant:-24],
    ]];

    _currentSettings = [NSMutableDictionary dictionary];
    [self loadCurrentSettings];
    [self updatePreview];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [_behaviorSettingsController.view setNeedsLayout];
    [_behaviorSettingsController.view layoutIfNeeded];
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

#pragma mark - 控件事件（只更新内存预览，不写盘）

- (void)colorWellDidChange:(UIColorWell *)sender {
    if (sender == _textColorWell) {
        [_currentSettings setObject:sender.selectedColor forKey:HUDUserDefaultsKeyTextColor];
    } else if (sender == _backgroundColorWell) {
        [_currentSettings setObject:sender.selectedColor forKey:HUDUserDefaultsKeyBackgroundColor];
    }
    [self updatePreview];
}

- (void)stepperDidChange:(UIStepper *)sender {
    if (sender == _textSizeStepper) {
        [_currentSettings setObject:@(sender.value) forKey:HUDUserDefaultsKeyTextSize];
    }
    [self updatePreview];
}

- (void)segmentedControlDidChange:(UISegmentedControl *)sender {
    NSTextAlignment alignment;
    switch (sender.selectedSegmentIndex) {
        case 0: alignment = NSTextAlignmentLeft; break;
        case 1: alignment = NSTextAlignmentCenter; break;
        case 2: alignment = NSTextAlignmentRight; break;
        default: alignment = NSTextAlignmentCenter; break;
    }
    [_currentSettings setObject:@(alignment) forKey:HUDUserDefaultsKeyTextAlignment];
    [self updatePreview];
}

- (void)sliderDidChange:(UISlider *)sender {
    if (sender == _textAlphaSlider) {
        [_currentSettings setObject:@(sender.value) forKey:HUDUserDefaultsKeyTextAlpha];
    } else if (sender == _backgroundAlphaSlider) {
        [_currentSettings setObject:@(sender.value) forKey:HUDUserDefaultsKeyBackgroundAlpha];
    }
    [self updatePreview];
}

- (void)saveButtonTapped:(UIButton *)sender {
    [self saveSettings]; // 写入 plist 并通知 HUD
    if ([self.delegate respondsToSelector:@selector(editTextSettingsDidSave)]) {
        [self.delegate editTextSettingsDidSave];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)cancelButtonTapped:(UIButton *)sender {
    // 取消：丢弃 currentSettings，不调用 saveSettings
    if ([self.delegate respondsToSelector:@selector(editTextSettingsDidCancel)]) {
        [self.delegate editTextSettingsDidCancel];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - 预览区刷新（仅影响本页 textViewPreview，不影响 HUD）

- (void)updatePreview {
    UIColor *textColor = [_currentSettings objectForKey:HUDUserDefaultsKeyTextColor];
    if (textColor) {
        _textViewPreview.textColor = textColor;
    }

    NSNumber *textSize = [_currentSettings objectForKey:HUDUserDefaultsKeyTextSize];
    if (textSize) {
        _textViewPreview.font = [UIFont systemFontOfSize:[textSize floatValue]];
    }

    NSNumber *textAlignment = [_currentSettings objectForKey:HUDUserDefaultsKeyTextAlignment];
    if (textAlignment) {
        _textViewPreview.textAlignment = (NSTextAlignment)[textAlignment integerValue];
    }

    NSNumber *textAlpha = [_currentSettings objectForKey:HUDUserDefaultsKeyTextAlpha];
    _textViewPreview.alpha = textAlpha ? [textAlpha floatValue] : 1.0;

    UIColor *bgColor = [_currentSettings objectForKey:HUDUserDefaultsKeyBackgroundColor] ?: [UIColor blackColor];
    NSNumber *bgAlpha = [_currentSettings objectForKey:HUDUserDefaultsKeyBackgroundAlpha];
    _textViewPreview.backgroundColor = [bgColor colorWithAlphaComponent:bgAlpha ? [bgAlpha floatValue] : 0.0];
}

#pragma mark - 读写共享 plist

// 打开页面时：从 plist 加载到 currentSettings，并同步到各控件
- (void)loadCurrentSettings {
    NSMutableDictionary *savedSettings = LoadHUDSettingsPlist();

    _currentSettings[HUDUserDefaultsKeyTextContent] = [savedSettings objectForKey:HUDUserDefaultsKeyTextContent] ?: NSLocalizedString(@"Hello World!", nil);
    _currentSettings[HUDUserDefaultsKeyTextColor] = [self colorFromSettingsData:[savedSettings objectForKey:HUDUserDefaultsKeyTextColor] fallback:[UIColor redColor]];
    _currentSettings[HUDUserDefaultsKeyTextSize] = [savedSettings objectForKey:HUDUserDefaultsKeyTextSize] ?: @(10.0f);
    _currentSettings[HUDUserDefaultsKeyTextAlignment] = [savedSettings objectForKey:HUDUserDefaultsKeyTextAlignment] ?: @(NSTextAlignmentCenter);
    _currentSettings[HUDUserDefaultsKeyTextAlpha] = [savedSettings objectForKey:HUDUserDefaultsKeyTextAlpha] ?: @(1.0f);
    _currentSettings[HUDUserDefaultsKeyBackgroundColor] = [self colorFromSettingsData:[savedSettings objectForKey:HUDUserDefaultsKeyBackgroundColor] fallback:[UIColor blackColor]];
    _currentSettings[HUDUserDefaultsKeyBackgroundAlpha] = [savedSettings objectForKey:HUDUserDefaultsKeyBackgroundAlpha] ?: @(0.0f);

    _textViewPreview.text = _currentSettings[HUDUserDefaultsKeyTextContent];
    _textColorWell.selectedColor = _currentSettings[HUDUserDefaultsKeyTextColor];
    _textSizeStepper.value = [_currentSettings[HUDUserDefaultsKeyTextSize] doubleValue];
    _textAlignmentSegmentedControl.selectedSegmentIndex = [_currentSettings[HUDUserDefaultsKeyTextAlignment] integerValue];
    _textAlphaSlider.value = [_currentSettings[HUDUserDefaultsKeyTextAlpha] floatValue];
    _backgroundColorWell.selectedColor = _currentSettings[HUDUserDefaultsKeyBackgroundColor];
    _backgroundAlphaSlider.value = [_currentSettings[HUDUserDefaultsKeyBackgroundAlpha] floatValue];
}

// 点保存时：合并进 plist 文件，并发送 NOTIFY_RELOAD_HUD 通知 HUD 进程刷新
- (void)saveSettings {
    NSMutableDictionary *settings = LoadHUDSettingsPlist();

    settings[HUDUserDefaultsKeyTextContent] = _textViewPreview.text;

    // UIColor 需序列化为 NSData 才能存入 plist
    NSData *textColorData = [NSKeyedArchiver archivedDataWithRootObject:[_currentSettings objectForKey:HUDUserDefaultsKeyTextColor] requiringSecureCoding:NO error:nil];
    if (textColorData) {
        settings[HUDUserDefaultsKeyTextColor] = textColorData;
    }

    settings[HUDUserDefaultsKeyTextSize] = [_currentSettings objectForKey:HUDUserDefaultsKeyTextSize];
    settings[HUDUserDefaultsKeyTextAlignment] = [_currentSettings objectForKey:HUDUserDefaultsKeyTextAlignment];
    settings[HUDUserDefaultsKeyTextAlpha] = [_currentSettings objectForKey:HUDUserDefaultsKeyTextAlpha];

    NSData *bgColorData = [NSKeyedArchiver archivedDataWithRootObject:[_currentSettings objectForKey:HUDUserDefaultsKeyBackgroundColor] requiringSecureCoding:NO error:nil];
    if (bgColorData) {
        settings[HUDUserDefaultsKeyBackgroundColor] = bgColorData;
    }

    settings[HUDUserDefaultsKeyBackgroundAlpha] = [_currentSettings objectForKey:HUDUserDefaultsKeyBackgroundAlpha];

    SaveHUDSettingsPlist(settings);
    notify_post(NOTIFY_RELOAD_HUD); // HUDRootViewController 监听此通知后调用 reloadUserDefaults
}

#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *)textView {
    [_currentSettings setObject:textView.text forKey:HUDUserDefaultsKeyTextContent];
    [self updatePreview];
}

@end
