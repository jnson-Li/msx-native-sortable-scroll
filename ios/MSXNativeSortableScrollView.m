#import "MSXNativeSortableScrollView.h"

#import <React/UIView+React.h>

static const CGFloat MSXDragActivationMoveThreshold = 4.0;

@interface MSXNativeSortableScrollView () <UIGestureRecognizerDelegate>

@property (nonatomic, strong) NSMutableArray<UIView *> *orderedSubviews;
@property (nonatomic, strong) NSMutableArray<UIView *> *displaySubviews;
@property (nonatomic, strong, nullable) UIView *activeView;
@property (nonatomic, strong, nullable) UIView *activeSnapshotView;
@property (nonatomic, strong, nullable) UIColor *activeViewPreviousBackgroundColor;
@property (nonatomic, assign) NSInteger activeIndex;
@property (nonatomic, assign) NSInteger targetIndex;
@property (nonatomic, assign) NSInteger pendingDragIndex;
@property (nonatomic, assign) CGFloat activeTouchOffsetY;
@property (nonatomic, assign) CGFloat lastTouchYInContent;
@property (nonatomic, assign) CGFloat pendingTouchOffsetY;
@property (nonatomic, assign) CGFloat pendingTouchStartYInContent;
@property (nonatomic, strong) UILongPressGestureRecognizer *longPressGestureRecognizer;
@property (nonatomic, strong, nullable) CADisplayLink *autoScrollDisplayLink;
@property (nonatomic, strong, nullable) NSTimer *favoriteLongPressTimer;
@property (nonatomic, assign) NSInteger autoScrollDirection;
@property (nonatomic, assign) BOOL favoriteLongPressTriggered;
@property (nonatomic, strong) UISelectionFeedbackGenerator *selectionFeedbackGenerator;
@property (nonatomic, strong) UIImpactFeedbackGenerator *activationFeedbackGenerator;

@end

@implementation MSXNativeSortableScrollView

- (instancetype)init
{
  if ((self = [super initWithFrame:CGRectZero])) {
    _orderedSubviews = [NSMutableArray new];
    _displaySubviews = [NSMutableArray new];
    _activeIndex = NSNotFound;
    _targetIndex = NSNotFound;
    _pendingDragIndex = NSNotFound;
    _rowHeight = 56;
    _longPressDelayMs = 300;
    _favoriteLongPressDelayMs = 1000;
    _autoScrollEdgeDistance = 72;
    _autoScrollStep = 4;
    _dragActiveBackgroundColor = UIColor.clearColor;
    _selectionFeedbackGenerator = [UISelectionFeedbackGenerator new];
    _activationFeedbackGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    self.showsVerticalScrollIndicator = NO;
    self.delaysContentTouches = NO;

    _longPressGestureRecognizer =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    _longPressGestureRecognizer.minimumPressDuration = _longPressDelayMs / 1000.0;
    _longPressGestureRecognizer.delegate = self;
    [self addGestureRecognizer:_longPressGestureRecognizer];
  }

  return self;
}

- (void)setItemKeys:(NSArray<NSString *> *)itemKeys
{
  _itemKeys = [itemKeys copy];
}

- (void)setLongPressDelayMs:(CGFloat)longPressDelayMs
{
  _longPressDelayMs = longPressDelayMs;
  self.longPressGestureRecognizer.minimumPressDuration = longPressDelayMs / 1000.0;
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  self.contentSize = CGSizeMake(CGRectGetWidth(self.bounds), self.rowHeight * self.orderedSubviews.count);
  [self layoutOrderedSubviewsAnimated:NO];
}

- (void)insertReactSubview:(UIView *)subview atIndex:(NSInteger)atIndex
{
  [self.orderedSubviews removeObject:subview];
  [self.displaySubviews removeObject:subview];
  [self.orderedSubviews insertObject:subview atIndex:MIN(atIndex, self.orderedSubviews.count)];
  [self.displaySubviews insertObject:subview atIndex:MIN(atIndex, self.displaySubviews.count)];
  [self addSubview:subview];
  [self setNeedsLayout];
}

- (void)removeReactSubview:(UIView *)subview
{
  [self.orderedSubviews removeObject:subview];
  [self.displaySubviews removeObject:subview];
  [subview removeFromSuperview];
  [self setNeedsLayout];
}

- (NSArray<UIView *> *)reactSubviews
{
  return self.orderedSubviews;
}

