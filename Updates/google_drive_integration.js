// Google Drive API Integration for Anderson's Library
// Handles file downloads, user permissions, and offline sync

class AndersonLibraryDriveManager {
    constructor() {
        this.gapi = null;
        this.driveApi = null;
        this.isInitialized = false;
        this.userPermissions = {
            canRead: false,
            canDownload: false,
            canUpload: false,
            role: 'guest'
        };
        
        // Google Drive folder IDs (set these after creating folders)
        this.folderIds = {
            books: '1abcdefghijklmnopqrstuvwxyz123456',      // Books folder
            covers: '1bcdefghijklmnopqrstuvwxyz1234567',     // Covers folder  
            database: '1cdefghijklmnopqrstuvwxyz12345678',   // Database folder
            system: '1defghijklmnopqrstuvwxyz123456789'      // System folder
        };
    }

    // Initialize Google Drive API
    async initialize() {
        try {
            console.log('🔧 Initializing Google Drive API...');
            
            // Load Google API
            await this.loadGoogleAPI();
            
            // Initialize with OAuth2
            await gapi.load('auth2:client:drive', async () => {
                await gapi.client.init({
                    apiKey: 'YOUR_GOOGLE_API_KEY',
                    clientId: 'YOUR_GOOGLE_CLIENT_ID',
                    discoveryDocs: ['https://www.googleapis.com/discovery/v1/apis/drive/v3/rest'],
                    scope: [
                        'https://www.googleapis.com/auth/drive.readonly',
                        'https://www.googleapis.com/auth/drive.file'
                    ].join(' ')
                });
                
                this.driveApi = gapi.client.drive;
                this.isInitialized = true;
                
                console.log('✅ Google Drive API initialized');
                
                // Check if user is already signed in
                const authInstance = gapi.auth2.getAuthInstance();
                if (authInstance.isSignedIn.get()) {
                    await this.loadUserPermissions();
                }
            });
            
        } catch (error) {
            console.error('❌ Failed to initialize Google Drive API:', error);
            throw error;
        }
    }

    // Load Google API script
    loadGoogleAPI() {
        return new Promise((resolve, reject) => {
            if (window.gapi) {
                resolve();
                return;
            }
            
            const script = document.createElement('script');
            script.src = 'https://apis.google.com/js/api.js';
            script.onload = () => resolve();
            script.onerror = () => reject(new Error('Failed to load Google API'));
            document.head.appendChild(script);
        });
    }

    // Authenticate user with Google
    async authenticateUser() {
        try {
            if (!this.isInitialized) {
                await this.initialize();
            }
            
            const authInstance = gapi.auth2.getAuthInstance();
            const user = await authInstance.signIn();
            
            console.log('✅ User authenticated with Google Drive');
            
            // Load user permissions from your user database
            await this.loadUserPermissions();
            
            return user;
            
        } catch (error) {
            console.error('❌ Google Drive authentication failed:', error);
            throw error;
        }
    }

    // Load user permissions from your user management system
    async loadUserPermissions() {
        try {
            const user = gapi.auth2.getAuthInstance().currentUser.get();
            const email = user.getBasicProfile().getEmail();
            
            // This would normally query your Google Sheets user database
            // For now, we'll simulate the response
            const userRecord = await this.getUserRecord(email);
            
            this.userPermissions = {
                canRead: userRecord.status === 'active',
                canDownload: ['admin', 'user'].includes(userRecord.role),
                canUpload: userRecord.role === 'admin',
                role: userRecord.role || 'guest'
            };
            
            console.log('👤 User permissions loaded:', this.userPermissions);
            
        } catch (error) {
            console.error('❌ Failed to load user permissions:', error);
            // Default to guest permissions
            this.userPermissions = {
                canRead: false,
                canDownload: false,
                canUpload: false,
                role: 'guest'
            };
        }
    }

    // Get user record from Google Sheets database
    async getUserRecord(email) {
        // This would integrate with Google Sheets API
        // For now, return a mock response
        return {
            email: email,
            role: 'user',
            status: 'active',
            permissions: ['read', 'download']
        };
    }

    // Download the main library database
    async downloadLibraryDatabase() {
        try {
            if (!this.userPermissions.canRead) {
                throw new Error('Access denied: User does not have read permissions');
            }
            
            console.log('📥 Downloading library database...');
            
            // Search for the database file
            const response = await this.driveApi.files.list({
                q: `name='library-database.json' and parents in '${this.folderIds.database}'`,
                fields: 'files(id, name, modifiedTime, size)'
            });
            
            if (response.result.files.length === 0) {
                throw new Error('Library database not found');
            }
            
            const file = response.result.files[0];
            
            // Download the file content
            const content = await this.downloadFileContent(file.id);
            const libraryData = JSON.parse(content);
            
            // Cache locally for offline access
            await this.cacheLibraryData(libraryData);
            
            console.log(`✅ Downloaded library database: ${libraryData.books.length} books`);
            return libraryData;
            
        } catch (error) {
            console.error('❌ Failed to download library database:', error);
            
            // Try to load from local cache
            return await this.loadCachedLibraryData();
        }
    }

