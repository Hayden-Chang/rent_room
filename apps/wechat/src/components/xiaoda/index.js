import {poseSource} from '../../lib/xiaoda-skin.js';
import {createTypewriter} from '../../lib/typewriter.js';
import {speechParts} from '../../lib/speech-parts.js';
Component({
  options:{multipleSlots:true},
  properties:{text:String,layout:{type:String,value:'inline'},highlights:{type:Array,value:[]},highlightColor:String,icons:{type:Object,value:{}},pose:{type:String,value:'idle'},closable:Boolean,messageId:String,targetPointer:String,paused:Boolean},
  data:{shown:'',fullParts:[],shownParts:[],source:poseSource('idle'),finished:false},
  observers:{'text,messageId,highlights,icons'(){this.startText();},pose(value){this.setData({source:poseSource(value)});},paused(value){if(value)this.writer?.pause();else if(!this.pageHidden)this.writer?.resume();}},
  lifetimes:{attached(){this.startText();},detached(){this.writer?.stop();}},
  pageLifetimes:{hide(){this.pageHidden=true;this.writer?.pause();},show(){this.pageHidden=false;if(!this.data.paused)this.writer?.resume();}},
  methods:{
    startText(){this.writer?.stop();this.setData({finished:false,fullParts:speechParts(this.data.text,this.data.highlights,Infinity,this.data.icons)});this.writer=createTypewriter({write:shown=>this.setData({shown,shownParts:speechParts(this.data.text,this.data.highlights,Array.from(shown).length,this.data.icons)}),done:()=>{this.setData({finished:true});this.triggerEvent('typed');}});this.writer.start(this.data.text);if(this.data.paused||this.pageHidden)this.writer.pause();},
    finish(){if(!this.data.finished&&!this.data.paused)this.writer?.finish();},
    close(){this.triggerEvent('dismiss');}
  }
});
