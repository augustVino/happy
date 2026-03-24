/**
 * Loading indicator component.
 * Displays a centered ring progress indicator with optional message text.
 */
import { LightColors } from '../theme/Colors';
import { AppTypography } from '../theme/Typography';

const PROGRESS_SIZE: number = 48;
const MESSAGE_TOP_MARGIN: number = 16;

@Component
export struct LoadingIndicator {
  @Prop message: string = '';
  @State progressValue: number = 0;
  private timer: number = -1;

  aboutToAppear(): void {
    this.startAnimation();
  }

  aboutToDisappear(): void {
    this.stopAnimation();
  }

  private startAnimation(): void {
    this.timer = setInterval(() => {
      animateTo({ duration: 800, curve: Curve.Linear }, () => {
        this.progressValue = this.progressValue >= 100 ? 0 : this.progressValue + 10;
      });
    }, 800) as number;
  }

  private stopAnimation(): void {
    if (this.timer !== -1) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  build() {
    Column({ space: 0 }) {
      Progress({ value: this.progressValue, total: 100, type: ProgressType.Ring })
        .width(PROGRESS_SIZE)
        .height(PROGRESS_SIZE)
        .color(LightColors.PRIMARY)
        .style({ strokeWidth: 4 })

      if (this.message !== '') {
        Text(this.message)
          .fontSize(AppTypography.BODY_MEDIUM)
          .fontColor(LightColors.TEXT_SECONDARY)
          .margin({ top: MESSAGE_TOP_MARGIN })
          .textAlign(TextAlign.Center)
      }
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
