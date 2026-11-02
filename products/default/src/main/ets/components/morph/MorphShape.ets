// 形变几何：progress 0 显示 iconOff，1 显示 iconOn，中间值由实现自行插值
export interface MorphShape {
  draw(canvas: CanvasRenderingContext2D, iconSize: number, color: number, progress: number): void
}
