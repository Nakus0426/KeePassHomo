// KDBX 读写公共环境：Argon2d 注入、ArrayBuffer 转换、加载与错误翻译。
// app 侧的 ohpm kdbxweb 是 HarmonyOS HAR（只能跑在设备上），这里用 npm 同名库处理标准 KDBX4 文件。

const kdbxweb = require('kdbxweb')
const hashwasm = require('hash-wasm')

/**
 * kdbxweb 默认 KDF 是 Argon2d，而 Node 没有内置 Argon2，必须注入实现。
 * kdbxweb 传给该实现的 memory 单位是 KiB（KDBX 头部 M 字段是字节），hash-wasm 同样收 KiB，直接透传。
 * version 由 kdbxweb 传 19（0x13），hash-wasm 的 argon2d 即为该版本。
 */
function registerArgon2() {
    kdbxweb.CryptoEngine.setArgon2Impl((password, salt, memory, iterations, length, parallelism) =>
    hashwasm.argon2d({
        password: new Uint8Array(password),
        salt: new Uint8Array(salt),
        parallelism,
        iterations,
        memorySize: memory,
        hashLength: length,
        outputType: 'binary',
    }))
}

/** kdbxweb 只接受 ArrayBuffer；Node Buffer 是共享内存池里的视图，必须切片出独立 ArrayBuffer。 */
function toArrayBuffer(buffer) {
    return buffer.buffer.slice(buffer.byteOffset, buffer.byteOffset + buffer.byteLength)
}

/**
 * 加载保险库。preserveXml 与 app 保持一致，避免丢掉 app 写入的未知 XML 节点。
 */
async function loadVault(file, password) {
    const fs = require('fs')
    if (!fs.existsSync(file)) {
        throw new Error(`保险库文件不存在：${file}`)
    }
    registerArgon2()
    const credentials = new kdbxweb.Credentials(kdbxweb.ProtectedValue.fromString(password))
    try {
        return await kdbxweb.Kdbx.load(toArrayBuffer(fs.readFileSync(file)), credentials,
            { preserveXml: true })
    } catch (error) {
        throw new Error(describeError(error))
    }
}

/** 把 kdbxweb 的错误码翻译成可读原因，避免只看到 InvalidKey 之类的英文码。 */
function describeError(error) {
    const message = error && error.message ? error.message : String(error)
    if (message.includes('InvalidKey')) {
        return '主密码不匹配（若该库还绑定了密钥文件，本工具不支持，请在 app 里操作）'
    }
    if (message.includes('BadSignature')) {
        return '不是有效的 KDBX 文件'
    }
    return message
}

module.exports = {
    kdbxweb,
    loadVault,
    toArrayBuffer,
    describeError
}
