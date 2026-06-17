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

static NSString *PasteboardPlainTextFromController(void) {
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    NSString *text = pasteboard.string;
    if (text.length > 0) {
        return text;
    }
    NSArray<NSString *> *types = @[
        @"public.utf8-plain-text",
        @"public.text",
        @"public.plain-text",
    ];
    for (NSString *type in types) {
        id value = [pasteboard valueForPasteboardType:type];
        if ([value isKindOfClass:[NSString class]]) {
            text = (NSString *)value;
        } else if ([value isKindOfClass:[NSData class]]) {
            text = [[NSString alloc] initWithData:(NSData *)value encoding:NSUTF8StringEncoding];
        } else {
            text = nil;
        }
        if (text.length > 0) {
            return text;
        }
    }
    return @"";
}

@interface PasteEnabledTextView : UITextView
@end

@implementation PasteEnabledTextView

- (instancetype)init {
    self = [super init];
    if (self) {
        self.editable = YES;
        self.selectable = YES;
        self.scrollEnabled = YES;
    }
    return self;
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(paste:)) {
        return self.isEditable && PasteboardPlainTextFromController().length > 0;
    }
    if (action == @selector(copy:) || action == @selector(cut:)) {
        return self.isEditable && self.selectedRange.length > 0;
    }
    if (action == @selector(selectAll:)) {
        return self.isEditable && self.text.length > 0;
    }
    return [super canPerformAction:action withSender:sender];
}

- (void)paste:(id)sender {
    NSString *string = PasteboardPlainTextFromController();
    if (string.length == 0) {
        return;
    }
    if (self.selectedRange.location == NSNotFound) {
        self.selectedRange = NSMakeRange(self.text.length, 0);
    }
    [self insertText:string];
}

@end

@interface EditTextSettingsViewController () <UITextViewDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIView *bottomBar;
@property (nonatomic, strong) UIButton *pasteButton;
@property (nonatomic, strong) UITextView *textViewPreview;
@property (nonatomic, strong) UIColorWell *textColorWell;
@property (nonatomic, strong) UIStepper *textSizeStepper;
@property (nonatomic, strong) UISegmentedControl *textAlignmentSegmentedControl;
@property (nonatomic, strong) UISegmentedControl *textVerticalSegmentedControl;
@property (nonatomic, strong) UISlider *textAlphaSlider;
@property (nonatomic, strong) UIColorWell *backgroundColorWell;
@property (nonatomic, strong) UISlider *backgroundAlphaSlider;
@property (nonatomic, strong) UISlider *portraitOffsetXSlider;
@property (nonatomic, strong) UISlider *portraitOffsetYSlider;
@property (nonatomic, strong) UISlider *landscapeOffsetXSlider;
@property (nonatomic, strong) UISlider *landscapeOffsetYSlider;
@property (nonatomic, strong) UILabel *behaviorSectionLabel;
@property (nonatomic, strong) UIView *behaviorSettingsContainer;
@property (nonatomic, strong) TSSettingsController *behaviorSettingsController;
@property (nonatomic, strong) UIButton *resetButton;
@property (nonatomic, strong) UIButton *saveButton;
@property (nonatomic, strong) UIButton *cancelButton;
@property (nonatomic, strong) NSMutableDictionary *currentSettings;
@property (nonatomic, strong) NSMutableDictionary *committedSettings;
@property (nonatomic, strong) NSMutableDictionary *draftBehaviorSettings;
@property (nonatomic, assign) BOOL didFinishEditing;

@end

static NSArray<NSString *> *EditBehaviorSettingKeys(void)
{
    static NSArray<NSString *> *keys;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keys = @[
            HUDUserDefaultsKeyHideAtSnapshot,
            HUDUserDefaultsKeyUsesRotation,
        ];
    });
    return keys;
}

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

- (void)pasteIntoEditor {
    NSString *pastedText = PasteboardPlainTextFromController();
    if (pastedText.length == 0) {
        return;
    }

    UITextView *textView = _textViewPreview;
    if (![textView isFirstResponder]) {
        [textView becomeFirstResponder];
    }
    if (textView.selectedRange.location == NSNotFound) {
        textView.selectedRange = NSMakeRange(textView.text.length, 0);
    }
    [textView insertText:pastedText];
}

