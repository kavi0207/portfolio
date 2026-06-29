#!/usr/bin/env bash
# Regenerate the whole portfolio from sources (index.html, style.css, *.md, diagrams/*.mmd).
# Outputs: diagrams/*.png, *.html article pages, pdf/*.pdf, and self-contained *-standalone.html.
# Requires: npx (@mermaid-js/mermaid-cli), python3 + markdown, and the gstack make-pdf binary.
set -euo pipefail
cd "$(dirname "$0")"

ARTICLES=(threat-intel threat-event dark-owl)
PDF_BIN="${MAKE_PDF_BIN:-$HOME/.claude/skills/gstack/make-pdf/dist/pdf}"

echo "==> 1/5 Rendering Mermaid diagrams -> PNG"
mkdir -p diagrams
printf '{ "args": ["--no-sandbox"] }\n' > diagrams/puppeteer.json
for f in diagrams/*.mmd; do
  npx -y @mermaid-js/mermaid-cli -i "$f" -o "${f%.mmd}.png" -b white -s 2 -p diagrams/puppeteer.json >/dev/null
done
echo "    $(ls diagrams/*.png | wc -l | tr -d ' ') diagrams rendered"

echo "==> 2/5 Article HTML pages (hosted set)"
python3 - "${ARTICLES[@]}" <<'PY'
import markdown, pathlib, html as _html, sys
md = markdown.Markdown(extensions=['extra','tables','fenced_code','sane_lists','attr_list'])
TPL = '''<!DOCTYPE html>
<html lang="en"><head>
<meta charset="utf-8"/><meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>{title}</title><meta name="description" content="{desc}"/>
<link rel="preconnect" href="https://fonts.googleapis.com"/>
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin/>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet"/>
<link rel="stylesheet" href="style.css"/>
</head><body>
<article class="article">
<a class="back" href="index.html">&larr; Back to portfolio</a>
{body}
<hr/>
<a class="back" href="index.html">&larr; Back to portfolio</a>
&nbsp;&middot;&nbsp; <a class="back" href="pdf/{slug}.pdf">Download as PDF</a>
</article></body></html>'''
META = {
 'threat-intel': ('Scoring Every Known Vulnerability','A threat-intelligence pipeline that scores every known CVE 0-100.'),
 'threat-event': ('Turning Messy Breach Reports Into Clean Threat Intelligence','A medallion data pipeline for breach-event intelligence.'),
 'dark-owl': ('Watching the Dark Web at Scale','A dark-web monitoring pipeline with LLM role-aware triage.'),
}
for slug in sys.argv[1:]:
    title, desc = META[slug]; md.reset()
    body = md.convert(pathlib.Path(f'{slug}.md').read_text())
    pathlib.Path(f'{slug}.html').write_text(
        TPL.format(title=_html.escape(title), desc=_html.escape(desc), body=body, slug=slug))
    print(f"    {slug}.html")
PY

echo "==> 3/5 PDFs (stats block -> list, images -> base64)"
mkdir -p pdf pdf-build
python3 - "${ARTICLES[@]}" <<'PY'
import re, base64, pathlib, sys
src, build = pathlib.Path('.'), pathlib.Path('pdf-build')
def stats_to_list(text):
    # PDFs don't carry the CSS, so render the stat strip as a clean bold list.
    def repl(m):
        items = re.findall(r'<span class="num">(.*?)</span><span class="lab">(.*?)</span>', m.group(1), re.S)
        und = {'&amp;':'&','&lt;':'<','&gt;':'>'}
        def clean(s):
            for k,v in und.items(): s=s.replace(k,v)
            return s.strip()
        return "\n".join(f"- **{clean(n)}**, {clean(l)}" for n,l in items) + "\n"
    return re.sub(r'<div class="stats">\n(.*?)\n</div>', repl, text, flags=re.S)
def inline_imgs(text):
    return re.sub(r'!\[([^\]]*)\]\((diagrams/[^)]+)\)',
        lambda m: f'<img alt="{m.group(1)}" src="data:image/png;base64,'
                  f'{base64.b64encode((src/m.group(2)).read_bytes()).decode()}" '
                  f'style="max-width:100%;width:100%;height:auto;display:block;margin:1em auto;" />',
        text)
for n in sys.argv[1:]:
    t = (src/f'{n}.md').read_text()
    (build/f'{n}.md').write_text(inline_imgs(stats_to_list(t)))
PY
for n in "${ARTICLES[@]}"; do
  "$PDF_BIN" generate "pdf-build/$n.md" "pdf/$n.pdf" --no-confidential --no-chapter-breaks >/dev/null
  echo "    pdf/$n.pdf"
done

echo "==> 4/5 Standalone landing page (CSS + images inlined)"
python3 - <<'PY'
import re, base64, pathlib
css  = pathlib.Path('style.css').read_text()
html = pathlib.Path('index.html').read_text()
html = re.sub(r'<link rel="stylesheet" href="style.css" ?/>', f'<style>\n{css}\n</style>', html)
def b64(m):
    p = pathlib.Path(m.group(1))
    return f'src="data:image/png;base64,{base64.b64encode(p.read_bytes()).decode()}"' if p.exists() else m.group(0)
html = re.sub(r'src="(diagrams/[^"]+\.png)"', b64, html)
for s in ['threat-intel','threat-event','dark-owl']:
    html = html.replace(f'href="{s}.html"', f'href="{s}-standalone.html"')
pathlib.Path('portfolio-standalone.html').write_text(html)
print("    portfolio-standalone.html")
PY

echo "==> 5/5 Standalone article pages (CSS + images inlined)"
python3 - "${ARTICLES[@]}" <<'PY'
import re, base64, pathlib, sys
css = pathlib.Path('style.css').read_text()
def b64(m):
    p = pathlib.Path(m.group(1))
    return f'src="data:image/png;base64,{base64.b64encode(p.read_bytes()).decode()}"' if p.exists() else m.group(0)
for s in sys.argv[1:]:
    html = pathlib.Path(f'{s}.html').read_text()
    html = re.sub(r'<link rel="stylesheet" href="style.css" ?/>', f'<style>\n{css}\n</style>', html)
    html = re.sub(r'src="(diagrams/[^"]+\.png)"', b64, html)
    html = html.replace('href="index.html"', 'href="portfolio-standalone.html"')
    pathlib.Path(f'{s}-standalone.html').write_text(html)
    print(f"    {s}-standalone.html")
PY

rm -rf pdf-build
echo "==> Done."
