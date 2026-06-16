#import <UIKit/UIKit.h>
#import "TrollMemo-Swift.h"

NS_ASSUME_NONNULL_BEGIN

@protocol EditTextSettingsViewControllerDelegate <NSObject>

- (void)editTextSettingsDidSave;
- (void)editTextSettingsDidCancel;

@end

@interface EditTextSettingsViewController : UIViewController

@property (nonatomic, weak) id<EditTextSettingsViewControllerDelegate> delegate;
@property (nonatomic, weak) id<TSSettingsControllerDelegate> behaviorSettingsDelegate;
@property (nonatomic, assign) BOOL hudAlreadyLaunched;

@end

NS_ASSUME_NONNULL_END
