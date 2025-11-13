/**
 * Background Service Worker for UUID Resolver Chrome Extension
 * Context Menu-based UUID Resolution System
 */

console.log('UUID Resolver: Background service worker starting...');

// Extension lifecycle
chrome.runtime.onInstalled.addListener((details) => {
  console.log('UUID Resolver: Extension installed/updated');
  setupContextMenu();
  
  if (details.reason === 'install') {
    initializeExtension();
  }
});

// Ensure context menu exists after browser startup
chrome.runtime.onStartup?.addListener(() => {
  try {
    setupContextMenu();
  } catch (_) {}
});

// Extension action - open options page
chrome.action.onClicked.addListener(async (tab) => {
  try {
    await chrome.runtime.openOptionsPage();
    console.log('UUID Resolver: Options page opened');
  } catch (error) {
    console.error('UUID Resolver: Failed to open options page:', error);
    chrome.tabs.create({ url: chrome.runtime.getURL('options/options.html') });
  }
});

/**
 * Setup context menu for UUID resolution
 */
function setupContextMenu() {
  chrome.contextMenus.removeAll(() => {
    chrome.contextMenus.create({
      id: 'resolve-uuid',
      title: 'Resolve UUID',
      contexts: ['selection'],
      documentUrlPatterns: [
        'https://*.data.workspaceone.com/*',
        'https://*.awmdm.com/*'
      ]
    });
    console.log('UUID Resolver: Context menu created');
  });
}

/**
 * Handle context menu clicks
 */
chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  console.log('UUID Resolver: Context menu clicked', info);
  
  if (info.menuItemId === 'resolve-uuid') {
    const selectedText = info.selectionText || '';
    console.log('UUID Resolver: Selected text:', selectedText);
    
    // Extract UUID from selected text
    const uuidMatch = selectedText.match(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i);
    
    if (uuidMatch) {
      const uuid = uuidMatch[0].toLowerCase();
      console.log('UUID Resolver: Found UUID:', uuid);

      // Stats: increment totalFound
      incrementStat('totalFound');
      
      // Show immediate feedback that we found a UUID
      try {
        showNotification('UUID Found', `Found UUID: ${uuid}\nAttempting to resolve...`, tab, { level: 'info' });
        
        // Start UUID resolution process
        await resolveUUIDWithFallback(uuid, tab);
      } catch (error) {
        console.error('UUID Resolver: Error in resolution process:', error);
        incrementStat('totalErrors');
        showNotification('Resolution Error', `Error processing UUID: ${error.message}`, tab, { level: 'error' });
      }
    } else {
      console.log('UUID Resolver: No valid UUID found in selection');
      showNotification('No UUID Found', `Selected text: "${selectedText}"\n\nNo valid UUID found. Please select text containing a UUID (format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx) and try again.`, tab, { level: 'error' });
    }
  }
});

/**
 * Resolve UUID with fallback through entity types
 */
async function resolveUUIDWithFallback(uuid, tab) {
  console.log('UUID Resolver: Starting resolution for UUID:', uuid);
  
  // Check if extension is configured first
  try {
    const settings = await getSettings();
    if (!settings.serverUrl) {
      showNotification('Configuration Required', `UUID found: ${uuid}\n\nPlease configure the extension first by clicking the extension icon and setting up your UEM server URL and credentials.`, tab, { level: 'error' });
      return;
    }

    if (settings.authType === 'basic' && (!settings.username || !settings.password || !settings.apiKey)) {
      showNotification('Authentication Required', `UUID found: ${uuid}\n\nPlease configure your username, password, and API key (tenant code) in the extension settings.`, tab, { level: 'error' });
      return;
    }

    if (settings.authType === 'oauth' && (!settings.clientId || !settings.clientSecret || !settings.tokenUrl)) {
      showNotification('OAuth Configuration Required', `UUID found: ${uuid}\n\nPlease configure your OAuth settings in the extension options.`, tab, { level: 'error' });
      return;
    }
  } catch (error) {
    console.error('UUID Resolver: Failed to check settings:', error);
    showNotification('Configuration Error', `UUID found: ${uuid}\n\nFailed to check extension configuration: ${error.message}`, tab, { level: 'error' });
    return;
  }
  
  // Order of resolution attempts (based on likelihood)
  const entityTypes = [
    { type: 'tag', name: 'Tag' },
    { type: 'script', name: 'Script' },
    { type: 'organization-group', name: 'Organization Group' },
    { type: 'application', name: 'Application' },
    { type: 'product', name: 'Product' },
    { type: 'profile', name: 'Profile' }
  ];
  
  try {
    for (const entityType of entityTypes) {
      try {
        console.log(`UUID Resolver: Attempting to resolve as ${entityType.name}...`);
        const result = await resolveUUID(uuid, entityType.type);
        
        if (result) {
          console.log(`UUID Resolver: Successfully resolved as ${entityType.name}:`, result);
          
          // Show success popup/notification
          showEntityDetails(result, tab);
          return;
        }
      } catch (error) {
        console.log(`UUID Resolver: Failed to resolve as ${entityType.name}:`, error.message);
        continue;
      }
    }
    
    // If we get here, no entity type worked
    console.log('UUID Resolver: Could not resolve UUID with any entity type');
    incrementStat('totalFailures');
    showNotification('UUID Not Found', `Could not resolve UUID: ${uuid}\n\nThe UUID may not exist, you may not have permission to access it, or it may be a different type of entity not yet supported.`, tab, { level: 'error' });
    
  } catch (error) {
    console.error('UUID Resolver: Resolution process failed:', error);
    incrementStat('totalErrors');
    showNotification('Resolution Error', `Failed to resolve UUID: ${uuid}\n\nError: ${error.message}`, tab, { level: 'error' });
  }
}

