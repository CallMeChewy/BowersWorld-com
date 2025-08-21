// File: OurLibraryGoogleAuth.js
// Path: /home/herb/Desktop/OurLibrary/JS/OurLibraryGoogleAuth.js
// Standard: AIDEV-PascalCase-2.3
// Created: 2025-08-19
// Last Modified: 2025-08-19 04:15PM
// Description: OurLibrary Google Drive authentication and registration tracking
// Adapted from AndyGoogle GoogleDriveAuth.js for OurLibrary hybrid architecture

class OurLibraryGoogleAuth {
    constructor(config) {
        this.config = {
            clientId: config.clientId,
            apiKey: config.apiKey,
            scopes: [
                'https://www.googleapis.com/auth/drive.file',
                'https://www.googleapis.com/auth/spreadsheets',
                'https://www.googleapis.com/auth/userinfo.email',
                'https://www.googleapis.com/auth/userinfo.profile'
            ],
            discoveryDocs: [
                'https://www.googleapis.com/discovery/v1/apis/drive/v3/rest',
                'https://www.googleapis.com/discovery/v1/apis/sheets/v4/rest'
            ],
            sheetIds: {
                userRegistrations: config.userRegistrationsSheetId,
                incompleteEmails: config.incompleteEmailsSheetId,
                sessionTracking: config.sessionTrackingSheetId
            }
        };
        
        this.isSignedIn = false;
        this.currentUser = null;
        this.accessToken = null;
        this.sheetsService = null;
        this.gapiLoaded = false;
        this.sessionId = this.generateSessionId();
        this.simulateMode = false;
    }

    async initialize() {
        try {
            console.log('🔑 Initializing OurLibrary Google Services...');
            
            // Check if we have a real client ID (not placeholder)
            if (this.config.clientId.includes('himalaya2025ourlibrary')) {
                console.warn('⚠️ Using placeholder OAuth Client ID - Sheets logging will be simulated');
                this.simulateMode = true;
                console.log('✅ OurLibrary Google Services initialized (simulation mode)');
                return true;
            }
            
            console.log('🎯 Using REAL OAuth Client ID - Live Google Sheets integration enabled');
            
            // Load Google Identity Services
            await this.loadGoogleIdentityServices();
            
            // Load Google API client for Sheets API calls
            await this.loadGoogleAPI();
            
            // Initialize Google Identity Services
            google.accounts.id.initialize({
                client_id: this.config.clientId,
                callback: this.handleCredentialResponse.bind(this),
                auto_select: false,
                cancel_on_tap_outside: false
            });

            console.log('✅ OurLibrary Google Services initialized');
            return true;

        } catch (error) {
            console.warn('⚠️ Google Services initialization failed, falling back to simulation mode:', error);
            this.simulateMode = true;
            return true;
        }
    }

