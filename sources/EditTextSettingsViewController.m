#import "EditTextSettingsViewController.h"
#import "RootViewController.h" // 导入RootViewController.h 以便访问 HUDUserDefaultsKeyTextContent 等键

@interface EditTextSettingsViewController () <UITextViewDelegate>

@property (nonatomic, strong) UITextView *textViewPreview; // 文本预览视图
@property (nonatomic, strong) UIColorWell *textColorWell; // 文字颜色选择器
@property (nonatomic, strong) UIStepper *textSizeStepper; // 文字大小选择器
@property (nonatomic, strong) UISegmentedControl *textAlignmentSegmentedControl; // 文字对齐选择器
@property (nonatomic, strong) UISlider *textAlphaSlider; // 文字透明度调节器
@property (nonatomic, strong) UIColorWell *backgroundColorWell; // 背景颜色选择器
@property (nonatomic, strong) UISlider *backgroundAlphaSlider; // 背景透明度调节器

@property (nonatomic, strong) UIButton *saveButton; // 保存按钮
@property (nonatomic, strong) UIButton *cancelButton; // 取消按钮

// 用于存储当前设置的临时值，以便在取消时可以恢复或不保存
@property (nonatomic, strong) NSMutableDictionary *currentSettings; 

@end

@implementation EditTextSettingsViewController