- (void)layoutOrderedSubviewsAnimated:(BOOL)animated
{
  void (^layoutBlock)(void) = ^{
    CGFloat width = CGRectGetWidth(self.bounds);
    [self.displaySubviews enumerateObjectsUsingBlock:^(UIView * _Nonnull child, NSUInteger idx, BOOL * _Nonnull stop) {
      child.frame = CGRectMake(0, idx * self.rowHeight, width, self.rowHeight);
    }];
  };

  if (animated) {
    [UIView animateWithDuration:0.12 animations:layoutBlock];
  } else {
    layoutBlock();
  }
}

- (NSInteger)indexForTouchLocationInContent:(CGPoint)location
{
  if (self.displaySubviews.count == 0 || self.rowHeight <= 0) {
    return NSNotFound;
  }

  NSInteger index = floor(location.y / self.rowHeight);
  if (index < 0 || index >= self.displaySubviews.count) {
    return NSNotFound;
  }

  return index;
}

- (NSArray<NSString *> *)currentOrderedKeys
{
  if (self.itemKeys.count == self.displaySubviews.count && self.itemKeys.count > 0) {
    return [self.itemKeys copy];
  }

  NSMutableArray<NSString *> *fallbackKeys = [NSMutableArray arrayWithCapacity:self.displaySubviews.count];
  [self.displaySubviews enumerateObjectsUsingBlock:^(UIView * _Nonnull subview, NSUInteger idx, BOOL * _Nonnull stop) {
    [fallbackKeys addObject:[NSString stringWithFormat:@"%@", subview.reactTag ?: @(idx)]];
  }];
  return fallbackKeys;
}

- (void)moveItemKeyFromIndex:(NSInteger)fromIndex toIndex:(NSInteger)toIndex
{
  if (self.itemKeys.count != self.displaySubviews.count) {
    return;
  }

  if (fromIndex < 0 || toIndex < 0 || fromIndex >= self.itemKeys.count || toIndex >= self.itemKeys.count || fromIndex == toIndex) {
    return;
  }

  NSMutableArray<NSString *> *mutableKeys = [self.itemKeys mutableCopy];
  NSString *movingKey = mutableKeys[fromIndex];
  [mutableKeys removeObjectAtIndex:fromIndex];
  [mutableKeys insertObject:movingKey atIndex:toIndex];
  self.itemKeys = [mutableKeys copy];
}

- (void)triggerReorderHaptic
{
  [self.selectionFeedbackGenerator selectionChanged];
  [self.selectionFeedbackGenerator prepare];
}

- (void)stopFavoriteLongPressTimer
{
  [self.favoriteLongPressTimer invalidate];
  self.favoriteLongPressTimer = nil;
}

- (void)resetPendingDragState
{
  [self stopFavoriteLongPressTimer];
  self.pendingDragIndex = NSNotFound;
  self.pendingTouchOffsetY = 0;
  self.pendingTouchStartYInContent = 0;
  self.favoriteLongPressTriggered = NO;
}

- (void)emitFavoriteLongPressIfNeeded
{
  if (self.favoriteLongPressTriggered || self.pendingDragIndex == NSNotFound || self.activeSnapshotView != nil) {
    return;
  }

  self.favoriteLongPressTriggered = YES;

  if (self.onFavoriteLongPress != nil) {
    self.onFavoriteLongPress(@{
      @"fromIndex": @(self.pendingDragIndex),
      @"toIndex": @(self.pendingDragIndex),
      @"order": [self currentOrderedKeys],
      @"scrollY": @(self.contentOffset.y),
    });
  }

  [self stopFavoriteLongPressTimer];
}

- (void)scheduleFavoriteLongPress
{
  [self stopFavoriteLongPressTimer];

  NSTimeInterval delayMs = MAX(0, self.favoriteLongPressDelayMs - self.longPressDelayMs);
  self.favoriteLongPressTimer = [NSTimer scheduledTimerWithTimeInterval:delayMs / 1000.0
                                                                 target:self
                                                               selector:@selector(handleFavoriteLongPressTimer)
                                                               userInfo:nil
                                                                repeats:NO];
}

- (void)handleFavoriteLongPressTimer
{
  [self emitFavoriteLongPressIfNeeded];
}

