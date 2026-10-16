import { createPlugin, pkgRootFrom } from '@deepwhale-cn/dsh-guard-core/plugin';

export const { name, inject, apply } = createPlugin({
  name: 'phishing-guard',
  pkgRoot: pkgRootFrom(import.meta.url),
  skillFile: 'skill/phishing-guard.md',
  binFile: 'bin/cli.mjs',
  description: 'agent 读到的内容里，有没有人在给它下命令',
  whenToUse: '要把一批文档 / 知识库 / 提示词模板 / 网页抓取内容喂给 agent 之前，先看里面有没有人在给 agent 下命令时用。'
    + '用户会说：「这些文档能不能直接喂给 agent」「知识库被人塞了东西吗」「这份外部资料安不安全」「扫一下 prompt 文件」。',
});
