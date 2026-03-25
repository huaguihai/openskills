# Sentinel 红线清单

> 合并自 skill-vetter + 依赖安全增强

## Skill 审查红线

### 基础红线（继承自 skill-vetter）

- curl/wget 到未知 URL
- 向外部服务器发送数据
- 请求凭证/token/API key
- 读取 `~/.ssh`、`~/.aws`、`~/.config`（无明确理由）
- 访问 `MEMORY.md`、`USER.md`、`SOUL.md`、`IDENTITY.md`
- 使用 base64 decode
- 使用 `eval()`/`exec()` 处理外部输入
- 修改 workspace 外的系统文件
- 安装未声明的包
- 网络调用使用 IP 而非域名
- 混淆代码（压缩、编码、minify）
- 请求 sudo 权限
- 访问浏览器 cookie/session
- 触碰凭证文件

### 增强红线（sentinel 新增）

- 包含 `.pth` 文件
- 大段 base64/hex 编码内容（>100 字符）
- 修改 `CLAUDE.md` 或 `settings.json`（权限提升攻击）
- 注册 Claude Code Hook（可劫持其他操作）
- scripts/ 中有网络调用且目标在 known-malicious.md 中
- 引入外部依赖但未在文档中声明

## 依赖安装红线

### 元数据红线

- 版本发布 < 48 小时
- 维护者与上一版本不同
- 版本号异常跳跃（跳过多个小版本）
- 包名与知名包高度相似（typosquatting）
- 在 OSV 漏洞数据库有中/高危记录
- 在 known-malicious.md 名单中

### 代码内容红线

- `.pth` 文件含执行代码（`import`、`exec`、`eval`、`subprocess`）
- `setup.py` 覆写 `cmdclass`（install/develop/egg_info）
- `setup.py` 中有网络调用或进程创建
- `__init__.py` 顶层有网络外传调用
- `exec()`/`eval()` 执行 base64/hex 解码后的内容
- 大段 base64 编码字符串（>200 字符）
- 访问 `~/.ssh`、`~/.aws`、`~/.kube`、`~/.gnupg`
- 批量遍历 `os.environ`（>10 处引用）
- npm `postinstall`/`preinstall` 脚本含 `child_process` 或网络调用
