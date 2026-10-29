// Only iOS opts into this state. Historical deleted/imported records cannot
// reliably establish a creation count, so counting starts with this version.
export function reviewProgress(state) {
  const value = state.iosReview || {};
  return {created: Number.isSafeInteger(value.created) && value.created > 0 ? value.created : 0,
    purchased: value.purchased === true, requested: value.requested === true};
}
export function recordHouseCreated(state) {
  const progress = reviewProgress(state);
  state.iosReview = {...progress, created: Math.min(3, progress.created + 1)};
}
export function mergeReviewProgress(state, incoming) {
  const a = reviewProgress(state), b = reviewProgress(incoming);
  state.iosReview = {created: Math.min(3, a.created + b.created),
    purchased: a.purchased || b.purchased, requested: a.requested || b.requested};
}
export const reviewActions = {
  reviewPurchaseConfirmed(store) {
    if (reviewProgress(store.get()).purchased) return;
    store.change(state => { state.iosReview = {...reviewProgress(state), purchased: true}; }, true);
  },
  reviewRequest(store) {
    const progress = reviewProgress(store.get());
    if (progress.requested || progress.created < 3 && !progress.purchased) return false;
    store.change(state => { state.iosReview = {...progress, requested: true}; }, true);
    return true;
  }
};
