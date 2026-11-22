# Real-Time Audio Sharing Signaling Server

Lightweight, high-performance Node.js & WebSocket signaling server for WebRTC peer-to-peer session coordination and audio relay fallback.

## Features

- **Session Management**: Dynamic 6-character code generation or custom session codes.
- **WebRTC Signaling**: SDP Offer/Answer negotiation and ICE Candidate forwarding.
- **Access Control**: Sender approval step before incoming receivers can connect.
- **Relay Fallback**: Automatic WebSocket audio chunk relay for symmetric NAT environments where WebRTC P2P is blocked.
- **Mobile Heartbeat**: Periodic ping/pong to keep connections alive through mobile carrier network NATs.
- **Health Check Endpoint**: `GET /health` returns JSON server status and active session count.

## Quick Start (Local Run)

1. Navigate to the `server` directory:
   ```bash
   cd server
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Start the server:
   ```bash
   npm start
   ```

The server will listen on `http://0.0.0.0:8080`.
- Health check: `http://localhost:8080/health`
- WebSocket endpoint: `ws://<your-computer-ip>:8080` (e.g., `ws://192.168.1.100:8080`)

> **Note for testing on physical Android phones**: Both phones and the computer running the server must be on the same Wi-Fi network. Find your computer's local IP (via `ipconfig` on Windows or `ifconfig` on Linux/Mac) and set it in the Flutter app settings.

## Deploying to Cloud (Free & Production)

### 1. Render.com (Recommended - Free)
1. Fork or push this repository to GitHub.
2. In [Render Dashboard](https://dashboard.render.com), click **New +** -> **Web Service**.
3. Connect your repository.
4. Set:
   - **Root Directory**: `server`
   - **Environment**: `Node`
   - **Build Command**: `npm install`
   - **Start Command**: `npm start`
5. Click **Create Web Service**. Render gives you a free HTTPS/WSS URL:
   `wss://your-service-name.onrender.com`

### 2. Railway.app
1. Create a new project in Railway.
2. Deploy from GitHub repo with root directory `server`.
3. Railway automatically sets `PORT` and provides a public domain with SSL.

### 3. Docker Deployment
```bash
docker run -d -p 8080:8080 --name audio-sharing-signaling node:18-alpine sh -c "cd /app && npm install && npm start"
```
