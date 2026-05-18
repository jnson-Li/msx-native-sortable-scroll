#import <React/RCTViewManager.h>

#import "MSXNativeSortableScrollView.h"

@interface MSXNativeSortableScrollManager : RCTViewManager
@end

@implementation MSXNativeSortableScrollManager

RCT_EXPORT_MODULE(MSXNativeSortableScrollView)

+ (BOOL)requiresMainQueueSetup
{
  return YES;
}

- (UIView *)view
{
  return [MSXNativeSortableScrollView new];
}

RCT_EXPORT_VIEW_PROPERTY(itemKeys, NSArray<NSString *>)
RCT_EXPORT_VIEW_PROPERTY(rowHeight, CGFloat)
RCT_EXPORT_VIEW_PROPERTY(longPressDelayMs, CGFloat)
RCT_EXPORT_VIEW_PROPERTY(favoriteLongPressDelayMs, CGFloat)
RCT_EXPORT_VIEW_PROPERTY(autoScrollEdgeDistance, CGFloat)
RCT_EXPORT_VIEW_PROPERTY(autoScrollStep, CGFloat)
RCT_EXPORT_VIEW_PROPERTY(dragActiveBackgroundColor, UIColor)
RCT_EXPORT_VIEW_PROPERTY(onDragStart, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onDragEnd, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onFavoriteLongPress, RCTDirectEventBlock)

@end
