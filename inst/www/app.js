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


// Drag and drop anywhere on the page (Steve, 2026-09-03: "dropping a file
// anywhere on the app should open the file. Same file types").
//
// HOW, AND WHY THIS WAY. A dropped file is handed to the SAME <input
// type="file"> the "Browse" button fills (Shiny's fileInput "upload"), and
// that control's own change event is fired. Shiny's file-input binding then
// uploads it exactly as a picked file, so every byte still travels the one
// upload path the server guards - the extension allowlist, the zip
// expansion, the header preflight and the parse subprocess - and nothing
// here reads, decodes or stores a file. This handler only forwards.
//
// The extension list below mirrors fileInput()'s `accept` in
// R/app_ui.R; a test pins the two lists equal. A file outside the list is
// not forwarded (the browser would let it through - `accept` only filters
// the picker's dialog), and its name goes to the server as `dropRejected`
// so the comments log can say what happened and what is accepted.
(function () {
  var ACCEPT = ['.csv', '.xls', '.xlsx', '.pdf', '.docx', '.xml',
                '.jpg', '.jpeg', '.png', '.tif', '.tiff', '.zip'];
  var depth = 0;   // dragenter/dragleave fire per element crossed; count them

  function carriesFiles(e) {
    var dt = e.originalEvent && e.originalEvent.dataTransfer;
    if (!dt || !dt.types) return false;
    return Array.prototype.indexOf.call(dt.types, 'Files') >= 0;
  }
  function extOf(name) {
    var i = name.lastIndexOf('.');
    return i >= 0 ? name.slice(i).toLowerCase() : '';
  }

  $(document).on('dragenter', function (e) {
    if (!carriesFiles(e)) return;
    e.preventDefault();
    depth += 1;
    $('body').addClass('ia-dropping');
  });
  $(document).on('dragover', function (e) {
    if (!carriesFiles(e)) return;
    e.preventDefault();                       // without this the browser opens the file itself
    e.originalEvent.dataTransfer.dropEffect = 'copy';
  });
  $(document).on('dragleave', function (e) {
    if (!carriesFiles(e)) return;
    depth = Math.max(0, depth - 1);
    if (depth === 0) $('body').removeClass('ia-dropping');
  });
  $(document).on('drop', function (e) {
    if (!carriesFiles(e)) return;
    e.preventDefault();
    depth = 0;
    $('body').removeClass('ia-dropping');

    var files = e.originalEvent.dataTransfer.files;
    var input = document.getElementById('upload');
    if (!input || !files || !files.length) return;

    var keep = new DataTransfer();
    var rejected = [];
    for (var i = 0; i < files.length; i++) {
      if (ACCEPT.indexOf(extOf(files[i].name)) >= 0) keep.items.add(files[i]);
      else rejected.push(files[i].name);
    }
    if (rejected.length && window.Shiny) {
      Shiny.setInputValue('dropRejected',
                          { names: rejected, nonce: Date.now() });
    }
    if (!keep.files.length) return;
    input.files = keep.files;
    input.dispatchEvent(new Event('change', { bubbles: true }));
  });
})();
