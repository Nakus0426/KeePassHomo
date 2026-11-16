// 用法：node gen-vault.js <输出文件> <主密码> [条目数]
// 从零生成测试保险库：条目覆盖全部条目模板，含附件、SSH 密钥、自定义字段、标签、收藏与归档。

const fs = require('fs')
const { kdbxweb, registerArgon2, describeError, LAYOUT_TYPE_KEY } = require('./kdbx-env')

const DEFAULT_COUNT = 100
const VAULT_NAME = '测试保险库'
const PAD_LENGTH = 3
const DAY_MS = 24 * 60 * 60 * 1000
const NOW = Date.now()

// 与 app 侧常量保持一致。
const FIELD_TYPES_KEY = 'KeePassHomo.FieldTypes'
const FAVORITE_KEY = 'KeePassHomo.Favorite'
const ARCHIVED_KEY = 'KeePassHomo.Archived'
const SSH_KEYS_FIELD = 'SshKeys'
const SSH_KEYS_VERSION = 1

const TEMPLATE_LOGIN = 'Login'
const TEMPLATE_SECURE_NOTE = 'SecureNote'
const TEMPLATE_CREDIT_CARD = 'CreditCard'
const TEMPLATE_SSH_KEY = 'SshKey'
const TEMPLATE_ATTACHMENT = 'Attachment'
const TEMPLATE_PASSWORD = 'Password'

const GROUP_ROOT = '测试保险库'
const GROUP_WORK = '工作'
const GROUP_PERSONAL = '个人'
const GROUP_SERVERS = '服务器'
const GROUP_FINANCE = '财务卡券'
const GROUP_DOCS = '文档附件'

const LOGIN_SITES = [
    'GitHub', 'GitLab 企业版', '公司 OA 系统', '阿里云控制台', '腾讯云控制台',
    'AWS 控制台', '网易邮箱', 'Gmail', 'Outlook 邮箱', '知乎',
    '哔哩哔哩', '微博', '豆瓣', '京东', '淘宝',
    '拼多多', '美团', '饿了么', '铁路 12306', '航空公司常旅客',
    '招商银行网银', '中国银行网银', '建设银行网银', '支付宝', '微信公众平台',
    '掘金', 'Stack Overflow', 'Docker Hub', 'npm 账号', 'PyPI 账号',
    'Cloudflare', 'Vercel', 'Netlify', '域名注册商', '服务器面板',
    '家庭路由器管理', 'NAS 管理后台', '智能家居网关', 'Steam', 'Epic Games',
]

const NOTE_TOPICS = [
    'Wi-Fi 密码与访客网络', '服务器部署笔记', '身份证与护照信息备份', '银行保险箱编号',
    '家庭网络拓扑记录', '软件许可证密钥', '域名与 DNS 记录说明', '常用命令行片段',
    '出差行程与酒店偏好', '医疗记录与过敏信息', '保险单号与理赔电话', '旧设备的恢复密钥',
]

const CARD_ISSUERS = [
    ['招商银行', '银联'], ['中国银行', 'Visa'], ['建设银行', 'Mastercard'],
    ['工商银行', '银联'], ['交通银行', 'Visa'], ['浦发银行', 'American Express'],
    ['中信银行', 'JCB'], ['民生银行', 'Discover'], ['平安银行', '银联'],
    ['广发银行', 'Visa'], ['兴业银行', 'Mastercard'], ['农业银行', '银联'],
]

const PASSWORD_TARGETS = [
    '家庭 Wi-Fi', '路由器管理员', 'NAS 管理员', '服务器 root', '主机 BIOS',
    '智能门锁', '加密磁盘', 'MySQL 数据库', 'Redis 实例', '公司 VPN',
    '网络打印机', '文件保险柜',
]

const SSH_TARGETS = [
    '生产服务器 01', '生产服务器 02', '跳板机', 'Git 服务器', 'CI Runner',
    '数据库堡垒机', '家庭 NAS', '树莓派', '云主机', 'Kubernetes 集群',
    '备份服务器', '防火墙',
]

