/**
 * WebSocket 传输层
 *
 * 为鸿蒙客户端提供独立的 WebSocket 通道，
 * 与现有 Socket.IO 共存，复用认证和事件路由逻辑。
 */

import { WebSocketServer, WebSocket } from 'ws';
import { IncomingMessage } from 'http';
import { URL } from 'url';
import { onShutdown } from '@/utils/shutdown';
import { Fastify } from './types';
import { log } from '@/utils/log';
import { auth } from '@/app/auth/auth';
import { eventRouter, ClientConnection, buildMachineActivityEphemeral } from '@/app/events/eventRouter';
import { adaptWebSocketToSocketIO, WsAdapterSocket } from './wsAdapters';
import { wsPingHandler, wsRpcHandler, wsSessionUpdateHandler, wsMessageHandler } from './wsHandlers';
import { incrementWebSocketConnection, decrementWebSocketConnection } from '../monitoring/metrics2';
import { sessionAliveEventsCounter, websocketEventsCounter } from '../monitoring/metrics2';
import { buildSessionActivityEphemeral } from '@/app/events/eventRouter';
import { activityCache } from '@/app/presence/sessionCache';
import { db } from '@/storage/db';

/**
 * 启动 WebSocket 服务器
 *
 * @param app - Fastify 应用实例
 */
