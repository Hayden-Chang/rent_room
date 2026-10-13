const fs = require('node:fs');
const path = require('node:path');

async function perform(request, ci) {
  const production = request.command === 'production-upload';
  if (!production && (request.command !== 'preview' || !Number.isInteger(request.robot) || request.robot < 2 || request.robot > 30)) {
    throw Error('Preview requires an allocated robot from 2-30');
  }
  if (production && (request.robot !== 1 || request.confirmed !== true || !request.approval?.trim() || !request.version?.trim())) {
    throw Error('Robot 1 requires explicit production approval and version');
  }
  const project = new ci.Project({appid: request.appid, type: 'miniProgram',
    projectPath: request.project, privateKeyPath: request.key, ignores: ['project.private.config.json']});
  const options = {project, robot: request.robot, desc: request.desc,
    setting: {useProjectConfig: true}, threads: 2, onProgressUpdate() {}};
  const result = production ? await ci.upload({...options, version: request.version})
    : await ci.preview({...options, pagePath: request.pagePath || undefined,
      qrcodeFormat: 'image', qrcodeOutputDest: path.join(request.output, 'qrcode.jpg')});
  return {success: true, packages: result.subPackageInfo || []};
}

module.exports = {perform};
if (require.main === module) {
  (async () => {
    const request = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
    const result = await perform(request, require('miniprogram-ci'));
    fs.writeFileSync(path.join(request.output, 'result.json'), JSON.stringify(result), {mode: 0o600});
    process.exit(0);
  })().catch(() => { console.error('CI operation failed; inspect the private SDK log.'); process.exit(1); });
}
