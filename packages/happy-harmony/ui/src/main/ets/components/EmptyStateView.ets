/**
 * Empty state view component.
 * Displays a centered icon, title, and description for empty content scenarios.
 * Set showIcon to true and provide iconSrc to display an image icon.
 */
import { LightColors } from '../theme/Colors';
import { AppTypography } from '../theme/Typography';

const ICON_SIZE: number = 64;
const TITLE_BOTTOM_MARGIN: number = 8;
const ICON_BOTTOM_MARGIN: number = 16;

@Component
export struct EmptyStateView {
  @Prop title: string = '';
  @Prop description: string = '';
  @Prop showIcon: boolean = false;
  @Prop iconSrc: string | Resource = '';
  private displayIcon: string | Resource = '';

  aboutToAppear(): void {
    if (this.showIcon && this.iconSrc !== '') {
      this.displayIcon = this.iconSrc;
    }
  }

  build() {
    Column() {
      // Icon
      if (this.displayIcon !== '') {
        Image(this.displayIcon)
          .width(ICON_SIZE)
          .height(ICON_SIZE)
          .objectFit(ImageFit.Contain)
          .fillColor(LightColors.TEXT_TERTIARY)
          .opacity(0.6)
          .margin({ bottom: ICON_BOTTOM_MARGIN })
      }

      // Title
      if (this.title !== '') {
        Text(this.title)
          .fontSize(AppTypography.TITLE_SMALL)
          .fontWeight(FontWeight.Medium)
          .fontColor(LightColors.TEXT_PRIMARY)
          .margin({ bottom: TITLE_BOTTOM_MARGIN })
          .textAlign(TextAlign.Center)
      }

      // Description
      if (this.description !== '') {
        Text(this.description)
          .fontSize(AppTypography.BODY_MEDIUM)
          .fontColor(LightColors.TEXT_SECONDARY)
          .textAlign(TextAlign.Center)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding({ left: 32, right: 32 })
      }
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
