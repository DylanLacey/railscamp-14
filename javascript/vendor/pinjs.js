define(function() {

  /*
    Require.js loader plugin for the Pin Payments Javascript API

    Firstly, ensure that your <html> element has the following attributes set:

      data-pin-api             - either "test" or "live"
      data-pin-publishable-key - your Pin publishable API key

    If Pin.js is loaded successfully, callback will be called. Else, errback
    will be called with the require.js error object.

    Example:

      define(["domReady!", "pinjs", "jquery"], function(doc, pinjs, $) {
        pinjs(function(Pin) {
          $("form").submit(function() {
            // ...
          });
        }, function(err) {
          // Pin.js failed to load
        });
      });

      // Or using the loader plugin syntax
      define(["domReady!", "pinjs!", "jquery"], function(doc, Pin, $) {
        $("form").submit(function() {
          // ...
        });
      });

  */
  function pinjs(callback, errback) {
    var apiAttr = 'data-pin-api',
        api = document.documentElement.getAttribute(apiAttr),
        host = 'cdn.pin.net.au',
        url = "https://" + host + "/pin.v2.js";

    var keyAttr = 'data-pin-publishable-key',
        key = document.documentElement.getAttribute(keyAttr);

    require([url],
      function(Pin) {
        console.log("Loaded PIN");
        var pin = new Pin.Api(key, api);
        console.log("Created new API");
        callback(pin);
      },
      errback
    );
  }

  // Loader Plugin API hook
  pinjs.load = function (name, req, onLoad, config) {
    if (config.isBuild) {
      onLoad(null);
    } else {
      pinjs(onLoad);
    }
  };

  return pinjs;
});
