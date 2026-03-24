/**
 * Message bubble component.
 * Renders different message types (text, service, tool-call, file) with
 * appropriate styling for user (right, blue) and agent (left, white) messages.
 *
 * Thinking text is displayed in italic with secondary color.
 */
import { LightColors } from '../theme/Colors';
import { AppTypography } from '../theme/Typography';
import { SessionMessage, MessageEventTypes, MessageRoles } from 'common';

const BUBBLE_PADDING_H: number = 14;
const BUBBLE_PADDING_V: number = 10;
const BUBBLE_RADIUS: number = 18;
const SERVICE_PADDING_H: number = 12;
const SERVICE_PADDING_V: number = 6;
const SERVICE_RADIUS: number = 12;
const TOOL_NAME_SIZE: number = 12;
const TOOL_DESC_SIZE: number = 12;
const FILE_ICON_SIZE: number = 20;
const FILE_INFO_GAP: number = 4;
const TOOL_PARAM_MAX_LINES: number = 5;

/** Typed class for JSON field extraction, avoiding ESObject/any usage. */
class ParsedJsonContent {
  name: string = '';
  title: string = '';
  description: string = '';
  size: string = '';
  t: string = '';
  text: string = '';
  status: string = '';
  ev: string = '';
}

@Reusable
@Component
export struct MessageBubble {
  @Prop message: SessionMessage = new SessionMessage();

  build() {
    if (this.message.eventType === MessageEventTypes.TURN_START) {
      this.TurnDivider()
    } else if (this.message.eventType === MessageEventTypes.TURN_END ||
      this.message.eventType === MessageEventTypes.STOP ||
      this.message.eventType === MessageEventTypes.TOOL_CALL_END ||
      this.message.eventType === MessageEventTypes.START) {
      // Hidden events - render nothing
      Column().width(0).height(0)
    } else if (this.message.role === MessageRoles.USER) {
      this.UserBubble()
    } else {
      this.AgentBubble()
    }
  }

  @Builder UserBubble() {
    Row() {
      Text(this.getDisplayContent())
        .fontSize(AppTypography.BODY_MEDIUM)
        .fontColor(LightColors.PRIMARY_TEXT)
        .lineHeight(22)
        .wordBreak(WordBreak.BREAK_ALL)
    }
    .padding({
      left: BUBBLE_PADDING_H,
      right: BUBBLE_PADDING_H,
      top: BUBBLE_PADDING_V,
      bottom: BUBBLE_PADDING_V
    })
    .constraintSize({ maxWidth: '78%' })
    .backgroundColor(LightColors.PRIMARY)
    .borderRadius({
      topLeft: BUBBLE_RADIUS,
      topRight: BUBBLE_RADIUS,
      bottomLeft: BUBBLE_RADIUS,
      bottomRight: 4
    })
    .justifyContent(FlexAlign.End)
  }

  @Builder AgentBubble() {
    Column() {
      if (this.message.eventType === MessageEventTypes.TEXT) {
        this.TextContent()
      } else if (this.message.eventType === MessageEventTypes.SERVICE) {
        this.ServiceMessage()
      } else if (this.message.eventType === MessageEventTypes.TOOL_CALL_START) {
        this.ToolCallCard()
      } else if (this.message.eventType === MessageEventTypes.FILE) {
        this.FileAttachment()
      } else {
        // Fallback: render as text
        this.TextContent()
      }
    }
    .alignItems(HorizontalAlign.Start)
  }

  @Builder TextContent() {
    Row() {
      Text(this.getDisplayContent())
        .fontSize(AppTypography.BODY_MEDIUM)
        .fontColor(this.message.isThinking ? LightColors.TEXT_SECONDARY : LightColors.TEXT_PRIMARY)
        .fontStyle(this.message.isThinking ? FontStyle.Italic : FontStyle.Normal)
        .lineHeight(22)
        .wordBreak(WordBreak.BREAK_ALL)
    }
    .padding({
      left: BUBBLE_PADDING_H,
      right: BUBBLE_PADDING_H,
      top: BUBBLE_PADDING_V,
      bottom: BUBBLE_PADDING_V
    })
    .constraintSize({ maxWidth: '78%' })
    .backgroundColor(LightColors.SURFACE)
    .borderRadius({
      topLeft: 4,
      topRight: BUBBLE_RADIUS,
      bottomLeft: BUBBLE_RADIUS,
      bottomRight: BUBBLE_RADIUS
    })
  }

