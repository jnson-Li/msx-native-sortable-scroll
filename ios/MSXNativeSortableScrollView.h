#import <UIKit/UIKit.h>
#import <React/RCTComponent.h>

NS_ASSUME_NONNULL_BEGIN

@interface MSXNativeSortableScrollView : UIScrollView

@property (nonatomic, copy) NSArray<NSString *> *itemKeys;
@property (nonatomic, assign) CGFloat rowHeight;
@property (nonatomic, assign) CGFloat longPressDelayMs;
@property (nonatomic, assign) CGFloat favoriteLongPressDelayMs;
@property (nonatomic, assign) CGFloat autoScrollEdgeDistance;
@property (nonatomic, assign) CGFloat autoScrollStep;
@property (nonatomic, strong) UIColor *dragActiveBackgroundColor;
@property (nonatomic, copy) RCTDirectEventBlock onDragStart;
@property (nonatomic, copy) RCTDirectEventBlock onDragEnd;
@property (nonatomic, copy) RCTDirectEventBlock onFavoriteLongPress;

- (void)insertReactSubview:(UIView *)subview atIndex:(NSInteger)atIndex;
- (void)removeReactSubview:(UIView *)subview;
- (void)cancelDrag;

@end

NS_ASSUME_NONNULL_END
