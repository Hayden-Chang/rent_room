"""Create a disposable infrastructure fixture outside the production app."""
import json
from pathlib import Path
import sys

root, slot, appid = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
(root / 'pages/index').mkdir(parents=True)
files = {
    'project.config.json': {'appid': appid, 'projectname': 'Pool-' + slot,
                            'compileType': 'miniprogram', 'miniprogramRoot': './',
                            'libVersion': '3.17.3', 'setting': {'es6': True, 'urlCheck': True, 'minifyWXML': True}},
    'app.json': {'pages': ['pages/index/index'], 'window': {'navigationBarTitleText': 'Pool ' + slot}},
    'app.js': 'App({})',
    'pages/index/index.js': "Page({data:{slot:%s,count:0},onLoad(){this.setData({count:wx.getStorageSync('pool-counter')||0})}})" % json.dumps(slot),
    'pages/index/index.wxml': '<view>{{slot}}</view><view>{{count}}</view>',
    'pages/index/index.wxss': 'view { margin:24px; font-size:24px; overflow-wrap:anywhere; }',
    'pages/index/index.json': {},
}
for name, data in files.items():
    (root / name).write_text(json.dumps(data) if isinstance(data, dict) else data)
