export type ValidationValue = string | number

export interface ValidationError {
  rule: string
  message: string
}

export interface ValidationResult {
  valid: boolean
  errors: Array<ValidationError>
}

export interface ValidationRule {
  readonly name: string

  validate(value: ValidationValue): string | undefined
}

export interface ValidationSchema {
  validate(value: ValidationValue): ValidationResult
}

type ValidationFunction = (value: ValidationValue) => string | undefined

function passResult(): ValidationResult {
  return { valid: true, errors: [] }
}

function collectResult(value: ValidationValue, rules: Array<ValidationRule>): ValidationResult {
  const errors: Array<ValidationError> = []
  for (const rule of rules) {
    if (typeof value === 'string' && value.trim().length === 0 && rule.name !== 'required') {
      continue
    }
    const message: string | undefined = rule.validate(value)
    if (message !== undefined) {
      errors.push({ rule: rule.name, message })
    }
  }
  return errors.length === 0 ? passResult() : { valid: false, errors }
}

class Rule implements ValidationRule {
  readonly name: string
  private readonly validator: ValidationFunction

  constructor(name: string, validator: ValidationFunction) {
    this.name = name
    this.validator = validator
  }

  validate(value: ValidationValue): string | undefined {
    return this.validator(value)
  }
}

export class StringSchema implements ValidationSchema {
  private readonly rules: Array<ValidationRule>

  constructor(rules: Array<ValidationRule> = []) {
    this.rules = rules
  }

  validate(value: ValidationValue): ValidationResult {
    if (typeof value !== 'string') {
      return {
        valid: false,
        errors: [{ rule: 'string', message: '请输入文本' }],
      }
    }
    return collectResult(value, this.rules)
  }
}

export class NumberSchema implements ValidationSchema {
  private readonly rules: Array<ValidationRule>

  constructor(rules: Array<ValidationRule> = []) {
    this.rules = rules
  }

  validate(value: ValidationValue): ValidationResult {
    if (typeof value !== 'number' || Number.isNaN(value)) {
      return {
        valid: false,
        errors: [{ rule: 'number', message: '请输入数字' }],
      }
    }
    return collectResult(value, this.rules)
  }
}

export function stringSchema(rules: Array<ValidationRule> = []): StringSchema {
  return new StringSchema(rules)
}

export function numberSchema(rules: Array<ValidationRule> = []): NumberSchema {
  return new NumberSchema(rules)
}

export function required(message: string = '此项为必填项'): ValidationRule {
  return new Rule('required', (value: ValidationValue): string | undefined => {
    if (typeof value === 'string' && value.trim().length === 0) {
      return message
    }
    return undefined
  })
}

export function minLength(length: number, message: string = `长度不能少于 ${length} 个字符`): ValidationRule {
  return new Rule('minLength', (value: ValidationValue): string | undefined => {
    if (typeof value === 'string' && value.length < length) {
      return message
    }
    return undefined
  })
}

export function maxLength(length: number, message: string = `长度不能超过 ${length} 个字符`): ValidationRule {
  return new Rule('maxLength', (value: ValidationValue): string | undefined => {
    if (typeof value === 'string' && value.length > length) {
      return message
    }
    return undefined
  })
}

export function length(expected: number, message: string = `长度必须为 ${expected} 个字符`): ValidationRule {
  return new Rule('length', (value: ValidationValue): string | undefined => {
    if (typeof value === 'string' && value.length !== expected) {
      return message
    }
    return undefined
  })
}

export function email(message: string = '请输入有效的邮箱地址'): ValidationRule {
  const pattern: RegExp = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
  return new Rule('email', (value: ValidationValue): string | undefined => {
    if (typeof value === 'string' && !pattern.test(value)) {
      return message
    }
    return undefined
  })
}

export function min(expected: number, message: string = `数值不能小于 ${expected}`): ValidationRule {
  return new Rule('min', (value: ValidationValue): string | undefined => {
    if (typeof value === 'number' && value < expected) {
      return message
    }
    return undefined
  })
}

export function max(expected: number, message: string = `数值不能大于 ${expected}`): ValidationRule {
  return new Rule('max', (value: ValidationValue): string | undefined => {
    if (typeof value === 'number' && value > expected) {
      return message
    }
    return undefined
  })
}

export function integer(message: string = '请输入整数'): ValidationRule {
  return new Rule('integer', (value: ValidationValue): string | undefined => {
    if (typeof value === 'number' && !Number.isInteger(value)) {
      return message
    }
    return undefined
  })
}

export function custom(validate: ValidationFunction, name: string = 'custom'): ValidationRule {
  return new Rule(name, validate)
}
