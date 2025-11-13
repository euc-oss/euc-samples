/**
 * Options Page Script for UUID Resolver Chrome Extension
 */

'use strict';

// Global state
let currentSettings = {};
let autoSaveTimeout = null;
let isDirty = false;
let isInitialized = false;

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', async () => {
  console.log('UUID Resolver Options: Initializing...');
  
  try {
    await initializeOptionsPage();
    setupEventListeners();
    await loadSettings();
    await updateStats();
    updateStatus();
    
    isInitialized = true;
    console.log('UUID Resolver Options: Initialization complete');
    showToast('Options page loaded successfully', 'success');
  } catch (error) {
    console.error('UUID Resolver Options: Initialization failed:', error);
    showToast('Failed to initialize options page', 'error');
  }
});

/**
 * Initialize options page
 */
async function initializeOptionsPage() {
  // Set up authentication type switching
  const authTypeSelect = document.getElementById('authType');
  authTypeSelect.addEventListener('change', toggleAuthType);
  
  // Initial auth type setup
  toggleAuthType();
  
  // Set version in footer
  const manifest = chrome.runtime.getManifest();
  const versionText = document.querySelector('.footer-info p');
  if (versionText) {
    versionText.textContent = `UUID Resolver v${manifest.version} for Workspace ONE UEM`;
  }
}

/**
 * Set up all event listeners
 */
function setupEventListeners() {
  // Auto-save on input changes
  const inputs = document.querySelectorAll('input[type="text"], input[type="url"], input[type="password"], input[type="number"], select');
  console.log('UUID Resolver Options: Setting up auto-save for', inputs.length, 'input fields');
  
  inputs.forEach((input, index) => {
    if (input.id !== 'authToken') { // Don't auto-save readonly OAuth token
      console.log(`UUID Resolver Options: Adding listeners to input ${index}: ${input.id || input.name || 'unnamed'}`);
      input.addEventListener('input', handleInputChange);
      input.addEventListener('change', handleInputChange);
      input.addEventListener('blur', handleInputBlur);
    }
  });
  
  // Checkbox changes
  const checkboxes = document.querySelectorAll('input[type="checkbox"]');
  console.log('UUID Resolver Options: Setting up auto-save for', checkboxes.length, 'checkboxes');
  
  checkboxes.forEach((checkbox, index) => {
    console.log(`UUID Resolver Options: Adding listeners to checkbox ${index}: ${checkbox.id || checkbox.name || 'unnamed'}`);
    checkbox.addEventListener('change', handleInputChange);
  });
  
  // Action buttons
  document.getElementById('testConnectionBtn').addEventListener('click', handleTestConnection);
  document.getElementById('refreshBtn').addEventListener('click', handleRefresh);
  document.getElementById('exportSettingsBtn').addEventListener('click', handleExportSettings);
  document.getElementById('resetSettingsBtn').addEventListener('click', handleResetSettings);
  document.getElementById('openOptionsBtn').addEventListener('click', () => {
    chrome.tabs.create({ url: 'chrome://extensions/' });
  });
  
  // Keyboard shortcuts
  document.addEventListener('keydown', handleKeyboardShortcuts);
}

/**
 * Handle keyboard shortcuts
 */
function handleKeyboardShortcuts(event) {
  // Ctrl/Cmd + S to save
  if ((event.ctrlKey || event.metaKey) && event.key === 's') {
    event.preventDefault();
    saveSettingsManually();
  }
  
  // Ctrl/Cmd + T to test connection
  if ((event.ctrlKey || event.metaKey) && event.key === 't') {
    event.preventDefault();
    handleTestConnection();
  }
}

/**
 * Handle input changes for auto-save
 */
function handleInputChange(event) {
  console.log('UUID Resolver Options: Input changed:', event.target.id || event.target.name);
  markAsDirty();
  
  // Clear existing timeout
  if (autoSaveTimeout) {
    clearTimeout(autoSaveTimeout);
  }
  
  // Set new timeout for auto-save
  autoSaveTimeout = setTimeout(() => autoSave(), 2000); // 2 seconds for options page
}

/**
 * Handle input blur for immediate save
 */
function handleInputBlur(event) {
  console.log('UUID Resolver Options: Input blur:', event.target.id || event.target.name);
  
  // Clear auto-save timeout and save immediately
  if (autoSaveTimeout) {
    clearTimeout(autoSaveTimeout);
    autoSaveTimeout = null;
  }
  
  autoSave();
}

