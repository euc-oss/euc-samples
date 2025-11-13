/**
 * Content Script for UUID Resolver Chrome Extension
 * Simple context menu-based UUID resolution
 */

console.log('UUID Resolver: Content script loaded');

let showExtraFieldsInToast = true;

// Load settings to determine whether to show extra fields in success toast
try {
  chrome.runtime.sendMessage({ action: 'getSettings' }, (resp) => {
    if (resp && resp.success && resp.data) {
      // repurposed: showTooltips means show extra fields in success toast
      showExtraFieldsInToast = resp.data.showTooltips !== false;
    }
  });
} catch (_) {}

// Toast utilities
function ensureStyle() {
  if (document.getElementById('uuid-resolver-toast-style')) return;
  const style = document.createElement('style');
  style.id = 'uuid-resolver-toast-style';
  style.textContent = `
    .uuid-resolver-toast-container{position:fixed;right:16px;bottom:16px;z-index:2147483647;display:flex;flex-direction:column;gap:8px}
    .uuid-resolver-toast{background:#0b6aa2;color:#fff;padding:12px 14px;border-radius:8px;box-shadow:0 4px 18px rgba(0,0,0,.2);max-width:380px;font:13px/1.4 -apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;position:relative;padding-right:36px}
    .uuid-resolver-toast.info{background:#d97706} /* orange-600 */
    .uuid-resolver-toast.success{background:#3778F5}
    .uuid-resolver-toast.error{background:#b00020}
    /* Hard reset to prevent host page styles (borders/dividers) from leaking in */
    .uuid-resolver-toast, .uuid-resolver-toast * { box-sizing: border-box; border: 0 !important; outline: 0; }
    .uuid-resolver-toast hr{ display:none !important }
    .uuid-resolver-toast .header{display:flex;align-items:center;justify-content:space-between;margin:0 0 2px 0;background:transparent !important}
    .uuid-resolver-toast .header:before, .uuid-resolver-toast .header:after{content:none !important;display:none !important;border:0 !important}
    .uuid-resolver-toast .title{color:#fff !important;font-weight:600;margin:0;flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;background:transparent !important;line-height:1.2}
    .uuid-resolver-toast.success .title{font-size:16px;font-weight:700}
    .uuid-resolver-toast .type-pill{padding:2px 8px;border-radius:9999px;background:#6B7280;color:#fff;font-size:11px;font-weight:700;letter-spacing:.02em;text-transform:uppercase;white-space:nowrap;line-height:18px}
    .uuid-resolver-toast .body{white-space:pre-wrap;word-break:break-word;background:transparent !important;margin-top:0}
    .uuid-resolver-toast .header + .body{border-top:none !important}
    .uuid-resolver-toast .body:before,.uuid-resolver-toast .body:after{content:none !important;display:none !important;border:0 !important}
    .uuid-resolver-toast .close{position:absolute;top:8px;right:10px;cursor:pointer;opacity:.9}
  `;
  document.head.appendChild(style);
}

function getContainer(){
  let c = document.querySelector('.uuid-resolver-toast-container');
  if (!c){
    c = document.createElement('div');
    c.className = 'uuid-resolver-toast-container';
    document.body.appendChild(c);
  }
  return c;
}

function showToast(title, body, level='info', timeout=6000, persist=false, badgeText){
  ensureStyle();
  const el = document.createElement('div');
  el.className = `uuid-resolver-toast ${level}`;
  const badge = badgeText && level === 'success' ? `<span class="type-pill" title="Type">${badgeText}</span>` : '';
  el.innerHTML = `<div class="header"><div class="title">${title}</div>${badge}</div><div class="body">${body}</div><div class="close" aria-label="Close">×</div>`;
  const closeBtn = el.querySelector('.close');
  closeBtn.addEventListener('click', () => el.remove());
  getContainer().appendChild(el);
  if (!persist) {
    setTimeout(()=>{ el.remove(); }, timeout);
  }
}

function formatEntityToast(data){
  // Title already shows the Name; keep body focused on details only
  const uuid = data.uuid || '';
  let body = '';
  if (data.description) body += `${data.description}`;
  if (uuid) body += `${body ? '\n' : ''}UUID: ${uuid}`;
  if (showExtraFieldsInToast) {
    // Append extra fields if available
    const extra = [];
    if (data.version) extra.push(`Version: ${data.version}`);
    if (data.platform) extra.push(`Platform: ${data.platform}`);
    if (data.groupId) extra.push(`Group ID: ${data.groupId}`);
    if (data.deviceType) extra.push(`Device Type: ${data.deviceType}`);
    if (extra.length) body += `${body ? '\n' : ''}${extra.join('\n')}`;
  }
  return body;
}

function dismissInfoToasts(){
  document.querySelectorAll('.uuid-resolver-toast.info')?.forEach(el => el.remove());
}

// Listen for messages from background script
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message?.action === 'displayResolvedEntity' && message.data) {
    const body = formatEntityToast(message.data);
    // Remove any in-progress info toast
    dismissInfoToasts();
    // Use entity name as prominent title and show type as a pill
    const entityTitle = message.data.name || 'UUID Resolved';
    const badge = message.data.subType || message.data.type || 'Entity';
    showToast(entityTitle, body, 'success', 12000, true, badge);
    sendResponse?.({ ok: true });
    return; // handled
  }
  if (message?.action === 'displayExtensionMessage') {
    const { title = 'UUID Resolver', message: msg = ' ', level = 'info', persist = false } = message;
    // Collapse any existing info (orange) toast when showing success/error
    if (level === 'success' || level === 'error') dismissInfoToasts();
    const defaultTimeout = level === 'success' ? 12000 : level === 'error' ? 7000 : 3000;
    showToast(title, msg, level, defaultTimeout, !!persist);
    sendResponse?.({ ok: true });
    return;
  }
  if (message?.action === 'ping') {
    sendResponse?.({ success: true, message: 'Content script is active' });
    return;
  }
  sendResponse?.({ success: true });
});

// Notify background that content script is loaded
chrome.runtime.sendMessage({ action: 'contentScriptLoaded', url: window.location.href }).catch(()=>{});

console.log('UUID Resolver: Context menu-based UUID resolver ready');