/**
 * Robust notification creator with fallback icon and error handling
 */
function createNotification(options, onError) {
  const defaultOptions = {
    type: 'basic',
    title: 'UUID Resolver',
    message: '',
    iconUrl: chrome.runtime.getURL('icons/icon-48.png')
  };

  const merged = { ...defaultOptions, ...options };

  // Ensure required fields exist
  if (!merged.type) merged.type = 'basic';
  if (!merged.title) merged.title = 'UUID Resolver';
  if (!merged.message) merged.message = ' ';
  if (!merged.iconUrl) merged.iconUrl = chrome.runtime.getURL('icons/icon-48.png');

  chrome.notifications.create('', merged, (id) => {
    const err = chrome.runtime.lastError;
    if (err) {
      console.warn('UUID Resolver: Notification error, retrying with data URL icon:', err.message);
      // Fallback with tiny transparent PNG data URL
      const fallbackIcon = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIW2P8/5+hHgAHggJ/Pvx4GQAAAABJRU5ErkJggg==';
      const fallback = { ...merged, iconUrl: fallbackIcon };
      chrome.notifications.create('', fallback, () => {
        const err2 = chrome.runtime.lastError;
        if (err2) {
          console.error('UUID Resolver: Fallback notification failed:', err2.message);
          if (typeof onError === 'function') {
            try { onError(err2); } catch (_) {}
          }
        }
      });
    }
  });
}

/**
 * Show entity details in a notification or popup
 */
function showEntityDetails(entityData, tab) {
  const { uuid, name, type, subType, description } = entityData;
  
  // Ensure we have valid values
  const entityName = name || 'Unknown';
  const entityType = subType || type || 'Unknown Type';
  const entityUuid = uuid || 'Unknown UUID';
  
  // Create detailed message
  let message = `Name: ${entityName}\nType: ${entityType}\n`;
  if (description && description !== 'undefined' && description !== 'null') {
    message += `Description: ${description}\n`;
  }
  message += `UUID: ${entityUuid}`;
  
  // Store details for popup access
  chrome.storage.local.set({
    'lastResolvedEntity': {
      ...entityData,
      timestamp: Date.now(),
      tabId: tab?.id
    }
  });

  // Stats: increment totalResolved
  incrementStat('totalResolved');
  
  // Show notification via helper (best-effort)
  createNotification({
    title: `✅ ${entityType} Found`,
    message
  });

  // Also send to content script to show an in-page toast (visible fallback)
  if (tab?.id) {
    try {
      chrome.tabs.sendMessage(tab.id, { action: 'displayResolvedEntity', data: entityData, persist: true });
    } catch (e) {
      console.warn('UUID Resolver: Failed to send in-page toast message:', e?.message);
    }
  }
  
  console.log('UUID Resolver: Entity details displayed:', entityData);
}

/**
 * Show error/informational notification
 */
