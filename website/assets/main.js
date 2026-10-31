/*
  AVD Studio website: two small progressive enhancements.
  1. The download button asks the GitHub API for the latest release.
  2. The copy buttons in the install section.
  The page works without this file. No dependencies, no analytics, no cookies.
*/
(function () {
  'use strict';

  var REPO = 'https://github.com/mrcsxsiq/avd-studio';
  var API = 'https://api.github.com/repos/mrcsxsiq/avd-studio/releases/latest';
  var CACHE_KEY = 'avdstudio:latest-release';
  var CACHE_MS = 10 * 60 * 1000; // stay well inside GitHub's unauthenticated rate limit
  var TIMEOUT_MS = 6000;

  // ---------- Latest release ----------

  function cacheRead() {
    try {
      var entry = JSON.parse(sessionStorage.getItem(CACHE_KEY) || 'null');
      if (entry && entry.result && Date.now() - entry.at < CACHE_MS) return entry.result;
    } catch (e) {
      /* storage can be blocked; carry on without it */
    }
    return null;
  }

  function cacheWrite(result) {
    try {
      sessionStorage.setItem(CACHE_KEY, JSON.stringify({ at: Date.now(), result: result }));
    } catch (e) {
      /* ignore */
    }
  }

  // Resolves to { state: 'release', tag, page, dmg } | { state: 'soon' } | { state: 'unknown' }. Never rejects.
  function fetchLatest() {
    var cached = cacheRead();
    if (cached) return Promise.resolve(cached);
    if (typeof fetch !== 'function') return Promise.resolve({ state: 'unknown' });

    var controller = typeof AbortController === 'function' ? new AbortController() : null;
    var timer = controller ? setTimeout(function () { controller.abort(); }, TIMEOUT_MS) : null;
    var soon = { state: 'soon' };

    return fetch(API, controller ? { signal: controller.signal } : undefined)
      .then(function (response) {
        // 403 and 429 mean GitHub is rate-limiting this visitor. We know nothing, so say nothing.
        if (response.status === 403 || response.status === 429) return { state: 'unknown' };
        // 404 is what GitHub answers while a repository has no published release.
        if (response.status === 404) { cacheWrite(soon); return soon; }
        if (!response.ok) return soon;
        return response.json().then(function (data) {
          if (!data || typeof data.tag_name !== 'string' || !data.tag_name) return soon;
          var assets = Array.isArray(data.assets) ? data.assets : [];
          var dmg = null;
          for (var i = 0; i < assets.length; i++) {
            var asset = assets[i];
            if (
              asset && typeof asset.name === 'string' && /\.dmg$/i.test(asset.name) &&
              typeof asset.browser_download_url === 'string' &&
              asset.browser_download_url.indexOf(REPO + '/releases/download/') === 0
            ) { dmg = asset.browser_download_url; break; }
          }
          var page = typeof data.html_url === 'string' && data.html_url.indexOf(REPO + '/releases/') === 0
            ? data.html_url
            : REPO + '/releases';
          var result = { state: 'release', tag: data.tag_name.slice(0, 40), page: page, dmg: dmg };
          cacheWrite(result);
          return result;
        });
      })
      .catch(function () { return soon; }) // offline, blocked, timed out or malformed JSON
      .then(function (result) {
        if (timer) clearTimeout(timer);
        return result;
      });
  }

  function setLabel(link, label) {
    var span = link.querySelector('[data-label]');
    (span || link).textContent = label;
  }

  function applyRelease(result) {
    var blocks = document.querySelectorAll('[data-release]');
    var downloads = document.querySelectorAll('[data-download]');
    var repoLinks = document.querySelectorAll('[data-repo-link]');
    var notes = document.querySelectorAll('[data-note]');
    var pills = document.querySelectorAll('[data-dmg-pill]');
    var i;

    if (result.state === 'release') {
      for (i = 0; i < downloads.length; i++) {
        downloads[i].href = result.dmg || result.page;
        setLabel(downloads[i], result.dmg ? 'Download AVD Studio ' + result.tag : 'See AVD Studio ' + result.tag + ' on GitHub');
      }
      for (i = 0; i < notes.length; i++) {
        notes[i].textContent = result.dmg
          ? 'Version ' + result.tag + ' for Apple Silicon Macs on macOS 14 or newer. Free and open source.'
          : 'Version ' + result.tag + ' is on GitHub Releases.';
      }
      if (result.dmg) {
        for (i = 0; i < pills.length; i++) {
          pills[i].textContent = 'Available now';
          pills[i].classList.add('pill-now');
        }
      }
      for (i = 0; i < blocks.length; i++) blocks[i].setAttribute('data-state', 'release');
    } else if (result.state === 'soon') {
      for (i = 0; i < downloads.length; i++) setLabel(downloads[i], 'First release coming soon');
      for (i = 0; i < repoLinks.length; i++) setLabel(repoLinks[i], 'Star / watch on GitHub');
      for (i = 0; i < notes.length; i++) {
        notes[i].textContent = 'No release has been published yet. Star or watch the repository on GitHub to hear about the first one.';
      }
      for (i = 0; i < blocks.length; i++) blocks[i].setAttribute('data-state', 'soon');
    }
    // 'unknown' keeps the neutral markup that shipped in the HTML.
  }

  // ---------- Copy buttons ----------

  var liveRegion = null;

  function announce(message) {
    if (!liveRegion) {
      liveRegion = document.createElement('div');
      liveRegion.className = 'visually-hidden';
      liveRegion.setAttribute('role', 'status');
      document.body.appendChild(liveRegion);
    }
    liveRegion.textContent = '';
    setTimeout(function () { liveRegion.textContent = message; }, 30);
  }

  function selectContents(node) {
    var selection = window.getSelection && window.getSelection();
    if (!selection) return false;
    var range = document.createRange();
    range.selectNodeContents(node);
    selection.removeAllRanges();
    selection.addRange(range);
    return true;
  }

  function copyText(source) {
    var value = source.textContent.trim();
    if (navigator.clipboard && window.isSecureContext) {
      return navigator.clipboard.writeText(value).then(function () { return true; }, function () { return legacyCopy(source); });
    }
    return Promise.resolve(legacyCopy(source));
  }

  function legacyCopy(source) {
    try {
      if (!selectContents(source)) return false;
      var ok = document.execCommand('copy');
      if (ok) window.getSelection().removeAllRanges();
      return ok;
    } catch (e) {
      return false;
    }
  }

  function setupCopyButtons() {
    var buttons = document.querySelectorAll('button[data-copy]');
    Array.prototype.forEach.call(buttons, function (button) {
      var source = document.getElementById(button.getAttribute('data-copy'));
      if (!source) return;
      var idle = button.textContent;
      var reset = null;
      button.hidden = false;
      button.addEventListener('click', function () {
        copyText(source).then(function (ok) {
          if (!ok) selectContents(source); // leave the text selected so Cmd+C works
          button.textContent = ok ? 'Copied' : 'Press ⌘C';
          if (ok) button.setAttribute('data-copied', 'true');
          announce(ok ? 'Command copied to the clipboard.' : 'Copying failed. The command is selected; press Command C.');
          clearTimeout(reset);
          reset = setTimeout(function () {
            button.textContent = idle;
            button.removeAttribute('data-copied');
          }, 2200);
        });
      });
    });
  }

  // ---------- Start ----------

  function init() {
    try { setupCopyButtons(); } catch (e) { /* the commands stay selectable */ }
    try {
      fetchLatest().then(function (result) {
        try { applyRelease(result); } catch (e) { /* keep the neutral markup */ }
      });
    } catch (e) {
      /* keep the neutral markup */
    }
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
