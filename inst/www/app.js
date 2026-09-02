$(document).on('shiny:connected', function(event) {
  var timeNow = new Date().toLocaleTimeString();
  Shiny.setInputValue("client_time", timeNow);
});


$(document).on('shiny:value', function(event) {
  if (event.target.id === 'logContent') {
    setTimeout(function() {
      // #logSection is not always in the DOM when logContent updates, and
      // $logger[0] is then undefined - reading .scrollHeight off it threw
      // "Cannot read properties of undefined" on every log write. Harmless
      // in itself (it runs in its own task, so it broke nothing else), but
      // it filled the console and buried real errors. Guard the lookup.
      var $logger = $('#logSection');
      if ($logger.length) $logger.scrollTop($logger[0].scrollHeight);
    }, 0);
  }
});
