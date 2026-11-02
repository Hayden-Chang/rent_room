import {validateCredits} from '../../apps/wechat/src/lib/property-credits.js';

// NativeStore supplies the compile-time gate. Release always passes false.
export function grantDevelopmentCredits(store, enabled) {
  if (!enabled) throw Error('开发点数仅限开发构建');
  const info = store.capacity();
  if (![info.limit + 10, info.spent + 10].every(Number.isSafeInteger)) throw Error('开发点数已达上限');
  store.change(state => {
    const credits = validateCredits(state.propertyCredits);
    const previous = credits.development || {granted: 0, spent: 0};
    credits.development = {granted: previous.granted + 10, spent: previous.spent};
    validateCredits(credits);
  }, true);
}
