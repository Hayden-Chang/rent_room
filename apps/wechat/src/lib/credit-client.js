import {uid,validateState} from './model.js';

export function validateCreditBalance(value) {
  if(!value||value.version!==1||typeof value.migrated!=='boolean'||value.migrated&&(!Number.isSafeInteger(value.remaining)||value.remaining<0))throw Error('房源点数暂时无法确认，请稍后重试');
  return {...value};
}

function files(fs,root) {
  const read=name=>{const path=root+'/'+name;try{fs.accessSync(path);}catch{return null;}return JSON.parse(fs.readFileSync(path,'utf8'));};
  const write=(name,value)=>{const path=root+'/'+name;fs.writeFileSync(path+'.pending',JSON.stringify(value),'utf8');fs.renameSync(path+'.pending',path);};
  return {read,write};
}

// Freeze the account's own occupancy before associating guest/imported records.
export function prepareCreditMigration(fs,root,account) {
  try{fs.mkdirSync(root,true);}catch{fs.accessSync(root);}
  const io=files(fs,root),saved=io.read('credit-migration-input.json');
  if(saved){if(saved.account!==account||!Number.isSafeInteger(saved.active)||saved.active<0)throw Error('原有房源点数记录无效，请保留本机数据');return saved.active;}
  const state=io.read('state.json'),active=state?validateState(state).houses.filter(h=>!h.archived).length:0;
  io.write('credit-migration-input.json',{account,active});return active;
}

export function createCreditClient({fs,root,billing,createLocal,ensureActive,migrationActive}) {
  const io=files(fs,root);let busy=null;
  const save=value=>io.write('credit-creation.json',value);
  function pending(){
    const value=io.read('credit-creation.json');if(!value)return null;
    if(!/^[A-Za-z0-9_-]{16,64}$/.test(value.requestId)||!/^h[a-z0-9]+$/.test(value.houseId)||typeof value.name!=='string'||value.saved!==undefined&&typeof value.saved!=='boolean')throw Error('新建记录读取失败，请保留本机数据');
    return value;
  }
  async function recover() {
    ensureActive();const value=pending();if(!value)return null;
    // Durable local state decides the outcome, never a timed-out HTTP response.
    const state=value.saved?null:io.read('state.json');
    const exists=value.saved||!!(state&&(validateState(state)._creditCreation===value.requestId||state.houses.some(h=>h.id===value.houseId)));
    const result=await billing.creditOperation(value.requestId,exists?'commit':'cancel');ensureActive();
    if(!['committed',...(exists?[]:['cancelled'])].includes(result.operation.state))throw Error('新建结果尚未确认，请重试');
    save(null);return exists?value:null;
  }
  async function initialize() {
    ensureActive();await billing.migrateCredits(migrationActive);ensureActive();// Settlement can wait while offline; existing local records remain usable.
    try{await recover();}catch{}
  }
  async function create(name) {
    if(busy)return busy;
    busy=(async()=>{
      ensureActive();const resumed=await recover();
      if(resumed?.name===name)return resumed.houseId;
      await billing.migrateCredits(migrationActive);ensureActive();
      const value={requestId:'create_'+uid()+uid(),houseId:uid(),name};
      save(value);
      try {
        const result=await billing.creditOperation(value.requestId,'reserve');ensureActive();
        if(result.operation.state!=='reserved')throw Error('新建请求已结束，请重试');
        createLocal(name,value.houseId,value.requestId);
        try{save({...value,saved:true});}catch{}
      } catch(error) {
        // If the request outcome is unknown, cancellation leaves a server-side
        // tombstone. A late reservation cannot charge this request afterward.
        try{await recover();}catch{}
        throw error;
      }
      // A saved house remains successful even when the commit ACK is delayed.
      // Its reservation already holds the point; startup/retry settles once.
      try{await recover();}catch{}
      return value.houseId;
    })().finally(()=>{busy=null;});return busy;
  }
  return {initialize,create,recover};
}
