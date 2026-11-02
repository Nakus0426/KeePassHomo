# 自定义组件内容插槽（@BuilderParam）

## 症状

把组件里的 `@Builder` 方法直接传给子组件的 `@BuilderParam`，子组件里这块内容**整片空白**，但组件本身、点击、
按压反馈都正常。没有编译错误、没有运行时报错，只能靠布局树看出插槽节点下没有子节点。

## 根因

`@Builder` 方法内部的 `this` 指向**调用点所在的组件**，不是声明它的组件。跨组件传递后，子组件调用该 builder
时 `this` 已经是子组件，父组件的 `@Param` / `@Local` 全部读成 `undefined`，于是渲染出空内容。

同时，`@Builder` 跨组件传递会让构建出的子组件在组件树上的父子关系与状态管理的父子关系不一致。

## 正确写法

用 `@LocalBuilder` 声明，传方法引用：

```ets
@ComponentV2
struct IconToggleButton {
  @LocalBuilder
  private iconContent() {
    SymbolGlyph(this.symbol) // this 永远指向 IconToggleButton
  }

  build() {
    DsButton({ contentBuilder: this.iconContent })
  }
}
```

`@LocalBuilder` 从 API 12 开始支持，`this` 始终指向声明它的组件，且组件树父子关系与状态管理一致。官方文档：
`@LocalBuilder装饰器：维持组件关系`。

## 替代写法

```ets
DsButton({
  contentBuilder: () => {
    this.iconContent()
  },
})
```

箭头函数捕获声明处的 `this`，也能修正取值问题，官方文档同样列为可用写法；但它只修正 `this`，不改变组件树归属。
只有在不能改装饰器（例如 builder 由外部提供）时才用。

## 反例

```ets
@Builder
private iconContent() {
  SymbolGlyph(this.symbol) // this 指向 DsButton，this.symbol 为 undefined
}

DsButton({ contentBuilder: this.iconContent }) // 插槽空白
```

## 约束

- `@LocalBuilder` 只能在所属组件内声明：不能全局声明、不能修饰静态函数、不能与其他装饰器叠加。
- 传递方式优先传函数本身，其次 `() => { 函数调用 }`，不要传函数执行结果。
- `@BuilderParam` 内容需要随状态刷新时，参数用「单参数 + 对象字面量」按引用传递；多参数不刷新。
- 插槽内容不要用箭头函数直接构造自定义组件，运行时会报 `class constructor cannot called without 'new'`。
