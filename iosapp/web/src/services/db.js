/**
 * IndexedDB Service for Komal
 * Offline-first local storage for user data, sessions, and analytics
 */

const DB_NAME = 'komal-db';
const DB_VERSION = 2; // Updated to add subdomainHistory store

class KomalDB {
  constructor() {
    this.db = null;
  }

  async init() {
    if (this.db) return this.db;

    return new Promise((resolve, reject) => {
      const request = indexedDB.open(DB_NAME, DB_VERSION);

      request.onerror = () => reject(request.error);
      request.onsuccess = () => {
        this.db = request.result;
        console.log('[KomalDB] Database initialized');
        resolve(this.db);
      };

      request.onupgradeneeded = (event) => {
        const db = event.target.result;

        // Users store
        if (!db.objectStoreNames.contains('users')) {
          const userStore = db.createObjectStore('users', { keyPath: 'id' });
          userStore.createIndex('phoneNumber', 'phoneNumber', { unique: true });
          userStore.createIndex('email', 'email', { unique: false });
        }

        // Learners store
        if (!db.objectStoreNames.contains('learners')) {
          const learnerStore = db.createObjectStore('learners', { keyPath: 'id' });
          learnerStore.createIndex('userId', 'userId', { unique: false });
          learnerStore.createIndex('isActive', 'isActive', { unique: false });
        }

        // Sessions store
        if (!db.objectStoreNames.contains('sessions')) {
          const sessionStore = db.createObjectStore('sessions', { keyPath: 'id' });
          sessionStore.createIndex('learnerId', 'learnerId', { unique: false });
          sessionStore.createIndex('startTime', 'startTime', { unique: false });
          sessionStore.createIndex('focusArea', 'focusArea', { unique: false });
          sessionStore.createIndex('syncedToCloud', 'syncedToCloud', { unique: false });
        }

        // Analytics store
        if (!db.objectStoreNames.contains('analytics')) {
          const analyticsStore = db.createObjectStore('analytics', { keyPath: 'id' });
          analyticsStore.createIndex('learnerId', 'learnerId', { unique: false });
          analyticsStore.createIndex('startDate', 'startDate', { unique: false });
        }

        // ML Models cache
        if (!db.objectStoreNames.contains('mlModels')) {
          db.createObjectStore('mlModels', { keyPath: 'name' });
        }

        // Subdomain History store (for trend analysis)
        if (!db.objectStoreNames.contains('subdomainHistory')) {
          const historyStore = db.createObjectStore('subdomainHistory', { keyPath: 'id' });
          historyStore.createIndex('learnerId', 'learnerId', { unique: false });
          historyStore.createIndex('subdomainId', 'subdomainId', { unique: false });
          historyStore.createIndex('timestamp', 'timestamp', { unique: false });
        }

        console.log('[KomalDB] Database upgraded to version', DB_VERSION);
      };
    });
  }

  // Generic CRUD operations
  async add(storeName, data) {
    const db = await this.init();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction([storeName], 'readwrite');
      const store = transaction.objectStore(storeName);
      const request = store.add(data);

      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  }

  async get(storeName, key) {
    const db = await this.init();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction([storeName], 'readonly');
      const store = transaction.objectStore(storeName);
      const request = store.get(key);

      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  }

  async getAll(storeName) {
    const db = await this.init();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction([storeName], 'readonly');
      const store = transaction.objectStore(storeName);
      const request = store.getAll();

      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  }

  async getAllByIndex(storeName, indexName, value) {
    const db = await this.init();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction([storeName], 'readonly');
      const store = transaction.objectStore(storeName);
      const index = store.index(indexName);
      const request = index.getAll(value);

      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  }

  async update(storeName, data) {
    const db = await this.init();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction([storeName], 'readwrite');
      const store = transaction.objectStore(storeName);
      const request = store.put(data);

      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  }

  async delete(storeName, key) {
    const db = await this.init();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction([storeName], 'readwrite');
      const store = transaction.objectStore(storeName);
      const request = store.delete(key);

      request.onsuccess = () => resolve();
      request.onerror = () => reject(request.error);
    });
  }

  async clear(storeName) {
    const db = await this.init();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction([storeName], 'readwrite');
      const store = transaction.objectStore(storeName);
      const request = store.clear();

      request.onsuccess = () => resolve();
      request.onerror = () => reject(request.error);
    });
  }

  // Specific helper methods
  async getUserByPhone(phoneNumber) {
    const db = await this.init();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction(['users'], 'readonly');
      const store = transaction.objectStore('users');
      const index = store.index('phoneNumber');
      const request = index.get(phoneNumber);

      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  }

  async getLearnersByUserId(userId) {
    return this.getAllByIndex('learners', 'userId', userId);
  }

  async getSessionsByLearnerId(learnerId, limit = 100) {
    const db = await this.init();
    return new Promise((resolve, reject) => {
      const transaction = db.transaction(['sessions'], 'readonly');
      const store = transaction.objectStore(storeName);
      const index = store.index('learnerId');
      const request = index.getAll(learnerId, limit);

      request.onsuccess = () => {
        const sessions = request.result.sort((a, b) => b.startTime - a.startTime);
        resolve(sessions);
      };
      request.onerror = () => reject(request.error);
    });
  }

  async getUnsyncedSessions() {
    return this.getAllByIndex('sessions', 'syncedToCloud', false);
  }
}

export const db = new KomalDB();
