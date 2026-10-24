// Replace this resource pack to change the character. Flow and copy use only
// semantic poses; unknown or unavailable poses always fall back to idle.
export const xiaodaSkin=Object.freeze({id:'house-v1',poses:{
  idle:'/assets/xiaoda/idle.png',greet:'/assets/xiaoda/greet.png',point:'/assets/xiaoda/point.png',pointDownRight:'/assets/xiaoda/point-down-right.png',
  think:'/assets/xiaoda/think.png',expect:'/assets/xiaoda/expect.png',success:'/assets/xiaoda/success.png',bye:'/assets/xiaoda/bye.png'
}});
export const poseSource=pose=>xiaodaSkin.poses[pose]||xiaodaSkin.poses.idle;