- (void)beginPendingDragAtTouchY:(CGFloat)touchYInContent
{
  if (self.pendingDragIndex == NSNotFound || self.pendingDragIndex >= self.displaySubviews.count) {
    return;
  }

  UIView *view = self.displaySubviews[self.pendingDragIndex];
  self.activeIndex = self.pendingDragIndex;
  self.targetIndex = self.pendingDragIndex;
  self.activeView = view;
  self.activeViewPreviousBackgroundColor = view.backgroundColor;
  self.activeTouchOffsetY = self.pendingTouchOffsetY;
  view.backgroundColor = self.dragActiveBackgroundColor;
  self.activeSnapshotView = [view snapshotViewAfterScreenUpdates:YES];
  self.activeSnapshotView.frame = view.frame;
  self.activeSnapshotView.backgroundColor = self.dragActiveBackgroundColor;
  self.activeSnapshotView.layer.cornerRadius = 0;
  self.activeSnapshotView.layer.masksToBounds = NO;
  [self addSubview:self.activeSnapshotView];
  view.hidden = YES;
  [self stopFavoriteLongPressTimer];
  [self.selectionFeedbackGenerator prepare];
  [self.activationFeedbackGenerator impactOccurred];
  [self.activationFeedbackGenerator prepare];

  if (self.onDragStart != nil) {
    self.onDragStart(@{
      @"fromIndex": @(self.activeIndex),
      @"toIndex": @(self.activeIndex),
      @"order": [self currentOrderedKeys],
      @"scrollY": @(self.contentOffset.y),
    });
  }

  self.pendingDragIndex = NSNotFound;
  self.favoriteLongPressTriggered = NO;

  CGRect frame = self.activeSnapshotView.frame;
  frame.origin.y = touchYInContent - self.activeTouchOffsetY;
  self.activeSnapshotView.frame = frame;
  [self updateTargetIndexForSnapshot];
}

