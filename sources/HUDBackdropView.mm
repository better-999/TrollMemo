//
//  HUDBackdropView.m
//  TrollMemo
//
//  Created by Lessica on 2024/1/25.
//

#import "HUDBackdropView.h"

@implementation HUDBackdropView

+ (Class)layerClass {
    return [NSClassFromString(@"CABackdropLayer") class];
}

@end
