/**
 * WebSocket → Socket.IO 适配层
 *
 * 由于现有 eventRouter 期望 Socket.IO Socket 类型，
 * 需要适配 WebSocket 到兼容接口。
 */

import { WebSocket } from 'ws';
import { log } from '@/utils/log';

/**
 * 适配后的 Socket 接口，与 Socket.IO Socket 兼容
 */
export interface WsAdapterSocket {
    /** 发送事件到客户端 */
    emit: (event: string, data: unknown) => void;
    /** 监听客户端事件 */
    on: (event: string, handler: WsEventHandler) => void;
    /** 移除事件监听 */
    off: (event: string, handler: WsEventHandler) => void;
    /** 连接状态 */
    connected: boolean;
    /** 唯一标识 */
    id: string;
    /** 断开连接 */
    disconnect: () => void;
    /** 原始 WebSocket 实例 */
    _ws: WebSocket;
}

/**
 * 事件处理器类型
 */
export type WsEventHandler = (data: unknown, callback?: (response: unknown) => void) => void;

/**
 * WebSocket 消息帧（客户端 → 服务端）
 */
interface WsIncomingFrame {
    event: string;
    id?: string;  // 用于 ACK 的请求 ID
    data: unknown;
}

/**
 * WebSocket 消息帧（服务端 → 客户端）
 */
interface WsOutgoingFrame {
    event: string;
    id?: string;
    data: unknown;
    error?: string;
}

/**
 * 挂起的 ACK 回调
 */
interface PendingAck {
    resolve: (response: unknown) => void;
    reject: (error: Error) => void;
    timeout: NodeJS.Timeout;
}

/**
 * 适配 WebSocket 到 Socket.IO 兼容接口
 *
 * @param ws - 原始 WebSocket 实例
 * @param connectionId - 连接唯一标识
 * @returns 适配后的 Socket 对象
 */
export function adaptWebSocketToSocketIO(ws: WebSocket, connectionId: string): WsAdapterSocket {
    // 事件处理器映射
    const handlers = new Map<string, WsEventHandler>();
    // 挂起的 ACK 回调
    const pendingAcks = new Map<string, PendingAck>();

    // 监听 WebSocket 消息
    ws.on('message', (data: Buffer) => {
        try {
            const frame: WsIncomingFrame = JSON.parse(data.toString('utf-8'));
            const handler = handlers.get(frame.event);

            if (!handler) {
                log({ module: 'websocket-adapter', level: 'warn' }, `No handler for event: ${frame.event}`);
                return;
            }

            // 创建 ACK 回调
            const callback = frame.id
                ? (response: unknown) => {
                    sendAck(ws, frame.event, frame.id!, response);
                }
                : undefined;

            // 调用处理器
            handler(frame.data, callback);
        } catch (error) {
            log({ module: 'websocket-adapter', level: 'error' }, `Failed to parse message: ${error}`);
        }
    });

    // 清理挂起的 ACK
    ws.on('close', () => {
        for (const [id, ack] of pendingAcks.entries()) {
            clearTimeout(ack.timeout);
            ack.reject(new Error('Connection closed'));
            pendingAcks.delete(id);
        }
        handlers.clear();
    });

    return {
        emit: (event: string, data: unknown) => {
            if (ws.readyState === WebSocket.OPEN) {
                const frame: WsOutgoingFrame = { event, data };
                ws.send(JSON.stringify(frame));
            }
        },

        on: (event: string, handler: WsEventHandler) => {
            handlers.set(event, handler);
        },

        off: (event: string, handler?: WsEventHandler) => {
            if (handler) {
                // 移除特定处理器
                const existing = handlers.get(event);
                if (existing === handler) {
                    handlers.delete(event);
                }
            } else {
                // 移除所有该事件的处理器
                handlers.delete(event);
            }
        },

        get connected(): boolean {
            return ws.readyState === WebSocket.OPEN;
        },

        id: connectionId,

        disconnect: () => {
            ws.close();
        },

        _ws: ws
    };
}

/**
 * 发送 ACK 响应
 */
function sendAck(ws: WebSocket, originalEvent: string, id: string, data: unknown): void {
    if (ws.readyState !== WebSocket.OPEN) {
        return;
    }

    const frame: WsOutgoingFrame = {
        event: `${originalEvent}:ack`,
        id,
        data
    };

    ws.send(JSON.stringify(frame));
}

/**
 * 创建带超时的 ACK Promise
 *
 * 用于兼容 Socket.IO 的 emitWithAck 模式
 */
export function createAckPromise(
    socket: WsAdapterSocket,
    event: string,
    data: unknown,
    timeout: number
): Promise<unknown> {
    return new Promise((resolve, reject) => {
        const id = `ack_${Date.now()}_${Math.random().toString(36).slice(2)}`;

        // 设置超时
        const timer = setTimeout(() => {
            socket.off(`${event}:ack`, ackHandler);
            reject(new Error(`ACK timeout: ${event}`));
        }, timeout);

        // ACK 处理器
        const ackHandler = (response: unknown) => {
            clearTimeout(timer);
            resolve(response);
        };

        // 注册临时 ACK 监听
        socket.on(`${event}:ack`, ackHandler);

        // 发送请求
        const dataWithAck = typeof data === 'object' && data !== null ? { ...data, _ackId: id } : { _ackId: id };
        socket.emit(event, dataWithAck);
    });
}