    // Download file content from Google Drive
    async downloadFileContent(fileId) {
        const response = await gapi.client.request({
            path: `https://www.googleapis.com/drive/v3/files/${fileId}`,
            params: { alt: 'media' }
        });
        
        return response.body;
    }

    // Download a specific book PDF
    async downloadBook(bookFilename) {
        try {
            if (!this.userPermissions.canDownload) {
                throw new Error('Access denied: User does not have download permissions');
            }
            
            console.log(`📖 Downloading book: ${bookFilename}`);
            
            // Search for the book file
            const response = await this.driveApi.files.list({
                q: `name='${bookFilename}' and parents in '${this.folderIds.books}'`,
                fields: 'files(id, name, size, mimeType)'
            });
            
            if (response.result.files.length === 0) {
                throw new Error(`Book not found: ${bookFilename}`);
            }
            
            const file = response.result.files[0];
            
            // Create download link
            const downloadUrl = `https://drive.google.com/uc?id=${file.id}&export=download`;
            
            // Trigger download
            const link = document.createElement('a');
            link.href = downloadUrl;
            link.download = bookFilename;
            link.target = '_blank';
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
            
            console.log(`✅ Download started: ${bookFilename}`);
            
            // Log download for analytics
            await this.logBookAccess(bookFilename, 'download');
            
        } catch (error) {
            console.error(`❌ Failed to download book: ${bookFilename}`, error);
            throw error;
        }
    }

    // Get book for reading (streaming)
    async getBookForReading(bookFilename) {
        try {
            if (!this.userPermissions.canRead) {
                throw new Error('Access denied: User does not have read permissions');
            }
            
            console.log(`📄 Loading book for reading: ${bookFilename}`);
            
            // Search for the book file
            const response = await this.driveApi.files.list({
                q: `name='${bookFilename}' and parents in '${this.folderIds.books}'`,
                fields: 'files(id, name, webViewLink, embedLink)'
            });
            
            if (response.result.files.length === 0) {
                throw new Error(`Book not found: ${bookFilename}`);
            }
            
            const file = response.result.files[0];
            
            // Return URLs for PDF.js or Google Drive viewer
            const bookData = {
                id: file.id,
                name: file.name,
                viewUrl: file.webViewLink,
                embedUrl: file.embedLink,
                directUrl: `https://drive.google.com/file/d/${file.id}/view`
            };
            
            // Log reading access for analytics
            await this.logBookAccess(bookFilename, 'read');
            
            console.log(`✅ Book ready for reading: ${bookFilename}`);
            return bookData;
            
        } catch (error) {
            console.error(`❌ Failed to load book for reading: ${bookFilename}`, error);
            throw error;
        }
    }

    // Download book cover image
    async downloadBookCover(bookId) {
        try {
            console.log(`🖼️ Downloading cover for book: ${bookId}`);
            
            // Search for cover image
            const coverFilename = `${bookId}.jpg`;
            const response = await this.driveApi.files.list({
                q: `name='${coverFilename}' and parents in '${this.folderIds.covers}'`,
                fields: 'files(id, name, webContentLink)'
            });
            
            if (response.result.files.length === 0) {
                // Return default cover if not found
                return '/library/assets/images/default-book-cover.png';
            }
            
            const file = response.result.files[0];
            return `https://drive.google.com/uc?id=${file.id}`;
            
        } catch (error) {
            console.error(`❌ Failed to download cover for: ${bookId}`, error);
            return '/library/assets/images/default-book-cover.png';
        }
    }

    // Cache library data locally using IndexedDB
    async cacheLibraryData(libraryData) {
        try {
            if (!('indexedDB' in window)) {
                console.warn('IndexedDB not supported - caching disabled');
                return;
            }
            
            const db = await this.openIndexedDB();
            const transaction = db.transaction(['library'], 'readwrite');
            const store = transaction.objectStore('library');
            
            await store.put({
                id: 'main',
                data: libraryData,
                timestamp: Date.now()
            });
            
            console.log('💾 Library data cached locally');
            
        } catch (error) {
            console.error('❌ Failed to cache library data:', error);
        }
    }

    // Load cached library data
    async loadCachedLibraryData() {
        try {
            if (!('indexedDB' in window)) {
                throw new Error('IndexedDB not supported');
            }
            
            const db = await this.openIndexedDB();
            const transaction = db.transaction(['library'], 'readonly');
            const store = transaction.objectStore('library');
            const result = await store.get('main');
            
            if (result && result.data) {
                console.log('📱 Loaded library data from cache');
                return result.data;
            }
            
            throw new Error('No cached data available');
            
        } catch (error) {
            console.error('❌ Failed to load cached data:', error);
            
            // Return empty library structure
            return {
                metadata: {
                    totalBooks: 0,
                    lastUpdated: new Date().toISOString(),
                    version: '1.0.0',
                    source: 'Cache unavailable'
                },
                books: []
            };
        }
    }

