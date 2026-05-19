package com.msx.nativesortablescroll

import android.content.Context
import android.graphics.Color
import android.os.SystemClock
import android.view.HapticFeedbackConstants
import android.view.GestureDetector
import android.view.MotionEvent
import android.view.View
import android.widget.ScrollView
import androidx.core.view.GestureDetectorCompat
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.events.RCTEventEmitter
import org.json.JSONArray
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

class MSXNativeSortableScrollView(context: Context) : ScrollView(context) {
  companion object {
    private const val DRAG_ACTIVATION_MOVE_THRESHOLD_PX = 4f
  }

  private inner class ContentLayout(context: Context) : android.view.ViewGroup(context) {
    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
      val width = MeasureSpec.getSize(widthMeasureSpec)
      val contentHeight = max((orderedChildren.size * rowHeightPx).toInt(), 0)
      val exactChildWidthSpec = MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY)
      val exactChildHeightSpec = MeasureSpec.makeMeasureSpec(rowHeightPx.toInt(), MeasureSpec.EXACTLY)

      for (index in 0 until childCount) {
        getChildAt(index).measure(exactChildWidthSpec, exactChildHeightSpec)
      }

      setMeasuredDimension(width, contentHeight)
    }

    override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
      applyChildLayouts()
    }
  }

  private val contentLayout = ContentLayout(context)
  private val orderedChildren = mutableListOf<View>()
  private val detector = GestureDetectorCompat(context, LongPressListener())
  private var activeView: View? = null
  private var activeIndex = -1
  private var targetIndex = -1
  private var pendingDragIndex = -1
  private var touchOffsetY = 0f
  private var lastTouchYInContent = 0f
  private var pendingTouchOffsetY = 0f
  private var pendingTouchStartYInContent = 0f
  private var autoScrollDirection = 0
  private var autoScrollPosted = false
  private var itemKeys = mutableListOf<String>()
  private val keyByViewId = mutableMapOf<Int, String>()
  private var favoriteLongPressPosted = false
  private var favoriteLongPressTriggered = false
  var dragActiveBackgroundColor = Color.TRANSPARENT
  private var activeViewPreviousBackgroundColor: android.graphics.drawable.Drawable? = null

  var rowHeightPx = 56f
    set(value) {
      field = value
      requestLayout()
    }

  var longPressDelayMs = 300L
  var favoriteLongPressDelayMs = 1000L
  var autoScrollEdgeDistancePx = 72f
  var autoScrollStepPx = 4f

  init {
    isVerticalScrollBarEnabled = false
    clipToPadding = true
    clipChildren = true
    contentLayout.clipToPadding = true
    contentLayout.clipChildren = true
    addView(
      contentLayout,
      LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT)
    )
  }

  val reactChildCount: Int
    get() = orderedChildren.size

  fun getReactChildAt(index: Int): View? = orderedChildren.getOrNull(index)

  fun addReactChild(child: View, index: Int) {
    val safeIndex = index.coerceIn(0, orderedChildren.size)
    orderedChildren.add(safeIndex, child)
    contentLayout.addView(child)
    rebuildKeyMapping()
    requestLayout()
  }

  fun removeReactChildAt(index: Int) {
    val child = orderedChildren.removeAt(index)
    contentLayout.removeView(child)
    keyByViewId.remove(child.id)
    requestLayout()
  }

  fun setItemKeys(readableArray: ReadableArray?) {
    itemKeys.clear()
    readableArray?.let { array ->
      for (i in 0 until array.size()) {
        itemKeys.add(array.getString(i) ?: i.toString())
      }
    }
    rebuildKeyMapping()
  }

  override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
    super.onMeasure(widthMeasureSpec, heightMeasureSpec)
    val width = MeasureSpec.getSize(widthMeasureSpec)
    val childHeight = max((orderedChildren.size * rowHeightPx).toInt(), measuredHeight)
    contentLayout.measure(
      MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY),
      MeasureSpec.makeMeasureSpec(childHeight, MeasureSpec.EXACTLY)
    )
  }

  override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
    super.onLayout(changed, l, t, r, b)
    contentLayout.layout(0, 0, width, max((orderedChildren.size * rowHeightPx).toInt(), height))
    applyChildLayouts()
  }

  private fun applyChildLayouts(resetTranslations: Boolean = false) {
    orderedChildren.forEachIndexed { index, child ->
      val top = (index * rowHeightPx).toInt()
      child.animate().cancel()
      child.layout(0, top, width, top + rowHeightPx.toInt())
      if (resetTranslations && child !== activeView) {
        child.translationY = 0f
      }
    }
  }

  private fun clearPendingDragState() {
    removeCallbacks(favoriteLongPressRunnable)
    pendingDragIndex = -1
    pendingTouchOffsetY = 0f
    pendingTouchStartYInContent = 0f
    favoriteLongPressPosted = false
    favoriteLongPressTriggered = false
  }

  private fun scheduleFavoriteLongPress() {
    removeCallbacks(favoriteLongPressRunnable)
    favoriteLongPressPosted = true
    postDelayed(favoriteLongPressRunnable, max(0L, favoriteLongPressDelayMs - longPressDelayMs))
  }

  override fun onInterceptTouchEvent(ev: MotionEvent): Boolean {
    detector.onTouchEvent(ev)
    return activeView != null || super.onInterceptTouchEvent(ev)
  }

  override fun onTouchEvent(ev: MotionEvent): Boolean {
    detector.onTouchEvent(ev)

    when (ev.actionMasked) {
      MotionEvent.ACTION_MOVE -> {
        activeView?.let { draggedView ->
          val touchYInContent = ev.y + scrollY
          lastTouchYInContent = touchYInContent
          val desiredTop = touchYInContent - touchOffsetY
          draggedView.translationY = desiredTop - draggedView.top
          draggedView.bringToFront()
          updateTargetIndex(draggedView.top + draggedView.translationY + rowHeightPx / 2f)
          updateAutoScroll()
          return true
        }

        if (pendingDragIndex >= 0 && !favoriteLongPressTriggered) {
          val touchYInContent = ev.y + scrollY
          if (abs(touchYInContent - pendingTouchStartYInContent) > DRAG_ACTIVATION_MOVE_THRESHOLD_PX) {
            beginDrag(pendingDragIndex, touchYInContent, pendingTouchOffsetY)
            activeView?.let { draggedView ->
              val desiredTop = touchYInContent - touchOffsetY
              draggedView.translationY = desiredTop - draggedView.top
              draggedView.bringToFront()
              updateTargetIndex(draggedView.top + draggedView.translationY + rowHeightPx / 2f)
              updateAutoScroll()
              return true
            }
          }
        }
      }
      MotionEvent.ACTION_UP,
      MotionEvent.ACTION_CANCEL -> {
        if (activeView != null) {
          finishDrag()
          return true
        }
        clearPendingDragState()
      }
    }

    return activeView != null || super.onTouchEvent(ev)
  }

  private fun beginDrag(index: Int, touchYInContent: Float, initialTouchOffsetY: Float? = null) {
    val child = orderedChildren.getOrNull(index) ?: return
    activeView = child
    activeIndex = index
    targetIndex = index
    touchOffsetY = initialTouchOffsetY ?: (touchYInContent - child.top)
    activeViewPreviousBackgroundColor = child.background
    child.setBackgroundColor(dragActiveBackgroundColor)
    child.elevation = 100f
    child.alpha = 0.98f
    removeCallbacks(favoriteLongPressRunnable)
    favoriteLongPressPosted = false
    favoriteLongPressTriggered = false
    pendingDragIndex = -1
    performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
    sendEvent("onDragStart", index, index)
  }

  private fun triggerReorderHaptic() {
    performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
  }

  private fun updateTargetIndex(activeCenterY: Float) {
    val nextIndex = min(max((activeCenterY / rowHeightPx).toInt(), 0), orderedChildren.size - 1)
    if (nextIndex == targetIndex || activeView == null) return

    val draggedView = activeView!!
    val draggedVisualTop = draggedView.top + draggedView.translationY
    orderedChildren.remove(draggedView)
    orderedChildren.add(nextIndex, draggedView)
    targetIndex = nextIndex
    triggerReorderHaptic()
    applyChildLayouts()
    draggedView.translationY = draggedVisualTop - draggedView.top
  }

  private fun updateAutoScroll() {
    val draggedView = activeView ?: run {
      autoScrollDirection = 0
      autoScrollPosted = false
      return
    }

    val activeTop = draggedView.top + draggedView.translationY - scrollY
    val activeBottom = activeTop + rowHeightPx
    val nextDirection = when {
      activeTop < autoScrollEdgeDistancePx -> -1
      activeBottom > height - autoScrollEdgeDistancePx -> 1
      else -> 0
    }

    autoScrollDirection = nextDirection
    if (!autoScrollPosted && nextDirection != 0) {
      autoScrollPosted = true
      postOnAnimation(autoScrollRunnable)
    }
  }

  private val autoScrollRunnable = object : Runnable {
    override fun run() {
      val draggedView = activeView
      if (draggedView == null || autoScrollDirection == 0) {
        autoScrollPosted = false
        return
      }

      val maxScroll = max(0, contentLayout.height - height)
      val nextScrollY = min(max(scrollY + (autoScrollDirection * autoScrollStepPx).toInt(), 0), maxScroll)
      val delta = nextScrollY - scrollY

      if (delta == 0) {
        autoScrollPosted = false
        return
      }

      scrollTo(scrollX, nextScrollY)
      draggedView.translationY += delta
      lastTouchYInContent += delta
      updateTargetIndex(draggedView.top + draggedView.translationY + rowHeightPx / 2f)

      postOnAnimation(this)
    }
  }

  private val favoriteLongPressRunnable = Runnable {
    if (activeView != null || pendingDragIndex < 0 || favoriteLongPressTriggered) {
      return@Runnable
    }

    favoriteLongPressTriggered = true
    favoriteLongPressPosted = false
    sendEvent("onFavoriteLongPress", pendingDragIndex, pendingDragIndex)
    pendingDragIndex = -1
  }

  private fun finishDrag() {
    val draggedView = activeView ?: return
    autoScrollDirection = 0
    autoScrollPosted = false

    draggedView.translationY = 0f
    draggedView.elevation = 0f
    draggedView.alpha = 1f
    draggedView.background = activeViewPreviousBackgroundColor
    applyChildLayouts(resetTranslations = true)

    sendEvent("onDragEnd", activeIndex, targetIndex)

    activeView = null
    activeIndex = -1
    targetIndex = -1
    activeViewPreviousBackgroundColor = null
    clearPendingDragState()
  }

  private fun sendEvent(eventName: String, fromIndex: Int, toIndex: Int) {
    val reactContext = context as? ThemedReactContext ?: return
    val event = Arguments.createMap().apply {
      putInt("fromIndex", fromIndex)
      putInt("toIndex", toIndex)
      putDouble("scrollY", scrollY.toDouble())
      putString("order", JSONArray(currentOrderedKeys()).toString())
    }

    reactContext.getJSModule(RCTEventEmitter::class.java).receiveEvent(id, eventName, event)
  }

  private fun currentOrderedKeys(): List<String> {
    return orderedChildren.mapIndexed { index, view ->
      keyByViewId[view.id] ?: (view.id.takeIf { it != View.NO_ID }?.toString() ?: index.toString())
    }
  }

  private fun rebuildKeyMapping() {
    keyByViewId.clear()
    val count = min(itemKeys.size, orderedChildren.size)
    for (index in 0 until count) {
      keyByViewId[orderedChildren[index].id] = itemKeys[index]
    }
  }

  private inner class LongPressListener : GestureDetector.SimpleOnGestureListener() {
    override fun onDown(e: MotionEvent): Boolean = true

    override fun onLongPress(e: MotionEvent) {
      if (activeView != null) return
      if (SystemClock.uptimeMillis() - e.downTime < longPressDelayMs) return

      val touchYInContent = e.y + scrollY
      val index = min(max((touchYInContent / rowHeightPx).toInt(), 0), orderedChildren.size - 1)
      val child = orderedChildren.getOrNull(index) ?: return
      pendingDragIndex = index
      pendingTouchOffsetY = touchYInContent - child.top
      pendingTouchStartYInContent = touchYInContent
      favoriteLongPressTriggered = false
      scheduleFavoriteLongPress()
    }
  }
}
