import { MorphShape } from './MorphShape'

// 步骤图标 -> 对勾的形变数据契约，字段对齐 generate_step_morph.py 的产物。
export interface StepMorphDataSpec {
  VIEW_BOX: number
  SUBPATH_COUNT: number
  SAMPLES_PER_SUBPATH: number
  CENTER_FROM_X: number
  CENTER_FROM_Y: number
  CENTER_TO_X: number
  CENTER_TO_Y: number
  ROTATION: number
  SCALE: number
  POINTS_FROM: number[]
  POINTS_TO: number[]
}

// 与 EyeMorphShape 同一 region morph 公式，只是数据由外部注入，供多对图标复用。
export class StepMorphShape implements MorphShape {
  private readonly data: StepMorphDataSpec

  constructor(data: StepMorphDataSpec) {
    this.data = data
  }

  draw(canvas: CanvasRenderingContext2D, iconSize: number, color: number, progress: number): void {
    const data: StepMorphDataSpec = this.data
    const unit: number = iconSize / data.VIEW_BOX
    const angle: number = progress * data.ROTATION
    const cos: number = Math.cos(angle)
    const sin: number = Math.sin(angle)
    const zoom: number = Math.pow(data.SCALE, progress)
    const centerX: number = (data.CENTER_FROM_X + (data.CENTER_TO_X - data.CENTER_FROM_X) * progress) * unit
    const centerY: number = (data.CENTER_FROM_Y + (data.CENTER_TO_Y - data.CENTER_FROM_Y) * progress) * unit
    const samples: number = data.SAMPLES_PER_SUBPATH

    const path: Path2D = new Path2D()
    for (let subpath: number = 0; subpath < data.SUBPATH_COUNT; subpath++) {
      const base: number = subpath * samples * 2
      for (let i: number = 0; i < samples; i++) {
        const index: number = base + i * 2
        const fromX: number = data.POINTS_FROM[index]
        const fromY: number = data.POINTS_FROM[index + 1]
        const x: number = (fromX + (data.POINTS_TO[index] - fromX) * progress) * zoom
        const y: number = (fromY + (data.POINTS_TO[index + 1] - fromY) * progress) * zoom
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
