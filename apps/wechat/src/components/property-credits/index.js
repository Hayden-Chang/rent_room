// Presentation only. The page supplies the verified balance and handles payment.
Component({
 properties:{remaining:{type:Number,value:0},authenticated:{type:Boolean,value:false},busy:{type:Boolean,value:false},pending:{type:Boolean,value:false},error:{type:String,value:''}},
 methods:{purchase(){if(!this.data.busy&&!this.data.pending)this.triggerEvent('purchase');},restore(){if(!this.data.busy)this.triggerEvent('restore');},cancel(){if(!this.data.busy)this.triggerEvent('cancel');}}
});
