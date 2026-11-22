const http = require('http');
const { WebSocketServer } = require('ws');
const { SignalingManager } = require('./signaling');

const PORT = process.env.PORT || 8080;
const signalingManager = new SignalingManager();

// Create standard HTTP server for health checks and status
const server = http.createServer((req, res) => {
  // Enable CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  if (req.url === '/' || req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(
      JSON.stringify({
        status: 'online',
        service: 'Audio Sharing WebRTC Signaling Server',
        activeSessions: signalingManager.getActiveSessionsCount(),
        uptimeSeconds: Math.floor(process.uptime()),
        timestamp: new Date().toISOString()
      })
    );
    return;
  }

  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'Not found' }));
});

// Attach WebSocket Server
const wss = new WebSocketServer({ server });

wss.on('connection', (ws, req) => {
  const clientIp = req.socket.remoteAddress;
  console.log(`[Server] New WebSocket connection from ${clientIp}`);
  signalingManager.handleConnection(ws);
});

// Heartbeat ping interval to keep mobile sockets alive across cell towers/NATs
const heartbeatInterval = setInterval(() => {
  wss.clients.forEach((ws) => {
    if (ws.isAlive === false) {
      console.log('[Server] Terminating unresponsive client');
      return ws.terminate();
    }
    ws.isAlive = false;
    ws.ping();
  });
}, 30000);

wss.on('close', () => {
  clearInterval(heartbeatInterval);
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`====================================================`);
  console.log(`  Audio Sharing Signaling Server running!`);
  console.log(`  HTTP Health Check: http://localhost:${PORT}/health`);
  console.log(`  WebSocket URL:     ws://localhost:${PORT}`);
  console.log(`====================================================`);
});
