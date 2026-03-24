@Entry
@Component
struct Index {
  @State message: Resource = $r('app.string.EntryAbility_label');

  build() {
    Row() {
      Column() {
        Text(this.message)
          .fontSize(50)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
    }
    .height('100%')
  }
}
