// 向现有 KDBX 保险库追加测试条目（只填 Title 与 UserName），用于手测条目列表。
//
// 用法：
//   node gen-entries.js <保险库路径> <主密码> [数量] [--out <输出文件>]
//   默认就地写回原文件，并在同目录先生成 <文件名>.backup-<时间戳>.kdbx 备份；
//   带 --out 时写入新文件，原文件不动。

const fs = require('fs')
const path = require('path')
const { loadVault, describeError } = require('./kdbx-env')

const DEFAULT_COUNT = 100
const PAD_LENGTH = 3
const NUMBERED_LIMIT = 90

/** 超长中英混排标题：验证列表标题的省略号。 */
const LONG_TITLES = [
    '企业统一身份认证平台生产环境管理员账户（含双因子与备用恢复码）',
    'MyBankOnlineBankingPersonalAccountWithLongName',
    '跨区域多云 VPC 网络运维专用高权限运维账号与审计日志入口',
    'LegacyEnterpriseSSOAdministratorAccountForStagingEnvironment',
    '家庭共享流媒体订阅与设备授权管理入口（含子账号与家长控制）',
]

/** 纯英文标题：验证无头像时「标题前两个字母」的展示。 */
const ENGLISH_TITLES = ['AlphaBetaSite', 'GitHubPersonal', 'AmazonShopping']

/** 含 emoji 与前后空格的标题：验证 trim 与空标题回退。 */
const EMOJI_TITLES = ['  🎉 生日礼物与红包记账  ', '🔐 二次元账号收藏夹']

function pad(index) {
    return String(index).padStart(PAD_LENGTH, '0')
}

function titleOf(index) {
    if (index <= NUMBERED_LIMIT) {
        return `测试条目 ${pad(index)}`
    }
    if (index <= NUMBERED_LIMIT + LONG_TITLES.length) {
        return LONG_TITLES[index - NUMBERED_LIMIT - 1]
    }
    const englishStart = NUMBERED_LIMIT + LONG_TITLES.length
    if (index <= englishStart + ENGLISH_TITLES.length) {
        return ENGLISH_TITLES[index - englishStart - 1]
    }
    const emojiStart = englishStart + ENGLISH_TITLES.length
    if (index <= emojiStart + EMOJI_TITLES.length) {
        return EMOJI_TITLES[index - emojiStart - 1]
    }
    return `测试条目 ${pad(index)}`
}

function usernameOf(index) {
    return `user${pad(index)}@example.com`
}

function usage() {
    console.log('用法: node gen-entries.js <保险库路径> <主密码> [数量] [--out <输出文件>]')
    console.log('  数量默认 100；默认就地写回并生成同目录 <文件名>.backup-<时间戳>.kdbx 备份')
    console.log('  --out <文件>  写入新文件，原文件不动')
}

function parseArgs(argv) {
    const positional = []
    let out = ''
    for (let i = 0; i < argv.length; i++) {
        if (argv[i] === '--out') {
            out = argv[++i] || ''
            continue
        }
        positional.push(argv[i])
    }
    const [file, password, countText] = positional
    if (!file || !password) {
        usage()
        process.exit(1)
    }
    const count = countText === undefined ? DEFAULT_COUNT : Number(countText)
    if (!Number.isInteger(count) || count <= 0) {
        console.error(`数量必须是正整数：${countText}`)
        process.exit(1)
    }
    return {
        file,
        password,
        count,
        out
    }
}

function backupName(file) {
    const stamp = new Date().toISOString().replace(/[-:T]/g, '').slice(0, 14)
    const ext = path.extname(file)
    return `${file.slice(0, file.length - ext.length)}.backup-${stamp}${ext}`
}

async function main() {
    const { file, password, count, out } = parseArgs(process.argv.slice(2))
    const db = await loadVault(file, password)
    const before = db.groups.reduce((sum, group) => sum + group.entries.length, 0)
    const group = db.getDefaultGroup()
    for (let index = 1; index <= count; index++) {
        const entry = db.createEntry(group)
        entry.fields.set('Title', titleOf(index))
        entry.fields.set('UserName', usernameOf(index))
    }
    const data = Buffer.from(await db.save())
    if (out.length > 0) {
        fs.writeFileSync(out, data)
        console.log(`已写入新文件：${out}`)
    } else {
        const backup = backupName(file)
        fs.copyFileSync(file, backup)
        fs.writeFileSync(file, data)
        console.log(`已就地写回：${file}`)
        console.log(`原文件备份：${backup}`)
    }
    // 写回后重新加载一次，确认文件可用且条目数正确。
    const reopened = await loadVault(out.length > 0 ? out : file, password)
    const after = reopened.groups.reduce((sum, group) => sum + group.entries.length, 0)
    console.log(`条目数：${before} -> ${after}（本次追加 ${count}）`)
    console.log(`文件大小：${fs.statSync(out.length > 0 ? out : file).size} 字节`)
}

main().catch((error) => {
    console.error(`失败：${describeError(error)}`)
    process.exit(1)
})
