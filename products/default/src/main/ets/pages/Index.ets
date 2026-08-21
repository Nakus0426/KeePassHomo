import { AppShell } from '../components/AppShell'

@Entry
@ComponentV2
struct Index {
  build() {
    Stack() {
      AppShell()
    }
    .width('100%')
    .height('100%')
  }
}