- (void)loadView {
    self.view = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    _scrollView = [[UIScrollView alloc] init];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _scrollView.alwaysBounceVertical = YES;
    _scrollView.delaysContentTouches = NO;
    _scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [self.view addSubview:_scrollView];

    _contentView = [[UIView alloc] init];
    _contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [_scrollView addSubview:_contentView];

    NSMutableDictionary *savedSettings = LoadHUDSettingsPlist();

    _pasteButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _pasteButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_pasteButton setTitle:NSLocalizedString(@"Paste", nil) forState:UIControlStateNormal];
    [_pasteButton addTarget:self action:@selector(pasteIntoEditor) forControlEvents:UIControlEventTouchUpInside];
    [_contentView addSubview:_pasteButton];

    _textViewPreview = [[PasteEnabledTextView alloc] init];
    _textViewPreview.translatesAutoresizingMaskIntoConstraints = NO;
    _textViewPreview.font = [UIFont systemFontOfSize:17.0];
    _textViewPreview.textColor = [UIColor labelColor];
    _textViewPreview.backgroundColor = [UIColor secondarySystemBackgroundColor];
    _textViewPreview.layer.cornerRadius = 5.0;
    _textViewPreview.layer.borderColor = [UIColor systemGray2Color].CGColor;
    _textViewPreview.layer.borderWidth = 1.0;
    _textViewPreview.textAlignment = NSTextAlignmentNatural;
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

    UILabel *textVerticalLabel = [[UILabel alloc] init];
    textVerticalLabel.translatesAutoresizingMaskIntoConstraints = NO;
    textVerticalLabel.text = NSLocalizedString(@"Text Vertical", nil);
    [_contentView addSubview:textVerticalLabel];

    _textVerticalSegmentedControl = [[UISegmentedControl alloc] initWithItems:@[NSLocalizedString(@"Top", nil), NSLocalizedString(@"Middle", nil), NSLocalizedString(@"Bottom", nil)]];
    _textVerticalSegmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    _textVerticalSegmentedControl.selectedSegmentIndex = [[savedSettings objectForKey:HUDUserDefaultsKeyTextVerticalPosition] integerValue];
    if (_textVerticalSegmentedControl.selectedSegmentIndex < 0 || _textVerticalSegmentedControl.selectedSegmentIndex > 2) {
        _textVerticalSegmentedControl.selectedSegmentIndex = 0;
    }
    [_textVerticalSegmentedControl addTarget:self action:@selector(segmentedControlDidChange:) forControlEvents:UIControlEventValueChanged];
    [_contentView addSubview:_textVerticalSegmentedControl];

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

    UILabel *portraitOffsetXLabel = [[UILabel alloc] init];
    portraitOffsetXLabel.translatesAutoresizingMaskIntoConstraints = NO;
    portraitOffsetXLabel.text = NSLocalizedString(@"Portrait X Offset", nil);
    [_contentView addSubview:portraitOffsetXLabel];

    _portraitOffsetXSlider = [[UISlider alloc] init];
    _portraitOffsetXSlider.translatesAutoresizingMaskIntoConstraints = NO;
    _portraitOffsetXSlider.minimumValue = -1000.0;
    _portraitOffsetXSlider.maximumValue = 1000.0;
    _portraitOffsetXSlider.value = [[savedSettings objectForKey:HUDUserDefaultsKeyPortraitOffsetX] floatValue];
    [_portraitOffsetXSlider addTarget:self action:@selector(sliderDidChange:) forControlEvents:UIControlEventValueChanged];
    [_portraitOffsetXSlider addTarget:self action:@selector(sliderDidChange:) forControlEvents:UIControlEventTouchDragInside | UIControlEventTouchDragOutside];
    [_contentView addSubview:_portraitOffsetXSlider];

    UILabel *portraitOffsetYLabel = [[UILabel alloc] init];
    portraitOffsetYLabel.translatesAutoresizingMaskIntoConstraints = NO;
    portraitOffsetYLabel.text = NSLocalizedString(@"Portrait Y Offset", nil);
    [_contentView addSubview:portraitOffsetYLabel];

    _portraitOffsetYSlider = [[UISlider alloc] init];
    _portraitOffsetYSlider.translatesAutoresizingMaskIntoConstraints = NO;
    _portraitOffsetYSlider.minimumValue = -1000.0;
    _portraitOffsetYSlider.maximumValue = 1000.0;
    _portraitOffsetYSlider.value = [[savedSettings objectForKey:HUDUserDefaultsKeyPortraitOffsetY] floatValue];
    [_portraitOffsetYSlider addTarget:self action:@selector(sliderDidChange:) forControlEvents:UIControlEventValueChanged];
    [_portraitOffsetYSlider addTarget:self action:@selector(sliderDidChange:) forControlEvents:UIControlEventTouchDragInside | UIControlEventTouchDragOutside];
    [_contentView addSubview:_portraitOffsetYSlider];

    UILabel *landscapeOffsetXLabel = [[UILabel alloc] init];
    landscapeOffsetXLabel.translatesAutoresizingMaskIntoConstraints = NO;
    landscapeOffsetXLabel.text = NSLocalizedString(@"Landscape X Offset", nil);
    [_contentView addSubview:landscapeOffsetXLabel];

    _landscapeOffsetXSlider = [[UISlider alloc] init];
    _landscapeOffsetXSlider.translatesAutoresizingMaskIntoConstraints = NO;
    _landscapeOffsetXSlider.minimumValue = -1000.0;
    _landscapeOffsetXSlider.maximumValue = 1000.0;
    _landscapeOffsetXSlider.value = [[savedSettings objectForKey:HUDUserDefaultsKeyLandscapeOffsetX] floatValue];
    [_landscapeOffsetXSlider addTarget:self action:@selector(sliderDidChange:) forControlEvents:UIControlEventValueChanged];
    [_landscapeOffsetXSlider addTarget:self action:@selector(sliderDidChange:) forControlEvents:UIControlEventTouchDragInside | UIControlEventTouchDragOutside];
    [_contentView addSubview:_landscapeOffsetXSlider];

    UILabel *landscapeOffsetYLabel = [[UILabel alloc] init];
    landscapeOffsetYLabel.translatesAutoresizingMaskIntoConstraints = NO;
    landscapeOffsetYLabel.text = NSLocalizedString(@"Landscape Y Offset", nil);
    [_contentView addSubview:landscapeOffsetYLabel];

    _landscapeOffsetYSlider = [[UISlider alloc] init];
    _landscapeOffsetYSlider.translatesAutoresizingMaskIntoConstraints = NO;
    _landscapeOffsetYSlider.minimumValue = -1000.0;
    _landscapeOffsetYSlider.maximumValue = 1000.0;
    _landscapeOffsetYSlider.value = [[savedSettings objectForKey:HUDUserDefaultsKeyLandscapeOffsetY] floatValue];
    [_landscapeOffsetYSlider addTarget:self action:@selector(sliderDidChange:) forControlEvents:UIControlEventValueChanged];
    [_landscapeOffsetYSlider addTarget:self action:@selector(sliderDidChange:) forControlEvents:UIControlEventTouchDragInside | UIControlEventTouchDragOutside];
    [_contentView addSubview:_landscapeOffsetYSlider];

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
    _behaviorSettingsController.delegate = self;
    _behaviorSettingsController.alreadyLaunched = self.hudAlreadyLaunched;
    [self addChildViewController:_behaviorSettingsController];
    [_behaviorSettingsContainer addSubview:_behaviorSettingsController.view];
    _behaviorSettingsController.view.translatesAutoresizingMaskIntoConstraints = NO;
    [_behaviorSettingsController didMoveToParentViewController:self];

    _bottomBar = [[UIView alloc] init];
    _bottomBar.translatesAutoresizingMaskIntoConstraints = NO;
    _bottomBar.backgroundColor = [UIColor systemBackgroundColor];
    [self.view addSubview:_bottomBar];

    _saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _saveButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_saveButton setTitle:NSLocalizedString(@"保存", nil) forState:UIControlStateNormal];
    [_saveButton addTarget:self action:@selector(saveButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [_bottomBar addSubview:_saveButton];

    _resetButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _resetButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_resetButton setTitle:NSLocalizedString(@"Reset", nil) forState:UIControlStateNormal];
    [_resetButton addTarget:self action:@selector(resetButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [_bottomBar addSubview:_resetButton];

    _cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_cancelButton setTitle:NSLocalizedString(@"取消", nil) forState:UIControlStateNormal];
    [_cancelButton addTarget:self action:@selector(cancelButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [_bottomBar addSubview:_cancelButton];

    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [_bottomBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_bottomBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_bottomBar.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor],
        [_bottomBar.heightAnchor constraintEqualToConstant:56],

        [_saveButton.centerYAnchor constraintEqualToAnchor:_bottomBar.centerYAnchor],
        [_saveButton.centerXAnchor constraintEqualToAnchor:_bottomBar.centerXAnchor],
        [_resetButton.centerYAnchor constraintEqualToAnchor:_bottomBar.centerYAnchor],
        [_resetButton.trailingAnchor constraintEqualToAnchor:_saveButton.leadingAnchor constant:-32],
        [_cancelButton.centerYAnchor constraintEqualToAnchor:_bottomBar.centerYAnchor],
        [_cancelButton.leadingAnchor constraintEqualToAnchor:_saveButton.trailingAnchor constant:32],

        [_scrollView.topAnchor constraintEqualToAnchor:safeArea.topAnchor],
        [_scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_scrollView.bottomAnchor constraintEqualToAnchor:_bottomBar.topAnchor],

        [_contentView.topAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.topAnchor],
        [_contentView.leadingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.leadingAnchor],
        [_contentView.trailingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.trailingAnchor],
        [_contentView.bottomAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.bottomAnchor],
        [_contentView.widthAnchor constraintEqualToAnchor:_scrollView.frameLayoutGuide.widthAnchor],

        [_pasteButton.topAnchor constraintEqualToAnchor:_contentView.topAnchor constant:12],
        [_pasteButton.trailingAnchor constraintEqualToAnchor:_contentView.trailingAnchor constant:-20],

        [_textViewPreview.topAnchor constraintEqualToAnchor:_pasteButton.bottomAnchor constant:8],
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

        [textVerticalLabel.topAnchor constraintEqualToAnchor:_textAlphaSlider.bottomAnchor constant:20],
        [textVerticalLabel.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:20],
        [_textVerticalSegmentedControl.centerYAnchor constraintEqualToAnchor:textVerticalLabel.centerYAnchor],
        [_textVerticalSegmentedControl.trailingAnchor constraintEqualToAnchor:_contentView.trailingAnchor constant:-20],
        [_textVerticalSegmentedControl.leadingAnchor constraintGreaterThanOrEqualToAnchor:textVerticalLabel.trailingAnchor constant:10],

        [backgroundColorLabel.topAnchor constraintEqualToAnchor:textVerticalLabel.bottomAnchor constant:20],
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

        [portraitOffsetXLabel.topAnchor constraintEqualToAnchor:_backgroundAlphaSlider.bottomAnchor constant:20],
        [portraitOffsetXLabel.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:20],
        [_portraitOffsetXSlider.topAnchor constraintEqualToAnchor:portraitOffsetXLabel.bottomAnchor constant:8],
        [_portraitOffsetXSlider.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:20],
        [_portraitOffsetXSlider.trailingAnchor constraintEqualToAnchor:_contentView.trailingAnchor constant:-20],

        [portraitOffsetYLabel.topAnchor constraintEqualToAnchor:_portraitOffsetXSlider.bottomAnchor constant:16],
        [portraitOffsetYLabel.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:20],
        [_portraitOffsetYSlider.topAnchor constraintEqualToAnchor:portraitOffsetYLabel.bottomAnchor constant:8],
        [_portraitOffsetYSlider.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:20],
        [_portraitOffsetYSlider.trailingAnchor constraintEqualToAnchor:_contentView.trailingAnchor constant:-20],

        [landscapeOffsetXLabel.topAnchor constraintEqualToAnchor:_portraitOffsetYSlider.bottomAnchor constant:16],
        [landscapeOffsetXLabel.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:20],
        [_landscapeOffsetXSlider.topAnchor constraintEqualToAnchor:landscapeOffsetXLabel.bottomAnchor constant:8],
        [_landscapeOffsetXSlider.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:20],
        [_landscapeOffsetXSlider.trailingAnchor constraintEqualToAnchor:_contentView.trailingAnchor constant:-20],

        [landscapeOffsetYLabel.topAnchor constraintEqualToAnchor:_landscapeOffsetXSlider.bottomAnchor constant:16],
        [landscapeOffsetYLabel.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:20],
        [_landscapeOffsetYSlider.topAnchor constraintEqualToAnchor:landscapeOffsetYLabel.bottomAnchor constant:8],
        [_landscapeOffsetYSlider.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:20],
        [_landscapeOffsetYSlider.trailingAnchor constraintEqualToAnchor:_contentView.trailingAnchor constant:-20],

        [_behaviorSectionLabel.topAnchor constraintEqualToAnchor:_landscapeOffsetYSlider.bottomAnchor constant:28],
        [_behaviorSectionLabel.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:20],

        [_behaviorSettingsContainer.topAnchor constraintEqualToAnchor:_behaviorSectionLabel.bottomAnchor constant:12],
        [_behaviorSettingsContainer.leadingAnchor constraintEqualToAnchor:_contentView.leadingAnchor constant:12],
        [_behaviorSettingsContainer.trailingAnchor constraintEqualToAnchor:_contentView.trailingAnchor constant:-12],
        [_behaviorSettingsContainer.heightAnchor constraintEqualToConstant:88],

        [_behaviorSettingsController.view.topAnchor constraintEqualToAnchor:_behaviorSettingsContainer.topAnchor],
        [_behaviorSettingsController.view.leadingAnchor constraintEqualToAnchor:_behaviorSettingsContainer.leadingAnchor],
        [_behaviorSettingsController.view.trailingAnchor constraintEqualToAnchor:_behaviorSettingsContainer.trailingAnchor],
        [_behaviorSettingsController.view.bottomAnchor constraintEqualToAnchor:_behaviorSettingsContainer.bottomAnchor],

        [_behaviorSettingsContainer.bottomAnchor constraintEqualToAnchor:_contentView.bottomAnchor constant:-24],
    ]];

    _committedSettings = LoadHUDSettingsPlist() ?: [NSMutableDictionary dictionary];
    _draftBehaviorSettings = [NSMutableDictionary dictionary];
    for (HUDUserDefaultsKey key in EditBehaviorSettingKeys()) {
        id value = _committedSettings[key];
        _draftBehaviorSettings[key] = value ?: @NO;
    }

    _currentSettings = [NSMutableDictionary dictionary];
    [self loadCurrentSettings];
    [self configurePlainTextEditor];
    [self pushPreviewToHUD];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [_behaviorSettingsController.view setNeedsLayout];
    [_behaviorSettingsController.view layoutIfNeeded];
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    if (!self.didFinishEditing && self.isBeingDismissed) {
        [self restoreCommittedSettingsToHUD];
    }
}

#pragma mark - 控件事件（调节时实时预览 HUD，保存后才固定）

- (void)colorWellDidChange:(UIColorWell *)sender {
    if (sender == _textColorWell) {
        [_currentSettings setObject:sender.selectedColor forKey:HUDUserDefaultsKeyTextColor];
    } else if (sender == _backgroundColorWell) {
        [_currentSettings setObject:sender.selectedColor forKey:HUDUserDefaultsKeyBackgroundColor];
    }
    [self pushPreviewToHUD];
}

- (void)stepperDidChange:(UIStepper *)sender {
    if (sender == _textSizeStepper) {
        [_currentSettings setObject:@(sender.value) forKey:HUDUserDefaultsKeyTextSize];
    }
    [self pushPreviewToHUD];
}

- (void)segmentedControlDidChange:(UISegmentedControl *)sender {
    if (sender == _textAlignmentSegmentedControl) {
        NSTextAlignment alignment;
        switch (sender.selectedSegmentIndex) {
            case 0: alignment = NSTextAlignmentLeft; break;
            case 1: alignment = NSTextAlignmentCenter; break;
            case 2: alignment = NSTextAlignmentRight; break;
            default: alignment = NSTextAlignmentCenter; break;
        }
        [_currentSettings setObject:@(alignment) forKey:HUDUserDefaultsKeyTextAlignment];
    } else if (sender == _textVerticalSegmentedControl) {
        [_currentSettings setObject:@(sender.selectedSegmentIndex) forKey:HUDUserDefaultsKeyTextVerticalPosition];
    }
    [self pushPreviewToHUD];
}

- (void)sliderDidChange:(UISlider *)sender {
    if (sender == _textAlphaSlider) {
        [_currentSettings setObject:@(sender.value) forKey:HUDUserDefaultsKeyTextAlpha];
    } else if (sender == _backgroundAlphaSlider) {
        [_currentSettings setObject:@(sender.value) forKey:HUDUserDefaultsKeyBackgroundAlpha];
    } else if (sender == _portraitOffsetXSlider) {
        [_currentSettings setObject:@(sender.value) forKey:HUDUserDefaultsKeyPortraitOffsetX];
    } else if (sender == _portraitOffsetYSlider) {
        [_currentSettings setObject:@(sender.value) forKey:HUDUserDefaultsKeyPortraitOffsetY];
    } else if (sender == _landscapeOffsetXSlider) {
        [_currentSettings setObject:@(sender.value) forKey:HUDUserDefaultsKeyLandscapeOffsetX];
    } else if (sender == _landscapeOffsetYSlider) {
        [_currentSettings setObject:@(sender.value) forKey:HUDUserDefaultsKeyLandscapeOffsetY];
    }
    [self pushPreviewToHUD];
}

- (void)saveButtonTapped:(UIButton *)sender {
    [self saveSettings];
    self.didFinishEditing = YES;
    if ([self.delegate respondsToSelector:@selector(editTextSettingsDidSave)]) {
        [self.delegate editTextSettingsDidSave];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)cancelButtonTapped:(UIButton *)sender {
    [self restoreCommittedSettingsToHUD];
    self.didFinishEditing = YES;
    if ([self.delegate respondsToSelector:@selector(editTextSettingsDidCancel)]) {
        [self.delegate editTextSettingsDidCancel];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)resetButtonTapped:(UIButton *)sender {
    NSString *textContent = _textViewPreview.text ?: @"";

    [_currentSettings setObject:[UIColor redColor] forKey:HUDUserDefaultsKeyTextColor];
    [_currentSettings setObject:@(NSTextAlignmentCenter) forKey:HUDUserDefaultsKeyTextAlignment];
    [_currentSettings setObject:@(1) forKey:HUDUserDefaultsKeyTextVerticalPosition];
    [_currentSettings setObject:@(0.0f) forKey:HUDUserDefaultsKeyPortraitOffsetX];
    [_currentSettings setObject:@(0.0f) forKey:HUDUserDefaultsKeyPortraitOffsetY];
    [_currentSettings setObject:@(0.0f) forKey:HUDUserDefaultsKeyLandscapeOffsetX];
    [_currentSettings setObject:@(0.0f) forKey:HUDUserDefaultsKeyLandscapeOffsetY];
    [_currentSettings setObject:@(1.0f) forKey:HUDUserDefaultsKeyTextAlpha];
    [_currentSettings setObject:@(0.0f) forKey:HUDUserDefaultsKeyBackgroundAlpha];
    [_currentSettings setObject:textContent forKey:HUDUserDefaultsKeyTextContent];

    [self syncControlsFromCurrentSettings];
    [self configurePlainTextEditor];
    [self pushPreviewToHUD];
}

#pragma mark - 文本编辑框（仅编辑文字，样式只同步到浮窗）

- (void)configurePlainTextEditor {
    _textViewPreview.font = [UIFont systemFontOfSize:17.0];
    _textViewPreview.textColor = [UIColor labelColor];
    _textViewPreview.backgroundColor = [UIColor secondarySystemBackgroundColor];
    _textViewPreview.alpha = 1.0;
    _textViewPreview.textAlignment = NSTextAlignmentNatural;
}

- (void)mergeDraftSettingsIntoPlist:(NSMutableDictionary *)settings
{
    settings[HUDUserDefaultsKeyPassthroughMode] = @YES;
    settings[HUDUserDefaultsKeyKeepInPlace] = @NO;
    settings[HUDUserDefaultsKeyTextContent] = _textViewPreview.text;
    settings[HUDUserDefaultsKeyTextSize] = [_currentSettings objectForKey:HUDUserDefaultsKeyTextSize];
    settings[HUDUserDefaultsKeyTextAlignment] = [_currentSettings objectForKey:HUDUserDefaultsKeyTextAlignment];
    settings[HUDUserDefaultsKeyTextAlpha] = [_currentSettings objectForKey:HUDUserDefaultsKeyTextAlpha];
    settings[HUDUserDefaultsKeyBackgroundAlpha] = [_currentSettings objectForKey:HUDUserDefaultsKeyBackgroundAlpha];
    settings[HUDUserDefaultsKeyTextVerticalPosition] = [_currentSettings objectForKey:HUDUserDefaultsKeyTextVerticalPosition];
    settings[HUDUserDefaultsKeyPortraitOffsetX] = [_currentSettings objectForKey:HUDUserDefaultsKeyPortraitOffsetX];
    settings[HUDUserDefaultsKeyPortraitOffsetY] = [_currentSettings objectForKey:HUDUserDefaultsKeyPortraitOffsetY];
    settings[HUDUserDefaultsKeyLandscapeOffsetX] = [_currentSettings objectForKey:HUDUserDefaultsKeyLandscapeOffsetX];
    settings[HUDUserDefaultsKeyLandscapeOffsetY] = [_currentSettings objectForKey:HUDUserDefaultsKeyLandscapeOffsetY];

    NSData *textColorData = [NSKeyedArchiver archivedDataWithRootObject:[_currentSettings objectForKey:HUDUserDefaultsKeyTextColor] requiringSecureCoding:NO error:nil];
    if (textColorData) {
        settings[HUDUserDefaultsKeyTextColor] = textColorData;
    }

    NSData *bgColorData = [NSKeyedArchiver archivedDataWithRootObject:[_currentSettings objectForKey:HUDUserDefaultsKeyBackgroundColor] requiringSecureCoding:NO error:nil];
    if (bgColorData) {
        settings[HUDUserDefaultsKeyBackgroundColor] = bgColorData;
    }

    for (NSString *key in EditBehaviorSettingKeys()) {
        settings[key] = _draftBehaviorSettings[key] ?: @NO;
    }
}

- (void)pushPreviewToHUD
{
    NSMutableDictionary *previewSettings = [_committedSettings mutableCopy];
    [self mergeDraftSettingsIntoPlist:previewSettings];
    SaveHUDSettingsPlist(previewSettings);
    notify_post(NOTIFY_RELOAD_HUD_INSTANT);
}

- (void)restoreCommittedSettingsToHUD
{
    SaveHUDSettingsPlist(_committedSettings);
    notify_post(NOTIFY_RELOAD_HUD_INSTANT);
}

#pragma mark - 读写共享 plist

// 打开页面时：从 plist 加载到 currentSettings，并同步到各控件
- (void)loadCurrentSettings {
    NSMutableDictionary *savedSettings = [_committedSettings mutableCopy] ?: [LoadHUDSettingsPlist() mutableCopy];

    _currentSettings[HUDUserDefaultsKeyTextContent] = [savedSettings objectForKey:HUDUserDefaultsKeyTextContent] ?: NSLocalizedString(@"Hello World!", nil);
    _currentSettings[HUDUserDefaultsKeyTextColor] = [self colorFromSettingsData:[savedSettings objectForKey:HUDUserDefaultsKeyTextColor] fallback:[UIColor redColor]];
    _currentSettings[HUDUserDefaultsKeyTextSize] = [savedSettings objectForKey:HUDUserDefaultsKeyTextSize] ?: @(10.0f);
    _currentSettings[HUDUserDefaultsKeyTextAlignment] = [savedSettings objectForKey:HUDUserDefaultsKeyTextAlignment] ?: @(NSTextAlignmentCenter);
    _currentSettings[HUDUserDefaultsKeyTextAlpha] = [savedSettings objectForKey:HUDUserDefaultsKeyTextAlpha] ?: @(1.0f);
    _currentSettings[HUDUserDefaultsKeyBackgroundColor] = [self colorFromSettingsData:[savedSettings objectForKey:HUDUserDefaultsKeyBackgroundColor] fallback:[UIColor blackColor]];
    _currentSettings[HUDUserDefaultsKeyBackgroundAlpha] = [savedSettings objectForKey:HUDUserDefaultsKeyBackgroundAlpha] ?: @(0.0f);
    _currentSettings[HUDUserDefaultsKeyTextVerticalPosition] = [savedSettings objectForKey:HUDUserDefaultsKeyTextVerticalPosition] ?: @(0);
    _currentSettings[HUDUserDefaultsKeyPortraitOffsetX] = [savedSettings objectForKey:HUDUserDefaultsKeyPortraitOffsetX] ?: @(0.0f);
    _currentSettings[HUDUserDefaultsKeyPortraitOffsetY] = [savedSettings objectForKey:HUDUserDefaultsKeyPortraitOffsetY] ?: @(0.0f);
    _currentSettings[HUDUserDefaultsKeyLandscapeOffsetX] = [savedSettings objectForKey:HUDUserDefaultsKeyLandscapeOffsetX] ?: @(0.0f);
    _currentSettings[HUDUserDefaultsKeyLandscapeOffsetY] = [savedSettings objectForKey:HUDUserDefaultsKeyLandscapeOffsetY] ?: @(0.0f);

    [self syncControlsFromCurrentSettings];
}

- (void)syncControlsFromCurrentSettings {
    _textViewPreview.text = _currentSettings[HUDUserDefaultsKeyTextContent];
    _textColorWell.selectedColor = _currentSettings[HUDUserDefaultsKeyTextColor];
    _textSizeStepper.value = [_currentSettings[HUDUserDefaultsKeyTextSize] doubleValue];
    _textAlignmentSegmentedControl.selectedSegmentIndex = [_currentSettings[HUDUserDefaultsKeyTextAlignment] integerValue];
    _textVerticalSegmentedControl.selectedSegmentIndex = [_currentSettings[HUDUserDefaultsKeyTextVerticalPosition] integerValue];
    _textAlphaSlider.value = [_currentSettings[HUDUserDefaultsKeyTextAlpha] floatValue];
    _backgroundColorWell.selectedColor = _currentSettings[HUDUserDefaultsKeyBackgroundColor];
    _backgroundAlphaSlider.value = [_currentSettings[HUDUserDefaultsKeyBackgroundAlpha] floatValue];
    _portraitOffsetXSlider.value = [_currentSettings[HUDUserDefaultsKeyPortraitOffsetX] floatValue];
    _portraitOffsetYSlider.value = [_currentSettings[HUDUserDefaultsKeyPortraitOffsetY] floatValue];
    _landscapeOffsetXSlider.value = [_currentSettings[HUDUserDefaultsKeyLandscapeOffsetX] floatValue];
    _landscapeOffsetYSlider.value = [_currentSettings[HUDUserDefaultsKeyLandscapeOffsetY] floatValue];
}

// 点保存时：合并草稿写入 plist，并即时刷新 HUD
- (void)saveSettings {
    NSMutableDictionary *settings = [_committedSettings mutableCopy];
    [self mergeDraftSettingsIntoPlist:settings];
    SaveHUDSettingsPlist(settings);
    _committedSettings = settings;
    notify_post(NOTIFY_RELOAD_HUD_INSTANT);
}

#pragma mark - UITextViewDelegate

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    return YES;
}

- (void)textViewDidChange:(UITextView *)textView {
    [_currentSettings setObject:textView.text forKey:HUDUserDefaultsKeyTextContent];
    [self pushPreviewToHUD];
}

#pragma mark - TSSettingsControllerDelegate

- (BOOL)settingHighlightedWithKey:(NSString *)key
{
    NSNumber *mode = _draftBehaviorSettings[key];
    return mode != nil ? [mode boolValue] : NO;
}

- (void)settingDidSelectWithKey:(NSString *)key
{
    BOOL highlighted = [self settingHighlightedWithKey:key];
    _draftBehaviorSettings[key] = @(!highlighted);
    [self pushPreviewToHUD];
}

@end
