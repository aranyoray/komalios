/**
 * Efficient model cache and loader
 * - Lazy loads models only when needed
 * - Caches in memory to avoid re-downloads
 * - Supports IndexedDB for persistent caching
 */

class ModelCache {
  constructor() {
    this.cache = new Map();
    this.loading = new Map();
    this.dbName = 'ganit-ml-cache';
    this.db = null;
  }

  async initDB() {
    if (this.db) return this.db;

    return new Promise((resolve, reject) => {
      const request = indexedDB.open(this.dbName, 1);

      request.onerror = () => reject(request.error);
      request.onsuccess = () => {
        this.db = request.result;
        resolve(this.db);
      };

      request.onupgradeneeded = (event) => {
        const db = event.target.result;
        if (!db.objectStoreNames.contains('models')) {
          db.createObjectStore('models');
        }
      };
    });
  }

  /**
   * Load model with caching
   * First checks memory, then IndexedDB, then network
   */
  async loadModel(modelName, loadFn, useDB = true) {
    // Check memory cache first
    if (this.cache.has(modelName)) {
      console.log(`[ModelCache] Loaded ${modelName} from memory`);
      return this.cache.get(modelName);
    }

    // Check if already loading (prevent duplicate requests)
    if (this.loading.has(modelName)) {
      console.log(`[ModelCache] Waiting for ${modelName} to load...`);
      return this.loading.get(modelName);
    }

    // Start loading
    const loadPromise = (async () => {
      try {
        // Try IndexedDB first
        if (useDB) {
          const cachedData = await this.getFromDB(modelName);
          if (cachedData) {
            console.log(`[ModelCache] Loaded ${modelName} from IndexedDB`);
            this.cache.set(modelName, cachedData);
            return cachedData;
          }
        }

        // Load from network
        console.log(`[ModelCache] Loading ${modelName} from network...`);
        const startTime = performance.now();
        const model = await loadFn();
        const loadTime = performance.now() - startTime;
        console.log(`[ModelCache] Loaded ${modelName} in ${loadTime.toFixed(0)}ms`);

        // Cache it
        this.cache.set(modelName, model);

        // Persist to IndexedDB (don't await to avoid blocking)
        if (useDB) {
          this.saveToDB(modelName, model).catch(err =>
            console.warn(`Failed to cache ${modelName} to IndexedDB:`, err)
          );
        }

        return model;
      } finally {
        this.loading.delete(modelName);
      }
    })();

    this.loading.set(modelName, loadPromise);
    return loadPromise;
  }

  async getFromDB(modelName) {
    try {
      const db = await this.initDB();
      return new Promise((resolve, reject) => {
        const transaction = db.transaction(['models'], 'readonly');
        const store = transaction.objectStore('models');
        const request = store.get(modelName);

        request.onsuccess = () => resolve(request.result);
        request.onerror = () => reject(request.error);
      });
    } catch (error) {
      console.warn('IndexedDB get failed:', error);
      return null;
    }
  }

  async saveToDB(modelName, data) {
    try {
      const db = await this.initDB();
      return new Promise((resolve, reject) => {
        const transaction = db.transaction(['models'], 'readwrite');
        const store = transaction.objectStore('models');
        const request = store.put(data, modelName);

        request.onsuccess = () => resolve();
        request.onerror = () => reject(request.error);
      });
    } catch (error) {
      console.warn('IndexedDB save failed:', error);
    }
  }

  /**
   * Preload models in background when idle
   */
  preloadWhenIdle(modelName, loadFn) {
    if ('requestIdleCallback' in window) {
      requestIdleCallback(() => {
        this.loadModel(modelName, loadFn);
      }, { timeout: 5000 });
    } else {
      // Fallback for browsers without requestIdleCallback
      setTimeout(() => {
        this.loadModel(modelName, loadFn);
      }, 2000);
    }
  }

  clearMemoryCache() {
    this.cache.clear();
    console.log('[ModelCache] Memory cache cleared');
  }

  async clearDBCache() {
    try {
      const db = await this.initDB();
      const transaction = db.transaction(['models'], 'readwrite');
      const store = transaction.objectStore('models');
      await store.clear();
      console.log('[ModelCache] IndexedDB cache cleared');
    } catch (error) {
      console.warn('Failed to clear IndexedDB:', error);
    }
  }

  getCacheInfo() {
    return {
      memoryCacheSize: this.cache.size,
      cachedModels: Array.from(this.cache.keys()),
      loadingModels: Array.from(this.loading.keys())
    };
  }
}

export const modelCache = new ModelCache();