/**
 * Mark form as dirty (unsaved changes)
 */
function markAsDirty() {
  if (!isDirty) {
    isDirty = true;
    const indicator = document.getElementById('unsavedIndicator');
    const saveText = document.getElementById('saveText');
    if (indicator) {
      indicator.classList.add('visible');
    }
    if (saveText) {
      saveText.textContent = 'Unsaved changes';
    }
    console.log('UUID Resolver Options: Form marked as dirty');
  }
}

/**
 * Mark form as clean (saved)
 */
function markAsClean() {
  if (isDirty) {
    isDirty = false;
    const indicator = document.getElementById('unsavedIndicator');
    const saveText = document.getElementById('saveText');
    if (indicator) {
      indicator.classList.remove('visible');
    }
    if (saveText) {
      saveText.textContent = 'All changes saved';
    }
    console.log('UUID Resolver Options: Form marked as clean');
  }
}

/**
 * Auto-save settings
 */
async function autoSave() {
  if (!isInitialized) {
    console.log('UUID Resolver Options: Skipping auto-save - not initialized');
    return;
  }
  
  try {
    console.log('UUID Resolver Options: Auto-saving settings...');
    const settings = collectSettings();
    await saveSettings(settings);
    markAsClean();
    console.log('UUID Resolver Options: Auto-save completed');
  } catch (error) {
    console.error('UUID Resolver Options: Auto-save failed:', error);
    showToast('Failed to save settings automatically', 'error');
  }
}

/**
 * Manual save (triggered by user action)
 */
async function saveSettingsManually() {
  try {
    const settings = collectSettings();
    await saveSettings(settings);
    markAsClean();
    showToast('Settings saved successfully', 'success');
  } catch (error) {
    console.error('UUID Resolver Options: Manual save failed:', error);
    showToast('Failed to save settings', 'error');
  }
}

/**
 * Toggle authentication type visibility
 */
function toggleAuthType() {
  const authType = document.getElementById('authType').value;
  const basicAuthSection = document.getElementById('basicAuthSection');
  const oauthSection = document.getElementById('oauthSection');
  
  if (authType === 'basic') {
    basicAuthSection.style.display = 'block';
    oauthSection.style.display = 'none';
  } else {
    basicAuthSection.style.display = 'none';
    oauthSection.style.display = 'block';
  }
}

/**
 * Load settings from storage
 */
async function loadSettings() {
  try {
    console.log('UUID Resolver Options: Loading settings...');
    
    // Try multiple storage methods with fallbacks
    let settings = {};
    
    // Method 1: Chrome runtime message to background script
    try {
      const response = await sendMessage({ action: 'getSettings' });
      if (response && response.success && response.data) {
        settings = response.data;
        console.log('UUID Resolver Options: Settings loaded via background script');
      }
    } catch (error) {
      console.warn('UUID Resolver Options: Background script method failed:', error);
    }
    
    // Method 2: Direct Chrome storage (fallback)
    if (Object.keys(settings).length === 0) {
      try {
        settings = await getStorageData();
        console.log('UUID Resolver Options: Settings loaded via direct storage');
      } catch (error) {
        console.warn('UUID Resolver Options: Direct storage method failed:', error);
      }
    }
    
    // Method 3: Use defaults if no settings found
    if (Object.keys(settings).length === 0) {
      settings = getDefaultSettings();
      console.log('UUID Resolver Options: Using default settings');
    }
    
    currentSettings = settings;
    populateForm(settings);
    
    console.log('UUID Resolver Options: Settings loaded successfully');
  } catch (error) {
    console.error('UUID Resolver Options: Failed to load settings:', error);
    showToast('Failed to load settings', 'error');
    
    // Use defaults as last resort
    const defaults = getDefaultSettings();
    currentSettings = defaults;
    populateForm(defaults);
  }
}

/**
 * Save settings to storage
 */
async function saveSettings(settings) {
  currentSettings = settings;
  
  // Method 1: Try background script first
  try {
    const response = await sendMessage({ 
      action: 'saveSettings', 
      settings: settings 
    });
    
    if (response && response.success) {
      console.log('UUID Resolver Options: Settings saved via background script');
      return;
    }
  } catch (error) {
    console.warn('UUID Resolver Options: Background script save failed:', error);
  }
  
  // Method 2: Direct storage fallback
  try {
    await setStorageData(settings);
    console.log('UUID Resolver Options: Settings saved via direct storage');
  } catch (error) {
    console.error('UUID Resolver Options: Direct storage save failed:', error);
    throw new Error('Failed to save settings to any storage method');
  }
}

