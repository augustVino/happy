/**
 * Message list component.
 * Renders a scrollable list of messages using LazyForEach for performance.
 * Auto-scrolls to the bottom when new messages arrive.
 */
import { LightColors } from '../theme/Colors';
import { SessionMessage, MessageEventTypes, MessageRoles } from 'common';
import { MessageBubble } from './MessageBubble';

const LIST_BOTTOM_PADDING: number = 8;
const ITEM_TOP_PADDING: number = 4;
const ITEM_BOTTOM_PADDING: number = 4;
const ITEM_SIDE_PADDING: number = 16;
const USER_ALIGNMENT: FlexAlign = FlexAlign.End;
const AGENT_ALIGNMENT: FlexAlign = FlexAlign.Start;
const CENTER_ALIGNMENT: FlexAlign = FlexAlign.Center;

/**
 * IDataSource implementation for LazyForEach.
 * Provides message data with change notification support.
 */
class MessageDataSource implements IDataSource {
  private messages: SessionMessage[] = [];
  private listeners: DataChangeListener[] = [];

  totalCount(): number {
    return this.messages.length;
  }

  getData(index: number): SessionMessage {
    return this.messages[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos: number = this.listeners.indexOf(listener);
    if (pos >= 0) {
      this.listeners.splice(pos, 1);
    }
  }

  updateData(newMessages: SessionMessage[]): void {
    this.messages = newMessages;
    this.notifyDataChange();
  }

  addMessage(message: SessionMessage): void {
    this.messages.push(message);
    this.notifyDataChange();
  }

  getMessages(): SessionMessage[] {
    return this.messages;
  }

  private notifyDataChange(): void {
    for (let i = 0; i < this.listeners.length; i++) {
      this.listeners[i].onDataChange(0);
      this.listeners[i].onDataAdd(this.messages.length - 1);
    }
  }
}

@Component
export struct MessageList {
  @State messages: SessionMessage[] = [];
  private scroller: Scroller = new Scroller();
  private messageDataSource: MessageDataSource = new MessageDataSource();
  private isInitialScroll: boolean = true;

  aboutToAppear(): void {
    this.messageDataSource.updateData(this.messages);
  }

  aboutToUpdate(): void {
    const currentLength: number = this.messageDataSource.totalCount();
    this.messageDataSource.updateData(this.messages);
    if (this.messages.length > currentLength && !this.isInitialScroll) {
      // New messages added, scroll to bottom after render
      this.scrollToBottomDelayed();
    }
  }

  build() {
    List({ space: 0 }) {
      LazyForEach(this.messageDataSource, (msg: SessionMessage, index: number) => {
        ListItem() {
          Row() {
            if (msg.eventType === MessageEventTypes.TURN_START ||
              msg.eventType === MessageEventTypes.SERVICE) {
              // Centered messages: turn dividers and service messages
              MessageBubble({ message: msg })
            } else if (msg.role === MessageRoles.USER) {
              // Right-aligned user messages
              MessageBubble({ message: msg })
            } else {
              // Left-aligned agent messages
              MessageBubble({ message: msg })
            }
          }
          .width('100%')
          .padding({
            left: ITEM_SIDE_PADDING,
            right: ITEM_SIDE_PADDING,
            top: ITEM_TOP_PADDING,
            bottom: ITEM_BOTTOM_PADDING
          })
          .justifyContent(this.getItemAlignment(msg))
        }
      }, (msg: SessionMessage, index: number) => {
        return msg.id + '-' + String(index);
      })
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Auto)
    .scrollBarColor(LightColors.BORDER)
    .scrollBarWidth(3)
    .edgeEffect(EdgeEffect.Spring)
    .cachedCount(5)
    .alignListItem(ListItemAlign.Start)
    .padding({ bottom: LIST_BOTTOM_PADDING })
    .onAppear(() => {
      if (this.isInitialScroll && this.messages.length > 0) {
        this.scrollToBottomDelayed();
        this.isInitialScroll = false;
      }
    })
  }

  /**
   * Public method to scroll the list to the bottom.
   */
  scrollToBottom(): void {
    const lastIndex: number = this.messageDataSource.totalCount() - 1;
    if (lastIndex >= 0) {
      this.scroller.scrollToIndex(lastIndex, true);
    }
  }

  private scrollToBottomDelayed(): void {
    setTimeout(() => {
      this.scrollToBottom();
    }, 100);
  }

  private getItemAlignment(msg: SessionMessage): FlexAlign {
    if (msg.eventType === MessageEventTypes.TURN_START ||
      msg.eventType === MessageEventTypes.SERVICE) {
      return CENTER_ALIGNMENT;
    }
    if (msg.role === MessageRoles.USER) {
      return USER_ALIGNMENT;
    }
    return AGENT_ALIGNMENT;
  }
}
