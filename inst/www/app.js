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
  // The one forwarding step, shared by drop and paste: filter by the
  // picker's list, name what was refused, hand the rest to the input.
  function forward(files) {
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
  }

  $(document).on('drop', function (e) {
    if (!carriesFiles(e)) return;
    e.preventDefault();
    depth = 0;
    $('body').removeClass('ia-dropping');
    forward(e.originalEvent.dataTransfer.files);
  });

  // Paste a picture (Steve, 2026-09-03: a screenshot of a table lands in
  // the clipboard as a PNG on every desktop and mobile OS). The clipboard's
  // image items become files named for the moment they were pasted and
  // take the same road as a drop - the OS wrote a real PNG or JPEG, and
  // the header preflight on the server judges it like any other. Two
  // pastes are deliberately left alone: one that carries TEXT (cells being
  // pasted into the grid, a key into the key field) and one aimed at a
  // text field or the grid itself, whatever it carries. Only an image-only
  // paste on the page at large is taken. On iOS and Android a page-level
  // paste of an image reaches the browser in some browsers and not others;
  // the drop and the picker are the sure routes there.
  $(document).on('paste', function (e) {
    var cd = e.originalEvent && e.originalEvent.clipboardData;
    if (!cd || !cd.items) return;
    var t = e.target;
    var tag = t && t.tagName ? t.tagName.toLowerCase() : '';
    if (tag === 'input' || tag === 'textarea' || (t && t.isContentEditable)) return;
    if ($(t).closest('.handsontable').length) return;
    var hasText = false, images = [];
    for (var i = 0; i < cd.items.length; i++) {
      var it = cd.items[i];
      if (it.kind === 'string' && (it.type === 'text/plain' || it.type === 'text/html')) hasText = true;
      if (it.kind === 'file' && (it.type === 'image/png' || it.type === 'image/jpeg')) images.push(it);
    }
    if (hasText || !images.length) return;
    e.preventDefault();
    var stamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
    var files = [];
    for (var j = 0; j < images.length; j++) {
      var blob = images[j].getAsFile();
      if (!blob) continue;
      var ext = images[j].type === 'image/png' ? '.png' : '.jpg';
      var name = 'pasted-' + stamp + (images.length > 1 ? '-' + (j + 1) : '') + ext;
      files.push(new File([blob], name, { type: images[j].type }));
    }
    forward(files);
  });
})();
