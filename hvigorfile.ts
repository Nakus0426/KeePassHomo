import { appTasks, OhosAppContext, OhosPluginId } from '@ohos/hvigor-ohos-plugin';
import { getNode } from '@ohos/hvigor';
import { existsSync, readFileSync } from 'fs';
import { dirname, join } from 'path';

// 签名配置按机器加密，不能入库；本机配置由 signing/local-signing.json 提供并在此注入
const LOCAL_SIGNING_FILE = join(dirname(__filename), 'signing', 'local-signing.json');

getNode(__filename).afterNodeEvaluate(node => {
  if (!existsSync(LOCAL_SIGNING_FILE)) {
    throw new Error(`缺少本机签名配置 ${LOCAL_SIGNING_FILE}，请按 README 的“团队签名”章节完成配置`);
  }
  const signingConfigs = JSON.parse(readFileSync(LOCAL_SIGNING_FILE, 'utf8')).signingConfigs;
  if (!Array.isArray(signingConfigs) || signingConfigs.length === 0) {
    throw new Error(`${LOCAL_SIGNING_FILE} 的 signingConfigs 为空`);
  }
  const appContext = node.getContext(OhosPluginId.OHOS_APP_PLUGIN) as OhosAppContext;
  const buildProfileOpt = appContext.getBuildProfileOpt();
  buildProfileOpt['app']['signingConfigs'] = signingConfigs;
  appContext.setBuildProfileOpt(buildProfileOpt);
});

export default {
  system: appTasks, /* Built-in plugin of Hvigor. It cannot be modified. */
  plugins: []       /* Custom plugin to extend the functionality of Hvigor. */
}
