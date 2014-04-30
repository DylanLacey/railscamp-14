define(["utils/dom", "pinjs", "domReady"], function(utils, pinjs, domReady) {

  var $ = utils.$,
      $$ = utils.$$;

  function init() {
    pinjs(function(Pin) {
      var callback = function(response) {
        console.log(response);
        appendCardToken(form, response);
        form.submit();
      };

      var errback = function(response) {
        showBusyIndicator(form);
        showPinError(form, response.error_description, response.messages);
      };

      var form = $('form');
      form.addEventListener('submit', function(e) {
        e.preventDefault();

        clearErrors();

        var card = pinCardAttributes(form);

        console.log("Creating Card Token");
        Pin.createCardToken(card).then(callback, errback).done();

      }, false);
    });
  }

  function clearErrors(form) {
    var errors = $(".errors", form);
    if (errors) {
      errors.parentNode.removeChild(errors);
      errors = undefined;
    }
  }

  // Show a busy indicator
  //
  // Returns a function that cancels the busy indicator
  function showBusyIndicator(form) {
    var submitButton = $("button", form),
        originalSubmitText = submitButton.textContent;
    submitButton.textContent = submitButton.dataset.busyText;
    return function() {
      submitButton.textContent = originalSubmitText;
    };
  }

  function pinCardAttributes(form) {
    var card = {};

    // Extract all the Pin card details
    $$("[data-pin]", form).forEach(function(input) {

      // Expiry text field needs munging
      if (input.dataset.pin == 'expiry') {
        var expiry = input.value.split("/");
        card.expiry_month = expiry[0];
        card.expiry_year = expiry[1];
        if (card.expiry_year.length == 2)
          card.expiry_year = "20" + card.expiry_year;
      }

      // Everything else passes through directly
      else {
        card[input.dataset.pin] = input.value;
      }

    });

    return card;
  }

  function appendCardToken(form, response) {
    function appendHiddenInput(name, value) {
      var input = document.createElement('input');
      input.type = 'hidden'; input.name = name; input.value = value;
      form.appendChild(input);
    }
    $("[data-pin-card-token]", form).value = response.token;
    $("[data-pin-ip-address]", form).value = response.ip_address;
  }

  function showPinError(form, description, messages) {
    if (window.console && console.log)
      console.log(description, messages);

    var errors = document.createElement('div');
    errors.className = "errors";
    errors.innerHTML = "<p>There were problems processing your credit card details. Please fix them and try again.</p>"+
                       "<ol></ol>";

    var errorList = $("ol", errors);
    messages.forEach(function(message) {
      var error = document.createElement('li');
      error.textContent = message.message;
      errorList.appendChild(error);
    });

    var submitFieldset = $("button", form).parentNode;
    submitFieldset.parentNode.insertBefore(errors, submitFieldset);
  }

  return function() {
    domReady(init);
  };

});