const ATTACHMENT_TOPICS = [
    '租房合同', '车辆行驶证', '重疾险保单', '个人简历', '年度体检报告',
    '项目验收单', '办公设备发票', '护照复印件', '网络拓扑图', '服务器资产清单',
]

const OLD_CLIENT_TITLES = ['旧客户端创建的条目', '未分类草稿']

const SSH_ALGORITHMS = [
    ['RSA', 4096], ['RSA', 2048], ['ED25519', 256], ['ECDSA', 384],
]

const LOGIN_TAGS = ['账号', '工作', '个人', '重要', '待整理']
const CARD_TAGS = ['财务', '卡券']
const SERVER_TAGS = ['服务器', '运维']

function pad(index) {
    return String(index).padStart(PAD_LENGTH, '0')
}

// 可重复的伪随机字节：大附件不压缩，用于压解锁与附件读取耗时。
function pseudoRandomBytes(size, seed) {
    const buffer = Buffer.alloc(size)
    let state = seed >>> 0
    for (let index = 0; index < size; index++) {
        state = (state * 1664525 + 1013904223) >>> 0
        buffer[index] = state >>> 24
    }
    return buffer
}

const PNG_BYTES = Buffer.from(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    'base64')

function reportText(topic, seed) {
    const lines = [`# ${topic}`, '', '由 kdbx-test-data 生成的测试附件，无真实业务含义。', '']
    for (let index = 1; index <= 40; index++) {
        lines.push(`${pad(index)} 项：第 ${seed + index} 条测试记录，包含足以换行的中文描述文本。`)
    }
    return lines.join('\n')
}

function accessLog(seed) {
    const lines = []
    for (let index = 1; index <= 2000; index++) {
        lines.push(`2026-0${(index % 9) + 1}-1${index % 9} 10:${pad(index % 60)}:00 INFO req=${seed}-${index} status=200 cost=${index % 500}ms`)
    }
    return lines.join('\n')
}

function attachmentFiles(topicIndex) {
    const base = topicIndex + 1
    const files = [
        { name: `${ATTACHMENT_TOPICS[topicIndex]}.txt`, bytes: Buffer.from(reportText(ATTACHMENT_TOPICS[topicIndex], base)) },
        { name: `metadata-${pad(base)}.json`, bytes: Buffer.from(JSON.stringify({
            id: `doc-${pad(base)}`,
            topic: ATTACHMENT_TOPICS[topicIndex],
            tags: ['测试', '附件'],
            pages: base + 2,
        }, null, 2)) },
    ]
    if (base % 3 === 0) {
        files.push({ name: `access-${pad(base)}.log`, bytes: Buffer.from(accessLog(base)) })
    }
    if (base % 4 === 0) {
        files.push({ name: `diagram-${pad(base)}.png`, bytes: PNG_BYTES })
    }
    if (base % 5 === 0) {
        files.push({ name: `backup-${pad(base)}.bin`, bytes: pseudoRandomBytes(4 * 1024 * 1024, base) })
    }
    return files
}

// 假密钥内容只用于渲染与复制，不具备任何加密意义。
function fakeSshKey(index) {
    const [algorithm, bits] = SSH_ALGORITHMS[index % SSH_ALGORITHMS.length]
    const seed = pad(index + 1)
    const publicBody = pseudoRandomBytes(96, index + 1).toString('base64').replace(/=+$/, '')
    return {
        name: `${algorithm.toLowerCase()}-${seed}`,
        algorithm,
        bits,
        addedAt: NOW - (index + 1) * 7 * DAY_MS,
        privateKey: [
            `-----BEGIN ${algorithm === 'ED25519' ? 'OPENSSH' : algorithm} PRIVATE KEY-----`,
            pseudoRandomBytes(48, index + 101).toString('base64'),
            pseudoRandomBytes(48, index + 202).toString('base64'),
            `-----END ${algorithm === 'ED25519' ? 'OPENSSH' : algorithm} PRIVATE KEY-----`,
        ].join('\n'),
        publicKey: `${algorithm === 'ED25519' ? 'ssh-ed25519' : `ssh-${algorithm.toLowerCase()}`} ${publicBody} test-${seed}`,
    }
}

