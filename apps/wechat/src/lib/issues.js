import {clone} from './model.js';

export function issueDraft(house, id) {
  const issue = house.issues?.find(item => item.id === id);
  return {title: issue?.title || '', note: issue?.note || '', media: clone(house.media.filter(item => item.issueId === id))};
}

export function writeIssue(house, id, draft, isNew) {
  const title = draft.title.trim(), note = draft.note.trim();
  if (!title) throw Error('请填写问题标题');
  if (title.length > 200) throw Error('标题不能超过 200 字');
  if (note.length > 10000) throw Error('备注不能超过 10000 字');
  const existing = house.issues?.find(item => item.id === id);
  if (!isNew && !existing) throw Error('问题已不存在，请返回查看');
  if (isNew && existing) throw Error('问题已保存，请返回查看');
  const issue = {...existing, id, title, note, resolved: existing?.resolved || false};
  house.issues = existing ? house.issues.map(item => item.id === id ? issue : item) : [...(house.issues || []), issue];
  house.media = [...house.media.filter(item => item.issueId !== id), ...clone(draft.media).map(item => ({...item, issueId: id, fieldId: ''}))];
}

export function mediaWithIssues(house) {
  return house.media.map(item => ({...item, issueTitle: house.issues?.find(issue => issue.id === item.issueId)?.title || ''}));
}
