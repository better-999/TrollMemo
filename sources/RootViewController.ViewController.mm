- (void)viewDidLoad {
    [super viewDidLoad];
    [_authorLabel setText:NSLocalizedString(@"Tap that button on the center again,\nto toggle ON/OFF \"Dynamic Island\" mode.", nil)];
}

- (BOOL)settingHighlightedWithKey:(NSString * _Nonnull)key

- (void)verticalSizeClassUpdated
{
    UIUserInterfaceSizeClass verticalClass = self.traitCollection.verticalSizeClass;
    BOOL isPad = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad);
    // 如果垂直尺寸类别为紧凑型
    if (verticalClass == UIUserInterfaceSizeClassCompact) {
        // CGFloat topConstant = _gTopButtonConstraintsConstantCompact; // 移除未使用的变量
        [_settingsButton setHidden:YES]; // 隐藏设置按钮
        [_authorLabelBottomConstraint setConstant:_gAuthorLabelBottomConstraintConstantCompact]; // 设置作者标签底部约束
    } else {
        // CGFloat topConstant = isPad ? _gTopButtonConstraintsConstantRegularPad : _gTopButtonConstraintsConstantRegular; // 移除未使用的变量
        [_settingsButton setHidden:NO]; // 显示设置按钮
        [_authorLabelBottomConstraint setConstant:_gAuthorLabelBottomConstraintConstantRegular]; // 设置作者标签底部约束
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection 