const statusEl = document.getElementById('status');
const versionEl = document.getElementById('version');
const connectButton = document.getElementById('connect');
let socket = null;
let requestId = 1;
const pendingRequests = {};
let useLegacy = false;

function updateStatus(message, type = 'info') {
    statusEl.textContent = message;
    statusEl.className = `status ${type}`;
}

function updateVersion(message) {
    versionEl.textContent = message;
}

function sendJSON(payload) {
    if (!socket || socket.readyState !== WebSocket.OPEN) {
        updateStatus('WebSocket not open', 'error');
        return;
    }
    socket.send(JSON.stringify(payload));
}

function sendRequest(requestType, requestData = {}) {
    const requestIdText = 'req_' + requestId++;
    const payload = useLegacy
        ? { 'request-type': requestType, 'message-id': requestIdText, ...requestData }
        : { op: 6, d: { requestType, requestId: requestIdText, requestData } };

    return new Promise((resolve, reject) => {
        pendingRequests[requestIdText] = { resolve, reject };
        sendJSON(payload);
        setTimeout(() => {
            if (pendingRequests[requestIdText]) {
                reject('Request timed out: ' + requestType);
                delete pendingRequests[requestIdText];
            }
        }, 8000);
    });
}

function bufferToBase64(buffer) {
    let binary = '';
    const bytes = new Uint8Array(buffer);
    bytes.forEach((b) => binary += String.fromCharCode(b));
    return btoa(binary);
}

async function sha256Base64(message) {
    const data = new TextEncoder().encode(message);
    const digest = await crypto.subtle.digest('SHA-256', data);
    return bufferToBase64(digest);
}

async function connectWebSocket() {
    const host = document.getElementById('host').value.trim();
    const port = document.getElementById('port').value.trim();
    const password = document.getElementById('password').value;
    useLegacy = document.getElementById('legacy').checked;

    if (!host || !port) {
        updateStatus('Host and port are required', 'error');
        return;
    }

    if (socket && socket.readyState === WebSocket.OPEN) {
        socket.close();
    }

    const url = `ws://${host}:${port}`;
    updateStatus(`Connecting to ${url}…`, 'info');
    updateVersion(`Protocol: ${useLegacy ? 'OBS WebSocket 4.x (legacy)' : 'OBS WebSocket 5.x'}`);

    socket = new WebSocket(url);

    socket.onopen = async () => {
        updateStatus('Connected. Authenticating…', 'info');
        try {
            const authInfo = await sendRequest('GetAuthRequired', {});
            const authRequired = useLegacy ? authInfo.authRequired === true : authInfo.authRequired;
            if (authRequired) {
                if (!password) {
                    updateStatus('Password is required', 'error');
                    return;
                }
                const secret = await sha256Base64(password + authInfo.salt);
                const auth = await sha256Base64(secret + authInfo.challenge);
                await sendRequest('Authenticate', { auth });
            }
            updateStatus('✓ Connected and authenticated', 'success');
        } catch (error) {
            updateStatus('Authentication failed: ' + error, 'error');
        }
    };

    socket.onmessage = (event) => {
        let message;
        try { message = JSON.parse(event.data); } catch (err) { return; }

        if (!useLegacy && message.op === 7 && message.d && message.d.requestId) {
            const pending = pendingRequests[message.d.requestId];
            if (pending) {
                delete pendingRequests[message.d.requestId];
                if (message.d.status && message.d.status.code === 0) {
                    pending.resolve(message.d.responseData || {});
                } else {
                    pending.reject(message.d.error || 'Unknown error');
                }
            }
        }

        if (useLegacy && message['message-id']) {
            const pending = pendingRequests[message['message-id']];
            if (pending) {
                delete pendingRequests[message['message-id']];
                if (message.status === 'ok') {
                    pending.resolve(message);
                } else {
                    pending.reject(message.error || 'Unknown error');
                }
            }
        }
    };

    socket.onerror = () => updateStatus('WebSocket error', 'error');
    socket.onclose = (event) => updateStatus(`Disconnected (${event.code})`, 'error');
}

async function triggerHotkey(name) {
    if (!socket || socket.readyState !== WebSocket.OPEN) {
        updateStatus('Not connected', 'error');
        return;
    }
    try {
        await sendRequest('TriggerHotkeyByName', { hotkeyName: name });
        updateStatus(`✓ Triggered: ${name}`, 'success');
    } catch (error) {
        updateStatus('Trigger failed: ' + error, 'error');
    }
}

connectButton.addEventListener('click', connectWebSocket);