export function startWebSocket(app: Fastify): void {
    const wss = new WebSocketServer({
        noServer: true,  // 手动升级 HTTP 连接
        path: '/v1/ws'   // WebSocket 路径（与 Socket.IO 的 /v1/updates 区分）
    });

    // RPC 监听器映射（用户 ID → 方法名 → Socket）
    const rpcListeners = new Map<string, Map<string, WsAdapterSocket>>();

    // 手动升级 HTTP 连接到 WebSocket
    app.server.on('upgrade', (request: IncomingMessage, socket: any, head: Buffer) => {
        const { pathname } = new URL(request.url || '', `http://${request.headers.host}`);

        // 只处理 /v1/ws 路径
        if (pathname === '/v1/ws') {
            wss.handleUpgrade(request, socket, head, (ws: WebSocket) => {
                wss.emit('connection', ws, request);
            });
        }
        // 其他路径（如 /v1/updates）由 Socket.IO 处理
    });

    // 连接处理
    wss.on('connection', async (ws: WebSocket, request: IncomingMessage) => {
        log({ module: 'websocket' }, `New WebSocket connection attempt`);

        // 从 URL query 获取认证参数
        const url = new URL(request.url || '', `http://${request.headers.host}`);
        const token = url.searchParams.get('token');
        const clientType = url.searchParams.get('clientType') as 'session-scoped' | 'user-scoped' | 'machine-scoped' | null;
        const sessionId = url.searchParams.get('sessionId');
        const machineId = url.searchParams.get('machineId');

        // 验证 token
        if (!token) {
            log({ module: 'websocket' }, `No token provided`);
            sendError(ws, 'Missing authentication token');
            ws.close();
            return;
        }

        // 验证 session-scoped 客户端有 sessionId
        if (clientType === 'session-scoped' && !sessionId) {
            log({ module: 'websocket' }, `Session-scoped client missing sessionId`);
            sendError(ws, 'Session ID required for session-scoped clients');
            ws.close();
            return;
        }

        // 验证 machine-scoped 客户端有 machineId
        if (clientType === 'machine-scoped' && !machineId) {
            log({ module: 'websocket' }, `Machine-scoped client missing machineId`);
            sendError(ws, 'Machine ID required for machine-scoped clients');
            ws.close();
            return;
        }

        // 验证 token
        const verified = await auth.verifyToken(token);
        if (!verified) {
            log({ module: 'websocket' }, `Invalid token provided`);
            sendError(ws, 'Invalid authentication token');
            ws.close();
            return;
        }

        const userId = verified.userId;
        const finalClientType = clientType || 'user-scoped';

        log({ module: 'websocket' }, `WebSocket connection established: userId=${userId}, clientType=${finalClientType}, sessionId=${sessionId || 'none'}, machineId=${machineId || 'none'}`);

        // 适配 WebSocket 到 Socket.IO 接口
        const connectionId = `ws_${userId}_${Date.now()}_${Math.random().toString(36).slice(2)}`;
        const adaptedSocket = adaptWebSocketToSocketIO(ws, connectionId);

        // 创建连接对象
        let connection: ClientConnection;
        if (finalClientType === 'session-scoped' && sessionId) {
            connection = {
                connectionType: 'session-scoped',
                socket: adaptedSocket as any,
                userId,
                sessionId
            };
        } else if (finalClientType === 'machine-scoped' && machineId) {
            connection = {
                connectionType: 'machine-scoped',
                socket: adaptedSocket as any,
                userId,
                machineId
            };
        } else {
            connection = {
                connectionType: 'user-scoped',
                socket: adaptedSocket as any,
                userId
            };
        }

        // 添加到事件路由
        eventRouter.addConnection(userId, connection);
        incrementWebSocketConnection(connection.connectionType);

        // 广播 daemon 在线状态
        if (connection.connectionType === 'machine-scoped') {
            const machineActivity = buildMachineActivityEphemeral(machineId!, true, Date.now());
            eventRouter.emitEphemeral({
                userId,
                payload: machineActivity,
                recipientFilter: { type: 'user-scoped-only' }
            });
        }

        // 断开处理
        ws.on('close', () => {
            websocketEventsCounter.inc({ event_type: 'disconnect' });

            eventRouter.removeConnection(userId, connection);
            decrementWebSocketConnection(connection.connectionType);

            log({ module: 'websocket' }, `WebSocket disconnected: userId=${userId}`);

            // 广播 daemon 离线状态
            if (connection.connectionType === 'machine-scoped') {
                const machineActivity = buildMachineActivityEphemeral(connection.machineId, false, Date.now());
                eventRouter.emitEphemeral({
                    userId,
                    payload: machineActivity,
                    recipientFilter: { type: 'user-scoped-only' }
                });
            }
        });

        // 错误处理
        ws.on('error', (error: Error) => {
            log({ module: 'websocket', level: 'error' }, `WebSocket error: ${error.message}`);
        });

        // 注册 RPC 监听器映射
        if (!rpcListeners.has(userId)) {
            rpcListeners.set(userId, new Map());
        }

        // 注册处理器
        let userRpcListeners = rpcListeners.get(userId)!;
        wsPingHandler(adaptedSocket);
        wsRpcHandler(userId, adaptedSocket, userRpcListeners);
        wsSessionUpdateHandler(userId, adaptedSocket, connection);
        wsMessageHandler(userId, adaptedSocket, connection);

        // session-alive 处理
        adaptedSocket.on('session-alive', async (data: unknown) => {
            try {
                websocketEventsCounter.inc({ event_type: 'session-alive' });
                sessionAliveEventsCounter.inc();

                const { sid, time, thinking } = data as { sid?: string; time?: number; thinking?: boolean };

                if (!sid || typeof time !== 'number') {
                    return;
                }

                let t = time;
                if (t > Date.now()) t = Date.now();
                if (t < Date.now() - 1000 * 60 * 10) return;

                const isValid = await activityCache.isSessionValid(sid, userId);
                if (!isValid) return;

                activityCache.queueSessionUpdate(sid, t);

                const sessionActivity = buildSessionActivityEphemeral(sid, true, t, thinking || false);
                eventRouter.emitEphemeral({
                    userId,
                    payload: sessionActivity,
                    recipientFilter: { type: 'user-scoped-only' }
                });
            } catch (error) {
                log({ module: 'websocket', level: 'error' }, `Error in session-alive: ${error}`);
            }
        });

        // session-end 处理
        adaptedSocket.on('session-end', async (data: unknown) => {
            try {
                const { sid, time } = data as { sid?: string; time?: number };

                if (!sid || typeof time !== 'number') {
                    return;
                }

                let t = time;
                if (t > Date.now()) t = Date.now();
                if (t < Date.now() - 1000 * 60 * 10) return;

                const session = await db.session.findUnique({
                    where: { id: sid, accountId: userId }
                });
                if (!session) return;

                await db.session.update({
                    where: { id: sid },
                    data: { lastActiveAt: new Date(t), active: false }
                });

                const sessionActivity = buildSessionActivityEphemeral(sid, false, t, false);
                eventRouter.emitEphemeral({
                    userId,
                    payload: sessionActivity,
                    recipientFilter: { type: 'user-scoped-only' }
                });
            } catch (error) {
                log({ module: 'websocket', level: 'error' }, `Error in session-end: ${error}`);
            }
        });

        log({ module: 'websocket' }, `WebSocket handlers registered: userId=${userId}`);
    });

    // 优雅关闭
    onShutdown('websocket', async () => {
        log({ module: 'websocket' }, 'Shutting down WebSocket server...');
        wss.close();
    });

    log({ module: 'websocket' }, 'WebSocket server started on path /v1/ws');
}

/**
 * 发送错误消息到客户端
 */
function sendError(ws: WebSocket, message: string): void {
    if (ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({
            event: 'error',
            data: { message }
        }));
    }
}
