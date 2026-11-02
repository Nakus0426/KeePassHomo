import { EyeMorphData } from './EyeMorphData'
import { MorphShape } from './MorphShape'

// morphicons region morph：两个可见面按 64 点/子路径逐点插值，
// 旋转 θ 与缩放 σ 由 Procrustes 解出；progress 0 = iconOff，1 = iconOn
export class EyeMorphShape implements MorphShape {
  draw(canvas: CanvasRenderingContext2D, iconSize: number, color: number, progress: number): void {
    const unit: number = iconSize / EyeMorphData.VIEW_BOX
    const angle: number = progress * EyeMorphData.ROTATION
    const cos: number = Math.cos(angle)
    const sin: number = Math.sin(angle)
    const zoom: number = Math.pow(EyeMorphData.SCALE, progress)
    const centerX: number = (EyeMorphData.CENTER_FROM_X +
      (EyeMorphData.CENTER_TO_X - EyeMorphData.CENTER_FROM_X) * progress) * unit
    const centerY: number = (EyeMorphData.CENTER_FROM_Y +
      (EyeMorphData.CENTER_TO_Y - EyeMorphData.CENTER_FROM_Y) * progress) * unit
    const samples: number = EyeMorphData.SAMPLES_PER_SUBPATH

    const path: Path2D = new Path2D()
    for (let subpath: number = 0; subpath < EyeMorphData.SUBPATH_COUNT; subpath++) {
      const base: number = subpath * samples * 2
      for (let i: number = 0; i < samples; i++) {
        const index: number = base + i * 2
        const fromX: number = EyeMorphData.POINTS_FROM[index]
        const fromY: number = EyeMorphData.POINTS_FROM[index + 1]
        const x: number = (fromX + (EyeMorphData.POINTS_TO[index] - fromX) * progress) * zoom
        const y: number = (fromY + (EyeMorphData.POINTS_TO[index + 1] - fromY) * progress) * zoom
        const px: number = (cos * x - sin * y) * unit + centerX
        const py: number = (sin * x + cos * y) * unit + centerY
        if (i === 0) {
          path.moveTo(px, py)
        } else {
          path.lineTo(px, py)
        }
      }
      path.closePath()
    }

    canvas.clearRect(0, 0, iconSize, iconSize)
    canvas.fillStyle = color
    canvas.globalCompositeOperation = 'source-over'
    canvas.fill(path, 'nonzero')
  }
}