function showNotification(title, message, tab, opts = {}) {
  const notificationTitle = title || 'UUID Resolver';
  const notificationMessage = message || ' ';
  createNotification({ title: notificationTitle, message: notificationMessage }, (err) => {
    // If notifications fail (e.g., icon load issues or OS blocked), we'll also send toast below
  });

  // Always send an in-page toast for colored UI and visibility
  const tabId = tab?.id;
  if (tabId) {
    try {
      chrome.tabs.sendMessage(tabId, {
        action: 'displayExtensionMessage',
        title: notificationTitle,
        message: notificationMessage,
        level: opts.level || 'info',
        persist: !!opts.persist
      });
    } catch (e) {
      console.warn('UUID Resolver: Failed to send fallback toast message:', e?.message || e);
    }
  }
}

/**
 * Message handling from content scripts and popups
 */
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  console.log('UUID Resolver: Received message:', message);
  
  try {
    switch (message.action) {
      case 'getSettings':
        getSettings().then(settings => {
          sendResponse({ success: true, data: settings });
        }).catch(error => {
          sendResponse({ success: false, error: error.message });
        });
        return true;
      
      case 'saveSettings':
        saveSettings(message.settings).then(() => {
          sendResponse({ success: true });
        }).catch(error => {
          sendResponse({ success: false, error: error.message });
        });
        return true;
      
      case 'testConnection':
        testAPIConnection(message.settings).then(result => {
          sendResponse({ success: true, data: result });
        }).catch(error => {
          sendResponse({ success: false, error: error.message });
        });
        return true;
      
      case 'getLastResolvedEntity':
        chrome.storage.local.get(['lastResolvedEntity'], (result) => {
          sendResponse({ success: true, data: result.lastResolvedEntity });
        });
        return true;

      case 'getStatistics':
        getStatistics().then((stats) => {
          sendResponse({ success: true, data: stats });
        }).catch((error) => {
          sendResponse({ success: false, error: error.message });
        });
        return true;
      
      default:
        sendResponse({ success: false, error: 'Unknown action' });
    }
  } catch (error) {
    console.error('UUID Resolver: Message handler error:', error);
    sendResponse({ success: false, error: error.message });
  }
});

/**
 * Initialize extension with default settings
 */
async function initializeExtension() {
  try {
    const settings = await getSettings();
    if (Object.keys(settings).length === 0) {
      await setDefaultSettings();
    }
    console.log('UUID Resolver: Extension initialized');
  } catch (error) {
    console.error('UUID Resolver: Failed to initialize:', error);
  }
}

/**
 * Get extension settings
 */
async function getSettings() {
  return new Promise((resolve) => {
    chrome.storage.sync.get(null, (result) => {
      resolve(result);
    });
  });
}

/**
 * Save extension settings
 */
async function saveSettings(settings) {
  return new Promise((resolve, reject) => {
    chrome.storage.sync.set(settings, () => {
      if (chrome.runtime.lastError) {
        reject(new Error(chrome.runtime.lastError.message));
      } else {
        resolve();
      }
    });
  });
}

/**
 * Set default settings
 */
async function setDefaultSettings() {
  const defaultSettings = {
    // Core server/auth
    serverUrl: '',
    organizationGroupId: null,
    authType: 'basic',
    username: '',
    password: '',
    apiKey: '',
    clientId: '',
    clientSecret: '',
    tokenUrl: '',

    // General settings
    showTooltips: true, // Show extra fields in success toast

    // Advanced settings
    apiTimeout: 30000
  };

  return new Promise((resolve, reject) => {
    chrome.storage.sync.set(defaultSettings, () => {
      if (chrome.runtime.lastError) {
        reject(new Error(chrome.runtime.lastError.message));
      } else {
        resolve();
      }
    });
  });
}

/**
 * Resolve UUID by entity type (sets auth headers and dispatches)
 */
