// 把 build-profile.json5 里的签名配置搬到本机未跟踪文件 signing/local-signing.json，
// 并将工程配置中的 signingConfigs 还原为空数组，保证该文件不产生 git 改动。
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const projectRoot = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const buildProfilePath = join(projectRoot, 'build-profile.json5');
const localSigningPath = join(projectRoot, 'signing', 'local-signing.json');

// 按括号配对截取 signingConfigs 数组原文，避免改写 JSON5 文件其余内容
function extractSigningConfigs(source) {
  const keyIndex = source.indexOf('"signingConfigs"');
  if (keyIndex < 0) {
    throw new Error('build-profile.json5 中未找到 signingConfigs 字段');
  }
  const start = source.indexOf('[', keyIndex);
  if (start < 0) {
    throw new Error('signingConfigs 字段后未找到数组起始符');
  }
  let depth = 0;
  let inString = false;
  let escaped = false;
  for (let i = start; i < source.length; i++) {
    const char = source[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char === '\\') {
        escaped = true;
      } else if (char === '"') {
        inString = false;
      }
      continue;
    }
    if (char === '"') {
      inString = true;
    } else if (char === '[') {
      depth++;
    } else if (char === ']') {
      depth--;
      if (depth === 0) {
        return { start, end: i, text: source.slice(start, i + 1) };
      }
    }
  }
  throw new Error('signingConfigs 数组未闭合');
}

const source = readFileSync(buildProfilePath, 'utf8');
const array = extractSigningConfigs(source);
const signingConfigs = JSON.parse(array.text);
if (!Array.isArray(signingConfigs) || signingConfigs.length === 0) {
  throw new Error('build-profile.json5 的 signingConfigs 为空，请先在 DevEco Studio 完成自动签名配置');
}

mkdirSync(dirname(localSigningPath), { recursive: true });
writeFileSync(localSigningPath, `${JSON.stringify({ signingConfigs }, null, 2)}\n`, 'utf8');

const restored = source.slice(0, array.start) + '[]' + source.slice(array.end + 1);
writeFileSync(buildProfilePath, restored, 'utf8');

console.log(`已写入 ${localSigningPath}`);
console.log(`已将 ${buildProfilePath} 的 signingConfigs 还原为空数组`);