- (void)beginAutoScrollIfNeeded
{
  if (self.activeSnapshotView == nil) {
    [self stopAutoScroll];
    return;
  }

  NSInteger direction = 0;
  CGFloat activeTop = CGRectGetMinY(self.activeSnapshotView.frame) - self.contentOffset.y;
  CGFloat activeBottom = CGRectGetMaxY(self.activeSnapshotView.frame) - self.contentOffset.y;

  if (activeTop < self.autoScrollEdgeDistance) {
    direction = -1;
  } else if (activeBottom > CGRectGetHeight(self.bounds) - self.autoScrollEdgeDistance) {
    direction = 1;
  }

  if (direction == 0) {
    [self stopAutoScroll];
    return;
  }

  self.autoScrollDirection = direction;
  if (self.autoScrollDisplayLink != nil) {
    return;
  }

  self.autoScrollDisplayLink =
      [CADisplayLink displayLinkWithTarget:self selector:@selector(handleAutoScrollTick)];
  [self.autoScrollDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stopAutoScroll
{
  self.autoScrollDirection = 0;
  [self.autoScrollDisplayLink invalidate];
  self.autoScrollDisplayLink = nil;
}

- (void)handleAutoScrollTick
{
  if (self.activeSnapshotView == nil || self.autoScrollDirection == 0) {
    [self stopAutoScroll];
    return;
  }

  CGFloat maxOffsetY = MAX(0, self.contentSize.height - CGRectGetHeight(self.bounds));
  CGFloat nextOffsetY = MIN(MAX(self.contentOffset.y + self.autoScrollDirection * self.autoScrollStep, 0), maxOffsetY);
  CGFloat delta = nextOffsetY - self.contentOffset.y;

  if (fabs(delta) < FLT_EPSILON) {
    [self stopAutoScroll];
    return;
  }

  self.contentOffset = CGPointMake(self.contentOffset.x, nextOffsetY);

  CGRect frame = self.activeSnapshotView.frame;
  frame.origin.y += delta;
  self.activeSnapshotView.frame = frame;
  self.lastTouchYInContent += delta;

  [self updateTargetIndexForSnapshot];
}

- (void)updateTargetIndexForSnapshot
{
  if (self.activeSnapshotView == nil || self.activeView == nil || self.activeIndex == NSNotFound) {
    return;
  }

  NSInteger nextIndex = MIN(MAX((NSInteger)floor(CGRectGetMidY(self.activeSnapshotView.frame) / self.rowHeight), 0), self.displaySubviews.count - 1);
  if (nextIndex == self.targetIndex) {
    return;
  }

  UIView *activeView = self.activeView;
  NSInteger previousTargetIndex = self.targetIndex;
  [self.displaySubviews removeObject:activeView];
  [self.displaySubviews insertObject:activeView atIndex:nextIndex];
  self.targetIndex = nextIndex;
  [self moveItemKeyFromIndex:previousTargetIndex toIndex:nextIndex];
  [self triggerReorderHaptic];
  [self layoutOrderedSubviewsAnimated:YES];
}

- (void)finishDrag
{
  [self stopAutoScroll];

  if (self.activeView == nil || self.activeSnapshotView == nil || self.activeIndex == NSNotFound || self.targetIndex == NSNotFound) {
    self.activeIndex = NSNotFound;
    self.targetIndex = NSNotFound;
    self.activeView = nil;
    self.activeSnapshotView = nil;
    return;
  }

  UIView *activeView = self.activeView;
  UIView *snapshot = self.activeSnapshotView;
  NSInteger fromIndex = self.activeIndex;
  NSInteger toIndex = self.targetIndex;

  activeView.hidden = NO;
  activeView.backgroundColor = self.activeViewPreviousBackgroundColor;
  [snapshot removeFromSuperview];

  if (self.onDragEnd != nil) {
    self.onDragEnd(@{
      @"fromIndex": @(fromIndex),
      @"toIndex": @(toIndex),
      @"order": [self currentOrderedKeys],
      @"scrollY": @(self.contentOffset.y),
    });
  }

  self.activeIndex = NSNotFound;
  self.targetIndex = NSNotFound;
  self.activeView = nil;
  self.activeSnapshotView = nil;
  self.activeViewPreviousBackgroundColor = nil;
  [self resetPendingDragState];
}

- (void)cancelDrag
{
  [self stopAutoScroll];

  if (self.activeView != nil) {
    self.activeView.hidden = NO;
    self.activeView.backgroundColor = self.activeViewPreviousBackgroundColor;
  }
  [self.activeSnapshotView removeFromSuperview];
  [self resetPendingDragState];
  self.activeSnapshotView = nil;
  self.activeView = nil;
  self.activeViewPreviousBackgroundColor = nil;
  self.activeIndex = NSNotFound;
  self.targetIndex = NSNotFound;
  [self.displaySubviews removeAllObjects];
  [self.displaySubviews addObjectsFromArray:self.orderedSubviews];
  [self layoutOrderedSubviewsAnimated:YES];
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture
{
  CGPoint locationInContent = [gesture locationInView:self];
  CGPoint locationInScrollView = locationInContent;
  self.lastTouchYInContent = locationInContent.y;

  switch (gesture.state) {
    case UIGestureRecognizerStateBegan: {
      NSInteger index = [self indexForTouchLocationInContent:locationInContent];
      if (index == NSNotFound || index >= self.displaySubviews.count) {
        return;
      }

      UIView *view = self.displaySubviews[index];
      self.pendingDragIndex = index;
      self.pendingTouchOffsetY = locationInContent.y - CGRectGetMinY(view.frame);
      self.pendingTouchStartYInContent = locationInContent.y;
      self.favoriteLongPressTriggered = NO;
      [self scheduleFavoriteLongPress];
      break;
    }

    case UIGestureRecognizerStateChanged: {
      if (self.activeSnapshotView == nil) {
        if (
          self.pendingDragIndex == NSNotFound ||
          self.favoriteLongPressTriggered ||
          fabs(locationInContent.y - self.pendingTouchStartYInContent) <= MSXDragActivationMoveThreshold
        ) {
          return;
        }

        [self beginPendingDragAtTouchY:locationInContent.y];
      }

      if (self.activeSnapshotView == nil) {
        return;
      }

      CGRect frame = self.activeSnapshotView.frame;
      frame.origin.y = locationInContent.y - self.activeTouchOffsetY;
      self.activeSnapshotView.frame = frame;
      [self updateTargetIndexForSnapshot];
      [self beginAutoScrollIfNeeded];
      break;
    }

    case UIGestureRecognizerStateEnded:
      if (self.activeSnapshotView != nil) {
        [self finishDrag];
      } else {
        [self resetPendingDragState];
      }
      break;

    case UIGestureRecognizerStateCancelled:
    case UIGestureRecognizerStateFailed:
      if (self.activeSnapshotView != nil) {
        [self cancelDrag];
      } else {
        [self resetPendingDragState];
      }
      break;

    default:
      break;
  }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
  return NO;
}

@end
