#!/usr/bin/env python3
"""Offline consistency checks, NOT an R parser or Microsoft TMDL validator."""
import argparse
import ast
import json
import re
from pathlib import Path


def lexical_check(text, name):
    """Check delimiters and string termination, ignoring R comments and strings."""
    stack, quote, escaped, comment, line = [], None, False, False, 1
    pairs = {')': '(', ']': '[', '}': '{'}
    for char in text:
        if char == '\n':
            line += 1
        if comment:
            if char == '\n':
                comment = False
            continue
        if quote:
            if escaped:
                if quote != '`' and char not in 'abfnrtv\\\"\'01234567xuU\n':
                    raise ValueError(f'{name}:{line}: invalid R string escape before {char!r}')
                escaped = False
            elif char == '\\':
                escaped = True
            elif char == quote:
                quote = None
            continue
        if char == '#':
            comment = True
        elif char in "'\"`":
            quote = char
        elif char in '([{':
            stack.append((char, line))
        elif char in ')]}':
            if not stack or stack[-1][0] != pairs[char]:
                raise ValueError(f'{name}:{line}: mismatched {char}, stack={stack[-3:]}')
            stack.pop()
    if quote or stack:
        raise ValueError(f'{name}: unterminated string/delimiter: {quote}, {stack[-3:]}')


def stripped_code(text):
    return re.sub(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|#[^\n]*', ' ', text)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    version = re.search(r'^Version:\s*(\S+)', (root / 'DESCRIPTION').read_text(), re.M).group(1)
    errors, checked = [], {}
    def check(label, func):
        try:
            checked[label] = func()
        except Exception as exc:
            errors.append(f'{label}: {exc}')
    namespace = (root / 'NAMESPACE').read_text()
    exports = re.findall(r'^export\((pbi_\w+)\)', namespace, re.M)
    sources = list((root / 'R').glob('*.R'))
    tests = list((root / 'tests').rglob('*.R'))
    examples = list((root / 'inst/examples').glob('*.R'))
    tools_r = list((root / 'tools').glob('*.R'))
    def source_check():
        paths = sources + tests + examples + tools_r
        for path in paths:
            lexical_check(path.read_text(), str(path.relative_to(root)))
        return {'files': len(paths), 'method': 'lexical delimiters/string termination only, not R parse or execution'}
    check('R_lexical_checks', source_check)
    def exports_check():
        defs = re.findall(r'^(pbi_\w+)\s*<-\s*function\s*\(', '\n'.join(p.read_text() for p in sources), re.M)
        assert sorted(defs) == sorted(exports), (sorted(set(exports)-set(defs)), sorted(set(defs)-set(exports)))
        assert 'export("%>%")' in namespace and 'importFrom(magrittr,"%>%")' in namespace
        return {'package_functions': len(exports), 'reexported_pipe': 1, 'total': len(exports)+1}
    check('exports', exports_check)
    def doc_check():
        counts = {}
        for name in ['README.md', 'REFERENCE.md', 'pbiweave-for-shiny-developers.md', 'MIGRATION.md']:
            path = root / name
            if not path.is_file():
                path = root / 'inst' / 'doc' / name
            text = path.read_text()
            blocks = re.findall(r'```r\n(.*?)```', text, re.S)
            for i, block in enumerate(blocks):
                lexical_check(block, f'{name} block {i+1}')
            counts[name] = len(blocks)
        readme = (root/'README.md').read_text()
        code = stripped_code('\n'.join(re.findall(r'```r\n(.*?)```', readme, re.S)))
        missing = [f for f in exports if not re.search(r'\b'+f+r'\s*\(', code)]
        assert not missing, missing
        assert '%>%' in code
        assert 'HOME ➜ REFRESH' in readme[:1500].upper()
        assert len(re.findall(r'^### [0-9]+\. ', readme.split('## Sixteen pedagogical examples', 1)[1].split('## R-first metadata', 1)[0], re.M)) == 16
        return {'R_blocks': counts, 'exports_demonstrated': len(exports)+1, 'cookbook_recipes': 16, 'complete_tutorials': 2}
    check('documentation', doc_check)
    def help_check():
        for name in exports:
            text = (root/'man'/f'{name}.Rd').read_text()
            for section in ['name', 'alias', 'title', 'description', 'usage', 'details', 'value', 'examples'] + ([] if name == 'pbi_demo_data' else ['arguments']):
                assert '\\'+section+'{' in text, (name, section)
            code = text.split('\\examples{', 1)[1].rsplit('}', 1)[0].replace('\\%', '%')
            lexical_check(code, f'{name}.Rd examples')
            assert name+'(' in code, (name, 'does not demonstrate itself')
        assert (root/'man/pipe.Rd').exists() and (root/'man/pbiweave-package.Rd').exists()
        return {'function_topics': len(exports)+1, 'package_overview': 1}
    check('help', help_check)
    def python_check():
        paths = list((root/'tools').glob('*.py'))
        for path in paths:
            ast.parse(path.read_text(), filename=str(path))
        return len(paths)
    check('Python_tools_parse', python_check)
    def text_check():
        paths = [p for p in root.rglob('*') if p.is_file() and p.suffix in {'.R', '.Rd', '.md', '.py', '.ps1', '.yaml', '.json'}
                 and 'artifacts' not in p.parts and 'legacy-0.1.0' not in p.parts and 'legacy-tests' not in p.parts and 'schemas' not in p.parts]
        for path in paths:
            text = path.read_text(encoding='utf-8')
            assert '\u2014' not in text, str(path)
            assert ('?utm_' + 'source=chatgpt.com') not in text and ('&utm_' + 'source=chatgpt.com') not in text, str(path)
        return len(paths)
    check('text_hygiene', text_check)
    testtext = '\n'.join(p.read_text() for p in tests)
    checked['regression_tests_provided_not_executed'] = {
        'test_that_cases': len(re.findall(r'\btest_that\s*\(', testtext)),
        'expectation_call_sites': len(re.findall(r'\bexpect_\w+\s*\(', testtext)),
        'R_runtime_executed': False}
    report = {'package': 'pbiweave', 'version': version, 'checks': checked, 'errors': errors,
              'passed': not errors, 'R_runtime_executed': False, 'Microsoft_TOM_executed': False, 'Power_BI_Desktop_executed': False}
    output = json.dumps(report, indent=2)
    print(output)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(output+'\n')
    return int(bool(errors))


if __name__ == '__main__':
    raise SystemExit(main())
