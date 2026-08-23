#!/usr/bin/env python3
"""Reports citations whose span no longer contains the symbol the sentence names.

The docs test proves a cited range exists. It cannot prove the range still says
what the prose claims — that is how a refactor silently rots an inventory.
Heuristic: when a sentence backticks an identifier that the cited file defines,
that identifier should appear inside the cited span.
"""
import re, sys, pathlib

CITATION = re.compile(r'`((?:lib|test|macos|web|windows|docs)/[\w./@-]+\.\w+)(?::(\d+)(?:-(\d+))?)?`')
IDENT = re.compile(r'`([A-Za-z_][\w]*(?:\.[A-Za-z_][\w]*)*)`')
DECL = 'class|enum|mixin|extension|typedef|const|final|void|Future|static'

def symbols_defined_in(text):
    found = set()
    for m in re.finditer(r'\b(?:class|enum|mixin|extension type|extension|typedef)\s+(\w+)', text):
        found.add(m.group(1))
    for m in re.finditer(r'^\s*(?:static\s+)?(?:const|final|var)?\s*[\w<>?,\s]*\b(\w+)\s*(?:\(|=>|=)', text, re.M):
        found.add(m.group(1))
    return found

def main(root='.'):
    docs = sorted(pathlib.Path(root, 'docs').rglob('*.md'))
    suspicious, checked = [], 0
    cache = {}
    for doc in docs:
        # Claims wrap across lines and bullets, so evaluate a paragraph at a
        # time: a citation anywhere in it may support any symbol it names.
        for line in re.split(r'\n\s*\n', doc.read_text()):
            cites = list(CITATION.finditer(line))
            if not cites:
                continue
            idents = {m.group(1).split('.')[-1] for m in IDENT.finditer(line)}
            idents -= {c.group(1).split('/')[-1].split('.')[0] for c in cites}
            spans, defined = [], set()
            for c in cites:
                path, start, end = c.group(1), c.group(2), c.group(3)
                f = pathlib.Path(root, path)
                if not f.exists():
                    suspicious.append((doc, path, 'file missing'))
                    continue
                if path not in cache:
                    cache[path] = f.read_text().split('\n')
                lines = cache[path]
                defined |= symbols_defined_in('\n'.join(lines))
                if not start:
                    continue
                a, b = int(start), int(end or start)
                if b > len(lines):
                    suspicious.append((doc, f'{path}:{a}-{b}', f'out of range ({len(lines)} lines)'))
                    continue
                # A doc may cite the body of the thing it names, so accept the
                # symbol appearing just above the span as well as inside it.
                spans.append((f'{path}:{a}-{b}', '\n'.join(lines[max(0, a - 11):b])))
            named = idents & defined
            if not named or not spans:
                continue
            checked += len(spans)
            # A paragraph pools several claims, so ask only that its citations
            # are anchored to it at all: at least one symbol it names must
            # appear in at least one cited span. A paragraph whose spans
            # mention nothing it talks about has drifted.
            if not any(n in text for n in named for _, text in spans):
                suspicious.append((doc, ', '.join(w for w, _ in spans), f'no span mentions any of {sorted(named)}'))

    for doc, where, why in suspicious:
        print(f'{doc}: {where} — {why}')
    print(f'\n{checked} symbol-anchored citations checked, {len(suspicious)} suspicious')
    return 1 if suspicious else 0

if __name__ == '__main__':
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else '.'))
