/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_SUPABASE_URL: string;
  readonly VITE_SUPABASE_ANON_KEY: string;
  // Add other env variables as needed
  readonly VITE_ADMOB_APP_ID: string;
  readonly VITE_ADMOB_BANNER_ID: string;
  readonly VITE_ADMOB_INTERSTITIAL_ID: string;
  readonly VITE_ADMOB_REWARDED_ID: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}

