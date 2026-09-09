# ohos-riscv64-sdk — OpenHarmony 6.1 (API 23) riscv64 设备端 HAP 开发 SDK

SpacemiT K3 pico（OpenHarmony 6.1 · API 23 · riscv64 · musl）**设备本机构建 HAP**
所需的 SDK 组件包，开箱即用：原始组件 + 全部调参/补丁/工具二进制均已就位，
解压即可配合 [ondevice-hap-dev](https://github.com/shihuan1999/ondevice-hap-dev)
工具链完成 ArkTS/NAPI 的 编译→打包→签名→安装 全流程。

## 包内容（oh-sdk-23-riscv64-6.1.0.32.tar.gz，109896037 字节）

```
oh-sdk/23/
├── ets/           ArkTS 组件（oh-uni-package 已调参 23/6.1.0.32；
│                  module_mode.js 为 useNormalizedOHMUrl 补丁版；
│                  es2abc 为 sh wrapper（剥 oh6.1 es2panda 不支持的参数），
│                  同目录 es2abc.real = riscv64 本机版）
├── js/            JS 组件（占位清单 + es2abc wrapper/real）
├── toolchains/    调参清单 + es2abc.real / syscap_tool / restool（riscv64 真身）
├── native/        占位清单（NAPI 编译用 ondevice-hap-dev 的 llvm 工具链）
└── previewer/     占位清单（设备端无预览器）
```

SHA256（v2）：`684685eb2c816ac12bdefb8cbed6d06ac97217aac8fde525766c4fa1da2bcc7b`
（110269758 字节；Release 资产按 16M 分卷发布 part0..part6，
`install.sh` 自动下载合并，`cat part-* > tar.gz` 亦可手工复原）

## 调参说明（为什么和官方分发不一样）

- 来源：PC 侧 HarmonyOS 6.1.1（API 24）SDK 的 openharmony ets/toolchains 组件。
  PC 版 hvigor 编不出 API 23 目标产物，才把 SDK 搬上设备（全原生开发路线）。
- 每个组件的 `oh-uni-package.json` 必须为 `apiVersion=23 / version=6.1.0.32`：
  hvigor sdkmanager 按 `<sdkRoot>/<apiVersion>/<component>` 计算期望路径，
  不一致会报 **00308018 "The SDK management mode has changed"**。
- js/native/previewer 组件用占位清单满足组件探测；native 编译由
  ondevice-hap-dev 的 llvm（clang++ + libace_napi.z.so）承担。

## 使用（设备端一条命令）

```sh
# 前置：网络就绪（默认路由 + DNS），配合 ondevice-hap-dev 已部署
sh install.sh            # 从本仓 Release 拉取 → 校验 → 解压到 /data/hap-dev/sdk/oh-sdk/23
# 验证：. /data/hap-dev/env.sh && hapdev run
```

离线场景：PC 下载 Release 资产后 `hdc file send` 推到 /data/stage/ 再执行
`sh install.sh`（检测到本地已存在时跳过下载）。

重启后（路由/DNS/vscode-server 丢失）：`sh /data/dev-env/start.sh` 一键恢复
（脚本也收录于本仓 start-dev-env.sh）。

## v2（2026-09-09）：系统应用编译支持

在 v1 基础上叠加三项（oh6.1 源码树实测 Settings 系统应用全量编译通过后固化）：

1. **全系统 API d.ts**（ets/api 叠加 obj/interface/api 的 507 个顶层声明）——
   公开发行 SDK 缺系统 API 类型（@ohos.systemparameter、accessibility.config、
   vpn/wifiManager/bluetooth 系统成员等），系统应用 ArkTS 编译报 174 错；叠加后归零。
2. **toolchains/syscapcheck/sysCapSchema.json**——系统应用触发 PreCheckSyscap，
   公开组件缺该数据文件（报 00308018 ENOENT）。
3. **module_mode.js 换回未打补丁原版**——hapdev 2026-08-22 的补丁版在多模块工程
   （settings 6 模块）CompileArkTS 期崩溃（pkgContextInfo undefined reading 'phone'）；
   原版下单模块 NAPI demo 回归全绿，补丁实为冗余。

另：多模块工程 hvigor 会从 worker 线程直接 spawn java，主线程映射补丁覆盖不到，
需在 PATH 放 java shim（见 ondevice-hap-dev 仓 bin/java）。

实测（K3 pico，2026-09-09）：Settings（modelVersion 5.0.1 / 6 模块 / bundle
com.ohos.settings）设备端 BUILD SUCCESSFUL → phone-default-unsigned.hap 5.0M；
hapdev 测试证书签名成功，覆盖安装报 9568332（系统应用须与镜像同源平台签名，属预期）。

## 已知坑（本包已处理）

| 坑 | 状态 |
|---|---|
| SDK 被 x86 二进制污染（restool/es2abc e_machine≠0xf3） | 本包二进制均为 riscv64 实测版 |
| es2abc 不认 `--enable-annotations` 等参数 | wrapper 已剥参转发 |
| hvigor 期望 apiVersion 目录 ≠ 组件清单 | 全组件已调参 23/6.1.0.32 |
| SyscapTransform 需要 toolchains/syscap_tool | 已内置 riscv64 真身 |
| restool 调用 | 已内置 toolchains/restool |

## 关联仓库

- [ondevice-hap-dev](https://github.com/shihuan1999/ondevice-hap-dev) — hapdev
  一键工具链（node/hvigor/ohpm/签名/hapdev），本 SDK 的宿主环境
- [vscode-ohos-port](https://github.com/shihuan1999/vscode-ohos-port) — 设备端
  vscode-server + ohos-dev 扩展（编辑器内一键 hapdev run）
- [deveco-ohos-port](https://github.com/shihuan1999/deveco-ohos-port) — DevEco
  Code 设备端部署（AI 辅助编码）

> 2026-09-08 在 K3 pico（hdc 147258369）实测：本包 + ondevice-hap-dev 重建后
> `hapdev run`（编译→签名→安装→启动→NAPI dlopen）全绿。
