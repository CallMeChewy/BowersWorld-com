// Google Drive Authentication & API Integration for Anderson's Library
// Author: Herb Bowers - Project Himalaya
// Created: 2025-06-22  18:00
// Path: /library/js/GoogleDriveAuth.js

class GoogleDriveAuth {
    constructor(config) {
        this.config = {
            clientId: config.clientId,
            apiKey: config.apiKey,
            scopes: [
                'https://www.googleapis.com/auth/drive.readonly',
                'https://www.googleapis.com/auth/userinfo.email',
                'https://www.googleapis.com/auth/spreadsheets'
            ],
            discoveryDocs: [
                'https://www.googleapis.com/discovery/v1/apis/drive/v3/rest',
                'https://sheets.googleapis.com/$discovery/rest?version=v4'
            ],
            folderIds: config.folderIds || {},
            sheetIds: config.sheetIds || {}
        };
        
        this.isSignedIn = false;
        this.currentUser = null;
        this.driveService = null;
        this.sheetsService = null;
    }

    async Initialize() {
        try {
            console.log('🔑 Initializing Google Drive authentication...');
            
            // Load Google API
            await this.LoadGoogleAPI();
            
            // Initialize Google API client
            await gapi.client.init({
                apiKey: this.config.apiKey,
                clientId: this.config.clientId,
                discoveryDocs: this.config.discoveryDocs,
                scope: this.config.scopes.join(' ')
            });

            // Get auth instance
            this.authInstance = gapi.auth2.getAuthInstance();
            
            // Check if user is already signed in
            this.isSignedIn = this.authInstance.isSignedIn.get();
            
            if (this.isSignedIn) {
                await this.HandleSignIn();
            }

            // Listen for sign-in state changes
            this.authInstance.isSignedIn.listen(this.OnSignInStatusChanged.bind(this));

            console.log('✅ Google Drive authentication initialized');
            return true;

        } catch (error) {
            console.error('❌ Failed to initialize Google Drive auth:', error);
            throw error;
        }
    }

    LoadGoogleAPI() {
        return new Promise((resolve, reject) => {
            if (typeof gapi !== 'undefined') {
                resolve();
                return;
            }

            const script = document.createElement('script');
            script.src = 'https://apis.google.com/js/api.js';
            script.onload = () => {
                gapi.load('client:auth2', resolve);
            };
            script.onerror = reject;
            document.head.appendChild(script);
        });
    }

    async SignIn() {
        try {
            console.log('🔐 Starting sign-in process...');
            
            const authResult = await this.authInstance.signIn();
            await this.HandleSignIn();
            
            return this.currentUser;

        } catch (error) {
            console.error('❌ Sign-in failed:', error);
            throw error;
        }
    }

    async SignOut() {
        try {
            await this.authInstance.signOut();
            this.isSignedIn = false;
            this.currentUser = null;
            console.log('👋 User signed out');

        } catch (error) {
            console.error('❌ Sign-out failed:', error);
            throw error;
        }
    }

    async HandleSignIn() {
        try {
            const googleUser = this.authInstance.currentUser.get();
            const profile = googleUser.getBasicProfile();
            
            this.currentUser = {
                id: profile.getId(),
                email: profile.getEmail(),
                name: profile.getName(),
                imageUrl: profile.getImageUrl(),
                accessToken: googleUser.getAuthResponse().access_token
            };

            this.isSignedIn = true;

            // Initialize API services
            this.driveService = gapi.client.drive;
            this.sheetsService = gapi.client.sheets;

            console.log('✅ User signed in:', this.currentUser.email);
            
            // Check user permissions in our system
            await this.CheckUserPermissions();

        } catch (error) {
            console.error('❌ Error handling sign-in:', error);
            throw error;
        }
    }

    OnSignInStatusChanged(isSignedIn) {
        if (isSignedIn) {
            this.HandleSignIn();
        } else {
            this.isSignedIn = false;
            this.currentUser = null;
            console.log('👤 User signed out');
        }
    }

