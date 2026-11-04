import {stats} from '../../apps/wechat/src/lib/model.js';

// Only iOS opts into this state. Historical deleted/imported records cannot
// reliably establish a creation count, so counting starts with this version.
export function reviewProgress(state) {
  const value = state.iosReview || {};
  return {created: Number.isSafeInteger(value.created) && value.created > 0 ? value.created : 0,
    purchased: value.purchased === true, requested: value.requested === true,
    pendingPurchase: typeof value.pendingPurchase === 'string' ? value.pendingPurchase : ''};
}
export function recordHouseCreated(state) {
  const progress = reviewProgress(state);
  state.iosReview = {...progress, created: Math.min(3, progress.created + 1)};
}
export function mergeReviewProgress(state, incoming) {
  const a = reviewProgress(state), b = reviewProgress(incoming);
  state.iosReview = {created: Math.min(3, a.created + b.created),
    purchased: a.purchased || b.purchased, requested: a.requested || b.requested,
    pendingPurchase: a.pendingPurchase || b.pendingPurchase};
}
export const reviewActions = {
  reviewPurchasePending(store, {value}) {
    const progress = reviewProgress(store.get());
    if (progress.purchased || progress.requested) return;
    if (typeof value !== 'string' || !value) throw Error('购买记录编号无效');
    store.change(state => { state.iosReview = {...progress, pendingPurchase: value}; }, true);
  },
  reviewPurchaseConfirmed(store) {
    if (reviewProgress(store.get()).purchased) return;
    store.change(state => { state.iosReview = {...reviewProgress(state), purchased: true, pendingPurchase: ''}; }, true);
  },
  reviewRequest(store, {value: includeFilledItems} = {}) {
    const progress = reviewProgress(store.get());
    if (progress.requested) return false;
    const filledEnough = includeFilledItems === true
      && store.get().houses.filter(h => !h.example).reduce((count, h) => count + stats(h).done, 0) > 50;
    if (progress.created < 3 && !progress.purchased && !filledEnough) return false;
    store.change(state => { state.iosReview = {...progress, requested: true}; }, true);
    return true;
  }
};
