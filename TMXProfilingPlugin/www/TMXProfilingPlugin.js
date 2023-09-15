 // Empty constructor
function TMXProfilingPlugin() {}

// The function that passes work along to native shells
// Message is a string, duration may be 'long' or 'short'
TMXProfilingPlugin.prototype.show = function(message, duration, successCallback, errorCallback) {
    var options = {};
    options.message = message;
    options.duration = duration;
    cordova.exec(successCallback, errorCallback, 'TMXProfilingPlugin', 'show', [options]);
}

TMXProfilingPlugin.prototype.profile = function(message, duration, successCallback, errorCallback) {
    var options = {};
    options.message = message;
    options.duration = duration;
    cordova.exec(successCallback, errorCallback, 'TMXProfilingPlugin', 'profile', [options]);
}

// Installation constructor that binds ToastyPlugin to window
TMXProfilingPlugin.install = function() {
    if (!window.plugins) {
        window.plugins = {};
    }
    window.plugins.TMXProfilingPlugin = new TMXProfilingPlugin();
    return window.plugins.TMXProfilingPlugin;
};
cordova.addConstructor(TMXProfilingPlugin.install);
