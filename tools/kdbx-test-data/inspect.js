// 只读查看 KDBX 保险库：头部参数（分组数、条目数、前/末几条），用于确认生成结果或设备上的文件。
//
// 用法：node inspect.js <保险库路径> <主密码>

const fs = require('fs')
const { loadVault, describeError } = require('./kdbx-env')

const SAMPLE_SIZE = 3

const KDF_NAMES = {
    'c9d9f39a628a4460bf740d08c18a4fea': 'AES-KDF',
    'ef636ddf8c29444b91f7a9a403e30a0c': 'Argon2d',
    '9e298b1956db4773b23dfc3ec6f0a1e6': 'Argon2id',
}

const CIPHER_NAMES = {
    '31c1f2e6bf714350be5805216afc5aff': 'AES128-CBC',
    'd6038a2b8b6f4cb5a524339a31dbb59a': 'AES256-CBC',
}

/** 头部是明文：签名 8 字节 + 版本 4 字节，随后是按「字段号 + 长度 + 数据」排列的字段。 */
function readHeader(file) {
    const buffer = fs.readFileSync(file)
    const fields = {
        // 头部版本按「minor(2 字节) + major(2 字节)」存放。
        version: `${buffer.readUInt16LE(10)}.${buffer.readUInt16LE(8)}`,
    }
    let offset = 12
    while (offset < buffer.length) {
        const fieldId = buffer[offset]
        offset += 1
        if (fieldId === 0) {
            break
        }
        const length = buffer.readUInt32LE(offset)
        offset += 4
        const data = buffer.subarray(offset, offset + length)
        offset += length
        if (fieldId === 2) {
            fields.cipher = CIPHER_NAMES[data.toString('hex')] || data.toString('hex')
        } else if (fieldId === 3) {
            fields.compression = data.readUInt32LE(0) === 1 ? 'gzip' : 'none'
        } else if (fieldId === 11) {
            fields.kdf = readKdf(data)
        }
    }
    return fields
}

function readKdf(buffer) {
    const kdf = {}
    let offset = 2 // 变体字典版本
    while (offset < buffer.length) {
        const type = buffer[offset]
        offset += 1
        if (type === 0) {
            break
        }
        const keyLength = buffer.readUInt32LE(offset)
        offset += 4
        const key = buffer.subarray(offset, offset + keyLength).toString('utf8')
        offset += keyLength
        const valueLength = buffer.readUInt32LE(offset)
        offset += 4
        const raw = buffer.subarray(offset, offset + valueLength)
        offset += valueLength
        if (type === 4) {
            kdf[key] = raw.readUInt32LE(0)
        } else if (type === 5) {
            kdf[key] = Number(raw.readBigUInt64LE(0))
        } else if (key === '$UUID') {
            kdf[key] = KDF_NAMES[raw.toString('hex')] || raw.toString('hex')
        } else if (key === 'S') {
            kdf[key] = `<${raw.length} 字节盐>`
        }
    }
    return kdf
}

function describe(file, password) {
    const header = readHeader(file)
    console.log(`== ${file}（${fs.statSync(file).size} 字节）`)
    console.log(`版本 KDBX ${header.version} | 加密 ${header.cipher} | 压缩 ${header.compression}`)
    console.log(
        `KDF ${header.kdf['$UUID']} | P=${header.kdf.P} I=${header.kdf.I} M=${header.kdf.M} 字节 | V=${header.kdf.V}`)
    return loadVault(file, password)
}

async function main() {
    const [file, password] = process.argv.slice(2)
    if (!file || !password) {
        console.log('用法: node inspect.js <保险库路径> <主密码>')
        process.exit(1)
    }
    const db = await describe(file, password)
    let total = 0
    for (const group of db.groups) {
        total += group.entries.length
        console.log(`分组「${group.name}」：直接子分组 ${group.groups.length} 个，条目 ${group.entries.length} 条`)
    }
    const entries = db.getDefaultGroup().entries
    console.log(`条目总数：${total}`)
    console.log('前 3 条：')
    for (const entry of entries.slice(0, SAMPLE_SIZE)) {
        console.log(`  ${entry.fields.get('Title')} / ${entry.fields.get('UserName')}`)
    }
    console.log('末 3 条：')
    for (const entry of entries.slice(-SAMPLE_SIZE)) {
        console.log(`  ${entry.fields.get('Title')} / ${entry.fields.get('UserName')}`)
    }
}

main().catch((error) => {
    console.error(`失败：${describeError(error)}`)
    process.exit(1)
})
