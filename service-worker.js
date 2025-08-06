// File: service-worker.js
// Path: /home/herb/Desktop/AndyLibrary/WebPages/service-worker.js
// Standard: AIDEV-PascalCase-2.1
// Created: 2025-07-27
// Last Modified: 2025-07-27 10:58PM

/**
 * Service Worker for AndyLibrary PWA
 * Educational mission: Offline-first caching for global accessibility
 */

const CACHE_NAME = 'andylibrary-v1.0.0';
const API_CACHE = 'andylibrary-api-v1.0.0';
const THUMBNAIL_CACHE = 'andylibrary-thumbnails-v1.0.0';

// Core files for offline functionality
const CORE_FILES = [
  '/',
  '/pdf-reader.html',
  '/static/assets/AndyLibrary.png',
  '/static/styles/desktop-library.css',
  '/static/scripts/desktop-library.js',
  '/manifest.json'
];

// Install event - cache core files
self.addEventListener('install', event => {
  console.log('📦 Service Worker installing...');
  
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => {
        console.log('📚 Caching core educational content...');
        return cache.addAll(CORE_FILES);
      })
      .then(() => {
        console.log('✅ Core files cached for offline access');
        return self.skipWaiting();
      })
      .catch(error => {
        console.error('❌ Cache installation failed:', error);
      })
  );
});

// Activate event - cleanup old caches
self.addEventListener('activate', event => {
  console.log('🚀 Service Worker activating...');
  
  event.waitUntil(
    caches.keys()
      .then(cacheNames => {
        return Promise.all(
          cacheNames.map(cacheName => {
            if (cacheName !== CACHE_NAME && 
                cacheName !== API_CACHE && 
                cacheName !== THUMBNAIL_CACHE) {
              console.log('🗑️ Removing old cache:', cacheName);
              return caches.delete(cacheName);
            }
          })
        );
      })
      .then(() => {
        console.log('✅ Service Worker activated - offline mode ready');
        return self.clients.claim();
      })
  );
});

// Fetch event - serve from cache with network fallback
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  
  // Handle different types of requests
  if (url.pathname.startsWith('/api/books/') && url.pathname.endsWith('/pdf')) {
    // PDF files: Aggressive caching for offline reading
    event.respondWith(handlePdfRequest(event.request));
  } else if (url.pathname.startsWith('/api/thumbnails/')) {
    // Thumbnails: Cache first, network fallback
    event.respondWith(handleThumbnailRequest(event.request));
  } else if (url.pathname.startsWith('/api/auth/')) {
    // Auth API calls: Always use network, never cache
    return; // Let browser handle directly
  } else if (url.pathname.startsWith('/api/')) {
    // API calls: Network first, cache fallback
    event.respondWith(handleApiRequest(event.request));
  } else {
    // Static files: Cache first, network fallback
    event.respondWith(handleStaticRequest(event.request));
  }
});

/**
 * Handle PDF requests with maximum caching for offline reading
 * Educational priority: PDFs are large files - cache aggressively for cost protection
 */
async function handlePdfRequest(request) {
  const PDF_CACHE = 'andylibrary-pdfs-v1.0.0';
  
  try {
    const cache = await caches.open(PDF_CACHE);
    const cached = await cache.match(request);
    
    if (cached) {
      console.log('📖 Serving cached PDF for offline reading');
      return cached;
    }
    
    // Fetch and cache new PDF
    console.log('📥 Downloading PDF for offline access...');
    const response = await fetch(request);
    
    if (response.ok) {
      console.log('📖 Caching PDF for offline reading');
      cache.put(request, response.clone());
    }
    
    return response;
    
  } catch (error) {
    console.error('❌ PDF request failed:', error);
    return new Response('PDF unavailable offline', { 
      status: 503,
      headers: { 'Content-Type': 'text/plain' }
    });
  }
}

/**
 * Handle thumbnail requests with aggressive caching
 * Educational priority: Images are expensive on limited data plans
 */
async function handleThumbnailRequest(request) {
  try {
    const cache = await caches.open(THUMBNAIL_CACHE);
    const cached = await cache.match(request);
    
    if (cached) {
      console.log('📸 Serving cached thumbnail');
      return cached;
    }
    
    // Fetch and cache new thumbnail
    const response = await fetch(request);
    if (response.ok) {
      console.log('📸 Caching new thumbnail');
      cache.put(request, response.clone());
    }
    return response;
    
  } catch (error) {
    console.error('❌ Thumbnail request failed:', error);
    return new Response('Thumbnail unavailable', { status: 404 });
  }
}

/**
 * Handle API requests with network priority
 * Educational priority: Fresh data when online, cached when offline
 */
async function handleApiRequest(request) {
  try {
    // Try network first
    const response = await fetch(request);
    
    if (response.ok) {
      // Cache successful API responses
      const cache = await caches.open(API_CACHE);
      cache.put(request, response.clone());
      console.log('📡 API response cached');
    }
    
    return response;
    
  } catch (error) {
    console.log('🔄 Network failed, trying cache...');
    
    // Fallback to cache
    const cache = await caches.open(API_CACHE);
    const cached = await cache.match(request);
    
    if (cached) {
      console.log('📚 Serving cached API data');
      return cached;
    }
    
    console.error('❌ No cached data available');
    return new Response(
      JSON.stringify({ 
        error: 'Offline - data not available',
        message: 'Connect to internet to sync latest content'
      }), 
      { 
        status: 503,
        headers: { 'Content-Type': 'application/json' }
      }
    );
  }
}

/**
 * Handle static file requests
 * Educational priority: Core functionality always available
 */
async function handleStaticRequest(request) {
  try {
    const cache = await caches.open(CACHE_NAME);
    const cached = await cache.match(request);
    
    if (cached) {
      console.log('📄 Serving cached static file');
      return cached;
    }
    
    // Fetch and cache new static file
    const response = await fetch(request);
    if (response.ok) {
      console.log('📄 Caching new static file');
      cache.put(request, response.clone());
    }
    return response;
    
  } catch (error) {
    console.error('❌ Static file request failed:', error);
    
    // Return offline page for navigation requests
    if (request.mode === 'navigate') {
      return caches.match('/') || new Response('Offline');
    }
    
    return new Response('Resource unavailable offline', { status: 404 });
  }
}

// Background sync for when connection returns
self.addEventListener('sync', event => {
  if (event.tag === 'library-sync') {
    console.log('🔄 Background sync: Updating library data...');
    event.waitUntil(syncLibraryData());
  }
});

/**
 * Sync library data when connection is restored
 */
async function syncLibraryData() {
  try {
    // Fetch latest categories and popular books
    const responses = await Promise.all([
      fetch('/api/categories'),
      fetch('/api/books/search?limit=100')
    ]);
    
    if (responses.every(r => r.ok)) {
      console.log('✅ Library data synced successfully');
    }
    
  } catch (error) {
    console.error('❌ Background sync failed:', error);
  }
}

// Show update notification when new version available
self.addEventListener('message', event => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    console.log('🔄 Updating to new version...');
    self.skipWaiting();
  }
});

console.log('📚 AndyLibrary Service Worker loaded - Educational mission enabled!');