async function resolveUUID(uuid, entityType) {
  const settings = await getSettings();
  const { serverUrl, authType } = settings;

  if (!serverUrl) {
    throw new Error('Server URL not configured. Please configure the extension in the options page.');
  }

  let headers = {
    'Accept': 'application/json',
    'Content-Type': 'application/json'
  };

  // Set up authentication
  if (authType === 'basic') {
    const { username, password, apiKey } = settings;
    if (!username || !password || !apiKey) {
      throw new Error('Basic authentication not properly configured: username, password, and API key (tenant code) are required');
    }

    const credentials = btoa(`${username}:${password}`);
    headers['Authorization'] = `Basic ${credentials}`;
    headers['aw-tenant-code'] = apiKey; // required for Basic auth
  } else if (authType === 'oauth') {
    const { clientId, clientSecret, tokenUrl } = settings;
    if (!clientId || !clientSecret || !tokenUrl) {
      throw new Error('OAuth not properly configured');
    }

    const token = await getOAuthToken(clientId, clientSecret, tokenUrl);
    headers['Authorization'] = `Bearer ${token}`;
  } else {
    throw new Error(`Unsupported auth type: ${authType}`);
  }

  // Resolve based on entity type
  switch (entityType) {
    case 'tag':
      return await resolveTag(uuid, serverUrl, headers, settings);
    case 'script':
      return await resolveScript(uuid, serverUrl, headers);
    case 'organization-group':
      return await resolveOrganizationGroup(uuid, serverUrl, headers);
    case 'application':
      return await resolveApplication(uuid, serverUrl, headers, settings);
    case 'product':
      return await resolveProduct(uuid, serverUrl, headers);
    case 'profile':
      return await resolveProfile(uuid, serverUrl, headers, settings);
    default:
      throw new Error(`Unsupported entity type: ${entityType}`);
  }
}

/**
 * Resolve Tag UUID
 */
async function resolveTag(uuid, baseURL, headers, settings) {
  const orgGroupId = settings.organizationGroupId;
  
  if (!orgGroupId) {
    throw new Error('Organization Group ID is required for tag resolution');
  }
  
  const response = await makeAPIRequest(`${baseURL}/mdm/tags/search?organizationgroupid=${orgGroupId}`, headers);
  const tags = response.Tags || [];
  
  const tag = tags.find(t => t.Id?.Value === uuid || t.Uuid === uuid);
  if (tag) {
    return {
      uuid: uuid,
      name: tag.TagName,
      type: 'tag',
      subType: 'Tag',
      description: tag.Description,
      color: tag.TagColorId
    };
  }
  
  throw new Error('Tag not found');
}

/**
 * Resolve Script UUID
 */
async function resolveScript(uuid, baseURL, headers) {
  const scriptHeaders = {
    ...headers,
    'Accept': 'application/json;version=2'
  };
  
  const response = await makeAPIRequest(`${baseURL}/mdm/workflows/${uuid}`, scriptHeaders);
  return {
    uuid: uuid,
    name: response.name || response.display_name || 'Unknown Script',
    type: 'script',
    subType: 'Script/Workflow',
    description: response.description,
    deviceType: response.device_type
  };
}

/**
 * Resolve Organization Group UUID
 */
async function resolveOrganizationGroup(uuid, baseURL, headers) {
  const orgGroupHeaders = {
    ...headers,
    'Accept': 'application/json;version=2'
  };
  
  const response = await makeAPIRequest(`${baseURL}/system/groups/${uuid}`, orgGroupHeaders);
  return {
    uuid: uuid,
    name: response.Name || response.GroupName || response.OrganizationGroupName,
    type: 'organization-group',
    subType: 'Organization Group',
    description: response.Description,
    groupId: response.Id?.Value || response.GroupId
  };
}

/**
 * Resolve Application UUID
 */
async function resolveApplication(uuid, baseURL, headers, settings) {
  // For application resolution, use API version 2 and do not pass organizationgroupid
  const appHeaders = {
    ...headers,
    'Accept': 'application/json;version=2'
  };

  // Try only these application endpoints
  const endpoints = [
    `/mam/apps/internal/${uuid}`,
    `/mam/apps/public/${uuid}`,
    `/mam/apps/purchased/${uuid}`
  ];
  
  for (const endpoint of endpoints) {
    try {
      const url = `${baseURL}${endpoint}`; // no org group query param
      const response = await makeAPIRequest(url, appHeaders);
      const name = response.ApplicationName || response.Name || response.AppName;
      
      if (name) {
        return {
          uuid: uuid,
          name: name,
          type: 'application',
          subType: 'Application',
          description: response.Description || response.AppDescription,
          version: response.AppVersion || response.Version,
          platform: response.Platform || response.DeviceType
        };
      }
    } catch (error) {
      continue;
    }
  }
  
  throw new Error('Application not found');
}

/**
 * Resolve Product UUID
 */
async function resolveProduct(uuid, baseURL, headers) {
  const response = await makeAPIRequest(`${baseURL}/mdm/products/${uuid}/details`, headers);
  return {
    uuid: uuid,
    name: response.product_name || 'Unknown Product',
    type: 'product',
    subType: 'Product',
    description: response.description,
    platform: response.platform,
    isActive: response.is_active
  };
}

