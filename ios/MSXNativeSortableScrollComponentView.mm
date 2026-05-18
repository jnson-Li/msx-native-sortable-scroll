#import "MSXNativeSortableScrollComponentView.h"

#import <react/renderer/components/MSXNativeSortableScrollSpec/ComponentDescriptors.h>
#import <react/renderer/components/MSXNativeSortableScrollSpec/EventEmitters.h>
#import <react/renderer/components/MSXNativeSortableScrollSpec/Props.h>
#import <react/renderer/components/MSXNativeSortableScrollSpec/RCTComponentViewHelpers.h>

#import "MSXNativeSortableScrollView.h"
#import "RCTFabricComponentsPlugins.h"

using namespace facebook::react;

static UIColor *MSXUIColorFromHexString(NSString *hexString)
{
  NSString *cleanString = [[hexString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] uppercaseString];
  if ([cleanString hasPrefix:@"#"]) {
    cleanString = [cleanString substringFromIndex:1];
  }

  if (cleanString.length != 6 && cleanString.length != 8) {
    return UIColor.clearColor;
  }

  unsigned int value = 0;
  NSScanner *scanner = [NSScanner scannerWithString:cleanString];
  if (![scanner scanHexInt:&value]) {
    return UIColor.clearColor;
  }

  CGFloat alpha = 1;
  CGFloat red = 0;
  CGFloat green = 0;
  CGFloat blue = 0;

  if (cleanString.length == 8) {
    alpha = ((value >> 24) & 0xFF) / 255.0;
    red = ((value >> 16) & 0xFF) / 255.0;
    green = ((value >> 8) & 0xFF) / 255.0;
    blue = (value & 0xFF) / 255.0;
  } else {
    red = ((value >> 16) & 0xFF) / 255.0;
    green = ((value >> 8) & 0xFF) / 255.0;
    blue = (value & 0xFF) / 255.0;
  }

  return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

@interface MSXNativeSortableScrollComponentView () <RCTMSXNativeSortableScrollViewViewProtocol>
@end

@implementation MSXNativeSortableScrollComponentView {
  MSXNativeSortableScrollView *_scrollView;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<MSXNativeSortableScrollViewComponentDescriptor>();
}

+ (BOOL)shouldBeRecycled
{
  return NO;
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if ((self = [super initWithFrame:frame])) {
    static const auto defaultProps = std::make_shared<const MSXNativeSortableScrollViewProps>();
    _props = defaultProps;

    _scrollView = [MSXNativeSortableScrollView new];
    self.contentView = _scrollView;
    [self installEventBlocks];
  }

  return self;
}

- (void)prepareForRecycle
{
  [_scrollView cancelDrag];
  [super prepareForRecycle];
}

- (void)mountChildComponentView:(UIView<RCTComponentViewProtocol> *)childComponentView index:(NSInteger)index
{
  [_scrollView insertReactSubview:childComponentView atIndex:index];
}

- (void)unmountChildComponentView:(UIView<RCTComponentViewProtocol> *)childComponentView index:(NSInteger)index
{
  [_scrollView removeReactSubview:childComponentView];
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  const auto &oldViewProps = *std::static_pointer_cast<MSXNativeSortableScrollViewProps const>(_props);
  const auto &newViewProps = *std::static_pointer_cast<MSXNativeSortableScrollViewProps const>(props);

  if (oldViewProps.itemKeys != newViewProps.itemKeys) {
    NSMutableArray<NSString *> *itemKeys = [NSMutableArray arrayWithCapacity:newViewProps.itemKeys.size()];
    for (const auto &itemKey : newViewProps.itemKeys) {
      [itemKeys addObject:[[NSString alloc] initWithUTF8String:itemKey.c_str()]];
    }
    _scrollView.itemKeys = itemKeys;
  }

  if (oldViewProps.rowHeight != newViewProps.rowHeight) {
    _scrollView.rowHeight = newViewProps.rowHeight;
  }

  if (oldViewProps.longPressDelayMs != newViewProps.longPressDelayMs) {
    _scrollView.longPressDelayMs = newViewProps.longPressDelayMs;
  }

  if (oldViewProps.favoriteLongPressDelayMs != newViewProps.favoriteLongPressDelayMs) {
    _scrollView.favoriteLongPressDelayMs = newViewProps.favoriteLongPressDelayMs;
  }

  if (oldViewProps.autoScrollEdgeDistance != newViewProps.autoScrollEdgeDistance) {
    _scrollView.autoScrollEdgeDistance = newViewProps.autoScrollEdgeDistance;
  }

  if (oldViewProps.autoScrollStep != newViewProps.autoScrollStep) {
    _scrollView.autoScrollStep = newViewProps.autoScrollStep;
  }

  if (oldViewProps.dragActiveBackgroundColor != newViewProps.dragActiveBackgroundColor) {
    NSString *colorString = [[NSString alloc] initWithUTF8String:newViewProps.dragActiveBackgroundColor.c_str()];
    _scrollView.dragActiveBackgroundColor = colorString.length > 0 ? MSXUIColorFromHexString(colorString) : UIColor.clearColor;
  }

  [super updateProps:props oldProps:oldProps];
}

- (void)installEventBlocks
{
  __weak __typeof(self) weakSelf = self;

  _scrollView.onDragStart = ^(NSDictionary *body) {
    [weakSelf emitDragEvent:body type:0];
  };

  _scrollView.onDragEnd = ^(NSDictionary *body) {
    [weakSelf emitDragEvent:body type:1];
  };

  _scrollView.onFavoriteLongPress = ^(NSDictionary *body) {
    [weakSelf emitDragEvent:body type:2];
  };
}

- (void)emitDragEvent:(NSDictionary *)body type:(NSInteger)type
{
  if (_eventEmitter == nullptr) {
    return;
  }

  NSArray<NSString *> *order = body[@"order"] ?: @[];
  NSData *orderData = [NSJSONSerialization dataWithJSONObject:order options:0 error:nil];
  NSString *orderString = orderData != nil ? [[NSString alloc] initWithData:orderData encoding:NSUTF8StringEncoding] : @"[]";
  std::string nativeOrder = std::string(orderString.UTF8String);

  const auto eventEmitter = std::static_pointer_cast<const MSXNativeSortableScrollViewEventEmitter>(_eventEmitter);

  if (type == 0) {
    MSXNativeSortableScrollViewEventEmitter::OnDragStart event = {
        .fromIndex = [body[@"fromIndex"] intValue],
        .toIndex = [body[@"toIndex"] intValue],
        .order = nativeOrder,
        .scrollY = [body[@"scrollY"] floatValue],
    };
    eventEmitter->onDragStart(event);
  } else if (type == 1) {
    MSXNativeSortableScrollViewEventEmitter::OnDragEnd event = {
        .fromIndex = [body[@"fromIndex"] intValue],
        .toIndex = [body[@"toIndex"] intValue],
        .order = nativeOrder,
        .scrollY = [body[@"scrollY"] floatValue],
    };
    eventEmitter->onDragEnd(event);
  } else {
    MSXNativeSortableScrollViewEventEmitter::OnFavoriteLongPress event = {
        .fromIndex = [body[@"fromIndex"] intValue],
        .toIndex = [body[@"toIndex"] intValue],
        .order = nativeOrder,
        .scrollY = [body[@"scrollY"] floatValue],
    };
    eventEmitter->onFavoriteLongPress(event);
  }
}

@end

Class<RCTComponentViewProtocol> MSXNativeSortableScrollViewCls(void)
{
  return MSXNativeSortableScrollComponentView.class;
}
