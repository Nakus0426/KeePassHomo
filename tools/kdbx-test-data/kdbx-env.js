// app 侧 ohpm kdbxweb 是只能跑在设备上的 HarmonyOS HAR，这里改用 npm 同名库处理标准 KDBX4 文件。

const kdbxweb = require('kdbxweb')
const hashwasm = require('hash-wasm')

// kdbxweb 默认 KDF 是 Argon2d，Node 无内置实现，必须注入；其 memory 单位是 KiB，hash-wasm 同样收 KiB，直接透传。
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

// kdbxweb 只接受 ArrayBuffer；Node Buffer 是共享内存池里的视图，必须切片出独立 ArrayBuffer。
function toArrayBuffer(buffer) {
    return buffer.buffer.slice(buffer.byteOffset, buffer.byteOffset + buffer.byteLength)
}

// preserveXml 与 app 保持一致，避免丢掉 app 写入的未知 XML 节点。
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