function setMeta(entry, key, value) {
    if (entry.customData === undefined) {
        entry.customData = new Map()
    }
    entry.customData.set(key, { value, lastModified: new Date() })
}

function setFieldTypes(entry, types) {
    if (Object.keys(types).length === 0) {
        return
    }
    setMeta(entry, FIELD_TYPES_KEY, JSON.stringify(types))
}

function setTimes(entry, daysAgo) {
    const created = new Date(NOW - daysAgo * DAY_MS)
    entry.times.creationTime = created
    entry.times.locationChanged = created
    entry.times.lastModTime = new Date(NOW - Math.floor(daysAgo / 2) * DAY_MS)
    entry.times.lastAccessTime = new Date(NOW - Math.floor(daysAgo / 3) * DAY_MS)
}

function setCommon(entry, title, url, notes, tags) {
    entry.fields.set('Title', title)
    entry.fields.set('UserName', '')
    entry.fields.set('Password', kdbxweb.ProtectedValue.fromString(''))
    entry.fields.set('URL', url)
    entry.fields.set('Notes', notes)
    entry.tags = tags
}

function fillLogin(db, entry, index, globalIndex) {
    const title = LOGIN_SITES[index % LOGIN_SITES.length]
    const account = `user${pad(globalIndex + 1)}@example.com`
    setCommon(entry, title, `https://${['github.com', 'gitlab.example.com', 'oa.example.com',
        'console.aliyun.com', 'console.cloud.tencent.com'][index % 5]}`, index % 3 === 0
        ? `第 ${globalIndex + 1} 条登录条目，用于测试备注换行与长文本。\n第二行内容。` : '', [
        LOGIN_TAGS[index % LOGIN_TAGS.length],
        ...(index % 4 === 0 ? [LOGIN_TAGS[(index + 2) % LOGIN_TAGS.length]] : []),
    ])
    entry.fields.set('UserName', account)
    entry.fields.set('Password', kdbxweb.ProtectedValue.fromString(`P@ssw0rd-${pad(globalIndex + 1)}!`))
    if (index % 10 === 0) {
        entry.fields.set('恢复邮箱', `backup${pad(globalIndex + 1)}@example.com`)
        entry.fields.set('两步验证备份码', kdbxweb.ProtectedValue.fromString(
            `${pseudoRandomBytes(4, globalIndex + 1).toString('hex')}\n${pseudoRandomBytes(4, globalIndex + 2).toString('hex')}`))
        setFieldTypes(entry, { '两步验证备份码': 'password', '恢复邮箱': 'email' })
    }
}

function fillSecureNote(db, entry, index, globalIndex) {
    const topic = NOTE_TOPICS[index % NOTE_TOPICS.length]
    setCommon(entry, topic, '', `${reportText(topic, globalIndex + 1)}\n\n记录人：测试账号 ${pad(globalIndex + 1)}`, [
        '笔记',
        index % 2 === 0 ? '个人' : '工作',
    ])
}

function fillCreditCard(db, entry, index, globalIndex) {
    const [issuer, cardType] = CARD_ISSUERS[index % CARD_ISSUERS.length]
    setCommon(entry, `${issuer} ${cardType} 信用卡`, '', index % 2 === 0
        ? '测试卡号，仅用于界面展示。' : '', CARD_TAGS)
    entry.fields.set('CardNumber', kdbxweb.ProtectedValue.fromString(
        `6225 ${pad(globalIndex + 1)} ${pad(globalIndex + 11)} ${pad(globalIndex + 21)}`))
    entry.fields.set('Issuer', issuer)
    entry.fields.set('CardType', cardType)
    entry.fields.set('CardHolderName', `ZHANG SAN ${pad(globalIndex + 1)}`)
    entry.fields.set('Expiry', `0${(index % 9) + 1}/2${(index % 4) + 6}`)
    setFieldTypes(entry, { CardNumber: 'password' })
}