/**
 * Resolve Profile UUID
 */
async function resolveProfile(uuid, baseURL, headers, settings) {
  const orgGroupId = settings.organizationGroupId;
  
  let url = `${baseURL}/mdm/profiles/${uuid}/detail`;
  if (orgGroupId) {
    url += `?organizationgroupid=${orgGroupId}`;
  }
  
  const response = await makeAPIRequest(url, headers);
  return {
    uuid: uuid,
    name: response.name || response.ProfileName || 'Unknown Profile',
    type: 'profile',
    subType: 'Profile',
    description: response.Description || response.description,
    platform: response.platform || response.Platform
  };
}

/**
 * Make API request with proper error handling
 */
async function makeAPIRequest(url, headers) {
  console.log(`UUID Resolver: Making API request to ${url}`);
  
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 10000);
  
  try {
    const response = await fetch(url, {
      method: 'GET',
      headers: headers,
      mode: 'cors',
      credentials: 'omit',
      signal: controller.signal
    });
    
    clearTimeout(timeoutId);
    
    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`API request failed: ${response.status} ${response.statusText} - ${errorText}`);
    }
    
    const data = await response.json();
    return data;
  } catch (error) {
    clearTimeout(timeoutId);
    if (error.name === 'AbortError') {
      throw new Error('API request timed out');
    }
    throw error;
  }
}

/**
 * Get OAuth token
 */
async function getOAuthToken(clientId, clientSecret, tokenUrl) {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 30000);
  
  try {
    const response = await fetch(tokenUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': `Basic ${btoa(`${clientId}:${clientSecret}`)}`,
        'Accept': 'application/json'
      },
      mode: 'cors',
      credentials: 'omit',
      body: 'grant_type=client_credentials',
      signal: controller.signal
    });

    clearTimeout(timeoutId);
    
    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`OAuth token request failed: ${response.status} ${response.statusText}. ${errorText}`);
    }

    const data = await response.json();
    
    if (!data.access_token) {
      throw new Error('No access token received from OAuth endpoint');
    }
    
    return data.access_token;
  } catch (error) {
    clearTimeout(timeoutId);
    if (error.name === 'AbortError') {
      throw new Error('OAuth token request timed out');
    }
    throw error;
  }
}

/**
 * Test API connection
 */
async function testAPIConnection(settings) {
  const { serverUrl, authType } = settings;
  
  if (!serverUrl) {
    throw new Error('Server URL is required');
  }
  
  let headers = {
    'Accept': 'application/json'
  };
  
  if (authType === 'basic') {
    const { username, password, apiKey } = settings;
    if (!username || !password || !apiKey) {
      throw new Error('Username, password, and API key (tenant code) are required for Basic authentication');
    }
    
    const credentials = btoa(`${username}:${password}`);
    headers['Authorization'] = `Basic ${credentials}`;
    headers['aw-tenant-code'] = apiKey; // required for Basic auth
  } else if (authType === 'oauth') {
    const { clientId, clientSecret, tokenUrl } = settings;
    if (!clientId || !clientSecret || !tokenUrl) {
      throw new Error('Client ID, Client Secret, and Token URL are required for OAuth');
    }
    
    const token = await getOAuthToken(clientId, clientSecret, tokenUrl);
    headers['Authorization'] = `Bearer ${token}`;
  }
  
  const response = await makeAPIRequest(`${serverUrl}/system/info`, headers);
  
  return {
    success: true,
    serverInfo: {
      version: response.ProductVersion || 'Unknown',
      build: response.BuildNumber || 'Unknown'
    }
  };
}

/**
 * Get statistics
 */
async function getStatistics() {
  return new Promise((resolve) => {
    chrome.storage.local.get(['stats'], (result) => {
      const stats = result.stats || { totalFound: 0, totalResolved: 0, totalFailures: 0, totalErrors: 0 };
      resolve(stats);
    });
  });
}

function incrementStat(key, by = 1) {
  try {
    chrome.storage.local.get(['stats'], (result) => {
      const stats = result.stats || { totalFound: 0, totalResolved: 0, totalFailures: 0, totalErrors: 0 };
      stats[key] = (stats[key] || 0) + by;
      chrome.storage.local.set({ stats });
    });
  } catch (_) {
    // ignore
  }
}

console.log('UUID Resolver: Background service worker ready');