- (void)loadView {
    self.view = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    // 文本预览视图 (UITextView)
    _textViewPreview = [[UITextView alloc] init];
    _textViewPreview.translatesAutoresizingMaskIntoConstraints = NO;
    _textViewPreview.font = [UIFont systemFontOfSize:17.0];
    _textViewPreview.textColor = [UIColor blackColor];
    _textViewPreview.backgroundColor = [UIColor systemGray5Color]; // 默认背景，方便看清文字
    _textViewPreview.layer.cornerRadius = 5.0;
    _textViewPreview.layer.borderColor = [UIColor systemGray2Color].CGColor;
    _textViewPreview.layer.borderWidth = 1.0;
    _textViewPreview.textAlignment = NSTextAlignmentCenter;
    _textViewPreview.delegate = self;
    _textViewPreview.text = [[NSUserDefaults standardUserDefaults] stringForKey:HUDUserDefaultsKeyTextContent] ?: NSLocalizedString(@"Hello World!", nil);
    [self.view addSubview:_textViewPreview];

    // 文字颜色：UIColorWell
    UILabel *textColorLabel = [[UILabel alloc] init];
    textColorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    textColorLabel.text = NSLocalizedString(@"文字颜色", nil);
    [self.view addSubview:textColorLabel];

    _textColorWell = [[UIColorWell alloc] init];
    _textColorWell.translatesAutoresizingMaskIntoConstraints = NO;
    _textColorWell.selectedColor = [[NSUserDefaults standardUserDefaults] colorForKey:HUDUserDefaultsKeyTextColor] ?: [UIColor redColor]; // 默认红色
    [_textColorWell addTarget:self action:@selector(colorWellDidChange:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_textColorWell];

    // 文字大小：UIStepper
    UILabel *textSizeLabel = [[UILabel alloc] init];
    textSizeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    textSizeLabel.text = NSLocalizedString(@"文字大小", nil);
    [self.view addSubview:textSizeLabel];

    _textSizeStepper = [[UIStepper alloc] init];
    _textSizeStepper.translatesAutoresizingMaskIntoConstraints = NO;
    _textSizeStepper.minimumValue = 5;
    _textSizeStepper.maximumValue = 50;
    _textSizeStepper.value = [[NSUserDefaults standardUserDefaults] floatForKey:HUDUserDefaultsKeyTextSize] ?: 10.0; // 默认10
    _textSizeStepper.stepValue = 1;
    [_textSizeStepper addTarget:self action:@selector(stepperDidChange:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_textSizeStepper];

    // 文字对齐：UISegmentedControl
    UILabel *textAlignmentLabel = [[UILabel alloc] init];
    textAlignmentLabel.translatesAutoresizingMaskIntoConstraints = NO;
    textAlignmentLabel.text = NSLocalizedString(@"文字对齐", nil);
    [self.view addSubview:textAlignmentLabel];

    _textAlignmentSegmentedControl = [[UISegmentedControl alloc] initWithItems:@[NSLocalizedString(@"左", nil), NSLocalizedString(@"中", nil), NSLocalizedString(@"右", nil)]];
    _textAlignmentSegmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
    _textAlignmentSegmentedControl.selectedSegmentIndex = [[NSUserDefaults standardUserDefaults] integerForKey:HUDUserDefaultsKeyTextAlignment] ?: NSTextAlignmentCenter; // 默认中间
    [_textAlignmentSegmentedControl addTarget:self action:@selector(segmentedControlDidChange:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_textAlignmentSegmentedControl];

    // 文字透明度：UISlider
    UILabel *textAlphaLabel = [[UILabel alloc] init];
    textAlphaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    textAlphaLabel.text = NSLocalizedString(@"文字透明度", nil);
    [self.view addSubview:textAlphaLabel];

    _textAlphaSlider = [[UISlider alloc] init];
    _textAlphaSlider.translatesAutoresizingMaskIntoConstraints = NO;
    _textAlphaSlider.minimumValue = 0.0;
    _textAlphaSlider.maximumValue = 1.0;
    _textAlphaSlider.value = [[NSUserDefaults standardUserDefaults] floatForKey:HUDUserDefaultsKeyTextAlpha] ?: 1.0; // 默认1.0 - 完全不透明
    [_textAlphaSlider addTarget:self action:@selector(sliderDidChange:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_textAlphaSlider];

    // 背景颜色：UIColorWell
    UILabel *backgroundColorLabel = [[UILabel alloc] init];
    backgroundColorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    backgroundColorLabel.text = NSLocalizedString(@"背景颜色", nil);
    [self.view addSubview:backgroundColorLabel];

    _backgroundColorWell = [[UIColorWell alloc] init];
    _backgroundColorWell.translatesAutoresizingMaskIntoConstraints = NO;
    _backgroundColorWell.selectedColor = [[NSUserDefaults standardUserDefaults] colorForKey:HUDUserDefaultsKeyBackgroundColor] ?: [UIColor blackColor]; // 默认黑色
    [_backgroundColorWell addTarget:self action:@selector(colorWellDidChange:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_backgroundColorWell];

    // 背景透明度：UISlider
    UILabel *backgroundAlphaLabel = [[UILabel alloc] init];
    backgroundAlphaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    backgroundAlphaLabel.text = NSLocalizedString(@"背景透明度", nil);
    [self.view addSubview:backgroundAlphaLabel];

    _backgroundAlphaSlider = [[UISlider alloc] init];
    _backgroundAlphaSlider.translatesAutoresizingMaskIntoConstraints = NO;
    _backgroundAlphaSlider.minimumValue = 0.0;
    _backgroundAlphaSlider.maximumValue = 1.0;
    _backgroundAlphaSlider.value = [[NSUserDefaults standardUserDefaults] floatForKey:HUDUserDefaultsKeyBackgroundAlpha] ?: 1.0; // 默认1.0 - 完全透明
    [_backgroundAlphaSlider addTarget:self action:@selector(sliderDidChange:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_backgroundAlphaSlider];

    // 保存和取消按钮
    _saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _saveButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_saveButton setTitle:NSLocalizedString(@"保存", nil) forState:UIControlStateNormal];
    [_saveButton addTarget:self action:@selector(saveButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_saveButton];

    _cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_cancelButton setTitle:NSLocalizedString(@"取消", nil) forState:UIControlStateNormal];
    [_cancelButton addTarget:self action:@selector(cancelButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_cancelButton];

    // 设置布局约束
    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        // textViewPreview 约束
        [_textViewPreview.topAnchor constraintEqualToAnchor:safeArea.topAnchor constant:20],
        [_textViewPreview.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor constant:20],
        [_textViewPreview.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-20],
        [_textViewPreview.heightAnchor constraintGreaterThanOrEqualToConstant:100], // 至少3行文字高度

        // textColorLabel 约束
        [textColorLabel.topAnchor constraintEqualToAnchor:_textViewPreview.bottomAnchor constant:20],
        [textColorLabel.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor constant:20],

        // textColorWell 约束
        [_textColorWell.centerYAnchor constraintEqualToAnchor:textColorLabel.centerYAnchor],
        [_textColorWell.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-20],
        [_textColorWell.widthAnchor constraintEqualToConstant:44],
        [_textColorWell.heightAnchor constraintEqualToConstant:44],

        // textSizeLabel 约束
        [textSizeLabel.topAnchor constraintEqualToAnchor:textColorLabel.bottomAnchor constant:20],
        [textSizeLabel.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor constant:20],

        // textSizeStepper 约束
        [_textSizeStepper.centerYAnchor constraintEqualToAnchor:textSizeLabel.centerYAnchor],
        [_textSizeStepper.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-20],

        // textAlignmentLabel 约束
        [textAlignmentLabel.topAnchor constraintEqualToAnchor:textSizeLabel.bottomAnchor constant:20],
        [textAlignmentLabel.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor constant:20],

        // textAlignmentSegmentedControl 约束
        [_textAlignmentSegmentedControl.centerYAnchor constraintEqualToAnchor:textAlignmentLabel.centerYAnchor],
        [_textAlignmentSegmentedControl.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-20],
        [_textAlignmentSegmentedControl.leadingAnchor constraintGreaterThanOrEqualToAnchor:textAlignmentLabel.trailingAnchor constant:10],

        // textAlphaLabel 约束
        [textAlphaLabel.topAnchor constraintEqualToAnchor:textAlignmentLabel.bottomAnchor constant:20],
        [textAlphaLabel.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor constant:20],

        // textAlphaSlider 约束
        [_textAlphaSlider.centerYAnchor constraintEqualToAnchor:textAlphaLabel.centerYAnchor],
        [_textAlphaSlider.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-20],
        [_textAlphaSlider.leadingAnchor constraintGreaterThanOrEqualToAnchor:textAlphaLabel.trailingAnchor constant:10],

        // backgroundColorLabel 约束
        [backgroundColorLabel.topAnchor constraintEqualToAnchor:textAlphaLabel.bottomAnchor constant:20],
        [backgroundColorLabel.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor constant:20],

        // backgroundColorWell 约束
        [_backgroundColorWell.centerYAnchor constraintEqualToAnchor:backgroundColorLabel.centerYAnchor],
        [_backgroundColorWell.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-20],
        [_backgroundColorWell.widthAnchor constraintEqualToConstant:44],
        [_backgroundColorWell.heightAnchor constraintEqualToConstant:44],

        // backgroundAlphaLabel 约束
        [backgroundAlphaLabel.topAnchor constraintEqualToAnchor:backgroundColorLabel.bottomAnchor constant:20],
        [backgroundAlphaLabel.leadingAnchor constraintEqualToAnchor:safeArea.leadingAnchor constant:20],

        // backgroundAlphaSlider 约束
        [_backgroundAlphaSlider.centerYAnchor constraintEqualToAnchor:backgroundAlphaLabel.centerYAnchor],
        [_backgroundAlphaSlider.trailingAnchor constraintEqualToAnchor:safeArea.trailingAnchor constant:-20],
        [_backgroundAlphaSlider.leadingAnchor constraintGreaterThanOrEqualToAnchor:backgroundAlphaLabel.trailingAnchor constant:10],

        // 保存和取消按钮约束
        [_saveButton.centerXAnchor constraintEqualToAnchor:safeArea.centerXAnchor constant:-60],
        [_saveButton.topAnchor constraintEqualToAnchor:backgroundAlphaLabel.bottomAnchor constant:40],
        [_cancelButton.centerXAnchor constraintEqualToAnchor:safeArea.centerXAnchor constant:60],
        [_cancelButton.centerYAnchor constraintEqualToAnchor:_saveButton.centerYAnchor],
    ]];

    // 初始化 currentSettings
    _currentSettings = [NSMutableDictionary dictionary];
    [self loadCurrentSettings];
    [self updatePreview];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

#pragma mark - Actions

- (void)colorWellDidChange:(UIColorWell *)sender {
    // 更新文字颜色
    if (sender == _textColorWell) {
        [_currentSettings setObject:sender.selectedColor forKey:HUDUserDefaultsKeyTextColor];
    } else if (sender == _backgroundColorWell) {
        [_currentSettings setObject:sender.selectedColor forKey:HUDUserDefaultsKeyBackgroundColor];
    }
    [self updatePreview];
}

- (void)stepperDidChange:(UIStepper *)sender {
    // 更新文字大小
    if (sender == _textSizeStepper) {
        [_currentSettings setObject:@(sender.value) forKey:HUDUserDefaultsKeyTextSize];
    }
    [self updatePreview];
}

- (void)segmentedControlDidChange:(UISegmentedControl *)sender {
    // 更新文字对齐
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
    // 更新透明度
    if (sender == _textAlphaSlider) {
        [_currentSettings setObject:@(sender.value) forKey:HUDUserDefaultsKeyTextAlpha];
    } else if (sender == _backgroundAlphaSlider) {
        [_currentSettings setObject:@(sender.value) forKey:HUDUserDefaultsKeyBackgroundAlpha];
    }
    [self updatePreview];
}

- (void)saveButtonTapped:(UIButton *)sender {
    [self saveSettings];
    if ([self.delegate respondsToSelector:@selector(editTextSettingsDidSave)]) {
        [self.delegate editTextSettingsDidSave];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)cancelButtonTapped:(UIButton *)sender {
    if ([self.delegate respondsToSelector:@selector(editTextSettingsDidCancel)]) {
        [self.delegate editTextSettingsDidCancel];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Preview Update

- (void)updatePreview {
    // 更新文字颜色
    UIColor *textColor = [_currentSettings objectForKey:HUDUserDefaultsKeyTextColor];
    if (textColor) {
        _textViewPreview.textColor = textColor;
    }
    
    // 更新文字大小
    NSNumber *textSize = [_currentSettings objectForKey:HUDUserDefaultsKeyTextSize];
    if (textSize) {
        _textViewPreview.font = [_textViewPreview.font fontWithSize:[textSize floatValue]];
    }

    // 更新文字对齐
    NSNumber *textAlignment = [_currentSettings objectForKey:HUDUserDefaultsKeyTextAlignment];
    if (textAlignment) {
        _textViewPreview.textAlignment = (NSTextAlignment)[textAlignment integerValue];
    }

    // 更新文字透明度
    NSNumber *textAlpha = [_currentSettings objectForKey:HUDUserDefaultsKeyTextAlpha];
    if (textAlpha) {
        _textViewPreview.alpha = [textAlpha floatValue];
    } else {
        _textViewPreview.alpha = 1.0; // 默认完全不透明
    }

    // 更新背景颜色和透明度
    UIColor *bgColor = [_currentSettings objectForKey:HUDUserDefaultsKeyBackgroundColor];
    NSNumber *bgAlpha = [_currentSettings objectForKey:HUDUserDefaultsKeyBackgroundAlpha];
    if (bgColor && bgAlpha) {
        _textViewPreview.backgroundColor = [bgColor colorWithAlphaComponent:[bgAlpha floatValue]];
    } else if (bgColor) {
        _textViewPreview.backgroundColor = bgColor; // 如果只设置了颜色，默认完全不透明
    } else if (bgAlpha) {
        // 如果只设置了透明度，但没有背景颜色，则使用默认的黑色背景
        _textViewPreview.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:[bgAlpha floatValue]];
    } else {
        // 如果都没有设置，则使用默认的黑色背景且完全不透明
        _textViewPreview.backgroundColor = [UIColor blackColor];
    }
}

#pragma mark - User Defaults Loading and Saving

- (void)loadCurrentSettings {
    // 加载文本内容
    _currentSettings[HUDUserDefaultsKeyTextContent] = [[NSUserDefaults standardUserDefaults] stringForKey:HUDUserDefaultsKeyTextContent] ?: NSLocalizedString(@"Hello World!", nil);

    // 加载文字颜色
    NSData *textColorData = [[NSUserDefaults standardUserDefaults] dataForKey:HUDUserDefaultsKeyTextColor];
    if (textColorData) {
        _currentSettings[HUDUserDefaultsKeyTextColor] = [NSKeyedUnarchiver unarchivedObjectOfClass:[UIColor class] fromData:textColorData error:nil];
    } else {
        _currentSettings[HUDUserDefaultsKeyTextColor] = [UIColor redColor];
    }
    
    // 加载文字大小
    _currentSettings[HUDUserDefaultsKeyTextSize] = @([[NSUserDefaults standardUserDefaults] floatForKey:HUDUserDefaultsKeyTextSize] ?: 10.0f);

    // 加载文字对齐
    _currentSettings[HUDUserDefaultsKeyTextAlignment] = @([[NSUserDefaults standardUserDefaults] integerForKey:HUDUserDefaultsKeyTextAlignment] ?: NSTextAlignmentCenter);

    // 加载文字透明度
    _currentSettings[HUDUserDefaultsKeyTextAlpha] = @([[NSUserDefaults standardUserDefaults] floatForKey:HUDUserDefaultsKeyTextAlpha] ?: 1.0f);

    // 加载背景颜色
    NSData *bgColorData = [[NSUserDefaults standardUserDefaults] dataForKey:HUDUserDefaultsKeyBackgroundColor];
    if (bgColorData) {
        _currentSettings[HUDUserDefaultsKeyBackgroundColor] = [NSKeyedUnarchiver unarchivedObjectOfClass:[UIColor class] fromData:bgColorData error:nil];
    } else {
        _currentSettings[HUDUserDefaultsKeyBackgroundColor] = [UIColor blackColor];
    }

    // 加载背景透明度
    _currentSettings[HUDUserDefaultsKeyBackgroundAlpha] = @([[NSUserDefaults standardUserDefaults] floatForKey:HUDUserDefaultsKeyBackgroundAlpha] ?: 1.0f);
}

- (void)saveSettings {
    // 保存文本内容
    [[NSUserDefaults standardUserDefaults] setObject:_textViewPreview.text forKey:HUDUserDefaultsKeyTextContent];

    // 保存文字颜色
    NSData *textColorData = [NSKeyedArchiver archivedDataWithRootObject:[_currentSettings objectForKey:HUDUserDefaultsKeyTextColor] requiringSecureCoding:NO error:nil];
    [[NSUserDefaults standardUserDefaults] setObject:textColorData forKey:HUDUserDefaultsKeyTextColor];

    // 保存文字大小
    [[NSUserDefaults standardUserDefaults] setFloat:[[_currentSettings objectForKey:HUDUserDefaultsKeyTextSize] floatValue] forKey:HUDUserDefaultsKeyTextSize];

    // 保存文字对齐
    [[NSUserDefaults standardUserDefaults] setInteger:[[_currentSettings objectForKey:HUDUserDefaultsKeyTextAlignment] integerValue] forKey:HUDUserDefaultsKeyTextAlignment];

    // 保存文字透明度
    [[NSUserDefaults standardUserDefaults] setFloat:[[_currentSettings objectForKey:HUDUserDefaultsKeyTextAlpha] floatValue] forKey:HUDUserDefaultsKeyTextAlpha];

    // 保存背景颜色
    NSData *bgColorData = [NSKeyedArchiver archivedDataWithRootObject:[_currentSettings objectForKey:HUDUserDefaultsKeyBackgroundColor] requiringSecureCoding:NO error:nil];
    [[NSUserDefaults standardUserDefaults] setObject:bgColorData forKey:HUDUserDefaultsKeyBackgroundColor];

    // 保存背景透明度
    [[NSUserDefaults standardUserDefaults] setFloat:[[_currentSettings objectForKey:HUDUserDefaultsKeyBackgroundAlpha] floatValue] forKey:HUDUserDefaultsKeyBackgroundAlpha];

    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *)textView {
    [_currentSettings setObject:textView.text forKey:HUDUserDefaultsKeyTextContent];
    [self updatePreview]; // 实时预览
}

@end 