function fillPassword(db, entry, index, globalIndex) {
    const target = PASSWORD_TARGETS[index % PASSWORD_TARGETS.length]
    setCommon(entry, target, '', `第 ${globalIndex + 1} 条独立密码条目。`, ['密码'])
    entry.fields.set('Password', kdbxweb.ProtectedValue.fromString(
        `${pseudoRandomBytes(12, globalIndex + 1).toString('base64')}`))
}

function fillSshKey(db, entry, index, globalIndex) {
    const target = SSH_TARGETS[index % SSH_TARGETS.length]
    const keyCount = index % 3 === 0 ? 2 : 1
    const keys = []
    for (let keyIndex = 0; keyIndex < keyCount; keyIndex++) {
        keys.push(fakeSshKey(index * 2 + keyIndex))
    }
    setCommon(entry, `${target} SSH 密钥`, '', `由测试工具生成的假密钥，用于测试密钥卡片列表。`, SERVER_TAGS)
    entry.fields.set(SSH_KEYS_FIELD, kdbxweb.ProtectedValue.fromString(
        JSON.stringify({ version: SSH_KEYS_VERSION, keys })))
    setFieldTypes(entry, { [SSH_KEYS_FIELD]: 'password' })
}

async function fillAttachment(db, entry, index, globalIndex) {
    const topic = ATTACHMENT_TOPICS[index % ATTACHMENT_TOPICS.length]
    setCommon(entry, `${topic}（附件）`, '', `附件条目 ${pad(globalIndex + 1)}，共 ${attachmentFiles(index).length} 个文件。`, [
        '附件', '文档',
    ])
    for (const file of attachmentFiles(index)) {
        entry.binaries.set(file.name, await db.createBinary(new Uint8Array(file.bytes)))
    }
}

function fillUntyped(db, entry, index, globalIndex) {
    setCommon(entry, OLD_CLIENT_TITLES[index % OLD_CLIENT_TITLES.length], 'https://example.com/legacy', '', [])
    entry.fields.set('UserName', `legacy${pad(globalIndex + 1)}`)
}

const PLAN = [
    { template: TEMPLATE_LOGIN, count: 40, group: (index) => index % 2 === 0 ? GROUP_WORK : GROUP_PERSONAL, fill: fillLogin },
    { template: TEMPLATE_SECURE_NOTE, count: 12, group: () => GROUP_PERSONAL, fill: fillSecureNote },
    { template: TEMPLATE_CREDIT_CARD, count: 12, group: () => GROUP_FINANCE, fill: fillCreditCard },
    { template: TEMPLATE_PASSWORD, count: 12, group: () => GROUP_WORK, fill: fillPassword },
    { template: TEMPLATE_SSH_KEY, count: 12, group: () => GROUP_SERVERS, fill: fillSshKey },
    { template: TEMPLATE_ATTACHMENT, count: 10, group: () => GROUP_DOCS, fill: fillAttachment },
    { template: '', count: 2, group: () => GROUP_ROOT, fill: fillUntyped },
]

function usage() {
    console.log('用法: node gen-vault.js <输出文件> <主密码> [条目数]')
    console.log(`  条目数默认 ${DEFAULT_COUNT}；条目按模板分配，超出内置分配的部分补为登录条目`)
}

function parseArgs(argv) {
    const [file, password, countText] = argv
    if (!file || !password) {
        usage()
        process.exit(1)
    }
    if (fs.existsSync(file)) {
        console.error(`输出文件已存在，拒绝覆盖：${file}`)
        process.exit(1)
    }
    const count = countText === undefined ? DEFAULT_COUNT : Number(countText)
    if (!Number.isInteger(count) || count <= 0) {
        console.error(`条目数必须是正整数：${countText}`)
        process.exit(1)
    }
    return { file, password, count }
}

