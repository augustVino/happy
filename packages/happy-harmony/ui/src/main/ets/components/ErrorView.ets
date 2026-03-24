/**
 * Error view component.
 * Displays an error icon, message, and optional retry button.
 * Uses callback class pattern to work around ArkTS function-prop restriction.
 */
import { LightColors } from '../theme/Colors';
import { AppTypography } from '../theme/Typography';

const ICON_SIZE: number = 48;
const TITLE_BOTTOM_MARGIN: number = 8;
const BUTTON_TOP_MARGIN: number = 24;
const BUTTON_HEIGHT: number = 40;
const BUTTON_PADDING_H: number = 32;

/** Callback class for retry action. */
export class ErrorViewCallback {
  onRetry: () => void = () => {};
}

@Component
export struct ErrorView {
  @Prop errorMessage: string = '';
  @Prop showRetry: boolean = false;
  private retryCallback: ErrorViewCallback | null = null;

  build() {
    Column() {
      // Error icon circle
      Column() {
        Text('!')
          .fontSize(AppTypography.TITLE_MEDIUM)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
      }
      .width(ICON_SIZE)
      .height(ICON_SIZE)
      .borderRadius(ICON_SIZE / 2)
      .backgroundColor(LightColors.ERROR)
      .justifyContent(FlexAlign.Center)
      .margin({ bottom: TITLE_BOTTOM_MARGIN })

      // Error message
      Text(this.errorMessage)
        .fontSize(AppTypography.BODY_MEDIUM)
        .fontColor(LightColors.TEXT_SECONDARY)
        .textAlign(TextAlign.Center)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .padding({ left: 32, right: 32 })

      // Retry button
      if (this.showRetry && this.retryCallback !== null) {
        Button('Retry')
          .fontSize(AppTypography.BODY_MEDIUM)
          .fontWeight(FontWeight.Medium)
          .fontColor(LightColors.PRIMARY_TEXT)
          .backgroundColor(LightColors.PRIMARY)
          .borderRadius(BUTTON_HEIGHT / 2)
          .height(BUTTON_HEIGHT)
          .padding({ left: BUTTON_PADDING_H, right: BUTTON_PADDING_H })
          .margin({ top: BUTTON_TOP_MARGIN })
          .onClick(() => {
            if (this.retryCallback !== null) {
              this.retryCallback.onRetry();
            }
          })
      }
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