    // Open IndexedDB connection
    openIndexedDB() {
        return new Promise((resolve, reject) => {
            const request = indexedDB.open('AndersonLibrary', 1);
            
            request.onerror = () => reject(request.error);
            request.onsuccess = () => resolve(request.result);
            
            request.onupgradeneeded = (event) => {
                const db = event.target.result;
                
                if (!db.objectStoreNames.contains('library')) {
                    db.createObjectStore('library', { keyPath: 'id' });
                }
                
                if (!db.objectStoreNames.contains('analytics')) {
                    db.createObjectStore('analytics', { keyPath: 'id', autoIncrement: true });
                }
            };
        });
    }

    // Log book access for analytics
    async logBookAccess(bookFilename, action) {
        try {
            const accessLog = {
                bookFilename,
                action,
                timestamp: Date.now(),
                userEmail: gapi.auth2.getAuthInstance().currentUser.get().getBasicProfile().getEmail()
            };
            
            // Store locally
            const db = await this.openIndexedDB();
            const transaction = db.transaction(['analytics'], 'readwrite');
            const store = transaction.objectStore('analytics');
            await store.add(accessLog);
            
            // Optionally sync to Google Sheets for admin analytics
            // await this.syncAnalyticsToSheets(accessLog);
            
        } catch (error) {
            console.error('❌ Failed to log book access:', error);
        }
    }

    // Check if user is authenticated with Google Drive
    isAuthenticated() {
        if (!this.isInitialized) return false;
        
        const authInstance = gapi.auth2.getAuthInstance();
        return authInstance && authInstance.isSignedIn.get();
    }

    // Sign out from Google Drive
    async signOut() {
        try {
            if (this.isInitialized) {
                const authInstance = gapi.auth2.getAuthInstance();
                await authInstance.signOut();
                
                // Clear permissions
                this.userPermissions = {
                    canRead: false,
                    canDownload: false,
                    canUpload: false,
                    role: 'guest'
                };
                
                console.log('👋 Signed out from Google Drive');
            }
        } catch (error) {
            console.error('❌ Failed to sign out:', error);
        }
    }

    // Upload file (admin only)
    async uploadFile(file, folderId) {
        try {
            if (!this.userPermissions.canUpload) {
                throw new Error('Access denied: User does not have upload permissions');
            }
            
            console.log(`📤 Uploading file: ${file.name}`);
            
            const metadata = {
                name: file.name,
                parents: [folderId]
            };
            
            const form = new FormData();
            form.append('metadata', new Blob([JSON.stringify(metadata)], {type: 'application/json'}));
            form.append('file', file);
            
            const response = await fetch('https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart', {
                method: 'POST',
                headers: new Headers({
                    'Authorization': `Bearer ${gapi.auth2.getAuthInstance().currentUser.get().getAuthResponse().access_token}`
                }),
                body: form
            });
            
            if (response.ok) {
                const result = await response.json();
                console.log(`✅ File uploaded: ${file.name}`);
                return result;
            } else {
                throw new Error(`Upload failed: ${response.statusText}`);
            }
            
        } catch (error) {
            console.error(`❌ Failed to upload file: ${file.name}`, error);
            throw error;
        }
    }

    // Get usage statistics
    async getUsageStatistics() {
        try {
            const db = await this.openIndexedDB();
            const transaction = db.transaction(['analytics'], 'readonly');
            const store = transaction.objectStore('analytics');
            const allRecords = await store.getAll();
            
            // Process statistics
            const stats = {
                totalAccess: allRecords.length,
                readsCount: allRecords.filter(r => r.action === 'read').length,
                downloadsCount: allRecords.filter(r => r.action === 'download').length,
                lastAccess: allRecords.length > 0 ? new Date(Math.max(...allRecords.map(r => r.timestamp))) : null,
                topBooks: this.getTopBooks(allRecords)
            };
            
            return stats;
            
        } catch (error) {
            console.error('❌ Failed to get usage statistics:', error);
            return {
                totalAccess: 0,
                readsCount: 0,
                downloadsCount: 0,
                lastAccess: null,
                topBooks: []
            };
        }
    }

    // Helper to get most accessed books
    getTopBooks(accessLogs) {
        const bookCounts = {};
        
        accessLogs.forEach(log => {
            bookCounts[log.bookFilename] = (bookCounts[log.bookFilename] || 0) + 1;
        });
        
        return Object.entries(bookCounts)
            .sort(([,a], [,b]) => b - a)
            .slice(0, 10)
            .map(([book, count]) => ({ book, count }));
    }
}

// Export for use in the library interface
if (typeof window !== 'undefined') {
    window.AndersonLibraryDriveManager = AndersonLibraryDriveManager;
}

// Usage example:
/*
const driveManager = new AndersonLibraryDriveManager();

// Initialize and authenticate
await driveManager.initialize();
await driveManager.authenticateUser();

// Download library database
const libraryData = await driveManager.downloadLibraryDatabase();

// Download a book
await driveManager.downloadBook('Programming_Python.pdf');

// Get book for reading
const bookData = await driveManager.getBookForReading('Core_Java.pdf');

// Get usage statistics
const stats = await driveManager.getUsageStatistics();
*/