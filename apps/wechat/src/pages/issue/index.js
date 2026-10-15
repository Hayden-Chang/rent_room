import {protectedPage} from '../../lib/auth-page.js';
import {uid} from '../../lib/model.js';
import {issueDraft} from '../../lib/issues.js';
import {service, attempt, notify} from '../../lib/ui.js';

Page(protectedPage({
  data: {houseId: '', issueId: '', title: '', note: '', media: [], readonly: false, dirty: false, selecting: false, saving: false, error: '', titleError: '', keyboardHeight: 0},
  onLoad(options) {
    this.staged = []; this.unloaded = false; this.isNew = !options.issueId;
    const house = service().store.house(options.id);
    if (!house || (!this.isNew && !house.issues?.some(item => item.id === options.issueId)) || (this.isNew && house.archived)) {
      notify('房源或问题不可编辑，请返回查看'); wx.navigateBack(); return;
    }
    const id = options.issueId || uid(), draft = issueDraft(house, id);
    this.original = JSON.stringify(draft);
    this.setData({houseId: house.id, issueId: id, readonly: !!house.archived, ...draft});
    wx.setNavigationBarTitle({title: house.archived ? '查看问题' : this.isNew ? '新建问题' : '编辑问题'});
  },
  onUnload() { this.unloaded = true; service().discardIssueMedia(this.staged || []); },
  draft() { return {title: this.data.title, note: this.data.note, media: this.data.media}; },
  changed(patch) {
    this.setData(patch);
    const dirty = JSON.stringify(this.draft()) !== this.original;
    if (dirty !== this.data.dirty) {
      this.setData({dirty});
      if (dirty) wx.enableAlertBeforeUnload?.({message: '内容尚未保存，确定放弃并返回吗？'});
      else wx.disableAlertBeforeUnload?.({});
    }
  },
  inputTitle(e) { if (!this.data.readonly) this.changed({title: e.detail.value, titleError: '', error: ''}); },
  inputNote(e) { if (!this.data.readonly) this.changed({note: e.detail.value, error: ''}); },
  keyboard(e) { this.setData({keyboardHeight: Math.max(0, e.detail.height || 0)}); },
  addMedia() { return attempt(async () => {
    if (this.data.readonly || this.data.selecting || this.data.saving) return;
    this.setData({selecting: true});
    try {
      const media = await service().stageIssueMedia(this.data.houseId);
      if (this.unloaded) { service().discardIssueMedia(media); return; }
      this.staged.push(...media);
      this.changed({media: [...this.data.media, ...media], error: ''});
    } finally { if (!this.unloaded) this.setData({selecting: false}); }
  }); },
  removeMedia(e) {
    if (this.data.readonly || this.data.saving) return;
    const id = e.currentTarget.dataset.id;
    this.changed({media: this.data.media.filter(item => item.id !== id)});
    service().discardIssueMedia(this.staged.filter(item => item.id === id));
    this.staged = this.staged.filter(item => item.id !== id);
  },
  preview(e) { return attempt(() => service().preview(this.data.media, e.currentTarget.dataset.id)); },
  async leave() {
    if (wx.disableAlertBeforeUnload) await service().api('disableAlertBeforeUnload');
    await service().api('navigateBack');
  },
  cancel() { return attempt(async () => {
    if (this.data.selecting || this.data.saving) return;
    if (this.data.dirty) {
      const result = await service().api('showModal', {title: '放弃修改？', content: '尚未保存的文字和新增影像将被放弃。', confirmText: '放弃', cancelText: '继续编辑'});
      if (!result.confirm) return;
    }
    await this.leave();
  }); },
  save() { return attempt(async () => {
    if (this.data.readonly || this.data.selecting || this.data.saving) return;
    if (!this.data.title.trim()) { this.setData({titleError: '请填写问题标题'}); return; }
    this.setData({saving: true, error: '', titleError: ''});
    try {
      service().saveIssue(this.data.houseId, this.data.issueId, this.draft(), this.isNew);
      this.isNew = false; this.original = JSON.stringify(this.draft());
      this.setData({dirty: false});
      service().discardIssueMedia(this.staged); this.staged = [];
      await this.leave();
    } catch (error) { this.setData({error: error.message || '保存失败，已填写内容仍保留，请重试'}); }
    finally { if (!this.unloaded) this.setData({saving: false}); }
  }); }
}));
