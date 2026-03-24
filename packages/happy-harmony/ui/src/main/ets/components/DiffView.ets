/**
 * Diff view component.
 * Displays unified diff content with color-coded lines:
 *   - Green: added lines (prefix +)
 *   - Red: deleted lines (prefix -)
 *   - Default: unchanged lines
 * Supports long content scrolling and line numbers.
 */
import { LightColors } from '../theme/Colors';
import { AppTypography } from '../theme/Typography';
import { Logger } from 'common';

const TAG = 'DiffView';
const LINE_HEIGHT: number = 22;
const LINE_NUMBER_WIDTH: number = 48;
const CODE_PADDING: number = 12;
const LINE_NUMBER_PADDING: number = 8;
const PREFIX_WIDTH: number = 20;

/** Diff line data model. */
class DiffLine {
  type: string = 'context';
  content: string = '';
  lineNumber: number = 0;

  constructor(type: string, content: string, lineNumber: number) {
    this.type = type;
    this.content = content;
    this.lineNumber = lineNumber;
  }
}

/** Diff line background colors. */
class DiffColors {
  static readonly ADDED_BG: string = 'rgba(52, 199, 89, 0.15)';
  static readonly ADDED_TEXT: string = '#34C759';
  static readonly DELETED_BG: string = 'rgba(255, 59, 48, 0.15)';
  static readonly DELETED_TEXT: string = '#FF3B30';
  static readonly CONTEXT_BG: string = 'transparent';
  static readonly CONTEXT_TEXT: string = '#1C1C1E';
  static readonly LINE_NUMBER_TEXT: string = '#8E8E93';
}

@Reusable
@Component
struct DiffLineItem {
  @Prop line: DiffLine = new DiffLine('context', '', 0);

  private getBackgroundColor(): string {
    if (this.line.type === 'added') {
      return DiffColors.ADDED_BG;
    }
    if (this.line.type === 'deleted') {
      return DiffColors.DELETED_BG;
    }
    return DiffColors.CONTEXT_BG;
  }

  private getTextColor(): string {
    if (this.line.type === 'added') {
      return DiffColors.ADDED_TEXT;
    }
    if (this.line.type === 'deleted') {
      return DiffColors.DELETED_TEXT;
    }
    return DiffColors.CONTEXT_TEXT;
  }

  private getPrefix(): string {
    if (this.line.type === 'added') {
      return '+';
    }
    if (this.line.type === 'deleted') {
      return '-';
    }
    return ' ';
  }

  build() {
    Row() {
      // Line number
      Text(this.line.lineNumber > 0 ? String(this.line.lineNumber) : '')
        .fontSize(AppTypography.CAPTION)
        .fontFamily('monospace')
        .fontColor(DiffColors.LINE_NUMBER_TEXT)
        .width(LINE_NUMBER_WIDTH)
        .padding({ right: LINE_NUMBER_PADDING })
        .textAlign(TextAlign.End)
        .constraintSize({ minWidth: LINE_NUMBER_WIDTH })

      // Prefix character
      Text(this.getPrefix())
        .fontSize(AppTypography.BODY_SMALL)
        .fontFamily('monospace')
        .fontColor(this.getTextColor())
        .width(PREFIX_WIDTH)
        .constraintSize({ minWidth: PREFIX_WIDTH })

      // Line content
      Text(this.line.content)
        .fontSize(AppTypography.BODY_SMALL)
        .fontFamily('monospace')
        .fontColor(this.getTextColor())
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height(LINE_HEIGHT)
    .backgroundColor(this.getBackgroundColor())
    .alignItems(VerticalAlign.Center)
    .padding({ left: CODE_PADDING })
  }
}

@Component
export struct DiffView {
  @Prop diffContent: string = '';
  private scrollController: Scroller = new Scroller();
  @State parsedLines: DiffLine[] = [];

  aboutToAppear(): void {
    this.parseDiff();
  }

  aboutToUpdate(): void {
    this.parseDiff();
  }

  private parseDiff(): void {
    if (this.diffContent === '') {
      this.parsedLines = [];
      return;
    }
    const lines: string[] = this.diffContent.split('\n');
    const result: DiffLine[] = [];
    let lineNumber: number = 0;

    for (let i = 0; i < lines.length; i++) {
      const line: string = lines[i];
      if (line.startsWith('+++') || line.startsWith('---') || line.startsWith('@@')) {
        // Skip diff headers
        continue;
      }
      if (line.startsWith('+')) {
        lineNumber++;
        result.push(new DiffLine('added', line.substring(1), lineNumber));
      } else if (line.startsWith('-')) {
        result.push(new DiffLine('deleted', line.substring(1), 0));
      } else {
        lineNumber++;
        result.push(new DiffLine('context', line.startsWith(' ') ? line.substring(1) : line, lineNumber));
      }
    }
    this.parsedLines = result;
  }

  build() {
    if (this.parsedLines.length === 0) {
      Column() {
        Text('No changes to display')
          .fontSize(AppTypography.BODY_MEDIUM)
          .fontColor(LightColors.TEXT_SECONDARY)
      }
      .width('100%')
      .height(120)
      .justifyContent(FlexAlign.Center)
    } else {
      Scroll(this.scrollController) {
        Column() {
          ForEach(this.parsedLines, (item: DiffLine, index: number) => {
            DiffLineItem({ line: item })
          }, (item: DiffLine, index: number) => {
            return String(index) + '-' + item.type + '-' + item.lineNumber;
          })
        }
      }
      .scrollBar(BarState.Auto)
      .scrollBarColor('#424242')
      .scrollBarWidth(4)
      .width('100%')
      .constraintSize({ maxHeight: 400 })
      .align(Alignment.Top)
      .backgroundColor('#FFFFFF')
      .borderRadius(8)
      .clip(true)
    }
  }
}
