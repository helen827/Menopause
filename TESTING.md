# 测试流程

项目的测试分为 Python 后端、React 原型和原生 iOS 三部分。根目录 `Makefile` 提供统一入口，GitHub Actions 在每个 PR 和 `main` 分支推送时执行相同检查。

仓库还包含 `CODEOWNERS`、PR 检查模板和 Dependabot 配置。依赖更新通过独立 PR 进入相同的测试与评审流程，不直接修改 `main`。

## 首次准备

后端：

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-dev.txt
```

后端自动化测试不连接 MySQL、阿里云或 DeepSeek；外部服务和数据库通过纯逻辑测试、假对象及 HTTP handler 测试隔离。

前端：

```bash
cd ui-prototype
npm ci
```

iOS 测试需要 Xcode 26 和可用的 iPhone 17 模拟器。

## 日常开发

改动后先运行受影响部分：

```bash
make test-backend
make test-frontend
make test-ios
```

提交 PR 前运行全部检查：

```bash
make test
```

后端可以只跑单个文件或测试：

```bash
cd backend
pytest tests/test_security.py
pytest tests/test_security.py::test_request_body_size_is_enforced
```

前端开发时可以使用监听模式：

```bash
cd ui-prototype
npm run test:watch
```

## 覆盖范围

- 后端：实体分片和序列化、安全限流与恶意输入、冥想模式和时间解析、就医清单生成、法律静态页面。
- 前端：默认趋势页、底部导航、落地页到登录页的关键路径，并执行 Vite 生产构建。
- iOS：手机号和验证码校验、输入规范化、API JSON 字段解码。
- CI：Python 编译检查、核心安全与实体服务的 pytest 覆盖率门槛、Vitest、前端生产构建、Xcode 单元测试。

## PR 合并规则建议

在 GitHub 仓库设置中保护 `main`，要求以下检查成功后才允许合并：

- `Backend tests`
- `Frontend tests and build`
- `iOS unit tests`

同时建议启用“Require a pull request before merging”和至少 1 位评审者。分支保护属于 GitHub 仓库设置，不能仅通过仓库文件启用。

单人维护阶段建议把强制审批数设为 0，但仍要求 PR、CI 和讨论全部解决；有第二位稳定协作者后，将审批数提高到 1。

推荐的 `main` 规则：

- 必须通过 PR 合并，并在新提交后撤销过期审批。
- 必须通过 `Backend tests`、`Frontend tests and build`、`iOS unit tests`。
- 合并前分支必须与 `main` 保持最新，所有讨论必须解决。
- 管理员同样遵守规则；禁止强推和删除 `main`。
- 要求线性历史，仅使用 squash merge，合并后自动删除功能分支。

## 需要人工验证的场景

以下场景依赖真实外部系统，自动化测试通过后仍需在测试环境验证：

- MySQL 建表、迁移及完整的账户删除链路。
- 阿里云短信发送和验证码登录。
- DeepSeek 对话质量、超时和失败降级。
- iPhone 真机上的音频、通知、相册权限和网络切换。
- App Store 隐私链接、用户协议和账户删除入口。

发布候选版本应完成一次冒烟测试：登录、发起 AI 对话、保存冥想、查看趋势、生成就医清单、退出或删除账户。
