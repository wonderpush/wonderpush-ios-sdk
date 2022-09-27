(function() {
    var identifierCounter = 0;
    var generateIdentifier = function() {
        return ""+(+new Date())+":"+(identifierCounter++);
    };
    // Send clipPath messages
    var sendClipPathMessage = function() {
        var rect = document.body.getBoundingClientRect();
        webkit.messageHandlers.WonderPushPopupSDK.postMessage({
          clipPath: { rect: JSON.parse(JSON.stringify(rect)) }
        });
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
                    window.WonderPushPopupSDK.callIdToPromise[callId] = {resolve:res, reject:rej};
                });
                var post = function() {
                    var result = webkit.messageHandlers.WonderPushPopupSDK.postMessage(message);
                    if (result && result.catch) result.catch(function(error) {
                        window.WonderPushPopupSDK.reject(error, callId);
                    });
                };
                // delay dimiss
                if (prop === "dismiss") setTimeout(post, 10);
                else post();
                return promise;
            };
        }.bind(this);
        this.callIdToPromise = {};
        this.resolve =  function(result, callId) {
            var promise = window.WonderPushPopupSDK.callIdToPromise[callId];
            if (!promise || !promise.resolve) return;
            promise.resolve(result);
            delete window.WonderPushPopupSDK.callIdToPromise[callId];
        };
        this.reject = function(error, callId) {
            var promise = window.WonderPushPopupSDK.callIdToPromise[callId];
            if (!promise || !promise.reject) return;
            promise.reject(error);
            delete window.WonderPushPopupSDK.callIdToPromise[callId];
        };
    });

    // Executed when the window is loaded
    var onload = function() {
        // Register resize handler
        window.addEventListener('resize', sendClipPathMessage);
        sendClipPathMessage();

        // Register event listeners on data-wonderpush-* elements
        var keys = [ // Order matters: we try to dismiss last
          "wonderpushCallMethod",
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
              case "wonderpushCallMethod":
                fn = function () {
                  window.WonderPushPopupSDK.callMethod(val);
                };
                break;
              case "wonderpushAddTag":
                fn = function () {
                  window.WonderPushPopupSDK.addTag(val);
                };
                break;
              case "wonderpushButtonLabel":
                fn = function () {
                  window.WonderPushPopupSDK.trackClick(val);
                };
                break;
              case "wonderpushDismiss":
                fn = function () {
                  window.WonderPushPopupSDK.dismiss();
                };
                break;
              case "wonderpushOpenDeepLink":
                fn = function () {
                  window.WonderPushPopupSDK.openDeepLink(val);
                };
                break;
              case "wonderpushOpenExternalUrl":
                fn = function () {
                  window.WonderPushPopupSDK.openExternalUrl(val);
                };
                break;
              case "wonderpushRemoveAllTags":
                fn = function () {
                  window.WonderPushPopupSDK.removeAllTags();
                };
                break;
              case "wonderpushRemoveTag":
                fn = function () {
                  window.WonderPushPopupSDK.removeTag(val);
                };
                break;
              case "wonderpushSubscribeToNotifications":
                fn = function () {
                  window.WonderPushPopupSDK.subscribeToNotifications();
                };
                break;
              case "wonderpushTrackEvent":
                fn = function () {
                  window.WonderPushPopupSDK.trackEvent(val);
                };
                break;
              case "wonderpushTriggerLocationPrompt":
                fn = function () {
                  window.WonderPushPopupSDK.triggerLocationPrompt();
                };
                break;
              case "wonderpushUnsubscribeFromNotifications":
                fn = function () {
                  window.WonderPushPopupSDK.unsubscribeFromNotifications();
                };
                break;
              case "wonderpushOpenAppRating":
                fn = function () {
                  window.WonderPushPopupSDK.openAppRating();
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

