# 测试指南

## 最低验证矩阵

| 变更             | 最低验证                                                  |
| ---------------- | --------------------------------------------------------- |
| Web              | `mise //web:check`；行为变更加 `mise //web:test --run`    |
| Mobile           | `mise //mobile:analyze` 与相关 `mise //mobile:test`       |
| OpenAPI/SDK      | `mise //:sdk:build`；生成变更时运行 `mise //:open-api`    |
| Browser E2E      | `mise //e2e:ci-unit`；必要时 `mise //e2e:test`            |
| Machine Learning | `mise //machine-learning:checklist`                       |
| Docs             | `mise //docs:format`；结构/MDX 变更加 `mise //docs:build` |
| Workflow YAML    | `mise //.github:format` 并解析 YAML                       |

## Browser E2E 边界

`e2e/src/ui/` 只覆盖浏览器 UI，API 响应由 Playwright route mocks 提供。它不会启动数据库、服务器容器或 `photo-classifier`，因此不能证明真实服务器兼容性。

真实 API、鉴权、MySQL、上传、回收站、pipeline 和客户端兼容性测试属于 `../photo-classifier`。

## 选择原则

1. 先运行最窄测试。
2. contract、shared state、sync 或生成代码变更扩大到模块 checklist。
3. 只使用 `mise tasks ls --all --name-only` 中存在的任务。
4. 所有 tracked diff 最后运行 `git diff --check`。

## 常用命令

```bash
mise //web:check
mise //web:test --run
mise //e2e:ci-unit
mise //mobile:checklist
mise //machine-learning:checklist
mise //docs:format
```
