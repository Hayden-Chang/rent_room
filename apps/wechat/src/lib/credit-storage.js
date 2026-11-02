import {validateCredits} from './property-credits.js';

// The sidecar is never exported with houses. A small write-ahead journal makes
// the state file's atomic rename the commit point for both creation and debit.
export function withCreditStorage(base) {
  if(!base.readCredits||!base.writeCredits)return base;
  const copy=value=>value==null?null:JSON.parse(JSON.stringify(value));
  let savedRaw, savedMarker;
  function commitMarker(raw) {
    if(raw!==savedRaw){const marker=raw?JSON.parse(raw)._creditsCommit:undefined;savedRaw=raw;savedMarker=marker;}
    return savedMarker;
  }
  function persist(state,options) {
    const text=JSON.stringify(state);
    base.write(text,options);
    savedRaw=text;savedMarker=state._creditsCommit;
  }
  function resolve(raw) {
    const text=base.readCredits();if(!text)return null;
    const ledger=JSON.parse(text);
    if(ledger.version!==1)throw Error('房源点数记录版本无效');
    if(ledger.committed!==null)validateCredits(ledger.committed);
    if(!ledger.pending)return ledger;
    const {id,after}=ledger.pending;validateCredits(after);
    if(typeof id!=='string'||!id)throw Error('房源点数保存记录无效');
    const committed=raw&&commitMarker(raw)===id?after:ledger.committed;
    const settled={version:1,committed};
    // A failed cleanup is safe: the next read resolves the same journal again.
    try{base.writeCredits(JSON.stringify(settled));}catch{}
    return settled;
  }
  return {...base,
    read(){
      const raw=base.read(),ledger=resolve(raw);
      if(!ledger?.committed)return raw;
      // Let the normal recovery path handle damaged house data while retaining
      // the independently committed consumption record.
      let state;try{state=raw?JSON.parse(raw):null;}catch{return raw;}
      if(!state)throw Error('房源记录缺失，请先恢复本机记录');
      state.propertyCredits=copy(ledger.committed);return JSON.stringify(state);
    },
    recoverCredits(){return copy(resolve(base.read())?.committed);},
    write(text,options){return writeState(JSON.parse(text),options);},
    writeState
  };
  function writeState(snapshot,options){
      const state={...snapshot},after=validateCredits(state.propertyCredits),raw=base.read(),old=resolve(raw);
      if(old?.committed&&JSON.stringify(old.committed)===JSON.stringify(after)){
        // If journal cleanup failed, ordinary edits must retain the disk commit
        // marker until settlement succeeds. The in-memory state may predate it.
        try{state._creditsCommit=commitMarker(raw);}catch{}
        persist(state,options);return;
      }
      let before=old?.committed??null;
      if(!old&&raw){try{before=JSON.parse(raw).propertyCredits??null;}catch{}}
      if(before)validateCredits(before);
      const id=Date.now().toString(36)+Math.random().toString(36).slice(2);
      base.writeCredits(JSON.stringify({version:1,committed:before,pending:{id,after}}));
      state._creditsCommit=id;
      try{persist(state,options);}
      catch(error){try{base.writeCredits(JSON.stringify({version:1,committed:before}));}catch{}throw error;}
      // The state rename already committed. Never report a failed creation just
      // because journal cleanup failed; restart can finish it using this token.
      try{base.writeCredits(JSON.stringify({version:1,committed:after}));}catch{}
  }
}
