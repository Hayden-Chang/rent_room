export function createTypewriter({write,done=()=>{},schedule=setTimeout,cancel=clearTimeout,delay=45}) {
  let timer=null,letters=[],index=0,paused=false,generation=0;
  function stop(){generation++;cancel(timer);timer=null;}
  function tick(run){if(run!==generation||paused)return;write(letters.slice(0,++index).join(''));if(index<letters.length)timer=schedule(()=>tick(run),delay);else{timer=null;done();}}
  return {
    start(text){stop();paused=false;letters=Array.from(text||'');index=0;write('');if(letters.length)timer=schedule(()=>tick(generation),delay);else done();},
    pause(){paused=true;stop();},
    resume(){if(!paused)return;paused=false;if(index<letters.length)timer=schedule(()=>tick(generation),delay);},
    finish(){stop();index=letters.length;write(letters.join(''));done();},stop
  };
}