/**
 * Collect settings from form
 */
function collectSettings() {
  return {
    serverUrl: document.getElementById('serverUrl').value.trim(),
    organizationGroupId: parseInt(document.getElementById('organizationGroupId').value) || null,
    authType: document.getElementById('authType').value,
    
    // Basic auth
    username: document.getElementById('username').value.trim(),
    password: document.getElementById('password').value,
    apiKey: document.getElementById('apiKey').value.trim(),
    
    // OAuth
    clientId: document.getElementById('clientId').value.trim(),
    clientSecret: document.getElementById('clientSecret').value.trim(),
    tokenUrl: document.getElementById('tokenUrl').value.trim(),
    authToken: document.getElementById('authToken').value,
    
    // General settings
    showTooltips: document.getElementById('showTooltips').checked, // repurposed: show extra fields in success toast
    
    // Advanced settings
    apiTimeout: parseInt(document.getElementById('apiTimeout').value) * 1000, // Convert to ms
    maxConcurrentRequests: parseInt(document.getElementById('maxConcurrentRequests').value),
    debugMode: document.getElementById('debugMode').checked,
    
    // Entity types
    entityTypes: {
      tag: document.getElementById('entityTag').checked,
      application: document.getElementById('entityApplication').checked,
      profile: document.getElementById('entityProfile').checked,
      script: document.getElementById('entityScript').checked,
      product: document.getElementById('entityProduct').checked,
      organizationGroup: document.getElementById('entityOrganizationGroup').checked
    }
  };
}

/**
 * Populate form with settings
 */
function populateForm(settings) {
  try {
    // Basic settings
    document.getElementById('serverUrl').value = settings.serverUrl || '';
    document.getElementById('organizationGroupId').value = settings.organizationGroupId || '';
    document.getElementById('authType').value = settings.authType || 'basic';
    
    // Basic auth
    document.getElementById('username').value = settings.username || '';
    document.getElementById('password').value = settings.password || '';
    document.getElementById('apiKey').value = settings.apiKey || '';
    
    // OAuth
    document.getElementById('clientId').value = settings.clientId || '';
    document.getElementById('clientSecret').value = settings.clientSecret || '';
    document.getElementById('tokenUrl').value = settings.tokenUrl || '';
    document.getElementById('authToken').value = settings.authToken || '';
    
    // General settings
    document.getElementById('showTooltips').checked = settings.showTooltips !== false;
    
    // Advanced settings
    document.getElementById('apiTimeout').value = Math.floor((settings.apiTimeout || 30000) / 1000); // Convert to seconds
    document.getElementById('maxConcurrentRequests').value = settings.maxConcurrentRequests || 5;
    document.getElementById('debugMode').checked = settings.debugMode || false;
    
    // Entity types
    const entityTypes = settings.entityTypes || {};
    document.getElementById('entityTag').checked = entityTypes.tag !== false;
    document.getElementById('entityApplication').checked = entityTypes.application !== false;
    document.getElementById('entityProfile').checked = entityTypes.profile !== false;
    document.getElementById('entityScript').checked = entityTypes.script !== false;
    document.getElementById('entityProduct').checked = entityTypes.product !== false;
    document.getElementById('entityOrganizationGroup').checked = entityTypes.organizationGroup !== false;
    
    // Update auth type visibility
    toggleAuthType();
    
    console.log('UUID Resolver Options: Form populated with settings');
  } catch (error) {
    console.error('UUID Resolver Options: Error populating form:', error);
  }
}

/**
 * Get default settings
 */
function getDefaultSettings() {
  return {
    serverUrl: '',
    authType: 'basic',
    username: '',
    password: '',
    apiKey: '',
    clientId: '',
    clientSecret: '',
    tokenUrl: '',
    authToken: '',
    showTooltips: true, // repurposed: show extra fields in success toast
    apiTimeout: 30000, // 30 seconds
    maxConcurrentRequests: 5,
    debugMode: false,
    entityTypes: {
      tag: true,
      application: true,
      profile: true,
      script: true,
      product: true,
      organizationGroup: true
    }
  };
}

/**
 * Update statistics display
 */
