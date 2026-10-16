#!/usr/bin/env node
import { runCli } from '@deepwhale-cn/dsh-guard-core/cli';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
runCli({ pkgRoot: join(dirname(fileURLToPath(import.meta.url)), '..'), meta: { name: '深鲸守护 · 可疑指令识别' } });
