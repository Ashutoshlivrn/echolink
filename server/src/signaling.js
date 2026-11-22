/**
 * WebRTC Signaling Manager
 * Manages active sessions, peer coordination, offer/answer, and ICE candidate exchange.
 */

class SignalingManager {
  constructor() {
    // Map of sessionId -> Session
    this.sessions = new Map();
    // Map of ws -> { role: 'sender'|'receiver', sessionId, peerId }
    this.clients = new WeakMap();

    // Session expiration cleaner (every 60 seconds)
    setInterval(() => this.cleanupExpiredSessions(), 60000);
  }

  generateSessionId() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Avoid confusing chars like 0, O, 1, I
    let id = '';
    do {
      id = '';
      for (let i = 0; i < 6; i++) {
        id += chars.charAt(Math.floor(Math.random() * chars.length));
      }
    } while (this.sessions.has(id));
    return id;
  }

  handleConnection(ws) {
    ws.isAlive = true;
    ws.on('pong', () => {
      ws.isAlive = true;
    });

    ws.on('message', (data) => {
      try {
        const message = JSON.parse(data.toString());
        this.handleMessage(ws, message);
      } catch (err) {
        console.error('[Signaling] Invalid JSON received:', err.message);
        this.send(ws, { type: 'error', message: 'Invalid JSON payload' });
      }
    });

    ws.on('close', () => {
      this.handleDisconnect(ws);
    });

    ws.on('error', (err) => {
      console.error('[Signaling] WebSocket error:', err.message);
    });
  }

  handleMessage(ws, msg) {
    const { type, sessionId, payload } = msg;

    switch (type) {
      case 'create-session':
        this.onCreateSession(ws, payload);
        break;

      case 'join-session':
        this.onJoinSession(ws, sessionId, payload);
        break;

      case 'accept-request':
        this.onAcceptRequest(ws, sessionId, payload);
        break;

      case 'reject-request':
        this.onRejectRequest(ws, sessionId, payload);
        break;

      case 'webrtc-offer':
        this.onWebRtcOffer(ws, sessionId, payload);
        break;

      case 'webrtc-answer':
        this.onWebRtcAnswer(ws, sessionId, payload);
        break;

      case 'ice-candidate':
        this.onIceCandidate(ws, sessionId, payload);
        break;

      case 'audio-relay':
        this.onAudioRelay(ws, sessionId, payload);
        break;

      case 'mic-relay':
        this.onMicRelay(ws, sessionId, payload);
        break;

      case 'mic-state-changed':
        this.onMicStateChanged(ws, sessionId, payload);
        break;

      case 'leave-session':
        this.onLeaveSession(ws, sessionId);
        break;

      case 'ping':
        this.send(ws, { type: 'pong', timestamp: Date.now() });
        break;

      default:
        console.warn('[Signaling] Unknown message type:', type);
        this.send(ws, { type: 'error', message: `Unknown message type: ${type}` });
    }
  }

  onCreateSession(ws, payload = {}) {
    const sessionId = (payload.customId || this.generateSessionId()).toUpperCase().trim();
    const senderId = payload.senderId || `sender-${Date.now()}`;
    const deviceName = payload.deviceName || 'Android Host Device';

    if (this.sessions.has(sessionId)) {
      return this.send(ws, {
        type: 'session-created-failed',
        message: 'Session ID is already in use. Please try again.'
      });
    }

    const session = {
      id: sessionId,
      senderWs: ws,
      senderId,
      deviceName,
      receivers: new Map(), // receiverId -> { ws, name, status }
      createdAt: Date.now(),
      lastActivity: Date.now()
    };

    this.sessions.set(sessionId, session);
    this.clients.set(ws, { role: 'sender', sessionId, peerId: senderId });

    console.log(`[Signaling] Created session: ${sessionId} by ${deviceName} (${senderId})`);

    this.send(ws, {
      type: 'session-created',
      sessionId,
      senderId,
      message: 'Session created successfully. Waiting for participants.'
    });
  }

  onJoinSession(ws, sessionId, payload = {}) {
    const normSessionId = (sessionId || '').toUpperCase().trim();
    const session = this.sessions.get(normSessionId);

    if (!session) {
      return this.send(ws, {
        type: 'join-failed',
        message: 'Session not found or has expired. Please verify the Session ID.'
      });
    }

    const receiverId = payload.receiverId || `receiver-${Date.now()}`;
    const deviceName = payload.deviceName || 'Android Friend Device';

    // Store receiver entry
    session.receivers.set(receiverId, {
      ws,
      name: deviceName,
      status: 'pending',
      joinedAt: Date.now()
    });

    session.lastActivity = Date.now();
    this.clients.set(ws, { role: 'receiver', sessionId: normSessionId, peerId: receiverId });

    console.log(`[Signaling] Receiver ${receiverId} (${deviceName}) requesting to join ${normSessionId}`);

    // Notify receiver that request is sent
    this.send(ws, {
      type: 'join-pending',
      sessionId: normSessionId,
      receiverId,
      senderDevice: session.deviceName,
      message: 'Connection request sent to sender. Awaiting approval...'
    });

    // Notify sender of connection request
    this.send(session.senderWs, {
      type: 'connection-request',
      sessionId: normSessionId,
      receiver: {
        id: receiverId,
        name: deviceName
      }
    });
  }

  onAcceptRequest(ws, sessionId, payload = {}) {
    const session = this.sessions.get(sessionId);
    if (!session || session.senderWs !== ws) {
      return;
    }

    const { receiverId } = payload;
    const receiver = session.receivers.get(receiverId);

    if (!receiver) {
      return this.send(ws, { type: 'error', message: 'Receiver not found' });
    }

    receiver.status = 'accepted';
    session.lastActivity = Date.now();

    console.log(`[Signaling] Sender approved receiver ${receiverId} in session ${sessionId}`);

    // Notify receiver that they are accepted
    this.send(receiver.ws, {
      type: 'connection-accepted',
      sessionId,
      senderId: session.senderId,
      message: 'Connection accepted! Establishing WebRTC audio stream...'
    });

    // Notify sender to begin WebRTC offer creation
    this.send(ws, {
      type: 'receiver-accepted',
      receiverId,
      message: 'Ready to create WebRTC offer'
    });
  }

  onRejectRequest(ws, sessionId, payload = {}) {
    const session = this.sessions.get(sessionId);
    if (!session || session.senderWs !== ws) return;

    const { receiverId, reason } = payload;
    const receiver = session.receivers.get(receiverId);

    if (receiver) {
      this.send(receiver.ws, {
        type: 'connection-rejected',
        message: reason || 'Connection request was declined by the sender.'
      });
      session.receivers.delete(receiverId);
    }
  }

  onWebRtcOffer(ws, sessionId, payload = {}) {
    const session = this.sessions.get(sessionId);
    if (!session) return;

    const clientMeta = this.clients.get(ws);
    const { targetReceiverId, sdp } = payload;

    if (clientMeta?.role === 'sender') {
      const receiver = session.receivers.get(targetReceiverId);
      if (receiver && receiver.ws) {
        this.send(receiver.ws, {
          type: 'webrtc-offer',
          senderId: session.senderId,
          sdp
        });
      }
    } else {
      if (session.senderWs) {
        this.send(session.senderWs, {
          type: 'webrtc-offer',
          senderId: clientMeta?.peerId,
          sdp
        });
      }
    }
  }

  onWebRtcAnswer(ws, sessionId, payload = {}) {
    const session = this.sessions.get(sessionId);
    if (!session) return;

    const clientMeta = this.clients.get(ws);
    const { sdp, receiverId } = payload;

    if (clientMeta?.role === 'sender') {
      const receiver = session.receivers.get(receiverId);
      if (receiver && receiver.ws) {
        this.send(receiver.ws, {
          type: 'webrtc-answer',
          sdp
        });
      }
    } else {
      if (session.senderWs) {
        this.send(session.senderWs, {
          type: 'webrtc-answer',
          receiverId: clientMeta?.peerId,
          sdp
        });
      }
    }
  }

  onIceCandidate(ws, sessionId, payload = {}) {
    const session = this.sessions.get(sessionId);
    if (!session) return;

    const { targetId, candidate } = payload;
    const clientMeta = this.clients.get(ws);

    if (clientMeta?.role === 'sender') {
      // Forward to specific receiver
      const receiver = session.receivers.get(targetId);
      if (receiver && receiver.ws) {
        this.send(receiver.ws, {
          type: 'ice-candidate',
          from: session.senderId,
          candidate
        });
      }
    } else {
      // Forward to sender
      this.send(session.senderWs, {
        type: 'ice-candidate',
        from: clientMeta?.peerId,
        candidate
      });
    }
  }

  onAudioRelay(ws, sessionId, payload = {}) {
    // Fallback: If WebRTC P2P fails due to strict symmetric NAT,
    // sender can stream chunks through WebSocket to connected accepted receivers.
    const session = this.sessions.get(sessionId);
    if (!session || session.senderWs !== ws) return;

    for (const [_, receiver] of session.receivers.entries()) {
      if (receiver.status === 'accepted' && receiver.ws) {
        this.send(receiver.ws, {
          type: 'audio-relay',
          data: payload.data
        });
      }
    }
  }

  onMicRelay(ws, sessionId, payload = {}) {
    const session = this.sessions.get(sessionId);
    if (!session) return;
    const clientMeta = this.clients.get(ws);

    if (clientMeta?.role === 'sender') {
      for (const [_, receiver] of session.receivers.entries()) {
        if (receiver.status === 'accepted' && receiver.ws) {
          this.send(receiver.ws, {
            type: 'mic-relay',
            data: payload.data
          });
        }
      }
    } else {
      if (session.senderWs) {
        this.send(session.senderWs, {
          type: 'mic-relay',
          data: payload.data
        });
      }
    }
  }

  onMicStateChanged(ws, sessionId, payload = {}) {
    const session = this.sessions.get(sessionId);
    if (!session) return;

    const { participantId, isMicEnabled } = payload;
    const clientMeta = this.clients.get(ws);

    const message = {
      type: 'mic-state-changed',
      participantId: participantId || clientMeta?.peerId,
      isMicEnabled: !!isMicEnabled
    };

    if (clientMeta?.role === 'receiver') {
      if (session.senderWs) {
        this.send(session.senderWs, message);
      }
    } else if (clientMeta?.role === 'sender') {
      for (const [_, receiver] of session.receivers.entries()) {
        if (receiver.status === 'accepted' && receiver.ws) {
          this.send(receiver.ws, message);
        }
      }
    }
  }

  onLeaveSession(ws, sessionId) {
    this.handleDisconnect(ws);
  }

  handleDisconnect(ws) {
    const meta = this.clients.get(ws);
    if (!meta) return;

    const { role, sessionId, peerId } = meta;
    const session = this.sessions.get(sessionId);

    if (role === 'sender' && session && session.senderWs === ws) {
      console.log(`[Signaling] Sender disconnected. Terminating session ${sessionId}`);
      // Notify all receivers
      for (const [_, receiver] of session.receivers.entries()) {
        if (receiver.ws) {
          this.send(receiver.ws, {
            type: 'session-closed',
            message: 'Sender has ended the audio sharing session.'
          });
        }
      }
      this.sessions.delete(sessionId);
    } else if (role === 'receiver' && session) {
      console.log(`[Signaling] Receiver ${peerId} left session ${sessionId}`);
      session.receivers.delete(peerId);
      // Notify sender
      if (session.senderWs) {
        this.send(session.senderWs, {
          type: 'receiver-disconnected',
          receiverId: peerId
        });
      }
    }

    this.clients.delete(ws);
  }

  cleanupExpiredSessions() {
    const now = Date.now();
    const timeout = 2 * 60 * 60 * 1000; // 2 hours of complete inactivity

    for (const [sessionId, session] of this.sessions.entries()) {
      if (now - session.lastActivity > timeout) {
        console.log(`[Signaling] Cleaning up inactive session ${sessionId}`);
        this.sessions.delete(sessionId);
      }
    }
  }

  send(ws, object) {
    if (ws && ws.readyState === 1) { // WebSocket.OPEN
      try {
        ws.send(JSON.stringify(object));
      } catch (err) {
        console.error('[Signaling] Error sending message:', err.message);
      }
    }
  }

  getActiveSessionsCount() {
    return this.sessions.size;
  }
}

module.exports = { SignalingManager };
