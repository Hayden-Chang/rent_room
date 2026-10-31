// Device-local presentation state, independent of accounts and house backups.
const key='xunju.house-long-press-hint.dismissed';
export function houseLongPressHintDismissed(){
  try{return wx.getStorageSync(key)===true;}catch{return false;}
}
export function dismissHouseLongPressHint(){wx.setStorageSync(key,true);}
