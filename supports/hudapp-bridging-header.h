//
//  hudapp-bridging-header.h
//  TrollMemo
//
//  Created by Lessica on 2024/1/25.
//

#ifndef hudapp_bridging_header_h
#define hudapp_bridging_header_h

#import <Foundation/Foundation.h>

#import "HUDHelper.h"

typedef NSString * HUDUserDefaultsKey;

static HUDUserDefaultsKey const HUDUserDefaultsKeySelectedMode = @"selectedMode";
static HUDUserDefaultsKey const HUDUserDefaultsKeySelectedModeLandscape = @"selectedModeLandscape";
static HUDUserDefaultsKey const HUDUserDefaultsKeyCurrentPositionY = @"currentPositionY";
static HUDUserDefaultsKey const HUDUserDefaultsKeyCurrentLandscapePositionY = @"currentLandscapePositionY";
static HUDUserDefaultsKey const HUDUserDefaultsKeyPassthroughMode = @"passthroughMode";
static HUDUserDefaultsKey const HUDUserDefaultsKeyUsesLargeFont = @"usesLargeFont";
static HUDUserDefaultsKey const HUDUserDefaultsKeyUsesRotation = @"usesRotation";
static HUDUserDefaultsKey const HUDUserDefaultsKeyUsesInvertedColor = @"usesInvertedColor";
static HUDUserDefaultsKey const HUDUserDefaultsKeyKeepInPlace = @"keepInPlace";
static HUDUserDefaultsKey const HUDUserDefaultsKeyHideAtSnapshot = @"hideAtSnapshot";

static HUDUserDefaultsKey const HUDUserDefaultsKeyUsesCustomFontSize = @"usesCustomFontSize";
static HUDUserDefaultsKey const HUDUserDefaultsKeyRealCustomFontSize = @"realCustomFontSize";
static HUDUserDefaultsKey const HUDUserDefaultsKeyUsesCustomOffset = @"usesCustomOffset";
static HUDUserDefaultsKey const HUDUserDefaultsKeyRealCustomOffsetX = @"realCustomOffsetX";
static HUDUserDefaultsKey const HUDUserDefaultsKeyRealCustomOffsetY = @"realCustomOffsetY";

static HUDUserDefaultsKey const HUDUserDefaultsKeyTextContent = @"HUDUserDefaultsKeyTextContent";
static HUDUserDefaultsKey const HUDUserDefaultsKeyTextColor = @"HUDUserDefaultsKeyTextColor";
static HUDUserDefaultsKey const HUDUserDefaultsKeyTextSize = @"HUDUserDefaultsKeyTextSize";
static HUDUserDefaultsKey const HUDUserDefaultsKeyTextAlignment = @"HUDUserDefaultsKeyTextAlignment";
static HUDUserDefaultsKey const HUDUserDefaultsKeyTextAlpha = @"HUDUserDefaultsKeyTextAlpha";
static HUDUserDefaultsKey const HUDUserDefaultsKeyBackgroundColor = @"HUDUserDefaultsKeyBackgroundColor";
static HUDUserDefaultsKey const HUDUserDefaultsKeyBackgroundAlpha = @"HUDUserDefaultsKeyBackgroundAlpha";
static HUDUserDefaultsKey const HUDUserDefaultsKeyTextVerticalPosition = @"HUDUserDefaultsKeyTextVerticalPosition";
static HUDUserDefaultsKey const HUDUserDefaultsKeyPortraitOffsetX = @"HUDUserDefaultsKeyPortraitOffsetX";
static HUDUserDefaultsKey const HUDUserDefaultsKeyPortraitOffsetY = @"HUDUserDefaultsKeyPortraitOffsetY";
static HUDUserDefaultsKey const HUDUserDefaultsKeyLandscapeOffsetX = @"HUDUserDefaultsKeyLandscapeOffsetX";
static HUDUserDefaultsKey const HUDUserDefaultsKeyLandscapeOffsetY = @"HUDUserDefaultsKeyLandscapeOffsetY";

#endif /* hudapp_bridging_header_h */
