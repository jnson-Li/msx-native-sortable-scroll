import type { HostComponent, ViewProps } from 'react-native'
import codegenNativeComponent from 'react-native/Libraries/Utilities/codegenNativeComponent'
import type {
  DirectEventHandler,
  Float,
  Int32,
} from 'react-native/Libraries/Types/CodegenTypes'

export type NativeSortableScrollDragEvent = Readonly<{
  fromIndex: Int32
  toIndex: Int32
  order: string
  scrollY: Float
}>

export interface NativeProps extends ViewProps {
  itemKeys: ReadonlyArray<string>
  rowHeight: Float
  longPressDelayMs?: Float
  favoriteLongPressDelayMs?: Float
  autoScrollEdgeDistance?: Float
  autoScrollStep?: Float
  dragActiveBackgroundColor?: string
  onDragStart?: DirectEventHandler<NativeSortableScrollDragEvent>
  onDragEnd?: DirectEventHandler<NativeSortableScrollDragEvent>
  onFavoriteLongPress?: DirectEventHandler<NativeSortableScrollDragEvent>
}

export default codegenNativeComponent<NativeProps>(
  'MSXNativeSortableScrollView',
) as HostComponent<NativeProps>
