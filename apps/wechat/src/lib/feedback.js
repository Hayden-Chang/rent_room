export function createFeedback(api,url='') {
 return {async submit(body){
  if(!url)throw Error('反馈暂时无法提交，请稍后重试。');
  const response=await api('request',{url:url+'/feedback',method:'POST',data:body,timeout:12000,header:{'content-type':'application/json'}});
  if(response.statusCode<200||response.statusCode>=300||response.data?.receipt!==body.requestId)throw Error(response.data?.detail?.message||'反馈未提交成功，内容已保留，请重试。');
  return response.data;
 }};
}
