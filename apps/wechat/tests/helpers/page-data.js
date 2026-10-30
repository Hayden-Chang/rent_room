// Match setData's synchronous data-path update and JSON value boundary.
export function applyPageData(data, patch) {
  for (const [path, value] of Object.entries(patch)) {
    if (value === undefined) continue;
    const keys = path.replace(/\[(\d+)\]/g, '.$1').split('.');
    let target = data;
    for (const key of keys.slice(0, -1)) target = target[key];
    target[keys.at(-1)] = JSON.parse(JSON.stringify(value));
  }
}
