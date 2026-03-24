/**
 * WebSocket 消息处理器
 *
 * 处理来自鸿蒙客户端的 WebSocket 消息，
 * 复用现有 Socket.IO handler 逻辑。
 */

import { log } from '@/utils/log';
import { buildUpdateSessionUpdate, ClientConnection, eventRouter } from '@/app/events/eventRouter';
import { randomKeyNaked } from '@/utils/randomKeyNaked';
import { db } from '@/storage/db';
import { allocateSessionSeq, allocateUserSeq } from '@/storage/seq';
import { WsAdapterSocket } from './wsAdapters';

/**
 * Ping 处理器
 *
 * 处理客户端心跳请求，立即返回 pong。
 */
export function wsPingHandler(socket: WsAdapterSocket): void {
    socket.on('ping', (data: unknown, callback?: (response: unknown) => void) => {
        try {
            callback?.({});
        } catch (error) {
            log({ module: 'websocket', level: 'error' }, `Error in ping: ${error}`);
        }
    });
}

/**
 * RPC 处理器
 *
 * 处理客户端 RPC 调用请求。
 * 复用现有 Socket.IO RPC 逻辑。
 */
export function wsRpcHandler(
    userId: string,
    socket: WsAdapterSocket,
    rpcListeners: Map<string, WsAdapterSocket>
): void {
    // RPC 调用
    socket.on('rpc-call', async (data: unknown, callback?: (response: unknown) => void) => {
        try {
            const { method, params } = data as { method?: string; params?: unknown };

            if (!method || typeof method !== 'string') {
                callback?.({ ok: false, error: 'Invalid parameters: method is required' });
                return;
            }

            const targetSocket = rpcListeners.get(method);

            if (!targetSocket || !targetSocket.connected) {
                callback?.({ ok: false, error: 'RPC method not available' });
                return;
            }

            // 不允许自己调用自己
            if (targetSocket === socket) {
                callback?.({ ok: false, error: 'Cannot call RPC on the same socket' });
                return;
            }

            // 转发 RPC 请求到目标 socket
            const startTime = Date.now();

            try {
                // 使用 emitWithAck 模式（通过适配层）
                const response = await emitWithAck(targetSocket, 'rpc-request', { method, params }, 30000);

                const duration = Date.now() - startTime;
                log({ module: 'websocket-rpc' }, `RPC call succeeded: ${method} (${duration}ms)`);

                callback?.({ ok: true, result: response });
            } catch (error) {
                const duration = Date.now() - startTime;
                const errorMsg = error instanceof Error ? error.message : 'RPC call failed';

                log({ module: 'websocket-rpc', level: 'error' }, `RPC call failed: ${method} - ${errorMsg} (${duration}ms)`);

                callback?.({ ok: false, error: errorMsg });
            }
        } catch (error) {
            log({ module: 'websocket', level: 'error' }, `Error in rpc-call: ${error}`);
            callback?.({ ok: false, error: 'Internal error' });
        }
    });

    // RPC 注册（供 daemon/CLI 使用）
    socket.on('rpc-register', async (data: unknown, callback?: (response: unknown) => void) => {
        try {
            const { method } = data as { method?: string };

            if (!method || typeof method !== 'string') {
                socket.emit('rpc-error', { type: 'register', error: 'Invalid method name' });
                return;
            }

            const previousSocket = rpcListeners.get(method);
            if (previousSocket && previousSocket !== socket) {
                // 重新注册
            }

            rpcListeners.set(method, socket);
            socket.emit('rpc-registered', { method });
        } catch (error) {
            log({ module: 'websocket', level: 'error' }, `Error in rpc-register: ${error}`);
            socket.emit('rpc-error', { type: 'register', error: 'Internal error' });
        }
    });

    // RPC 注销
    socket.on('rpc-unregister', async (data: unknown, callback?: (response: unknown) => void) => {
        try {
            const { method } = data as { method?: string };

            if (!method || typeof method !== 'string') {
                socket.emit('rpc-error', { type: 'unregister', error: 'Invalid method name' });
                return;
            }

            if (rpcListeners.get(method) === socket) {
                rpcListeners.delete(method);
            }

            socket.emit('rpc-unregistered', { method });
        } catch (error) {
            log({ module: 'websocket', level: 'error' }, `Error in rpc-unregister: ${error}`);
            socket.emit('rpc-error', { type: 'unregister', error: 'Internal error' });
        }
    });

    // 断开时清理
    socket._ws.on('close', () => {
        const methodsToRemove: string[] = [];
        for (const [method, registeredSocket] of rpcListeners.entries()) {
            if (registeredSocket === socket) {
                methodsToRemove.push(method);
            }
        }

        methodsToRemove.forEach(method => rpcListeners.delete(method));

        if (rpcListeners.size === 0) {
            rpcListeners.delete(userId);
        }
    });
}

/**
 * Session 更新处理器
 *
 * 处理会话元数据、状态更新、消息发送等。
 */
