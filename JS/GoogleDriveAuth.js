// File: GoogleDriveAuth.js
// Path: AndyGoogle/WebPages/JS/GoogleDriveAuth.js
// Standard: AIDEV-PascalCase-2.1
// Created: 2025-07-12
// Last Modified: 2025-07-12  07:50PM
// Description: Modern Google Drive authentication and API integration for AndyGoogle
// Updated to use Google Identity Services (2025) instead of deprecated gapi.auth2

class GoogleDriveAuth {
    constructor(config) {
        this.config = {
            clientId: config.clientId,
            apiKey: config.apiKey,
            scopes: [
                'https://www.googleapis.com/auth/drive.file',
                'https://www.googleapis.com/auth/drive.metadata.readonly',
                'https://www.googleapis.com/auth/spreadsheets',
                'https://www.googleapis.com/auth/userinfo.email'
            ],
            discoveryDocs: [
                'https://www.googleapis.com/discovery/v1/apis/drive/v3/rest',
                'https://www.googleapis.com/discovery/v1/apis/sheets/v4/rest'
            ],
            folderIds: config.folderIds || {},
            sheetIds: config.sheetIds || {}
        };
        
        this.isSignedIn = false;
        this.currentUser = null;
        this.accessToken = null;
        this.driveService = null;
        this.sheetsService = null;
        this.gapiLoaded = false;
    }

    async Initialize() {
        try {
            console.log('🔑 Initializing modern Google Identity Services...');
            
            // Load Google Identity Services
            await this.LoadGoogleIdentityServices();
            
            // Load Google API client for API calls
            await this.LoadGoogleAPI();
            
            // Initialize Google Identity Services
            google.accounts.id.initialize({
                client_id: this.config.clientId,
                callback: this.HandleCredentialResponse.bind(this),
                auto_select: false,
                cancel_on_tap_outside: false
            });

            console.log('✅ Modern Google Identity Services initialized');
            return true;

        } catch (error) {
            console.error('❌ Failed to initialize Google Identity Services:', error);
            throw error;
        }
    }

    LoadGoogleIdentityServices() {
        return new Promise((resolve, reject) => {
            if (typeof google !== 'undefined' && google.accounts) {
                resolve();
                return;
            }

            const script = document.createElement('script');
            script.src = 'https://accounts.google.com/gsi/client';
            script.onload = resolve;
            script.onerror = reject;
            document.head.appendChild(script);
        });
    }

    LoadGoogleAPI() {
        return new Promise((resolve, reject) => {
            if (typeof gapi !== 'undefined') {
                this.InitializeGapi().then(resolve).catch(reject);
                return;
            }

            const script = document.createElement('script');
            script.src = 'https://apis.google.com/js/api.js';
            script.onload = () => {
                gapi.load('client', () => {
                    this.InitializeGapi().then(resolve).catch(reject);
                });
            };
            script.onerror = reject;
            document.head.appendChild(script);
        });
    }

    async InitializeGapi() {
        try {
            await gapi.client.init({
                apiKey: this.config.apiKey,
                discoveryDocs: this.config.discoveryDocs
            });
            this.gapiLoaded = true;
            console.log('✅ Google API client initialized');
        } catch (error) {
            console.error('❌ Error initializing Google API client:', error);
            throw error;
        }
    }

    // Handle sign-in response from Google Identity Services
    HandleCredentialResponse(response) {
        console.log('🎉 Sign-in successful with Google Identity Services!');
        
        try {
            // Decode the JWT token to get user info
            const payload = this.ParseJWT(response.credential);
            
            this.currentUser = {
                id: payload.sub,
                email: payload.email,
                name: payload.name,
                imageUrl: payload.picture,
                emailVerified: payload.email_verified
            };

            this.isSignedIn = true;
            console.log('✅ User authenticated:', this.currentUser.email);
            
            // Trigger sign-in event
            this.OnSignInSuccess(this.currentUser);
            
        } catch (error) {
            console.error('❌ Error processing credential response:', error);
            this.OnSignInError(error);
        }
    }

