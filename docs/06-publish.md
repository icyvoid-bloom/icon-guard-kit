# 发布到 GitHub

本仓库只有文本与脚本，总体积不到 3 MB，不需要 Git 也能发布。下面两条路线选一条即可。

---

## 0. 发布前自检

| 项 | 要求 |
|---|---|
| 文件 | 只有 `.md` / `.txt` / `.ps1` / `.py` / `.json` / `.bat` / `.gitignore` / `LICENSE` |
| 图片 | **0 张**（`.ico`、`.png`、截图、参考图一律不入库） |
| 提示词 | `prompts/` 是纯文本，可入库；**生成出来的图不要放进来** |
| 隐私 | 文档里不出现本机用户名、`D:\` 私有路径、公司/学校内网地址 |
| 有效路径 | 示例配置里用 `%USERPROFILE%`、`%PUBLIC%` 这类环境变量，不写死盘符 |

`.gitignore` 已把 `*.ico`、`*.png`、`*.jpg`、`*.log`、`backup/` 排除，误放进去也不会被提交。

---

## 路线 A：网页上传（推荐，不装任何软件）

1. 登录 GitHub，右上角 **+ → New repository**。
2. 填写：
   - **Repository name**：`icon-guard-kit`
   - **Description**：`Windows 桌面快捷方式自定义图标 + 图标守卫（防止软件更新重写 .lnk 后图标丢失）`
   - 可见性选 **Public**
   - **不要**勾选 “Add a README file”“Add .gitignore”“Choose a license”——本地已有，避免冲突
3. 创建后进入空仓库页，点 **uploading an existing file**。
4. 把本地 `icon-guard-kit` 目录里的**文件和文件夹**拖进去（保持目录结构：`README.md`、`LICENSE`、`.gitignore`、`docs/`、`tools/`）。浏览器一次最多 100 个文件，本仓库远低于此限。
5. 底部 Commit changes 填 `init: icon guard kit`，提交。
6. 回到仓库首页，确认：
   - README 能正常渲染，`docs/` 里 6 篇文档链接可点；
   - 文件列表里**没有**任何 `.png` / `.ico`；
   - `LICENSE` 被识别（页面右侧显示 MIT）。
7. 可选：**About → 齿轮** 填 Description，Topics 加 `windows`、`powershell`、`desktop`、`icons`、`shortcut`。

> 网页上传无法保留 `.gitignore` 的空目录，`tools/examples/` 若为空会消失，属正常。

---

## 路线 B：装 Git 后用命令行

1. 安装 Git for Windows（<https://git-scm.com/download/win>），安装时保持默认即可。
2. 在仓库目录执行：

```powershell
cd <本地 icon-guard-kit 目录>
git init
git add .
git commit -m "init: icon guard kit"
git branch -M main
git remote add origin https://github.com/<你的用户名>/icon-guard-kit.git
git push -u origin main
```

3. 首次 push 会弹出浏览器登录 GitHub，授权后即完成。

后续改动：

```powershell
git add .
git commit -m "docs: 更新取景参数说明"
git push
```

---

## 发布后维护

- **只改文档/脚本**：网页端直接编辑单文件即可，或路线 B 的 `git add/commit/push`。
- **收到 Issue**：优先让提问者附上 `icon_guard.log` 片段与 `.lnk` 的 `TargetPath / Arguments / WorkingDirectory`，不要收截图以外的原始素材。
- **不接受**：图标成品、角色图、软件安装包、破解资源类 PR。

---

## 常见问题

**Q：上传后中文变乱码？**
GitHub 按 UTF-8 渲染，本地文件应以 UTF-8 保存；`.ps1` 若要在 Windows PowerShell 5.1 下运行，需要 UTF-8 **with BOM**，这与网页显示无关。

**Q：能放示例图标吗？**
不放。示例请使用者自己用 `build_ico.py` 生成，仓库只保留代码与说明。

**Q：仓库名能不能换？**
可以，但 `README` 标题与克隆命令里的名字要一起改；`icon-guard-kit` 足够表意，建议保留。
