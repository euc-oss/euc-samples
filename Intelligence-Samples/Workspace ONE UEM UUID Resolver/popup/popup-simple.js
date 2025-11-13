/**
 * Popup Script for UUID Resolver Chrome Extension
 * Simple context menu-based system
 */

document.addEventListener('DOMContentLoaded', async () => {
  console.log('UUID Resolver Popup: Loading...');
  
  try {
    // Load and display last resolved UUID
    await loadLastResolvedUUID();
    
    // Load configuration status
    await loadConfigurationStatus();
    
    // Setup event listeners
    setupEventListeners();
    
    console.log('UUID Resolver Popup: Loaded successfully');
  } catch (error) {
    console.error('UUID Resolver Popup: Failed to load:', error);
  }
});

/**
 * Load and display the last resolved UUID
 */
async function loadLastResolvedUUID() {
  try {
    const response = await chrome.runtime.sendMessage({ action: 'getLastResolvedEntity' });
    
    if (response && response.success && response.data) {
      const entityData = response.data;
      console.log('UUID Resolver Popup: Last resolved entity:', entityData);
      
      // Show the last resolved section
      document.getElementById('lastResolvedSection').style.display = 'block';
      document.getElementById('instructionsSection').style.display = 'none';
      document.getElementById('clearBtn').style.display = 'inline-block';
      
      // Populate entity details
      document.getElementById('entityName').textContent = entityData.name || 'Unknown';
      document.getElementById('entityType').textContent = entityData.subType || entityData.type || 'Unknown Type';
      document.getElementById('entityUuid').textContent = entityData.uuid;
      
      // Show description if available
      if (entityData.description && entityData.description !== 'undefined') {
        document.getElementById('entityDescription').textContent = entityData.description;
        document.getElementById('entityDescription').style.display = 'block';
      }
      
      // Show additional details if available
      const details = [];
      if (entityData.version) details.push(`Version: ${entityData.version}`);
      if (entityData.platform) details.push(`Platform: ${entityData.platform}`);
      if (entityData.category) details.push(`Category: ${entityData.category}`);
      if (entityData.groupId) details.push(`Group ID: ${entityData.groupId}`);
      if (entityData.isActive !== undefined) details.push(`Active: ${entityData.isActive ? 'Yes' : 'No'}`);
      
      if (details.length > 0) {
        document.getElementById('entityDetails').innerHTML = details.join('<br>');
        document.getElementById('entityDetails').style.display = 'block';
      }
      
    } else {
      // No last resolved UUID, show instructions
      showInstructions();
    }
  } catch (error) {
    console.error('UUID Resolver Popup: Failed to load last resolved UUID:', error);
    showInstructions();
  }
}

/**
 * Show instructions section
 */
function showInstructions() {
  document.getElementById('lastResolvedSection').style.display = 'none';
  document.getElementById('instructionsSection').style.display = 'block';
  document.getElementById('clearBtn').style.display = 'none';
}

/**
 * Load configuration status
 */
async function loadConfigurationStatus() {
  try {
    const response = await chrome.runtime.sendMessage({ action: 'getSettings' });
    
    if (response && response.success) {
      const settings = response.data;
      let status = 'Not configured';
      
      if (settings.serverUrl && settings.authType) {
        if (settings.authType === 'basic' && settings.username && settings.password) {
          status = '✅ Configured (Basic Auth)';
        } else if (settings.authType === 'oauth' && settings.clientId && settings.clientSecret && settings.tokenUrl) {
          status = '✅ Configured (OAuth)';
        } else {
          status = '⚠️ Partially configured';
        }
      }
      
      document.getElementById('configStatus').textContent = status;
    }
  } catch (error) {
    console.error('UUID Resolver Popup: Failed to load configuration status:', error);
    document.getElementById('configStatus').textContent = 'Error loading status';
  }
}

/**
 * Setup event listeners
 */
function setupEventListeners() {
  // Options button
  document.getElementById('optionsBtn').addEventListener('click', () => {
    chrome.runtime.openOptionsPage();
    window.close();
  });
  
  // Clear last resolved button
  document.getElementById('clearBtn').addEventListener('click', async () => {
    try {
      await chrome.storage.local.remove(['lastResolvedEntity']);
      showInstructions();
    } catch (error) {
      console.error('UUID Resolver Popup: Failed to clear last resolved:', error);
    }
  });
}
