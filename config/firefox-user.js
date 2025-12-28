// Firefox User Preferences
// Deployed by windows.rosematcha.com autoconfig
//
// This file is read on Firefox startup and applies these preferences.
// Changes made in about:config will persist until Firefox restarts.

// ============================================================================
// Privacy & Security
// ============================================================================

// Enhanced Tracking Protection - Strict mode
user_pref("browser.contentblocking.category", "strict");

// Disable Google Safe Browsing (sends URLs to Google)
user_pref("browser.safebrowsing.malware.enabled", false);
user_pref("browser.safebrowsing.phishing.enabled", false);

// Enable all tracking protection features
user_pref("privacy.trackingprotection.enabled", true);
user_pref("privacy.trackingprotection.socialtracking.enabled", true);
user_pref("privacy.trackingprotection.emailtracking.enabled", true);

// Fingerprinting protection
user_pref("privacy.fingerprintingProtection", true);

// Query string tracking parameter stripping
user_pref("privacy.query_stripping.enabled", true);
user_pref("privacy.query_stripping.enabled.pbmode", true);

// Bounce tracking protection
user_pref("privacy.bounceTrackingProtection.mode", 1);

// Stricter referrer policy for cross-site navigation
user_pref("network.http.referer.disallowCrossSiteRelaxingDefault.top_navigation", true);

// Strict annotation for tracking channels
user_pref("privacy.annotate_channels.strict_list.enabled", true);

// Container tabs
user_pref("privacy.userContext.enabled", true);
user_pref("privacy.userContext.ui.enabled", true);

// ============================================================================
// Disable AI/ML Features
// ============================================================================

user_pref("browser.ml.enable", false);
user_pref("browser.ml.chat.enabled", false);
user_pref("browser.ml.chat.menu", false);
user_pref("browser.ml.chat.sidebar", false);
user_pref("browser.ml.chat.shortcuts", false);
user_pref("browser.ml.chat.shortcuts.custom", false);
user_pref("browser.ml.checkForMemory", false);
user_pref("browser.ml.linkPreview.collapsed", true);

// ============================================================================
// New Tab & Homepage
// ============================================================================

// Blank new tab page
user_pref("browser.newtabpage.enabled", false);
user_pref("browser.startup.homepage", "chrome://browser/content/blanktab.html");

// Disable new tab page features
user_pref("browser.newtabpage.activity-stream.showSearch", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.newtabpage.activity-stream.feeds.topsites", false);

// Disable recommendations
user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons", false);
user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features", false);

// ============================================================================
// URL Bar & Search
// ============================================================================

// Disable search suggestions
user_pref("browser.urlbar.suggest.searches", false);
user_pref("browser.urlbar.suggest.topsites", false);
user_pref("browser.urlbar.suggest.engines", false);
user_pref("browser.urlbar.suggest.openpage", false);

// ============================================================================
// Network & Performance
// ============================================================================

// Disable DNS prefetching
user_pref("network.dns.disablePrefetch", true);

// Disable link prefetching
user_pref("network.prefetch-next", false);

// Disable speculative connections
user_pref("network.http.speculative-parallel-limit", 0);

// ============================================================================
// UI Preferences
// ============================================================================

// Vertical tabs (Firefox 138+)
user_pref("sidebar.verticalTabs", true);

// Hide bookmarks toolbar
user_pref("browser.toolbars.bookmarks.visibility", "never");

// New tabs open in foreground
user_pref("browser.tabs.loadInBackground", false);

// Don't check for default browser
user_pref("browser.shell.checkDefaultBrowser", false);

// ============================================================================
// Studies & Telemetry Opt-out
// ============================================================================

user_pref("app.shield.optoutstudies.enabled", false);

// ============================================================================
// Autofill
// ============================================================================

// Disable address and credit card autofill
user_pref("extensions.formautofill.addresses.enabled", false);
user_pref("extensions.formautofill.creditCards.enabled", false);

// ============================================================================
// Translation
// ============================================================================

// Auto-translate Japanese to English
user_pref("browser.translations.alwaysTranslateLanguages", "ja");
user_pref("browser.translations.mostRecentTargetLanguages", "en");
