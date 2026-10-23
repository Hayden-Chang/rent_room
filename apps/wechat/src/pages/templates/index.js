import {protectedPage} from '../../lib/auth-page.js';
Page(protectedPage({open(){wx.navigateTo({url:'/pages/template-edit/index?mode=detailed'});},confirm(){wx.navigateBack();}}));