async function updateStats() {
  try {
    // Get global stats from background
    const response = await chrome.runtime.sendMessage({ action: 'getStatistics' });
    const stats = (response && response.success && response.data) ? response.data : { totalFound: 0, totalResolved: 0, totalFailures: 0, totalErrors: 0 };

    // Update display
    document.getElementById('uuidCount').textContent = stats.totalFound || 0;
    document.getElementById('resolvedCount').textContent = stats.totalResolved || 0;

    // Calculate success rate
    const successRate = (stats.totalFound || 0) > 0
      ? Math.round(((stats.totalResolved || 0) / (stats.totalFound || 1)) * 100)
      : 0;
    document.getElementById('successRate').textContent = `${successRate}%`;
  } catch (error) {
    console.log('UUID Resolver Options: Could not get stats from background');
    // Reset to zeros if no stats available
    document.getElementById('uuidCount').textContent = '0';
    document.getElementById('resolvedCount').textContent = '0';
    document.getElementById('successRate').textContent = '0%';
  }
}

/**
 * Update status indicator
 */
function updateStatus() {
  const statusDot = document.getElementById('statusDot');
  const statusText = document.getElementById('statusText');
  
  if (currentSettings.serverUrl && (
    (currentSettings.authType === 'basic' && currentSettings.username && currentSettings.password) ||
    (currentSettings.authType === 'oauth' && currentSettings.clientId && currentSettings.clientSecret)
  )) {
    statusDot.className = 'status-dot online';
    statusText.textContent = 'Configuration Complete';
  } else {
    statusDot.className = 'status-dot offline';
    statusText.textContent = 'Configuration Required';
  }
}

/**
 * Handle test connection
 */
async function handleTestConnection() {
  const testBtn = document.getElementById('testConnectionBtn');
  const testResult = document.getElementById('testResult');
  
  try {
    // Disable button and show loading
    testBtn.disabled = true;
    testResult.style.display = 'none';
    
    const settings = collectSettings();
    
    // Validate required fields
    if (!settings.serverUrl) {
      throw new Error('Server URL is required');
    }
    
    if (settings.authType === 'basic' && (!settings.username || !settings.password || !settings.apiKey)) {
      throw new Error('Username, password, and API key (tenant code) are required for Basic authentication');
    }
    
    if (settings.authType === 'oauth' && (!settings.clientId || !settings.clientSecret || !settings.tokenUrl)) {
      throw new Error('Client ID, Client Secret, and Token URL are required for OAuth');
    }
    
    // Show different loading messages for OAuth vs Basic
    if (settings.authType === 'oauth') {
      testBtn.innerHTML = '<span class="btn-icon">🔐</span> Getting OAuth Token...';
      showToast('Getting OAuth token, this may take up to 30 seconds...', 'info');
    } else {
      testBtn.innerHTML = '<span class="btn-icon">⏳</span> Testing Connection...';
    }
    
    // Test connection via background script with longer timeout for OAuth
    const timeoutMs = settings.authType === 'oauth' ? 45000 : 15000;
    const response = await sendMessage({ 
      action: 'testConnection', 
      settings: settings 
    }, timeoutMs);
    
    if (response && response.success) {
      const result = response.data;
      
      // Update OAuth token if received
      if (settings.authType === 'oauth' && result.token) {
        document.getElementById('authToken').value = result.token;
        settings.authToken = result.token;
        await saveSettings(settings);
        showToast('OAuth token obtained and saved', 'success');
      }
      
      // Show success message
      testResult.className = 'test-result success';
      testResult.innerHTML = `
        <strong>✅ Connection successful!</strong><br>
        Server: ${result.serverInfo?.version || 'Unknown'}<br>
        Build: ${result.serverInfo?.build || 'Unknown'}<br>
        Environment: ${result.serverInfo?.environment || 'Unknown'}
      `;
      testResult.style.display = 'block';
      
      updateStatus();
      showToast('Connection test successful', 'success');
      
    } else {
      throw new Error(response?.error || 'Connection test failed');
    }
    
  } catch (error) {
    console.error('UUID Resolver Options: Connection test failed:', error);
    
    let errorMessage = error.message;
    
    // Provide specific guidance for common OAuth errors
    if (currentSettings.authType === 'oauth') {
      if (errorMessage.includes('timeout')) {
        errorMessage = 'OAuth request timed out. Check your token URL and network connection.';
      } else if (errorMessage.includes('401')) {
        errorMessage = 'OAuth authentication failed. Check your client ID and secret.';
      } else if (errorMessage.includes('CORS')) {
        errorMessage = 'CORS error. The OAuth server may not allow requests from browser extensions.';
      }
    }
    
    testResult.className = 'test-result error';
    testResult.innerHTML = `<strong>❌ Connection failed:</strong><br>${errorMessage}`;
    testResult.style.display = 'block';
    
    showToast('Connection test failed', 'error');
    
  } finally {
    // Re-enable button
    testBtn.disabled = false;
    testBtn.innerHTML = '<span class="btn-icon">🔧</span> Test Connection';
  }
}

