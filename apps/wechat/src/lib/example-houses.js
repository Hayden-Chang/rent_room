import {freshHouse,updateAnswer} from './model.js';

export function exampleHouses() {
  const choices=[
    {id:'example-metro-v1',name:'示例·地铁一居',address:'示例地址·地铁站旁',layout:'一室一厅',rent:'2800',area:'38',commute:'是',light:'否',noise:'否',
      summary:'通勤约 20 分钟，租金较低；采光偏弱，临街噪音需要再确认。'},
    {id:'example-sunny-v1',name:'示例·阳光两居',address:'示例地址·花园小区',layout:'两室一厅',rent:'3600',area:'58',commute:'否',light:'是',noise:'是',
      summary:'通勤约 45 分钟，租金较高；空间更大，采光和安静程度更好。'}
  ];
  return choices.map(item=>{
    const house=freshHouse(item.name,{selectedTemplate:'simple'});
    Object.assign(house,{id:item.id,example:true,currencyCode:'CNY',summary:item.summary,decision:'继续比较'});
    house.xiaoda={...house.xiaoda,intro:'done',disabled:true};
    for(const [field,value] of Object.entries({f1_1:item.address,f1_2:item.layout,f1_6:item.rent,f1_3:item.area,simple_01:item.commute,simple_02:'是',simple_04:'是',simple_05:'是',simple_11:item.light,simple_13:item.noise,simple_15:'是',simple_42:'是',simple_43:'是',simple_44:'是',simple_45:'是'}))updateAnswer(house,field,'value',value);
    updateAnswer(house,'simple_01','note',item.commute==='是'?'示例：步行到地铁站约 5 分钟，全程约 20 分钟。':'示例：公交换乘地铁，全程约 45 分钟。');
    if(item.noise==='否')updateAnswer(house,'simple_13','note','示例：关窗后仍能听到车流声，建议晚高峰再看一次。');
    return house;
  });
}