export function wsSessionUpdateHandler(
    userId: string,
    socket: WsAdapterSocket,
    connection: ClientConnection
): void {
    // 更新会话元数据
    socket.on('update-metadata', async (data: unknown, callback?: (response: unknown) => void) => {
        try {
            const { sid, metadata, expectedVersion } = data as {
                sid?: string;
                metadata?: string;
                expectedVersion?: number;
            };

            if (!sid || typeof metadata !== 'string' || typeof expectedVersion !== 'number') {
                callback?.({ result: 'error' });
                return;
            }

            const session = await db.session.findUnique({
                where: { id: sid, accountId: userId }
            });
            if (!session) {
                return;
            }

            // 版本检查
            if (session.metadataVersion !== expectedVersion) {
                callback?.({ result: 'version-mismatch', version: session.metadataVersion, metadata: session.metadata });
                return;
            }

            // 更新
            const { count } = await db.session.updateMany({
                where: { id: sid, metadataVersion: expectedVersion },
                data: { metadata, metadataVersion: expectedVersion + 1 }
            });

            if (count === 0) {
                callback?.({ result: 'version-mismatch', version: session.metadataVersion, metadata: session.metadata });
                return;
            }

            // 发送更新事件
            const updSeq = await allocateUserSeq(userId);
            const metadataUpdate = { value: metadata, version: expectedVersion + 1 };
            const updatePayload = buildUpdateSessionUpdate(sid, updSeq, randomKeyNaked(12), metadataUpdate);
            eventRouter.emitUpdate({
                userId,
                payload: updatePayload,
                recipientFilter: { type: 'all-interested-in-session', sessionId: sid }
            });

            callback?.({ result: 'success', version: expectedVersion + 1, metadata });
        } catch (error) {
            log({ module: 'websocket', level: 'error' }, `Error in update-metadata: ${error}`);
            callback?.({ result: 'error' });
        }
    });

    // 更新 Agent 状态
    socket.on('update-state', async (data: unknown, callback?: (response: unknown) => void) => {
        try {
            const { sid, agentState, expectedVersion } = data as {
                sid?: string;
                agentState?: string | null;
                expectedVersion?: number;
            };

            if (!sid || (typeof agentState !== 'string' && agentState !== null) || typeof expectedVersion !== 'number') {
                callback?.({ result: 'error' });
                return;
            }

            const session = await db.session.findUnique({
                where: { id: sid, accountId: userId }
            });
            if (!session) {
                callback?.({ result: 'error' });
                return;
            }

            if (session.agentStateVersion !== expectedVersion) {
                callback?.({ result: 'version-mismatch', version: session.agentStateVersion, agentState: session.agentState });
                return;
            }

            const { count } = await db.session.updateMany({
                where: { id: sid, agentStateVersion: expectedVersion },
                data: { agentState, agentStateVersion: expectedVersion + 1 }
            });

            if (count === 0) {
                callback?.({ result: 'version-mismatch', version: session.agentStateVersion, agentState: session.agentState });
                return;
            }

            const updSeq = await allocateUserSeq(userId);
            // 处理 null 值 - buildUpdateSessionUpdate 不接受 null value
            if (agentState !== null) {
                const agentStateUpdate = { value: agentState, version: expectedVersion + 1 };
                const updatePayload = buildUpdateSessionUpdate(sid, updSeq, randomKeyNaked(12), undefined, agentStateUpdate);
                eventRouter.emitUpdate({
                    userId,
                    payload: updatePayload,
                    recipientFilter: { type: 'all-interested-in-session', sessionId: sid }
                });
            }

            callback?.({ result: 'success', version: expectedVersion + 1, agentState });
        } catch (error) {
            log({ module: 'websocket', level: 'error' }, `Error in update-state: ${error}`);
            callback?.({ result: 'error' });
        }
    });
}

/**
 * 消息发送处理器
 *
 * 处理客户端发送的消息。
 * 注意：也可通过 REST API /v3/sessions/:id/messages 发送。
 */
export function wsMessageHandler(
    userId: string,
    socket: WsAdapterSocket,
    connection: ClientConnection
): void {
    socket.on('message', async (data: unknown) => {
        try {
            const { sid, message, localId } = data as {
                sid?: string;
                message?: string;
                localId?: string;
            };

            if (!sid || !message) {
                return;
            }

            log({ module: 'websocket' }, `Received message: sessionId=${sid}, connectionType=${connection.connectionType}`);

            const session = await db.session.findUnique({
                where: { id: sid, accountId: userId }
            });
            if (!session) {
                return;
            }

            const useLocalId = typeof localId === 'string' ? localId : null;

            // 创建加密消息
            const msgContent: PrismaJson.SessionMessageContent = {
                t: 'encrypted',
                c: message
            };

            // 分配 seq
            const updSeq = await allocateUserSeq(userId);
            const msgSeq = await allocateSessionSeq(sid);

            // 检查是否已存在（幂等）
            if (useLocalId) {
                const existing = await db.sessionMessage.findFirst({
                    where: { sessionId: sid, localId: useLocalId }
                });
                if (existing) {
                    return;
                }
            }

            // 创建消息
            const msg = await db.sessionMessage.create({
                data: {
                    sessionId: sid,
                    seq: msgSeq,
                    content: msgContent,
                    localId: useLocalId
                }
            });

            // 发送更新事件
            const { buildNewMessageUpdate } = await import('@/app/events/eventRouter');
            const updatePayload = buildNewMessageUpdate(msg, sid, updSeq, randomKeyNaked(12));
            eventRouter.emitUpdate({
                userId,
                payload: updatePayload,
                recipientFilter: { type: 'all-interested-in-session', sessionId: sid },
                skipSenderConnection: connection
            });
        } catch (error) {
            log({ module: 'websocket', level: 'error' }, `Error in message handler: ${error}`);
        }
    });
}

/**
 * 辅助函数：emitWithAck
 *
 * 由于 WebSocket 不原生支持 ACK，需要手动实现。
 */
async function emitWithAck(
    socket: WsAdapterSocket,
    event: string,
    data: unknown,
    timeout: number
): Promise<unknown> {
    return new Promise((resolve, reject) => {
        const ackId = `ack_${Date.now()}_${Math.random().toString(36).slice(2)}`;

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

        // 注册 ACK 监听
        socket.on(`${event}:ack`, ackHandler);

        // 发送请求（附加 ackId 用于匹配）
        const dataWithAck = typeof data === 'object' && data !== null ? { ...data, _ackId: ackId } : data;
        socket.emit(event, dataWithAck);
    });
}
