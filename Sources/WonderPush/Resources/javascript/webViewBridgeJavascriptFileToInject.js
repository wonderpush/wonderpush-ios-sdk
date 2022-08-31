(function() {
    var identifierCounter = 0;
    var generateIdentifier = function() {
        return ""+(+new Date())+":"+(identifierCounter++);
    };
    window.WonderPushInAppSDK = window.WonderPushPopupSDK = new Proxy({}, new function() {
        this.get = function(target, prop, receiver) {
            if (this.hasOwnProperty(prop)) return this[prop];
            return function() {
                var callId = generateIdentifier();
                var message = {
                    method : prop,
                    args: Array.from(arguments),
                    callId: callId,
                };
                var promise = new Promise(function(res, rej) {
                    window.WonderPushInAppSDK.callIdToPromise[callId] = {resolve:res, reject:rej};
                });
                var post = function() {
                    webkit.messageHandlers.WonderPushInAppSDK.postMessage(message);
                };
                // delay dimiss
                if (prop === "dismiss") setTimeout(post, 10);
                else post();
                return promise;
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
        // Register event listeners on data-wonderpush-* elements
        var keys = [ // Order matters: we try to dismiss last
          "wonderpushButtonLabel",
          "wonderpushRemoveAllTags", // remove tags before adding them
          "wonderpushRemoveTag",
          "wonderpushAddTag",
          "wonderpushUnsubscribeFromNotifications", // unsubscribe before subscribe
          "wonderpushSubscribeToNotifications",
          "wonderpushTrackEvent",
          "wonderpushTriggerLocationPrompt",
          "wonderpushOpenAppRating",
          "wonderpushOpenDeepLink", // move somewhere else last
          "wonderpushOpenExternalUrl",
          "wonderpushDismiss",
        ];
        document.querySelectorAll('*').forEach(function(elt) {
          if (!elt.dataset) return;
          keys.forEach(function (key) {
            if (!(key in elt.dataset)) return;
            var val = elt.dataset[key];
            var fn;
            switch (key) {
              case "wonderpushAddTag":
                fn = function () {
                  window.WonderPushInAppSDK.addTag(val);
                };
                break;
              case "wonderpushButtonLabel":
                fn = function () {
                  window.WonderPushInAppSDK.trackClick(val);
                };
                break;
              case "wonderpushDismiss":
                fn = function () {
                  window.WonderPushInAppSDK.dismiss();
                };
                break;
              case "wonderpushOpenDeepLink":
                fn = function () {
                  window.WonderPushInAppSDK.openDeepLink(val);
                };
                break;
              case "wonderpushOpenExternalUrl":
                fn = function () {
                  window.WonderPushInAppSDK.openExternalUrl(val);
                };
                break;
              case "wonderpushRemoveAllTags":
                fn = function () {
                  window.WonderPushInAppSDK.removeAllTags();
                };
                break;
              case "wonderpushRemoveTag":
                fn = function () {
                  window.WonderPushInAppSDK.removeTag(val);
                };
                break;
              case "wonderpushSubscribeToNotifications":
                fn = function () {
                  window.WonderPushInAppSDK.subscribeToNotifications();
                };
                break;
              case "wonderpushTrackEvent":
                fn = function () {
                  window.WonderPushInAppSDK.trackEvent(val);
                };
                break;
              case "wonderpushTriggerLocationPrompt":
                fn = function () {
                  window.WonderPushInAppSDK.triggerLocationPrompt();
                };
                break;
              case "wonderpushUnsubscribeFromNotifications":
                fn = function () {
                  window.WonderPushInAppSDK.unsubscribeFromNotifications();
                };
                break;
              case "wonderpushOpenAppRating":
                fn = function () {
                  window.WonderPushInAppSDK.openAppRating();
                };
                break;
            }
            if (fn) {
              elt.addEventListener('click', fn);
            }
          });
        });
    }
    if (document.readyState === "complete") {
        onload();
    } else {
        window.addEventListener("load", onload);
    }
})();

