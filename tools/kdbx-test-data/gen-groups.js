// 用法：node gen-groups.js <输入保险库> <主密码> <输出保险库>
// 向现有保险库补齐一套嵌套分组树，并为新叶子分组写入少量条目，用于手测分组选择器的层级与滚动。

const fs = require('fs')
const { kdbxweb, loadVault, describeError, LAYOUT_TYPE_KEY } = require('./kdbx-env')

// 分组树：name 为分组名，children 为子分组，entries 为该层新增条目数（已有条目的分组不再追加）。
const TREE = [
    {
        name: '项目资料', children: [
            { name: '进行中', entries: 2 },
            { name: '已完成', entries: 2 },
            { name: '归档', entries: 1 },
        ],
    },
    {
        name: '客户支持', children: [
            { name: '工单', entries: 2 },
            { name: '公告', entries: 1 },
        ],
    },
    {
        name: '实验室', children: [
            { name: '实验数据', entries: 2 },
            { name: '样本', entries: 1 },
        ],
    },
    {
        name: '旅行', children: [
            { name: '签证', entries: 1 },
            { name: '行程', entries: 2 },
        ],
    },
    {
        name: '媒体', children: [
            { name: '影视', entries: 2 },
            { name: '音乐', entries: 1 },
        ],
    },
    {
        name: '旧系统', children: [
            { name: '备份', entries: 1 },
            { name: '迁移', entries: 2 },
        ],
    },
    {
        name: '工作', children: [
            {
                name: '研发', children: [
                    { name: '前端', entries: 2 },
                    { name: '后端', entries: 2 },
                    { name: '移动端', entries: 1 },
                ],
            },
            {
                name: '运维', children: [
                    { name: '生产环境', entries: 2 },
                    { name: '预发环境', entries: 1 },
                ],
            },
            {
                name: '市场', children: [
                    { name: '品牌', entries: 1 },
                    { name: '活动', entries: 2 },
                ],
            },
            { name: '法务', entries: 1 },
        ],
    },
    {
        name: '个人', children: [
            { name: '家庭', entries: 1 },
            {
                name: '账号', children: [
                    { name: '邮箱', entries: 2 },
                    { name: '社交', entries: 2 },
                    { name: '购物', entries: 1 },
                ],
            },
            { name: '设备', entries: 1 },
            { name: '证件', entries: 1 },
        ],
    },
    {
        name: '服务器', children: [
            {
                name: '生产集群', children: [
                    { name: '华东', entries: 1 },
                    { name: '华北', entries: 1 },
                ],
            },
            { name: '数据库', entries: 1 },
            { name: '网络设备', entries: 1 },
        ],
    },
    {
        name: '财务卡券', children: [
            { name: '银行卡', entries: 1 },
            { name: '会员卡', entries: 1 },
            { name: '保险', entries: 1 },
        ],
    },
    {
        name: '文档附件', children: [
            { name: '合同', entries: 1 },
            { name: '发票', entries: 1 },
            { name: '报告', entries: 1 },
        ],
    },
    {
        name: '滚动测试', children: Array.from({ length: 16 }, (_, index) => ({
            name: `测试分组 ${String(index + 1).padStart(2, '0')}`,
            entries: index % 4,
        })),
    },
]

function findChild(parent, name) {
    return parent.groups.find((group) => group.name === name)
}

function ensureGroup(db, parent, name) {
    const existing = findChild(parent, name)
    if (existing !== undefined) {
        return { group: existing, created: false }
    }
    return { group: db.createGroup(parent, name), created: true }
}

function addEntries(db, group, count) {
    if (group.entries.length > 0 || count <= 0) {
        return 0
    }
    for (let index = 1; index <= count; index++) {
        const entry = db.createEntry(group)
        entry.fields.set('Title', `${group.name} 示例条目 ${index}`)
        entry.fields.set('UserName', `demo-${group.name}-${index}@example.com`)
        entry.fields.set('Password', kdbxweb.ProtectedValue.fromString(`Demo@${index}`))
        entry.fields.set('URL', 'https://example.com/demo')
        entry.fields.set('Notes', '由 gen-groups.js 生成的测试条目。')
        entry.tags = ['测试分组']
        entry.times.creationTime = new Date()
        entry.times.lastModTime = new Date()
        entry.customData = new Map([[LAYOUT_TYPE_KEY, { value: 'Login', lastModified: new Date() }]])
    }
    return count
}

function walk(db, parent, nodes) {
    let createdGroups = 0
    let createdEntries = 0
    for (const node of nodes) {
        const ensured = ensureGroup(db, parent, node.name)
        const group = ensured.group
        if (ensured.created) {
            createdGroups++
        }
        if (node.entries !== undefined) {
            createdEntries += addEntries(db, group, node.entries)
        }
        if (node.children !== undefined) {
            const child = walk(db, group, node.children)
            createdGroups += child.createdGroups
            createdEntries += child.createdEntries
        }
    }
    return { createdGroups, createdEntries }
}

function count(run) {
    return `${run.createdGroups} 个分组 / ${run.createdEntries} 条条目`
}

function usage() {
    console.log('用法: node gen-groups.js <输入保险库> <主密码> <输出保险库>')
    process.exit(1)
}

async function main() {
    const [input, password, output] = process.argv.slice(2)
    if (!input || !password || !output) {
        usage()
    }
    if (input === output) {
        console.error('输出文件不能与输入文件相同')
        process.exit(1)
    }
    const db = await loadVault(input, password)
    const root = db.getDefaultGroup()
    const run = walk(db, root, TREE)
    const saved = Buffer.from(await db.save())
    fs.writeFileSync(output, saved)
    console.log(`已写入：${output}`)
    console.log(`新增：${count(run)}`)
    console.log(`文件大小：${saved.length} 字节`)
}

main().catch((error) => {
    console.error(`失败：${describeError(error)}`)
    process.exit(1)
})
