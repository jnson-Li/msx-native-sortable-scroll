package com.msx.nativesortablescroll

import com.facebook.react.common.MapBuilder
import android.graphics.Color
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewGroupManager
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.uimanager.events.RCTEventEmitter
import com.facebook.react.uimanager.PixelUtil

class MSXNativeSortableScrollManager : ViewGroupManager<MSXNativeSortableScrollView>() {
  override fun getName(): String = "MSXNativeSortableScrollView"

  override fun createViewInstance(reactContext: ThemedReactContext): MSXNativeSortableScrollView {
    return MSXNativeSortableScrollView(reactContext)
  }

  override fun addView(parent: MSXNativeSortableScrollView, child: android.view.View, index: Int) {
    parent.addReactChild(child, index)
  }

  override fun getChildCount(parent: MSXNativeSortableScrollView): Int = parent.reactChildCount

  override fun getChildAt(parent: MSXNativeSortableScrollView, index: Int): android.view.View? =
    parent.getReactChildAt(index)

  override fun removeViewAt(parent: MSXNativeSortableScrollView, index: Int) {
    parent.removeReactChildAt(index)
  }

  @ReactProp(name = "rowHeight")
  fun setRowHeight(view: MSXNativeSortableScrollView, rowHeight: Float) {
    view.rowHeightPx = PixelUtil.toPixelFromDIP(rowHeight)
  }

  @ReactProp(name = "itemKeys")
  fun setItemKeys(view: MSXNativeSortableScrollView, itemKeys: com.facebook.react.bridge.ReadableArray?) {
    view.setItemKeys(itemKeys)
  }

  @ReactProp(name = "longPressDelayMs", defaultFloat = 300f)
  fun setLongPressDelayMs(view: MSXNativeSortableScrollView, delayMs: Float) {
    view.longPressDelayMs = delayMs.toLong()
  }

  @ReactProp(name = "favoriteLongPressDelayMs", defaultFloat = 1000f)
  fun setFavoriteLongPressDelayMs(view: MSXNativeSortableScrollView, delayMs: Float) {
    view.favoriteLongPressDelayMs = delayMs.toLong()
  }

  @ReactProp(name = "autoScrollEdgeDistance", defaultFloat = 72f)
  fun setAutoScrollEdgeDistance(view: MSXNativeSortableScrollView, distance: Float) {
    view.autoScrollEdgeDistancePx = PixelUtil.toPixelFromDIP(distance)
  }

  @ReactProp(name = "autoScrollStep", defaultFloat = 4f)
  fun setAutoScrollStep(view: MSXNativeSortableScrollView, step: Float) {
    view.autoScrollStepPx = PixelUtil.toPixelFromDIP(step)
  }

  @ReactProp(name = "dragActiveBackgroundColor")
  fun setDragActiveBackgroundColor(view: MSXNativeSortableScrollView, color: String?) {
    view.dragActiveBackgroundColor = try {
      if (color.isNullOrEmpty()) Color.TRANSPARENT else Color.parseColor(color)
    } catch (_: IllegalArgumentException) {
      Color.TRANSPARENT
    }
  }

  override fun getExportedCustomDirectEventTypeConstants(): MutableMap<String, Any> =
    mutableMapOf(
      "onDragStart" to MapBuilder.of("registrationName", "onDragStart"),
      "onDragEnd" to MapBuilder.of("registrationName", "onDragEnd"),
      "onFavoriteLongPress" to MapBuilder.of("registrationName", "onFavoriteLongPress"),
    )
}
