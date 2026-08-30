import { ValidationResult, ValidationSchema, ValidationValue } from '@ohos/common'

export enum Status {
  Idle = 'idle',
  Valid = 'valid',
  Invalid = 'invalid',
}

export enum LabelPlacement {
  Start = 'start',
  Top = 'top',
}

@ObservedV2
export class FormItemController {
  @Trace status: Status = Status.Idle
  @Trace result: ValidationResult = { valid: true, errors: [] }
  @Trace message: ResourceStr = ''
  private schema: ValidationSchema | undefined = undefined

  setSchema(schema: ValidationSchema | undefined): void {
    this.schema = schema
  }

  validate(value: ValidationValue): boolean {
    if (this.schema === undefined) {
      this.status = Status.Idle
      this.result = { valid: true, errors: [] }
      this.message = ''
      return true
    }

    this.result = this.schema.validate(value)
    this.status = this.result.valid ? Status.Valid : Status.Invalid
    this.message = this.result.errors.length > 0 ? this.result.errors[0].message : ''
    return this.result.valid
  }
}

@ComponentV2
export struct FormItem {
  @Param label: ResourceStr | undefined = undefined
  @Param value: ValidationValue = ''
  @Param schema: ValidationSchema | undefined = undefined
  @Param controller: FormItemController = new FormItemController()
  @Param reserveFeedbackSpace: boolean = false
  @Param required: boolean = false
  @Param labelPlacement: LabelPlacement = LabelPlacement.Top
  @BuilderParam labelBuilder?: () => void
  @BuilderParam contentBuilder: () => void

  aboutToAppear(): void {
    this.controller.setSchema(this.schema)
  }

  @Monitor('value')
  private onValueChanged(): void {
    this.controller.validate(this.value)
  }

  @Monitor('schema')
  private onSchemaChanged(): void {
    this.controller.setSchema(this.schema)
  }

  @Builder
  private labelText() {
    Text() {
      Span(this.label)
        .fontColor($r('sys.color.font_secondary'))
        .fontSize($r('sys.float.Body_M'))
      if (this.required) {
        Span(' ')
          .fontSize($r('sys.float.Body_S'))
        Span('*')
          .fontColor($r('sys.color.warning'))
          .fontSize($r('sys.float.Body_M'))
      }
    }
  }

  @Builder
  private feedbackRow() {

    Row() {
      Text() {
        SymbolSpan($r('sys.symbol.exclamationmark_circle_fill'))
        Span(' ')
        Span(this.controller.message)
      }
      .width('100%')
      .fontColor($r('sys.color.alert'))
      .fontSize($r('sys.float.Body_S'))
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height($r('sys.float.Body_L'))
    .margin({
      top: $r('sys.float.padding_level2'),
      bottom: $r('sys.float.padding_level2'),
      left: this.labelPlacement === LabelPlacement.Start ? 0 : $r('sys.float.padding_level8'),
    })
    .visibility(this.controller.status === Status.Invalid
      ? Visibility.Visible : Visibility.Hidden)
  }

  build() {
    Column() {
      if (this.labelPlacement === LabelPlacement.Start) {
        Row({ space: $r('sys.float.padding_level4') }) {
          if (this.labelBuilder !== undefined) {
            this.labelBuilder()
          } else if (this.label !== undefined) {
            this.labelText()
          }

          Row() {
            this.contentBuilder()
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.End)
        }

        if (this.reserveFeedbackSpace || this.controller.status === Status.Invalid) {
          this.feedbackRow()
        }
      } else {
        Column({ space: $r('sys.float.padding_level4') }) {
          if (this.labelBuilder !== undefined) {
            this.labelBuilder()
          } else if (this.label !== undefined) {
            Row() {
              this.labelText()
            }
            .width('100%')
            .margin({ left: $r('sys.float.padding_level8') })
          }

          this.contentBuilder()
        }

        this.feedbackRow()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
