import {poseSource} from '../../lib/xiaoda-skin.js';
import {createTypewriter} from '../../lib/typewriter.js';
import {speechParts} from '../../lib/speech-parts.js';
Component({
  properties:{text:String,layout:{type:String,value:'inline'},highlights:{type:Array,value:[]},pose:{type:String,value:'idle'},closable:Boolean,messageId:String},
  data:{shown:'',fullParts:[],shownParts:[],source:poseSource('idle'),finished:false},
  observers:{'text,messageId,highlights'(){this.startText();},pose(value){this.setData({source:poseSource(value)});}},
  lifetimes:{attached(){this.startText();},detached(){this.writer?.stop();}},
  pageLifetimes:{hide(){this.writer?.pause();},show(){this.writer?.resume();}},
  methods:{
    startText(){this.writer?.stop();this.setData({finished:false,fullParts:speechParts(this.data.text,this.data.highlights)});this.writer=createTypewriter({write:shown=>this.setData({shown,shownParts:speechParts(this.data.text,this.data.highlights,Array.from(shown).length)}),done:()=>{this.setData({finished:true});this.triggerEvent('typed');}});this.writer.start(this.data.text);},
    finish(){if(!this.data.finished)this.writer?.finish();},
    close(){this.triggerEvent('dismiss');}
  }
});
