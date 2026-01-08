//
//  ContentFilterPlugin.m
//  Komal - Capacitor Plugin Registration
//
//  Registers the plugin with Capacitor
//

#import <Foundation/Foundation.h>
#import <Capacitor/Capacitor.h>

CAP_PLUGIN(ContentFilterPlugin, "ContentFilter",
    CAP_PLUGIN_METHOD(initialize, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(showOnboarding, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(checkURL, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(checkURLBatch, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(showParentDashboard, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(openProtectedBrowser, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(getStats, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(getActivityLogs, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(getSettings, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(updateChildAge, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(setCustomRule, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(exportSettings, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(exportLogs, CAPPluginReturnPromise);
    CAP_PLUGIN_METHOD(clearCache, CAPPluginReturnPromise);
)