    // Request access token for API calls
    async RequestAccessToken() {
        return new Promise((resolve, reject) => {
            console.log('🔐 Requesting access token for API calls...');
            
            const tokenClient = google.accounts.oauth2.initTokenClient({
                client_id: this.config.clientId,
                scope: this.config.scopes.join(' '),
                callback: (tokenResponse) => {
                    this.accessToken = tokenResponse.access_token;
                    
                    // Set token for Google API client
                    if (this.gapiLoaded) {
                        gapi.client.setToken({
                            access_token: this.accessToken
                        });
                        
                        // Initialize API services
                        this.driveService = gapi.client.drive;
                        this.sheetsService = gapi.client.sheets;
                    }
                    
                    console.log('✅ Access token obtained for API calls');
                    resolve(this.accessToken);
                },
                error_callback: (error) => {
                    console.error('❌ Error getting access token:', error);
                    reject(error);
                }
            });
            
            tokenClient.requestAccessToken();
        });
    }

    // Show Google Sign-In button
    RenderSignInButton(elementId, options = {}) {
        const defaultOptions = {
            type: 'standard',
            theme: 'outline',
            size: 'large',
            text: 'signin_with',
            shape: 'rectangular'
        };
        
        const buttonOptions = { ...defaultOptions, ...options };
        
        google.accounts.id.renderButton(
            document.getElementById(elementId),
            buttonOptions
        );
    }

    // Show One Tap prompt
    ShowOneTap() {
        google.accounts.id.prompt((notification) => {
            if (notification.isNotDisplayed() || notification.isSkippedMoment()) {
                console.log('⚠️ One Tap prompt not displayed or skipped');
            } else {
                console.log('✅ One Tap prompt displayed');
            }
        });
    }

    // Sign out
    async SignOut() {
        try {
            // Revoke access token
            if (this.accessToken) {
                google.accounts.oauth2.revoke(this.accessToken);
            }
            
            this.isSignedIn = false;
            this.currentUser = null;
            this.accessToken = null;
            
            // Clear API client token
            if (this.gapiLoaded) {
                gapi.client.setToken(null);
            }
            
            console.log('👋 User signed out');
            this.OnSignOut();

        } catch (error) {
            console.error('❌ Sign-out failed:', error);
            throw error;
        }
    }

    // Parse JWT token
    ParseJWT(token) {
        try {
            const base64Url = token.split('.')[1];
            const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
            const jsonPayload = decodeURIComponent(atob(base64).split('').map(function(c) {
                return '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2);
            }).join(''));
            return JSON.parse(jsonPayload);
        } catch (error) {
            console.error('Error parsing JWT:', error);
            return {};
        }
    }

    // Event handlers (override these in your implementation)
    OnSignInSuccess(user) {
        console.log('🎉 Sign-in success event:', user.email);
    }

    OnSignInError(error) {
        console.error('❌ Sign-in error event:', error);
    }

    OnSignOut() {
        console.log('👋 Sign-out event');
    }

