//
//  HUDRootViewController.h
//  TrollMemo
//
//  Created by Lessica on 2024/1/24.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HUDRootViewController: UIViewController

@property (nonatomic, strong) UITextView *hudTextView; // 用于显示自定义文本的UITextView

+ (BOOL)passthroughMode;
- (void)resetLoopTimer;
- (void)stopLoopTimer;
@end

NS_ASSUME_NONNULL_END
