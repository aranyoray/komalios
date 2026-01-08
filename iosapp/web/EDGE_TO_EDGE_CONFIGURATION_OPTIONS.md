# Edge-to-Edge Configuration Options

## Current Setup

### Option 1: Keep Both (Recommended)
- `EdgeToEdge.enable()` - Window level edge-to-edge (Google Play Console requirement)
- `adjustMarginsForEdgeToEdge: 'auto'` - WebView level insets handling (Capacitor)

**Pros:**
- Satisfies Google Play Console recommendation
- Capacitor handles WebView insets automatically
- Works together at different levels

**Cons:**
- Might cause double-handling if not careful

### Option 2: Disable Capacitor's Auto-Handling
- `EdgeToEdge.enable()` - Window level edge-to-edge
- `adjustMarginsForEdgeToEdge: 'disable'` - Manual handling only
- Your CSS handles safe-area-inset-top

**Pros:**
- Full control over edge-to-edge behavior
- No potential conflicts

**Cons:**
- Need to ensure CSS safe-area-inset is working properly
- More manual configuration

## Recommendation

**Keep both** (`EdgeToEdge.enable()` + `adjustMarginsForEdgeToEdge: 'auto'`) because:
1. They work at different levels (window vs WebView)
2. Satisfies Google Play Console requirement
3. Capacitor handles WebView insets automatically
4. Your CSS already uses `env(safe-area-inset-top)` which works with both

If you see conflicts (double padding, extra spacing), then disable Capacitor's handling.

