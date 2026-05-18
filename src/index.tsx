import React from 'react'
import {
  requireNativeComponent,
  StyleProp,
  ViewProps,
  ViewStyle,
} from 'react-native'

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
  onDragStart?: (event: NativeSortableScrollDragEvent) => void
  onDragEnd?: (event: NativeSortableScrollDragEvent) => void
  onFavoriteLongPress?: (event: NativeSortableScrollDragEvent) => void
  containerStyle?: StyleProp<ViewStyle>
  children?: React.ReactNode
}

const NativeSortableScrollViewComponent =
  requireNativeComponent<NativeSortableScrollViewProps>(
    'MSXNativeSortableScrollView'
  )

export default function NativeSortableScrollView(
  props: NativeSortableScrollViewProps
) {
  return <NativeSortableScrollViewComponent {...props} />
}
