#!/bin/bash
# 双向验证：正例必须报，反例必须 0 命中（误报是安全工具的头号杀手）
#
# 另外几道自检：
#   · 样本里的不可见字符必须是真字节（不是占位符）
#   · 反例里确实有「引述」边界样本 —— 0 命中是因为区分得住
#   · 每条规则都要有可查证的 source
#   · 扫描范围限定在文本类扩展名（本插件不扫代码）
#   · 规则标题只描述文本特征，不对被扫对象下结论
set -uo pipefail
export PATH="/usr/local/bin:$PATH"
cd "$(dirname "$0")/.."
PASS=0; FAIL=0
ok(){ echo "  ✅ $1"; PASS=$((PASS+1)); }
bad(){ echo "  ❌ $1"; FAIL=$((FAIL+1)); }
RULES="PHISH-INSTR-OVERRIDE PHISH-AUTHORITY-URGENCY PHISH-HIDDEN-INWORD PHISH-HIDDEN-STRAY PHISH-HIDDEN-BOM PHISH-HIDDEN-HTML-INLINE PHISH-HIDDEN-HTML-BLOCK PHISH-EXFIL-DIRECTIVE PHISH-ROLE-MARKER"

echo ""; echo "  @deepwhale-cn/dsh-phishing-guard · 双向验证"
echo "  ────────────────────────────────────────────────"

echo ""; echo "  【正例】像真实知识库、中间夹着给 agent 的命令 —— 9 条规则都要报出来"
J=$(node bin/cli.mjs --root tests/fixtures/fail/demo-project --json 2>&1)
for rid in $RULES; do
  c=$(echo "$J" | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    print(len([f for f in d.get('findings',[]) if f.get('ruleId')=='$rid']))
except Exception: print(0)" 2>/dev/null)
  [ "${c:-0}" -gt 0 ] && ok "$rid 报出（$c 处）" || bad "$rid 未报出 —— 死规则"
done

echo ""; echo "  【反例】正常文档必须 0 命中（引述、system: production、隐藏的导航菜单都在里面）"
M=$(node bin/cli.mjs --root tests/fixtures/pass/clean-project --quiet 2>&1 | grep -oE '^[0-9]+' | head -1)
[ "${M:-1}" = "0" ] && ok "干净样本 0 命中" || bad "误报 ${M} 条"

echo ""; echo "  【样本真实性】不可见字符必须是真写进去的字节，不是占位符"
python3 - <<'PY' && ok "U+200B / U+FEFF 在正例里是真实字符" || bad "样本里的不可见字符不是真实字符"
import sys
faq = open('tests/fixtures/fail/demo-project/kb/faq.md', encoding='utf-8').read()
doc = open('tests/fixtures/fail/demo-project/docs/员工手册.md', encoding='utf-8').read()
if '\u200b' not in faq: print('faq.md 里没有 U+200B', file=sys.stderr); sys.exit(1)
if '\ufeff' not in faq: print('faq.md 里没有 U+FEFF', file=sys.stderr); sys.exit(1)
if '\u200b' not in doc: print('员工手册.md 里没有 U+200B', file=sys.stderr); sys.exit(1)
if '忽\u200b略' not in faq: print('faq.md 里的关键词没被拆开', file=sys.stderr); sys.exit(1)
PY

echo ""; echo "  【边界真实性】反例里确实有引述 —— 0 命中是因为区分得住，不是因为样本里没有"
python3 - <<'PY' && ok "反例含「忽略之前的指令」等引述且未误报" || bad "反例缺少引述边界样本（0 命中无说服力）"
import sys
t = open('tests/fixtures/pass/clean-project/README.md', encoding='utf-8').read()
for s in ('忽略之前的指令', 'ignore previous instructions', 'forget your rules'):
    if s not in t: print('缺少引述样本:', s, file=sys.stderr); sys.exit(1)
PY

echo ""; echo "  【溯源】每条规则必须带 source，且指得到公开文档/标准"
python3 - <<'PY' && ok "全部规则均有可查证的 source" || bad "有规则缺 source 或出处不可查"
import json, glob, sys
KEYS = ('OWASP', 'NIST', 'MITRE', 'ATLAS', 'Unicode', '标准', '文档', '规范', '指南')
for f in sorted(glob.glob('rules/*.json')):
    r = json.load(open(f, encoding='utf-8'))
    s = r.get('source', '')
    if not s:
        print('缺 source:', r.get('id'), file=sys.stderr); sys.exit(1)
    if not any(k in s for k in KEYS):
        print('出处不可查:', r.get('id'), file=sys.stderr); sys.exit(1)
PY

echo ""; echo "  【扫描范围】只扫文本类文件，不扫代码"
python3 - <<'PY' && ok "所有规则的 exts 都限定在文本类文件内" || bad "有规则会扫到代码文件"
import json, glob, sys
ALLOW = {'.md', '.txt', '.json', '.html', '.htm', '.yml', '.yaml'}
for f in sorted(glob.glob('rules/*.json')):
    r = json.load(open(f, encoding='utf-8'))
    exts = set(r.get('check', {}).get('exts') or [])
    if not exts:
        print('未限制 exts:', r.get('id'), file=sys.stderr); sys.exit(1)
    extra = exts - ALLOW
    if extra:
        print('扫到了非文本扩展名:', r.get('id'), extra, file=sys.stderr); sys.exit(1)
PY

echo ""; echo "  【措辞】规则标题只描述文本特征，不对被扫对象下结论"
BADTITLE=$(python3 - <<'PYB'
import json, glob, sys
VERDICT = ('恶意', '不安全', '危险', '病毒', '这是一条', '你这个')
for f in glob.glob('rules/*.json'):
    t = json.load(open(f, encoding='utf-8')).get('title', '')
    if any(w in t for w in VERDICT):
        print(t); sys.exit(0)
PYB
)
if [ -n "$BADTITLE" ]; then
  bad "规则标题出现定性措辞（只该描述文本特征）：$BADTITLE"
else
  ok "规则标题只描述文本特征，不下结论"
fi

echo ""; echo "  ────────────────────────────────────────────────"
echo "  通过 $PASS · 失败 $FAIL"; echo ""
[ "$FAIL" -eq 0 ] || exit 1
