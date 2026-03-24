/**
 * Session list item component.
 * Displays session title, last message preview, relative timestamp,
 * and thinking indicator. Supports @Reusable for list performance.
 */
import { Session } from 'common';
import { LightColors } from '../theme/Colors';
import { AppTypography } from '../theme/Typography';
import { ThinkingIndicator } from './ThinkingIndicator';
import { SessionItemParams, formatRelativeTime } from '../datasource/SessionDataSource';

const STATUS_DOT_SIZE: number = 10;
const TIMESTAMP_TOP_MARGIN: number = 2;
const INDICATOR_LEFT_MARGIN: number = 8;

@Reusable
@Component
export struct SessionItem {
  @Prop session: Session = new Session();
  @Prop isActive: boolean = false;

  aboutToReuse(params: Record<string, Object>): void {
    const sessionObj: Object | undefined = params['session'];
    const isActiveObj: Object | undefined = params['isActive'];
    if (sessionObj !== undefined) {
      this.session = sessionObj as Session;
    }
    if (isActiveObj !== undefined) {
      this.isActive = isActiveObj as boolean;
    }
  }

  build() {
    Row() {
      // Left: online/active status indicator
      Column() {
        if (this.isActive) {
          Circle()
            .width(STATUS_DOT_SIZE)
            .height(STATUS_DOT_SIZE)
            .fill(LightColors.PRIMARY)
        } else {
          Circle()
            .width(STATUS_DOT_SIZE)
            .height(STATUS_DOT_SIZE)
            .fill(LightColors.TEXT_TERTIARY)
            .opacity(0.5)
        }
      }
      .justifyContent(FlexAlign.Center)
      .margin({ right: 12 })

      // Middle: title, preview, timestamp
      Column() {
        // Title row
        Row() {
          Text(this.session.decryptedTitle !== '' ? this.session.decryptedTitle : 'Untitled Session')
            .fontSize(AppTypography.BODY_LARGE)
            .fontWeight(FontWeight.Medium)
            .fontColor(LightColors.TEXT_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          Text(formatRelativeTime(this.session.updatedAt))
            .fontSize(AppTypography.CAPTION)
            .fontColor(LightColors.TEXT_TERTIARY)
            .margin({ left: 8 })
        }
        .width('100%')

        // Last message preview
        Text(this.session.lastMessagePreview)
          .fontSize(AppTypography.BODY_SMALL)
          .fontColor(LightColors.TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: TIMESTAMP_TOP_MARGIN })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      // Right: thinking indicator
      if (this.session.isThinking) {
        ThinkingIndicator({ isThinking: true })
          .margin({ left: INDICATOR_LEFT_MARGIN })
      }
    }
    .width('100%')
    .padding({ left: 12, right: 16, top: 12, bottom: 16 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.isActive ? LightColors.NAV_BAR : LightColors.SURFACE)
    .borderRadius(12)
  }
}
