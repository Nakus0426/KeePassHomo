import { ResUtil } from '@pura/harmony-utils'
import { AnimationTokens } from '@ohos/common'

export enum DsLoadingIndicatorSize {
  Small = 'sm',
  Medium = 'md',
  Large = 'lg',
}

export enum DsLoadingIndicatorTone {
  Surface = 'surface',
  Inverse = 'inverse',
  Scrim = 'scrim',
}

const PULSE_CELLS: number[] = [0, 1, 2]

@ComponentV2
export struct DsLoadingIndicator {
  @Param indicatorSize: DsLoadingIndicatorSize = DsLoadingIndicatorSize.Medium
  @Param tone: DsLoadingIndicatorTone = DsLoadingIndicatorTone.Surface
  @Param accessibilityLabel: string = ''
  @Param accessibilityLabelResource: Resource | undefined = undefined

  @Local private activeCell: number = 0
  private beatTimer: number = -1

  aboutToAppear(): void {
    // 2.2 次/秒换格，240ms 缓动淡变，与 pen loading-pulse 的节奏一致。
    this.beatTimer = setInterval(() => {
      this.getUIContext().animateTo({
        duration: AnimationTokens.DURATION_LOADING_FADE,
        curve: AnimationTokens.EASE_STATE,
      }, () => {
        this.activeCell = (this.activeCell + 1) % PULSE_CELLS.length
      })
    }, AnimationTokens.DURATION_LOADING_BEAT)
  }

  aboutToDisappear(): void {
    clearInterval(this.beatTimer)
    this.beatTimer = -1
  }

  @Computed
  get pulseWidth(): Resource {
    switch (this.indicatorSize) {
      case DsLoadingIndicatorSize.Small:
        return $r('app.float.ds_loading_pulse_w_sm')
      case DsLoadingIndicatorSize.Large:
        return $r('app.float.ds_loading_pulse_w_lg')
      default:
        return $r('app.float.ds_loading_pulse_w_md')
    }
  }

  @Computed
  get pulseHeight(): Resource {
    switch (this.indicatorSize) {
      case DsLoadingIndicatorSize.Small:
        return $r('app.float.ds_loading_pulse_h_sm')
      case DsLoadingIndicatorSize.Large:
        return $r('app.float.ds_loading_pulse_h_lg')
      default:
        return $r('app.float.ds_loading_pulse_h_md')
    }
  }

  @Computed
  get pulseGap(): Resource {
    switch (this.indicatorSize) {
      case DsLoadingIndicatorSize.Small:
        return $r('app.float.ds_loading_pulse_gap_sm')
      case DsLoadingIndicatorSize.Large:
        return $r('app.float.ds_loading_pulse_gap_lg')
      default:
        return $r('app.float.ds_loading_pulse_gap_md')
    }
  }

  @Computed
  get activeColor(): ResourceColor {
    switch (this.tone) {
      case DsLoadingIndicatorTone.Inverse:
        return $r('app.color.ds_loading_inverse_active')
      case DsLoadingIndicatorTone.Scrim:
        return $r('app.color.ds_loading_on_scrim')
      default:
        return $r('app.color.ds_primary')
    }
  }

  @Computed
  get trailColor(): ResourceColor {
    switch (this.tone) {
      case DsLoadingIndicatorTone.Inverse:
        return $r('app.color.ds_loading_inverse_trail')
      case DsLoadingIndicatorTone.Scrim:
        return $r('app.color.ds_loading_on_scrim_trail')
      default:
        return $r('app.color.ds_text_disabled')
    }
  }

  @Computed
  get idleColor(): ResourceColor {
    switch (this.tone) {
      case DsLoadingIndicatorTone.Inverse:
        return $r('app.color.ds_loading_inverse_idle')
      case DsLoadingIndicatorTone.Scrim:
        return $r('app.color.ds_loading_on_scrim_idle')
      default:
        return $r('app.color.ds_surface_highest')
    }
  }

  @Computed
  get effectiveAccessibilityLabel(): string {
    if (this.accessibilityLabelResource !== undefined) {
      return ResUtil.getStringSync(this.accessibilityLabelResource)
    }
    return this.accessibilityLabel
  }

  private cellColor(index: number): ResourceColor {
    if (index === this.activeCell) {
      return this.activeColor
    }
    return index === (this.activeCell + PULSE_CELLS.length - 1) % PULSE_CELLS.length
      ? this.trailColor : this.idleColor
  }

  build() {
    Row({ space: this.pulseGap }) {
      ForEach(PULSE_CELLS, (index: number) => {
        Row()
          .width(this.pulseHeight)
          .height(this.pulseHeight)
          .backgroundColor(this.cellColor(index))
          .accessibilityLevel('no')
      }, (index: number) => index.toString())
    }
    .width(this.pulseWidth)
    .height(this.pulseHeight)
    .accessibilityGroup(true)
    .accessibilityLevel(this.effectiveAccessibilityLabel.length > 0 ? 'yes' : 'no')
    .accessibilityText(this.effectiveAccessibilityLabel)
  }
}