/**
 * Handle refresh action
 */
async function handleRefresh() {
  try {
    const tabs = await chrome.tabs.query({ active: true, currentWindow: true });
    if (tabs.length === 0) return;
    
    await chrome.tabs.sendMessage(tabs[0].id, { action: 'refreshResolution' });
    showToast('UUID resolution refreshed on current page', 'success');
    
    // Update stats after refresh
    setTimeout(() => updateStats(), 1000);
  } catch (error) {
    console.error('UUID Resolver Options: Refresh failed:', error);
    showToast('Refresh failed - not on a UEM page?', 'warning');
  }
}

/**
 * Handle export settings
 */
async function handleExportSettings() {
  try {
    const settings = collectSettings();
    
    // Remove sensitive data
    const exportSettings = { ...settings };
    delete exportSettings.password;
    delete exportSettings.clientSecret;
    delete exportSettings.authToken;
    
    const blob = new Blob([JSON.stringify(exportSettings, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    
    const a = document.createElement('a');
    a.href = url;
    a.download = 'uuid-resolver-settings.json';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    
    showToast('Settings exported successfully (passwords excluded)', 'success');
  } catch (error) {
    console.error('UUID Resolver Options: Export failed:', error);
    showToast('Failed to export settings', 'error');
  }
}

/**
 * Handle reset settings
 */
async function handleResetSettings() {
  if (confirm('Are you sure you want to reset all settings to defaults? This cannot be undone.')) {
    try {
      const defaults = getDefaultSettings();
      await saveSettings(defaults);
      populateForm(defaults);
      markAsClean();
      showToast('Settings reset to defaults', 'success');
    } catch (error) {
      console.error('UUID Resolver Options: Reset failed:', error);
      showToast('Failed to reset settings', 'error');
    }
  }
}

/**
 * Show toast notification
 */
function showToast(message, type = 'info') {
  const toastContainer = document.getElementById('toastContainer');
  const toast = document.createElement('div');
  toast.className = `toast ${type}`;
  toast.textContent = message;
  
  toastContainer.appendChild(toast);
  
  // Trigger animation
  setTimeout(() => toast.classList.add('show'), 100);
  
  // Auto-remove after 5 seconds
  setTimeout(() => {
    toast.classList.remove('show');
    setTimeout(() => {
      if (toast.parentNode) {
        toastContainer.removeChild(toast);
      }
    }, 300);
  }, 5000);
}

/**
 * Send message to background script
 */
function sendMessage(message, timeoutMs = 45000) { // Increased default timeout to 45 seconds
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      reject(new Error('Message timeout'));
    }, timeoutMs);
    
    chrome.runtime.sendMessage(message, (response) => {
      clearTimeout(timeout);
      
      if (chrome.runtime.lastError) {
        reject(new Error(chrome.runtime.lastError.message));
      } else {
        resolve(response);
      }
    });
  });
}

/**
 * Get data from Chrome storage
 */
function getStorageData() {
  return new Promise((resolve) => {
    chrome.storage.sync.get(null, (result) => {
      resolve(result);
    });
  });
}

/**
 * Set data to Chrome storage
 */
function setStorageData(data) {
  return new Promise((resolve, reject) => {
    chrome.storage.sync.set(data, () => {
      if (chrome.runtime.lastError) {
        reject(new Error(chrome.runtime.lastError.message));
      } else {
        resolve();
      }
    });
  });
}

// Update stats and status periodically
setInterval(() => {
  if (isInitialized) {
    updateStats();
    updateStatus();
  }
}, 10000); // Every 10 seconds

// Save on page unload
window.addEventListener('beforeunload', () => {
  if (isDirty) {
    const settings = collectSettings();
    // Use synchronous storage for unload
    chrome.storage.sync.set(settings);
  }
});

console.log('UUID Resolver Options: Script loaded');
