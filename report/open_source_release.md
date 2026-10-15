# GitHub 提交操作

目标：https://github.com/19203875374/airborne-telemetry ，沿用 MIT 和原署名。此文件描述方法，不声称已推送远端。

## 网页上传

1. 解压后进入最内层 airborne-telemetry，应直接看到 README.md、LICENSE 和各目录。
2. 打开仓库，Add file → Upload files，拖入内层目录中的文件与子目录；不要只上传 ZIP，也不要额外套一层项目目录。
3. 包括 .gitignore 和 .gitattributes；若浏览器没有选到，分别用 Add file → Create new file 创建同名文件并粘贴正文。
4. 检查路径，填写 `Add telemetry sources, reproducibility guide and reusable skills` 后提交。遇文件数限制可按目录分批；所有单文件均小于 25 MiB。
5. 核对首页目录、MIT、复现及 Skill 链接。用 Code → Download ZIP 在新目录重跑离线步骤，提交作品时附仓库链接及真实提交哈希，不用本地提交号冒充远端版本。

## Git 客户端

克隆目标仓库后复制交付内容，保留 .git。查看 git status，再 git add .、git commit、git push origin main。有远端更新时先合并，不强推。登录在自己的 GitHub 页面或官方客户端完成，不发送密码、验证码或令牌。

## 维护者待补项

硬件资料见 board/hardware_handoff.md。完整竞赛设计报告与演示视频若尚未入库，应后续新增并更新索引。外部依赖许可见 third_party.md；未执行的构建、MATLAB 或硬件测试不写成通过。
