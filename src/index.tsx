import React from 'react'
import { StyleProp, ViewProps, ViewStyle } from 'react-native'
import NativeSortableScrollViewComponent, {
  NativeSortableScrollDragEvent as NativeSortableScrollFabricDragEvent,
} from './MSXNativeSortableScrollViewNativeComponent'

export type NativeSortableScrollDragEvent = {
  nativeEvent: {
    fromIndex: number
    toIndex: number
    order: string[]
    scrollY: number
  }
}

export type NativeSortableScrollViewProps = ViewProps & {
  itemKeys: string[]
  rowHeight: number
  longPressDelayMs?: number
  favoriteLongPressDelayMs?: number
  autoScrollEdgeDistance?: number
  autoScrollStep?: number
  dragActiveBackgroundColor?: string
  onItemPress?: (event: NativeSortableScrollDragEvent) => void
  onDragStart?: (event: NativeSortableScrollDragEvent) => void
  onDragEnd?: (event: NativeSortableScrollDragEvent) => void
  onFavoriteLongPress?: (event: NativeSortableScrollDragEvent) => void
  containerStyle?: StyleProp<ViewStyle>
  children?: React.ReactNode
}

const parseFabricOrder = (order: string) => {
  try {
    const parsed = JSON.parse(order)
    return Array.isArray(parsed) ? parsed.filter((item) => typeof item === 'string') : []
  } catch {
    return []
  }
}

const wrapFabricDragEvent =
  (handler?: (event: NativeSortableScrollDragEvent) => void) =>
  (event: { nativeEvent: NativeSortableScrollFabricDragEvent }) => {
    if (!handler) return

    handler({
      nativeEvent: {
        ...event.nativeEvent,
        order: parseFabricOrder(event.nativeEvent.order),
      },
    })
  }

export default function NativeSortableScrollView(
  props: NativeSortableScrollViewProps
) {
  const {
    containerStyle: _containerStyle,
    onItemPress,
    onDragStart,
    onDragEnd,
    onFavoriteLongPress,
    ...nativeProps
  } = props

  return (
    <NativeSortableScrollViewComponent
      {...nativeProps}
      onItemPress={wrapFabricDragEvent(onItemPress)}
      onDragStart={wrapFabricDragEvent(onDragStart)}
      onDragEnd={wrapFabricDragEvent(onDragEnd)}
      onFavoriteLongPress={wrapFabricDragEvent(onFavoriteLongPress)}
    />
  )
}