  @Builder ServiceMessage() {
    Row() {
      Text(this.getDisplayContent())
        .fontSize(AppTypography.CAPTION)
        .fontColor(LightColors.TEXT_SECONDARY)
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .padding({
      left: SERVICE_PADDING_H,
      right: SERVICE_PADDING_H,
      top: SERVICE_PADDING_V,
      bottom: SERVICE_PADDING_V
    })
    .backgroundColor(LightColors.BACKGROUND)
    .borderRadius(SERVICE_RADIUS)
  }

  @Builder ToolCallCard() {
    Column() {
      Row() {
        // Tool icon indicator
        Column() {
          Text('T')
            .fontSize(TOOL_NAME_SIZE)
            .fontWeight(FontWeight.Bold)
            .fontColor(LightColors.PRIMARY_TEXT)
        }
        .width(28)
        .height(28)
        .borderRadius(6)
        .backgroundColor(LightColors.PRIMARY)
        .justifyContent(FlexAlign.Center)
        .margin({ right: 10 })

        Column() {
          Text(this.getToolName())
            .fontSize(TOOL_NAME_SIZE)
            .fontWeight(FontWeight.Bold)
            .fontColor(LightColors.TEXT_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.getToolTitle())
            .fontSize(TOOL_DESC_SIZE)
            .fontColor(LightColors.TEXT_SECONDARY)
            .margin({ top: 2 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // Tool description (if present)
      if (this.getToolDescription() !== '') {
        Text(this.getToolDescription())
          .fontSize(TOOL_DESC_SIZE)
          .fontColor(LightColors.TEXT_SECONDARY)
          .margin({ top: 8 })
          .maxLines(TOOL_PARAM_MAX_LINES)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
    }
    .padding({
      left: BUBBLE_PADDING_H,
      right: BUBBLE_PADDING_H,
      top: BUBBLE_PADDING_V,
      bottom: BUBBLE_PADDING_V
    })
    .constraintSize({ maxWidth: '85%' })
    .backgroundColor(LightColors.SURFACE)
    .borderRadius(BUBBLE_RADIUS)
  }

  @Builder FileAttachment() {
    Row() {
      // File icon
      Column() {
        Text('F')
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor(LightColors.PRIMARY)
      }
      .width(FILE_ICON_SIZE)
      .height(FILE_ICON_SIZE)
      .borderRadius(4)
      .backgroundColor('#E8F0FE')
      .justifyContent(FlexAlign.Center)
      .margin({ right: 10 })

      // File info
      Column() {
        Text(this.getFileName())
          .fontSize(AppTypography.BODY_MEDIUM)
          .fontColor(LightColors.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.getFileSize())
          .fontSize(AppTypography.CAPTION)
          .fontColor(LightColors.TEXT_SECONDARY)
          .margin({ top: FILE_INFO_GAP })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .padding({
      left: BUBBLE_PADDING_H,
      right: BUBBLE_PADDING_H,
      top: BUBBLE_PADDING_V,
      bottom: BUBBLE_PADDING_V
    })
    .constraintSize({ maxWidth: '78%' })
    .backgroundColor(LightColors.SURFACE)
    .borderRadius(BUBBLE_RADIUS)
    .alignItems(VerticalAlign.Center)
  }

  @Builder TurnDivider() {
    Row() {
      Blank()
      Text('New Turn')
        .fontSize(AppTypography.CAPTION)
        .fontColor(LightColors.TEXT_TERTIARY)
        .padding({ left: 10, right: 10, top: 4, bottom: 4 })
        .backgroundColor(LightColors.BACKGROUND)
        .borderRadius(10)
      Blank()
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }

  // ---- Helpers ----

  private getDisplayContent(): string {
    if (this.message.decryptedContent !== '') {
      return this.message.decryptedContent;
    }
    return this.message.content;
  }

  private getToolName(): string {
    const content: string = this.getDisplayContent();
    return this.extractJsonField(content, 'name');
  }

  private getToolTitle(): string {
    const content: string = this.getDisplayContent();
    return this.extractJsonField(content, 'title');
  }

  private getToolDescription(): string {
    const content: string = this.getDisplayContent();
    return this.extractJsonField(content, 'description');
  }

  private getFileName(): string {
    const content: string = this.getDisplayContent();
    return this.extractJsonField(content, 'name');
  }

  private getFileSize(): string {
    const content: string = this.getDisplayContent();
    const sizeStr: string = this.extractJsonField(content, 'size');
    if (sizeStr === '') {
      return '';
    }
    const sizeNum: number = parseInt(sizeStr, 10);
    if (isNaN(sizeNum)) {
      return sizeStr;
    }
    return this.formatFileSize(sizeNum);
  }

  private extractJsonField(json: string, field: string): string {
    if (json === '') {
      return '';
    }
    try {
      const obj: ParsedJsonContent = JSON.parse(json) as ParsedJsonContent;
      const value: string = this.readField(obj, field);
      if (value !== '') {
        return value;
      }
      // Also check nested 'ev' object
      if (obj.ev !== '') {
        try {
          const evObj: ParsedJsonContent = JSON.parse(obj.ev) as ParsedJsonContent;
          return this.readField(evObj, field);
        } catch (_e2) {
          // ev is not valid JSON
        }
      }
    } catch (_e) {
      // Not valid JSON, return empty
    }
    return '';
  }

  private readField(obj: ParsedJsonContent, field: string): string {
    if (field === 'name') { return obj.name; }
    if (field === 'title') { return obj.title; }
    if (field === 'description') { return obj.description; }
    if (field === 'size') { return obj.size; }
    if (field === 't') { return obj.t; }
    if (field === 'text') { return obj.text; }
    if (field === 'status') { return obj.status; }
    return '';
  }

  private formatFileSize(bytes: number): string {
    if (bytes < 1024) {
      return bytes + ' B';
    }
    if (bytes < 1024 * 1024) {
      return (bytes / 1024).toFixed(1) + ' KB';
    }
    return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
  }
}
