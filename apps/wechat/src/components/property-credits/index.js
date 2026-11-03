// Presentation only. The page supplies the verified balance and handles payment.
Component({
 properties:{fromCreation:{type:Boolean,value:false},remaining:{type:Number,value:0},authenticated:{type:Boolean,value:false},busy:{type:Boolean,value:false},pending:{type:Boolean,value:false},error:{type:String,value:''}},
 methods:{purchase(){if(!this.data.busy)this.triggerEvent('purchase');},restore(){if(!this.data.busy)this.triggerEvent('restore');}}
});