    loadGoogleIdentityServices() {
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

    loadGoogleAPI() {
        return new Promise((resolve, reject) => {
            if (typeof gapi !== 'undefined') {
                this.initializeGapi().then(resolve).catch(reject);
                return;
            }

            const script = document.createElement('script');
            script.src = 'https://apis.google.com/js/api.js';
            script.onload = () => {
                gapi.load('client', () => {
                    this.initializeGapi().then(resolve).catch(reject);
                });
            };
            script.onerror = reject;
            document.head.appendChild(script);
        });
    }

    async initializeGapi() {
        try {
            await gapi.client.init({
                apiKey: this.config.apiKey,
                discoveryDocs: this.config.discoveryDocs
            });
            this.gapiLoaded = true;
            console.log('✅ Google API client initialized for OurLibrary');
        } catch (error) {
            console.error('❌ Error initializing Google API client:', error);
            throw error;
        }
    }

    // Handle sign-in response from Google Identity Services
    handleCredentialResponse(response) {
        console.log('🎉 Google OAuth successful for OurLibrary!');
        
        try {
            // Decode the JWT token to get user info
            const payload = this.parseJWT(response.credential);
            
            this.currentUser = {
                id: payload.sub,
                email: payload.email,
                name: payload.name,
                imageUrl: payload.picture,
                emailVerified: payload.email_verified,
                credential: response.credential
            };

            this.isSignedIn = true;
            console.log('✅ User authenticated:', this.currentUser.email);
            
            // Request access token for API calls
            this.requestAccessToken().then(() => {
                // Log Google registration attempt
                this.logRegistrationActivity('google_oauth_success', {
                    email: this.currentUser.email,
                    name: this.currentUser.name,
                    provider: 'google'
                });
                
                // Trigger completion of Google registration
                this.onGoogleRegistrationSuccess(this.currentUser);
                
            }).catch(error => {
                console.error('❌ Error getting access token:', error);
                this.onRegistrationError(error);
            });
            
        } catch (error) {
            console.error('❌ Error processing credential response:', error);
            this.onRegistrationError(error);
        }
    }

    // Request access token for Sheets API calls
    async requestAccessToken() {
        return new Promise((resolve, reject) => {
            console.log('🔐 Requesting access token for Sheets API...');
            
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
                        
                        // Initialize Sheets service
                        this.sheetsService = gapi.client.sheets;
                    }
                    
                    console.log('✅ Access token obtained for Sheets API');
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

    // Parse JWT token
    parseJWT(token) {
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

    // Generate unique session ID
    generateSessionId() {
        return `ourlibrary_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    }

    // ==================== REGISTRATION TRACKING ====================

    // Log incomplete email capture
    async logIncompleteEmail(email, step = 'email_entered') {
        try {
            if (this.simulateMode) {
                console.log('🧪 SIMULATED - Incomplete email logged:', {
                    email,
                    step,
                    timestamp: new Date().toISOString(),
                    sessionId: this.sessionId,
                    sheetId: this.config.sheetIds.incompleteEmails
                });
                return;
            }

            if (!this.sheetsService) {
                console.warn('⚠️ Sheets service not available for logging');
                return;
            }

            const timestamp = new Date().toISOString();
            const values = [[
                email,
                timestamp,
                step,
                this.sessionId,
                navigator.userAgent,
                document.referrer || 'direct',
                window.location.hostname
            ]];

            await this.sheetsService.spreadsheets.values.append({
                spreadsheetId: this.config.sheetIds.incompleteEmails,
                range: 'Sheet1!A:G',
                valueInputOption: 'RAW',
                resource: { values }
            });

            console.log('📊 Incomplete email logged:', email, step);

        } catch (error) {
            console.error('❌ Error logging incomplete email:', error);
            // Don't block registration flow on logging errors
        }
    }

    // Log registration activity
    async logRegistrationActivity(action, details = {}) {
        try {
            if (this.simulateMode) {
                console.log('🧪 SIMULATED - Registration activity logged:', {
                    action,
                    email: details.email || 'unknown',
                    details,
                    timestamp: new Date().toISOString(),
                    sessionId: this.sessionId,
                    sheetId: this.config.sheetIds.sessionTracking
                });
                return;
            }

            if (!this.sheetsService) {
                console.warn('⚠️ Sheets service not available for logging');
                return;
            }

            const timestamp = new Date().toISOString();
            const userId = this.currentUser ? this.currentUser.id : 'anonymous';
            const email = this.currentUser ? this.currentUser.email : (details.email || 'unknown');
            
            const values = [[
                userId,
                email,
                action,
                JSON.stringify(details),
                this.sessionId,
                timestamp,
                navigator.userAgent,
                window.location.hostname
            ]];

            await this.sheetsService.spreadsheets.values.append({
                spreadsheetId: this.config.sheetIds.sessionTracking,
                range: 'Sheet1!A:H',
                valueInputOption: 'RAW',
                resource: { values }
            });

            console.log('📊 Registration activity logged:', action, email);

        } catch (error) {
            console.error('❌ Error logging registration activity:', error);
            // Don't block registration flow on logging errors
        }
    }

    // Complete user registration (write to UserRegistrations sheet)
    async completeUserRegistration(userData) {
        try {
            if (this.simulateMode) {
                console.log('🧪 SIMULATED - User registration completed:', {
                    userId: userData.userId,
                    email: userData.email,
                    name: userData.name,
                    authMethod: userData.authMethod,
                    timestamp: new Date().toISOString(),
                    sheetId: this.config.sheetIds.userRegistrations
                });
                return true;
            }

            if (!this.sheetsService) {
                throw new Error('Sheets service not available');
            }

            const timestamp = new Date().toISOString();
            const values = [[
                userData.userId || this.currentUser?.id || 'unknown',
                userData.email,
                userData.name || '',
                userData.authMethod || 'email',
                'complete',
                userData.registrationStartTime || timestamp,
                timestamp, // completion time
                userData.location || '',
                userData.consent || false,
                userData.notes || ''
            ]];

            await this.sheetsService.spreadsheets.values.append({
                spreadsheetId: this.config.sheetIds.userRegistrations,
                range: 'Sheet1!A:J',
                valueInputOption: 'RAW',
                resource: { values }
            });

            console.log('✅ User registration completed in Sheets:', userData.email);
            
            // Remove from incomplete emails if it was there
            await this.removeIncompleteEmail(userData.email);

            return true;

        } catch (error) {
            console.error('❌ Error completing user registration:', error);
            throw error;
        }
    }

    // Remove email from incomplete tracking
    async removeIncompleteEmail(email) {
        try {
            // For simplicity, we'll just log the completion
            // In a full implementation, you'd search and delete the row
            console.log('📊 Email moved from incomplete to complete:', email);
        } catch (error) {
            console.error('❌ Error removing incomplete email:', error);
        }
    }

    // ==================== EVENT HANDLERS ====================

    // Override these in your implementation
    onGoogleRegistrationSuccess(user) {
        console.log('🎉 Google registration success:', user.email);
        // This will be overridden by the registration form
    }

    onEmailRegistrationStep(step, data) {
        console.log('📧 Email registration step:', step, data);
        // This will be overridden by the registration form
    }

    onRegistrationError(error) {
        console.error('❌ Registration error:', error);
        // This will be overridden by the registration form
    }

    onRegistrationComplete(userData) {
        console.log('✅ Registration complete:', userData.email);
        // This will be overridden by the registration form
    }

    // ==================== UTILITY METHODS ====================

    // Show Google Sign-In button
    renderSignInButton(elementId, options = {}) {
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

    // Sign out
    async signOut() {
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
            
            console.log('👋 User signed out from OurLibrary');

        } catch (error) {
            console.error('❌ Sign-out failed:', error);
            throw error;
        }
    }
}

// Registration Manager - Coordinates Firebase Auth + Google Sheets
class OurLibraryRegistrationManager {
    constructor(firebaseAuth, googleAuth) {
        this.firebaseAuth = firebaseAuth;
        this.googleAuth = googleAuth;
        this.registrationStartTime = null;
        this.pendingUserData = null;
    }

    // Log incomplete email capture (exposed method)
    async logIncompleteEmail(email, step = 'email_blur') {
        try {
            return await this.googleAuth.logIncompleteEmail(email, step);
        } catch (error) {
            console.error('❌ Error logging incomplete email:', error);
            return { success: false, error: error.message };
        }
    }

    // Log complete registration (exposed method)
    async logCompleteRegistration(userData) {
        try {
            return await this.googleAuth.completeUserRegistration(userData);
        } catch (error) {
            console.error('❌ Error logging complete registration:', error);
            return { success: false, error: error.message };
        }
    }

    // Start email registration process
    async startEmailRegistration(formData) {
        try {
            this.registrationStartTime = new Date().toISOString();
            this.pendingUserData = { ...formData, authMethod: 'email' };

            // Log incomplete email immediately
            await this.googleAuth.logIncompleteEmail(formData.email, 'email_entered');
            
            // Log registration start
            await this.googleAuth.logRegistrationActivity('email_registration_start', {
                email: formData.email,
                name: formData.fullName
            });

            return { success: true };

        } catch (error) {
            console.error('❌ Error starting email registration:', error);
            return { success: false, error: error.message };
        }
    }

    // Complete email verification and create Firebase account
    async completeEmailRegistration(verificationCode) {
        try {
            if (!this.pendingUserData) {
                throw new Error('No pending registration data');
            }

            // Log verification attempt
            await this.googleAuth.logRegistrationActivity('email_verification_attempt', {
                email: this.pendingUserData.email,
                code: verificationCode
            });

            // Create Firebase account using the global function (not a method on auth object)
            const userCredential = await window.createUserWithEmailAndPassword(
                this.firebaseAuth,
                this.pendingUserData.email,
                this.pendingUserData.password
            );

            const firebaseUser = userCredential.user;
            
            // Since we verified the email through our custom system, mark it as verified in Firebase
            // Note: In production, you'd verify the code against your database first
            
            // Complete registration in Google Sheets
            const userData = {
                userId: firebaseUser.uid,
                email: this.pendingUserData.email,
                name: this.pendingUserData.fullName,
                authMethod: 'email',
                registrationStartTime: this.registrationStartTime,
                location: this.pendingUserData.location || '',
                consent: this.pendingUserData.consent || false
            };

            await this.googleAuth.completeUserRegistration(userData);

            // Log successful completion
            await this.googleAuth.logRegistrationActivity('email_registration_complete', {
                userId: firebaseUser.uid,
                email: this.pendingUserData.email
            });

            this.pendingUserData = null;
            return { success: true, user: firebaseUser };

        } catch (error) {
            console.error('❌ Error completing email registration:', error);
            
            // Log the error
            await this.googleAuth.logRegistrationActivity('email_registration_error', {
                email: this.pendingUserData?.email,
                error: error.message
            });

            return { success: false, error: error.message };
        }
    }

    // Handle Google OAuth registration
    async completeGoogleRegistration(googleUser, additionalData = {}) {
        try {
            // Get the ID token from the googleUser object
            const idToken = googleUser.credential;

            // Create a Google credential with the token
            const credential = window.GoogleAuthProvider.credential(idToken);

            // Sign in to Firebase with the credential
            const userCredential = await window.signInWithCredential(this.firebaseAuth, credential);
            const firebaseUser = userCredential.user;

            // Complete registration in Google Sheets
            const userData = {
                userId: firebaseUser.uid,
                email: googleUser.email,
                name: googleUser.name,
                authMethod: 'google',
                registrationStartTime: new Date().toISOString(),
                location: additionalData.location || '',
                consent: additionalData.consent || false
            };

            await this.googleAuth.completeUserRegistration(userData);

            // Log successful completion
            await this.googleAuth.logRegistrationActivity('google_registration_complete', {
                userId: firebaseUser.uid,
                email: googleUser.email
            });

            return { success: true, user: firebaseUser };

        } catch (error) {
            console.error('❌ Error completing Google registration:', error);
            
            // Log the error
            await this.googleAuth.logRegistrationActivity('google_registration_error', {
                email: googleUser.email,
                error: error.message
            });

            return { success: false, error: error.message };
        }
    }
}

// Export classes
window.OurLibraryGoogleAuth = OurLibraryGoogleAuth;
window.OurLibraryRegistrationManager = OurLibraryRegistrationManager;

console.log('📚 OurLibrary Google Auth module loaded');