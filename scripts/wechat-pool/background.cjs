// Injected before the vendor document-start script in pool copies only.
;(() => {
  if (typeof nw === 'undefined' || typeof process === 'undefined' ||
      process.env.WECHAT_POOL_UI_REVIEW === '1' ||
      process.env.WECHAT_POOL_BACKGROUND !== '1') return;
  const quiet = win => {
    if (!win || win.__poolQuiet) return win;
    Object.defineProperty(win, '__poolQuiet', {value: true});
    // Only initial non-activating creation may show automation windows.
    win.focus = () => {};
    win.requestAttention = () => {};
    win.show = () => {};
    // Project initialization restores its window even when focus is disabled.
    // On macOS that native restore also activates the application.
    win.restore = () => {};
    return win;
  };
  // Vendor modules use global.nw in the separate Node context. Patching only
  // the browser's nw object leaves those project-open calls unchanged.
  const apis = new Set([nw.Window]);
  if (typeof global !== 'undefined' && global.nw) apis.add(global.nw.Window);
  for (const api of apis) {
    if (api.__poolQuiet) continue;
    Object.defineProperty(api, '__poolQuiet', {value: true});
    const get = api.get.bind(api);
    api.get = (...args) => quiet(get(...args));
    // Enumeration returns fresh handles, including windows from other contexts.
    const getAll = api.getAll.bind(api);
    api.getAll = callback => getAll(windows => callback(windows.map(quiet)));
    const open = api.open.bind(api);
    api.open = (url, options, callback) => {
      if (typeof options === 'function') { callback = options; options = {}; }
      // A fully hidden project never finishes simulator initialization.
      return open(url, {...options, focus: false, show: true}, win => {
        quiet(win);
        if (callback) callback(win);
      });
    };
  }
  quiet(nw.Window.get());
})();