    async CheckUserPermissions() {
        try {
            if (!this.currentUser) {
                throw new Error('No user signed in');
            }

            console.log('🔍 Checking user permissions...');

            // Check if user exists in our user management sheet
            const userData = await this.GetUserFromSheet(this.currentUser.email);
            
            if (!userData) {
                console.log('⚠️ User not found in system - needs registration');
                return {
                    status: 'unregistered',
                    message: 'Please register for library access'
                };
            }

            const userStatus = {
                status: userData.status,
                role: userData.role,
                permissions: userData.permissions,
                lastLogin: userData.lastLogin
            };

            // Update last login time
            await this.UpdateUserLastLogin(this.currentUser.email);

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

    async GetUserFromSheet(email) {
        try {
            const response = await this.sheetsService.spreadsheets.values.get({
                spreadsheetId: this.config.sheetIds.users,
                range: 'Users!A:H'
            });

            const rows = response.result.values;
            if (!rows || rows.length <= 1) return null;

            // Find user by email (first column)
            for (let i = 1; i < rows.length; i++) {
                const row = rows[i];
                if (row[0] && row[0].toLowerCase() === email.toLowerCase()) {
                    return {
                        email: row[0],
                        userId: row[1],
                        role: row[2],
                        status: row[3],
                        created: row[4],
                        lastLogin: row[5],
                        permissions: row[6],
                        notes: row[7],
                        rowIndex: i + 1
                    };
                }
            }

            return null;

        } catch (error) {
            console.error('❌ Error getting user from sheet:', error);
            throw error;
        }
    }

    async UpdateUserLastLogin(email) {
        try {
            const user = await this.GetUserFromSheet(email);
            if (!user) return;

            const timestamp = new Date().toISOString();
            
            await this.sheetsService.spreadsheets.values.update({
                spreadsheetId: this.config.sheetIds.users,
                range: `Users!F${user.rowIndex}`,
                valueInputOption: 'RAW',
                resource: {
                    values: [[timestamp]]
                }
            });

            // Log the activity
            await this.LogActivity(email, 'login', 'User signed in');

        } catch (error) {
            console.error('❌ Error updating last login:', error);
        }
    }

    async LogActivity(email, action, details) {
        try {
            const timestamp = new Date().toISOString();
            const ip = await this.GetUserIP();

            await this.sheetsService.spreadsheets.values.append({
                spreadsheetId: this.config.sheetIds.activity,
                range: 'ActivityLog!A:E',
                valueInputOption: 'RAW',
                resource: {
                    values: [[timestamp, email, action, details, ip]]
                }
            });

        } catch (error) {
            console.error('❌ Error logging activity:', error);
        }
    }

    async GetUserIP() {
        try {
            const response = await fetch('https://api.ipify.org?format=json');
            const data = await response.json();
            return data.ip;
        } catch (error) {
            return 'unknown';
        }
    }
}

// Google Drive File Operations
class GoogleDriveFileManager {
    constructor(auth, config) {
        this.auth = auth;
        this.config = config;
    }

    async DownloadFile(fileId, fileName = null) {
        try {
            console.log(`📥 Downloading file: ${fileId}`);

            const response = await this.auth.driveService.files.get({
                fileId: fileId,
                alt: 'media'
            });

            // Convert response to blob
            const blob = new Blob([response.body], { 
                type: response.headers['content-type'] || 'application/octet-stream' 
            });

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
                fields: 'id,name,size,modifiedTime,mimeType,description'
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

    async StreamPDF(fileId) {
        try {
            console.log(`📖 Streaming PDF: ${fileId}`);

            // Get file metadata first
            const metadata = await this.GetFileMetadata(fileId);
            
            if (!metadata.mimeType.includes('pdf')) {
                throw new Error('File is not a PDF');
            }

            // Create streaming URL
            const streamUrl = `https://drive.google.com/file/d/${fileId}/preview`;
            
            return {
                streamUrl: streamUrl,
                metadata: metadata
            };

        } catch (error) {
            console.error(`❌ Error streaming PDF ${fileId}:`, error);
            throw error;
        }
    }
}

// Database Manager for SQLite files from Drive
class DatabaseManager {
    constructor(fileManager, config) {
        this.fileManager = fileManager;
        this.config = config;
        this.localDB = null;
        this.dbVersion = null;
    }

    async InitializeDatabase() {
        try {
            console.log('🗄️ Initializing library database...');

            // Check local database version
            const localVersion = this.GetLocalDBVersion();
            
            // Get remote database version
            const remoteVersion = await this.GetRemoteDBVersion();

            console.log(`Local DB version: ${localVersion || 'None'}`);
            console.log(`Remote DB version: ${remoteVersion}`);

            if (!localVersion || this.IsVersionNewer(remoteVersion, localVersion)) {
                console.log('📥 Database update required, downloading...');
                await this.DownloadAndInstallDatabase();
            } else {
                console.log('✅ Database is up to date');
                await this.LoadLocalDatabase();
            }

            return true;

        } catch (error) {
            console.error('❌ Error initializing database:', error);
            throw error;
        }
    }

    GetLocalDBVersion() {
        return localStorage.getItem('library_db_version');
    }

    async GetRemoteDBVersion() {
        try {
            const dbFileId = this.config.folderIds.database + '/my_library.db';
            const metadata = await this.fileManager.GetFileMetadata(dbFileId);
            
            // Version could be in description or we can use modifiedTime
            return metadata.description || metadata.modifiedTime;

        } catch (error) {
            console.error('❌ Error getting remote DB version:', error);
            return '1.0.0';
        }
    }

    IsVersionNewer(remoteVersion, localVersion) {
        // Simple comparison - in production, use semantic versioning
        return new Date(remoteVersion) > new Date(localVersion);
    }

    async DownloadAndInstallDatabase() {
        try {
            const dbFileId = this.config.folderIds.database + '/my_library.db';
            
            // Download database file
            const dbBlob = await this.fileManager.DownloadFile(dbFileId);
            
            // Store in IndexedDB for offline access
            await this.StoreInIndexedDB('library_database', dbBlob);
            
            // Initialize SQL.js
            await this.LoadLocalDatabase();
            
            // Update local version
            const remoteVersion = await this.GetRemoteDBVersion();
            localStorage.setItem('library_db_version', remoteVersion);

            console.log('✅ Database downloaded and installed');

        } catch (error) {
            console.error('❌ Error downloading database:', error);
            throw error;
        }
    }

    async LoadLocalDatabase() {
        // Implementation depends on SQL.js integration
        console.log('📊 Loading local database...');
        // This would initialize SQL.js with the database blob
    }

    async StoreInIndexedDB(storeName, data) {
        return new Promise((resolve, reject) => {
            const request = indexedDB.open('AndersonsLibrary', 1);
            
            request.onupgradeneeded = (event) => {
                const db = event.target.result;
                if (!db.objectStoreNames.contains(storeName)) {
                    db.createObjectStore(storeName);
                }
            };
            
            request.onsuccess = (event) => {
                const db = event.target.result;
                const transaction = db.transaction([storeName], 'readwrite');
                const store = transaction.objectStore(storeName);
                
                store.put(data, 'data');
                
                transaction.oncomplete = () => resolve();
                transaction.onerror = () => reject(transaction.error);
            };
            
            request.onerror = () => reject(request.error);
        });
    }
}

// Export for use in other modules
window.GoogleDriveAuth = GoogleDriveAuth;
window.GoogleDriveFileManager = GoogleDriveFileManager;
window.DatabaseManager = DatabaseManager;