    // Check user permissions (integrate with AndyGoogle backend)
    async CheckUserPermissions() {
        try {
            if (!this.currentUser) {
                throw new Error('No user signed in');
            }

            console.log('🔍 Checking user permissions with AndyGoogle backend...');

            // Call AndyGoogle API to check/register user
            const response = await fetch('/api/user/permissions', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${this.accessToken}`
                },
                body: JSON.stringify({
                    email: this.currentUser.email,
                    name: this.currentUser.name,
                    googleId: this.currentUser.id
                })
            });

            if (!response.ok) {
                throw new Error(`Permission check failed: ${response.status}`);
            }

            const userStatus = await response.json();
            console.log('✅ User permissions checked:', userStatus);
            return userStatus;

        } catch (error) {
            console.error('❌ Error checking user permissions:', error);
            return {
                status: 'error',
                message: 'Permission check failed'
            };
        }
    }

    // Log activity to Google Sheets via AndyGoogle backend
    async LogActivity(action, details) {
        try {
            if (!this.currentUser) return;

            await fetch('/api/analytics/log', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${this.accessToken}`
                },
                body: JSON.stringify({
                    user_email: this.currentUser.email,
                    action: action,
                    action_details: details,
                    session_id: this.GetSessionId()
                })
            });

        } catch (error) {
            console.error('❌ Error logging activity:', error);
        }
    }

    GetSessionId() {
        if (!this.sessionId) {
            this.sessionId = `session_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
        }
        return this.sessionId;
    }
}

// Google Drive File Operations (Modern API)
class GoogleDriveFileManager {
    constructor(auth) {
        this.auth = auth;
    }

    async DownloadFile(fileId, fileName = null) {
        try {
            console.log(`📥 Downloading file: ${fileId}`);

            if (!this.auth.accessToken) {
                throw new Error('No access token available');
            }

            // Use direct fetch with access token for better control
            const response = await fetch(`https://www.googleapis.com/drive/v3/files/${fileId}?alt=media`, {
                headers: {
                    'Authorization': `Bearer ${this.auth.accessToken}`
                }
            });

            if (!response.ok) {
                throw new Error(`Download failed: ${response.status}`);
            }

            const blob = await response.blob();

            if (fileName) {
                // Trigger download
                const url = window.URL.createObjectURL(blob);
                const a = document.createElement('a');
                a.href = url;
                a.download = fileName;
                document.body.appendChild(a);
                a.click();
                document.body.removeChild(a);
                window.URL.revokeObjectURL(url);
            }

            console.log(`✅ File downloaded: ${fileId}`);
            return blob;

        } catch (error) {
            console.error(`❌ Error downloading file ${fileId}:`, error);
            throw error;
        }
    }

    async GetFileMetadata(fileId) {
        try {
            const response = await this.auth.driveService.files.get({
                fileId: fileId,
                fields: 'id,name,size,modifiedTime,mimeType,description,parents'
            });

            return response.result;

        } catch (error) {
            console.error(`❌ Error getting file metadata ${fileId}:`, error);
            throw error;
        }
    }

    async ListFolderContents(folderId) {
        try {
            const response = await this.auth.driveService.files.list({
                q: `'${folderId}' in parents and trashed=false`,
                fields: 'files(id,name,size,modifiedTime,mimeType)',
                orderBy: 'name'
            });

            return response.result.files;

        } catch (error) {
            console.error(`❌ Error listing folder contents ${folderId}:`, error);
            throw error;
        }
    }

    async GetLatestDatabaseVersion() {
        try {
            // Call AndyGoogle backend API instead of direct Drive access
            const response = await fetch('/api/sync/updates', {
                headers: {
                    'Authorization': `Bearer ${this.auth.accessToken}`
                }
            });

            if (!response.ok) {
                throw new Error(`Failed to get database version: ${response.status}`);
            }

            return await response.json();

        } catch (error) {
            console.error('❌ Error getting latest database version:', error);
            throw error;
        }
    }
}

// Database Manager for AndyGoogle Integration
class DatabaseManager {
    constructor(auth) {
        this.auth = auth;
        this.localVersion = null;
        this.remoteVersion = null;
    }

    async CheckForUpdates() {
        try {
            console.log('🔍 Checking for database updates...');

            const response = await fetch('/api/sync/updates', {
                headers: {
                    'Authorization': `Bearer ${this.auth.accessToken}`
                }
            });

            if (!response.ok) {
                throw new Error(`Update check failed: ${response.status}`);
            }

            const updateInfo = await response.json();
            
            this.localVersion = updateInfo.local_version;
            this.remoteVersion = updateInfo.remote_version;
            
            console.log(`Local: v${this.localVersion}, Remote: v${this.remoteVersion}`);
            
            return updateInfo;

        } catch (error) {
            console.error('❌ Error checking for updates:', error);
            throw error;
        }
    }

    async TriggerSync() {
        try {
            console.log('🔄 Triggering database sync...');

            const response = await fetch('/api/sync/database', {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${this.auth.accessToken}`
                }
            });

            if (!response.ok) {
                throw new Error(`Sync failed: ${response.status}`);
            }

            const result = await response.json();
            console.log('✅ Database sync triggered:', result.message);
            
            return result;

        } catch (error) {
            console.error('❌ Error triggering sync:', error);
            throw error;
        }
    }

    async GetSyncStatus() {
        try {
            const response = await fetch('/api/sync/status', {
                headers: {
                    'Authorization': `Bearer ${this.auth.accessToken}`
                }
            });

            if (!response.ok) {
                throw new Error(`Status check failed: ${response.status}`);
            }

            return await response.json();

        } catch (error) {
            console.error('❌ Error getting sync status:', error);
            throw error;
        }
    }
}

// Export for use in other modules
window.GoogleDriveAuth = GoogleDriveAuth;
window.GoogleDriveFileManager = GoogleDriveFileManager;
window.DatabaseManager = DatabaseManager;

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', function() {
    console.log('📚 AndyGoogle Google Drive Auth module loaded');
});