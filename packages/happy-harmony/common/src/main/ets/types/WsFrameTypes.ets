/**
 * WebSocket frame types for real-time communication.
 * These are the JSON payloads sent/received over the WebSocket connection.
 */

/** Frame sent from client to server. */
export class WsIncomingFrame {
  event: string = '';
  id: string = '';
  data: string = '';

  constructor(event: string, data: string = '', id: string = '') {
    this.event = event;
    this.data = data;
    this.id = id;
  }
}

/** Frame received from server to client. */
export class WsOutgoingFrame {
  event: string = '';
  id: string = '';
  data: string = '';
  error: string = '';

  constructor(event: string = '', data: string = '', id: string = '', error: string = '') {
    this.event = event;
    this.data = data;
    this.id = id;
    this.error = error;
  }
}
