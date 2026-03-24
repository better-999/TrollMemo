#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol EditTextSettingsViewControllerDelegate <NSObject>

- (void)editTextSettingsDidSave;
- (void)editTextSettingsDidCancel;

@end

@interface EditTextSettingsViewController : UIViewController

@property (nonatomic, weak) id<EditTextSettingsViewControllerDelegate> delegate;

@end

NS_ASSUME_NONNULL_END 