(function() {
    var identifierCounter = 0;
    var generateIdentifier = function() {
        return ""+(+new Date())+":"+(identifierCounter++);
    };
    window.WonderPushInAppSDK = new Proxy({}, new function() {
        this.get = function(target, prop, receiver) {
            if (this.hasOwnProperty(prop)) return this[prop];
            return function() {
                var callId = generateIdentifier();
                webkit.messageHandlers.WonderPushInAppSDK.postMessage({
                    method : prop,
                    args: Array.from(arguments),
                    callId: callId,
                });
                return new Promise(function(res, rej) {
                    window.WonderPushInAppSDK.callIdToPromise[callId] = {resolve:res, reject:rej};
                });
            };
        }.bind(this);
        this.callIdToPromise = {};
        this.resolve =  function(result, callId) {
            var promise = window.WonderPushInAppSDK.callIdToPromise[callId];
            if (!promise || !promise.resolve) return;
            promise.resolve(result);
            delete window.WonderPushInAppSDK.callIdToPromise[callId];
        };
        this.reject = function(error, callId) {
            var promise = window.WonderPushInAppSDK.callIdToPromise[callId];
            if (!promise || !promise.reject) return;
            promise.reject(error);
            delete window.WonderPushInAppSDK.callIdToPromise[callId];
        };
    });
    
    // Executed when the window is loaded
    var onload = function() {
        // Register event listeners on data-wonderpush-button-label elements
        document.querySelectorAll('*[data-wonderpush-button-label]').forEach(function(elt) {
            var buttonLabel = elt.dataset.wonderpushButtonLabel;
            elt.addEventListener('click', function() {
                window.WonderPushInAppSDK.trackClick(buttonLabel);
            });
        });
        // Register event listeners on data-wonderpush-dismiss elements
        document.querySelectorAll('*[data-wonderpush-dismiss]').forEach(function(elt) {
            elt.addEventListener('click', function() {
                window.WonderPushInAppSDK.dismiss();
            });
        });
    }
    if (document.readyState === "complete") {
        onload();
    } else {
        window.addEventListener("load", onload);
    }
})();

