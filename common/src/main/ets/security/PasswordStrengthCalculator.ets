/**
 * 密码强度等级。
 */
export enum StrengthLevel {
  Invalid = 0,
  VeryWeak = 1,
  Weak = 2,
  Medium = 3,
  Strong = 4,
  VeryStrong = 5,
}

const COMMON_WEAK_PATTERNS: string[] = [
  'password', 'passw0rd', 'admin', 'administrator', 'qwerty', 'qwertyuiop',
  'welcome', 'letmein', 'login', 'secret', 'changeme', 'iloveyou',
  '123456', '12345678', '123456789', '111111', '000000', '654321',
  '密码', '管理员', '欢迎', '测试',
]

const KEYBOARD_SEQUENCES: string[] = [
  'qwertyuiop', 'asdfghjkl', 'zxcvbnm', '1234567890',
]

/**
 * 轻量启发式密码强度计算器。
 * 仅依赖密码文本，适合在 UI 输入变化时同步调用。
 */
export class PasswordStrengthCalculator {
  static calculate(password: string): StrengthLevel {
    if (password.length === 0) {
      return StrengthLevel.Invalid
    }

    const normalized = password.toLowerCase()
    if (PasswordStrengthCalculator.isEntirelyRepeated(password) ||
      PasswordStrengthCalculator.isRepeatedPattern(password)) {
      return StrengthLevel.VeryWeak
    }

    let score = PasswordStrengthCalculator.lengthScore(password.length)
    const hasLowercase = /[a-z]/.test(password)
    const hasUppercase = /[A-Z]/.test(password)
    const hasDigit = /[0-9]/.test(password)
    const hasSpecial = /[^A-Za-z0-9]/.test(password)
    const hasNonAscii = /[^\u0000-\u007f]/.test(password)

    score += hasLowercase ? 10 : 0
    score += hasUppercase ? 10 : 0
    score += hasDigit ? 10 : 0
    score += hasSpecial ? 10 : 0
    score += hasNonAscii ? 5 : 0

    if ((hasDigit && !hasLowercase && !hasUppercase && !hasSpecial) ||
      (!hasDigit && (hasLowercase || hasUppercase) && !hasSpecial)) {
      score -= 20
    }
    if (PasswordStrengthCalculator.hasWeakPattern(normalized)) {
      score -= 35
      if (/\d{1,4}$/.test(normalized)) {
        score -= 10
      }
    }
    if (PasswordStrengthCalculator.hasSequence(normalized)) {
      score -= 25
    }
    if (PasswordStrengthCalculator.hasRepeatedRun(password) ||
      PasswordStrengthCalculator.hasRepeatedPattern(password)) {
      score -= 25
    }

    const level = PasswordStrengthCalculator.levelForScore(score)
    if (password.length <= 4) {
      return Math.min(level, StrengthLevel.VeryWeak) as StrengthLevel
    }
    if (password.length <= 7) {
      return Math.min(level, StrengthLevel.Weak) as StrengthLevel
    }
    if (password.length <= 9) {
      return Math.min(level, StrengthLevel.Medium) as StrengthLevel
    }
    return level
  }

  private static lengthScore(length: number): number {
    if (length <= 4) {
      return 0
    }
    if (length <= 7) {
      return 10
    }
    if (length <= 10) {
      return 20
    }
    if (length <= 14) {
      return 35
    }
    if (length <= 19) {
      return 50
    }
    return 60
  }

  private static levelForScore(score: number): StrengthLevel {
    const boundedScore = Math.max(0, Math.min(100, score))
    if (boundedScore < 20) {
      return StrengthLevel.VeryWeak
    }
    if (boundedScore < 40) {
      return StrengthLevel.Weak
    }
    if (boundedScore < 60) {
      return StrengthLevel.Medium
    }
    if (boundedScore < 80) {
      return StrengthLevel.Strong
    }
    return StrengthLevel.VeryStrong
  }

  private static hasWeakPattern(value: string): boolean {
    for (const pattern of COMMON_WEAK_PATTERNS) {
      if (value === pattern || (value.startsWith(pattern) && /^\d{1,4}$/.test(value.slice(pattern.length)))) {
        return true
      }
    }
    return false
  }

  private static hasSequence(value: string): boolean {
    for (const sequence of KEYBOARD_SEQUENCES) {
      if (PasswordStrengthCalculator.containsSequence(value, sequence) ||
        PasswordStrengthCalculator.containsSequence(value, sequence.split('').reverse().join(''))) {
        return true
      }
    }
    for (let index = 2; index < value.length; index += 1) {
      const first = value.charCodeAt(index - 2)
      const second = value.charCodeAt(index - 1)
      const third = value.charCodeAt(index)
      if ((second - first === 1 && third - second === 1) ||
        (second - first === -1 && third - second === -1)) {
        return true
      }
    }
    return false
  }

  private static containsSequence(value: string, sequence: string): boolean {
    for (let index = 0; index <= sequence.length - 3; index += 1) {
      if (value.includes(sequence.slice(index, index + 3))) {
        return true
      }
    }
    return false
  }

  private static hasRepeatedRun(value: string): boolean {
    for (let index = 2; index < value.length; index += 1) {
      if (value[index] === value[index - 1] && value[index] === value[index - 2]) {
        return true
      }
    }
    return false
  }

  private static isEntirelyRepeated(value: string): boolean {
    return value.length >= 3 && value.split('').every((character: string) => character === value[0])
  }

  private static hasRepeatedPattern(value: string): boolean {
    return value.length >= 6 && PasswordStrengthCalculator.isRepeatedPattern(value)
  }

  private static isRepeatedPattern(value: string): boolean {
    for (let size = 1; size <= 3; size += 1) {
      if (value.length < size * 2 || value.length % size !== 0) {
        continue
      }
      const pattern = value.slice(0, size)
      if (pattern.repeat(value.length / size) === value) {
        return true
      }
    }
    return false
  }
}
