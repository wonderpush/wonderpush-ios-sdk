window.WonderPushInAppSDK = new function() {
this.sendToNative = function(method, args) {
    webkit.messageHandlers.WonderPushInAppSDK.postMessage({ method : method, args: args || [] });
}.bind(this);
this.openTargetUrl = function() {
 return this.sendToNative('openTargetUrl');
}.bind(this);
}();
