//
//  HUDHelper.h
//  TrollMemo
//
//  Created by Lessica on 2024/1/24.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

OBJC_EXTERN BOOL IsHUDEnabled(void);
OBJC_EXTERN void SetHUDEnabled(BOOL isEnabled);

#if DEBUG
OBJC_EXTERN void SimulateMemoryPressure(void);
#endif

OBJC_EXTERN NSUserDefaults *GetStandardUserDefaults(void);

#define HUD_PID_PATH @"/var/mobile/Library/Caches/ch.better.hudapp.pid"

OBJC_EXTERN NSString *HUDResolvedPath(NSString *path);
OBJC_EXTERN BOOL IsJailbrokenHUDEnvironment(void);

OBJC_EXTERN NSMutableDictionary *LoadHUDSettingsPlist(void);
OBJC_EXTERN BOOL SaveHUDSettingsPlist(NSDictionary *settings);

NS_ASSUME_NONNULL_END