// 收藏与归档分布固定，保证每次生成的数据一致。
function isFavorite(globalIndex, template) {
    return template === TEMPLATE_LOGIN ? globalIndex % 9 === 4 : globalIndex % 17 === 3
}

function isArchived(globalIndex) {
    return globalIndex % 31 === 7
}

async function buildVault(password, count) {
    registerArgon2()
    const credentials = new kdbxweb.Credentials(kdbxweb.ProtectedValue.fromString(password))
    const db = kdbxweb.Kdbx.create(credentials, VAULT_NAME)
    db.createDefaultGroup()
    db.getDefaultGroup().name = GROUP_ROOT

    const groups = new Map()
    for (const name of [GROUP_ROOT, GROUP_WORK, GROUP_PERSONAL, GROUP_SERVERS, GROUP_FINANCE, GROUP_DOCS]) {
        groups.set(name, name === GROUP_ROOT ? db.getDefaultGroup() : db.createGroup(db.getDefaultGroup(), name))
    }

    let globalIndex = 0
    for (const block of PLAN) {
        for (let index = 0; index < block.count && globalIndex < count; index++) {
            const entry = db.createEntry(groups.get(block.group(index)))
            await block.fill(db, entry, index, globalIndex)
            if (block.template.length > 0) {
                setMeta(entry, LAYOUT_TYPE_KEY, block.template)
            }
            if (isFavorite(globalIndex, block.template)) {
                setMeta(entry, FAVORITE_KEY, 'true')
            }
            if (isArchived(globalIndex)) {
                setMeta(entry, ARCHIVED_KEY, 'true')
            }
            setTimes(entry, (globalIndex % 180) + 1)
            globalIndex++
        }
    }
    // 条目数超过内置分配时继续补登录条目。
    while (globalIndex < count) {
        const entry = db.createEntry(groups.get(GROUP_PERSONAL))
        fillLogin(db, entry, globalIndex, globalIndex)
        setMeta(entry, LAYOUT_TYPE_KEY, TEMPLATE_LOGIN)
        setTimes(entry, (globalIndex % 180) + 1)
        globalIndex++
    }
    return db
}

function countByTemplate(db) {
    const counts = new Map()
    const walk = (group) => {
        for (const entry of group.entries) {
            const template = entry.customData?.get(LAYOUT_TYPE_KEY)?.value ?? '（未标记）'
            counts.set(template, (counts.get(template) ?? 0) + 1)
        }
        group.groups.forEach(walk)
    }
    db.groups.forEach(walk)
    return counts
}

async function main() {
    const { file, password, count } = parseArgs(process.argv.slice(2))
    const db = await buildVault(password, count)
    const data = Buffer.from(await db.save())
    fs.writeFileSync(file, data)

    // 写回后重新加载一次，确认文件可解开、条目数与附件都在。
    const reopened = await kdbxweb.Kdbx.load(
        data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength),
        new kdbxweb.Credentials(kdbxweb.ProtectedValue.fromString(password)),
        { preserveXml: true })
    const counts = countByTemplate(reopened)
    const total = [...counts.values()].reduce((sum, value) => sum + value, 0)
    let attachmentCount = 0
    const walk = (group) => {
        group.entries.forEach((entry) => attachmentCount += entry.binaries.size)
        group.groups.forEach(walk)
    }
    reopened.groups.forEach(walk)

    console.log(`已生成：${file}`)
    console.log(`条目数：${total}（请求 ${count}）`)
    for (const [template, value] of counts) {
        console.log(`  ${template}：${value}`)
    }
    console.log(`附件文件数：${attachmentCount}`)
    console.log(`文件大小：${fs.statSync(file).size} 字节`)
}

main().catch((error) => {
    console.error(`失败：${describeError(error)}`)
    process.exit(1)
})
