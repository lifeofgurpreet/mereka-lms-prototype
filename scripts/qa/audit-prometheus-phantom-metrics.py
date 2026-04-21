#!/usr/bin/env python3
"""Phantom-metric audit for Prometheus rules.

A "phantom" metric is a metric name referenced in a PrometheusRule `expr` that
does NOT exist in the live Prometheus `__name__` label-values inventory. Rules
referencing phantom metrics cannot fire — they are dead detection logic.

Origin: bead mereka-lms-33d8 (2026-04-21). Velero BSL alert referenced a
non-existent metric and silently failed for ~a week while prod DR posture
degraded. This script sweeps the entire rule set to catch the failure class.

Modes
-----
1. live-fetch (needs kubectl on PATH + cluster reachability):
     $ audit-prometheus-phantom-metrics.py --context rke2-prod
2. offline (for CI; consumes two JSON files):
     $ audit-prometheus-phantom-metrics.py \
         --rules-file rules.json --names-file metric-names.json

Outputs
-------
  --format md        Full markdown report (default, stdout)
  --format jsonl     Machine-readable per-rule record (stdout)
  --format check     Exit non-zero if any non-exempt phantom found
                     (alert rules carrying `labels.speculative: "true"` are exempted)
  --format summary   Brief counters (good for PR comment)

Exit codes
----------
  0 — no phantoms OR all phantoms are exempt
  1 — phantoms found and not exempt
  2 — usage or input error
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from collections import defaultdict
from collections.abc import Iterable

# ---- PromQL keywords/functions to filter out of metric-name extraction -----
# Anything matching identifier regex NOT in this set is treated as a metric ref.
# Case-insensitive (authors sometimes write `BY`, `WITHOUT`).
PROMQL_KEYWORDS = {
    # aggregation operators
    'sum', 'avg', 'min', 'max', 'count', 'count_values', 'stddev', 'stdvar',
    'topk', 'bottomk', 'quantile', 'group',
    # aggregation modifiers
    'by', 'without', 'on', 'ignoring', 'group_left', 'group_right',
    # set operators
    'and', 'or', 'unless', 'if', 'else',
    # rate / range-vector functions
    'rate', 'irate', 'increase', 'delta', 'idelta', 'deriv', 'predict_linear',
    'holt_winters', 'resets', 'changes',
    # aggregation over time
    'avg_over_time', 'min_over_time', 'max_over_time', 'sum_over_time',
    'count_over_time', 'quantile_over_time', 'stddev_over_time',
    'stdvar_over_time', 'last_over_time', 'present_over_time',
    'mad_over_time',
    # math
    'abs', 'absent', 'absent_over_time', 'ceil', 'exp', 'floor', 'ln',
    'log2', 'log10', 'round', 'scalar', 'sgn', 'sqrt', 'vector',
    'clamp', 'clamp_min', 'clamp_max',
    # time
    'time', 'timestamp', 'year', 'month', 'day_of_week', 'day_of_month',
    'day_of_year', 'days_in_month', 'hour', 'minute',
    # label manipulation
    'label_replace', 'label_join',
    # histogram
    'histogram_quantile', 'histogram_count', 'histogram_sum',
    'histogram_fraction', 'histogram_stddev', 'histogram_stdvar',
    'histogram_avg',
    # sort
    'sort', 'sort_desc',
    # boolean modifier
    'bool',
    # misc
    'Inf', 'NaN', 'inf', 'nan',
    # trig
    'acos', 'acosh', 'asin', 'asinh', 'atan', 'atanh', 'cos', 'cosh',
    'sin', 'sinh', 'tan', 'tanh', 'deg', 'rad', 'pi',
}
KEYWORDS_LOWER = {k.lower() for k in PROMQL_KEYWORDS}

IDENT_RE = re.compile(r'\b([a-zA-Z_][a-zA-Z0-9_:]*)\b')
COMMENT_RE = re.compile(r'#.*$', re.MULTILINE)
STR_DOUBLE_RE = re.compile(r'"(?:[^"\\]|\\.)*"')
STR_SINGLE_RE = re.compile(r"'(?:[^'\\]|\\.)*'")
STR_BACKTICK_RE = re.compile(r'`[^`]*`')
LABEL_SEL_RE = re.compile(r'\{[^{}]*\}')
RANGE_RE = re.compile(r'\[[^\]]+\]')
LABEL_LIST_RE = re.compile(
    r'\b(by|without|on|ignoring|group_left|group_right)\s*\(([^()]*)\)',
    re.IGNORECASE,
)


def sanitize_expr(expr: str) -> str:
    e = COMMENT_RE.sub('', expr)
    e = STR_DOUBLE_RE.sub('""', e)
    e = STR_SINGLE_RE.sub("''", e)
    e = STR_BACKTICK_RE.sub('``', e)
    e = LABEL_SEL_RE.sub('', e)
    # Strip label-list modifier parens BEFORE dropping ranges (both use [])
    e = LABEL_LIST_RE.sub(r'\1', e)
    e = RANGE_RE.sub('', e)
    return e


def extract_metrics(expr: str) -> set[str]:
    e = sanitize_expr(expr)
    out: set[str] = set()
    for m in IDENT_RE.finditer(e):
        tok = m.group(1)
        if tok.lower() in KEYWORDS_LOWER:
            continue
        if tok.isdigit():
            continue
        if tok in ('offset', 'true', 'false'):
            continue
        out.add(tok)
    return out


# ---- Classification helpers -----------------------------------------------
def trigrams(s: str) -> set[str]:
    s = f'##{s}##'
    return {s[i:i+3] for i in range(len(s)-2)}


def typo_candidates(p: str, pool: Iterable[str], top: int = 1) -> list[str]:
    p_tris = trigrams(p)
    scored = []
    for m in pool:
        if abs(len(m) - len(p)) > 5:
            continue
        m_tris = trigrams(m)
        if not m_tris:
            continue
        overlap = len(p_tris & m_tris) / max(len(p_tris | m_tris), 1)
        if overlap >= 0.6:
            scored.append((overlap, m))
    scored.sort(reverse=True)
    return [m for _, m in scored[:top]]


def classify(phantom: str, live: set[str], prefix_index: dict[str, set[str]]) -> tuple[str, str | None, str | None]:
    """Returns (kind, closest, family_stem)."""
    # family check
    stem = None
    family: list[str] = []
    parts = phantom.split('_')
    for i in range(min(len(parts), 5), 0, -1):
        s = '_'.join(parts[:i])
        hits = prefix_index.get(s, set()) - {phantom}
        if hits:
            stem, family = s, sorted(hits)[:3]
            break
    # typo check (scoped to family if available)
    pool = prefix_index.get(stem, live) if stem else live
    typos = typo_candidates(phantom, pool)
    if typos and typos[0] != phantom:
        return 'LIKELY_TYPO', typos[0], stem
    if family:
        return 'FAMILY_EXISTS', None, stem
    return 'NO_TRACE', None, None


# ---- Fetchers --------------------------------------------------------------
def live_fetch_rules(context: str) -> dict:
    out = subprocess.check_output([
        'kubectl', '--context', context, 'get', 'prometheusrules', '-A', '-o', 'json'
    ])
    return json.loads(out)


def live_fetch_names(context: str, prometheus_ns: str, prometheus_svc: str) -> dict:
    """Run a curl probe pod to query Prometheus /api/v1/label/__name__/values."""
    cmd = [
        'kubectl', '--context', context, 'run', '-n', prometheus_ns,
        f'phantom-audit-probe-{os.getpid()}',
        '--rm', '-i', '--restart=Never', '--image=curlimages/curl:latest', '--quiet', '--',
        'sh', '-c', f'curl -s "http://{prometheus_svc}:9090/api/v1/label/__name__/values"',
    ]
    out = subprocess.check_output(cmd)
    # `--quiet --rm` still can emit a trailing "pod ... terminated" line; peel it.
    text = out.decode('utf-8', errors='replace').strip()
    # Find the first '{' and parse from there.
    i = text.find('{')
    if i < 0:
        raise RuntimeError(f'no JSON in curl output: {text[:200]!r}')
    return json.loads(text[i:])


# ---- Main audit ------------------------------------------------------------
def audit(rules_doc: dict, names_doc: dict) -> dict:
    live = set(names_doc['data'])
    recording: set[str] = set()
    for item in rules_doc.get('items', []):
        for g in item.get('spec', {}).get('groups', []):
            for r in g.get('rules', []):
                if r.get('record'):
                    recording.add(r['record'])
    known = live | recording

    prefix_index: dict[str, set[str]] = defaultdict(set)
    for m in live:
        parts = m.split('_')
        for i in range(1, min(6, len(parts)+1)):
            prefix_index['_'.join(parts[:i])].add(m)

    entries = []
    for item in rules_doc.get('items', []):
        ns = item['metadata']['namespace']
        obj = item['metadata']['name']
        for g in item.get('spec', {}).get('groups', []):
            for r in g.get('rules', []):
                alert = r.get('alert') or r.get('record') or '(unnamed)'
                expr = r.get('expr', '')
                labels = r.get('labels', {})
                metrics = extract_metrics(expr)
                phantoms = [m for m in metrics if m not in known]
                if not phantoms:
                    continue
                classified = []
                for p in phantoms:
                    kind, closest, fam = classify(p, live, prefix_index)
                    classified.append({
                        'name': p, 'kind': kind,
                        'closest': closest, 'family_stem': fam,
                    })
                entries.append({
                    'namespace': ns, 'rule_object': obj,
                    'group': g.get('name', ''),
                    'alert': alert, 'severity': labels.get('severity', ''),
                    'team': labels.get('team', ''),
                    'speculative': str(labels.get('speculative', '')).lower() == 'true',
                    'expr': expr.strip(),
                    'phantoms': classified,
                })
    return {
        'rules_total': sum(
            1 for item in rules_doc.get('items', [])
            for g in item.get('spec', {}).get('groups', [])
            for _ in g.get('rules', [])
        ),
        'live_metrics': len(live),
        'recording_rules': len(recording),
        'phantom_entries': entries,
    }


# ---- Output formatters -----------------------------------------------------
def fmt_summary(a: dict) -> str:
    entries = a['phantom_entries']
    speculative = sum(1 for e in entries if e['speculative'])
    non_exempt = len(entries) - speculative
    kinds = defaultdict(int)
    for e in entries:
        for p in e['phantoms']:
            kinds[p['kind']] += 1
    ns_counts = defaultdict(int)
    for e in entries:
        ns_counts[e['namespace']] += 1
    out = []
    out.append(f"rules={a['rules_total']} live_metrics={a['live_metrics']} recording={a['recording_rules']}")
    out.append(f"phantom_rule_entries={len(entries)} speculative={speculative} non_exempt={non_exempt}")
    out.append(f"phantom_refs_by_kind={dict(kinds)}")
    out.append("by_namespace=" + ", ".join(f"{k}:{v}" for k, v in sorted(ns_counts.items(), key=lambda x: -x[1])))
    return "\n".join(out)


def fmt_jsonl(a: dict) -> str:
    return "\n".join(json.dumps(e, sort_keys=True) for e in a['phantom_entries'])


def fmt_md(a: dict) -> str:
    out = []
    out.append('# Phantom-Metric Audit')
    out.append('')
    out.append(fmt_summary(a))
    out.append('')
    by_obj = defaultdict(list)
    for e in a['phantom_entries']:
        by_obj[f"{e['namespace']}/{e['rule_object']}"].append(e)
    for obj in sorted(by_obj):
        out.append(f'## `{obj}` ({len(by_obj[obj])})')
        out.append('')
        for e in by_obj[obj]:
            spec = ' (speculative)' if e['speculative'] else ''
            out.append(f"- **{e['alert']}**{spec} severity={e['severity'] or '—'}")
            for p in e['phantoms']:
                hint = f" → try `{p['closest']}`" if p['closest'] else ''
                out.append(f"    - phantom `{p['name']}` `{p['kind']}`{hint}")
        out.append('')
    return "\n".join(out)


def fmt_check(a: dict) -> tuple[str, int]:
    """Exit non-zero if non-exempt phantoms exist."""
    non_exempt = [e for e in a['phantom_entries'] if not e['speculative']]
    if not non_exempt:
        return (f"OK — {len(a['phantom_entries'])} phantom entries (all labeled speculative=true)\n", 0)
    lines = [f"FAIL — {len(non_exempt)} non-exempt phantom rule entries:"]
    for e in non_exempt[:20]:
        names = ','.join(p['name'] for p in e['phantoms'])
        lines.append(f"  [{e['namespace']}/{e['rule_object']}] {e['alert']} phantoms=({names})")
    if len(non_exempt) > 20:
        lines.append(f"  ... and {len(non_exempt)-20} more")
    lines.append('')
    lines.append('Mark intentionally-speculative alerts with `labels.speculative: "true"`.')
    return ("\n".join(lines) + "\n", 1)


# ---- CLI -------------------------------------------------------------------
def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    src = ap.add_argument_group('input source')
    src.add_argument('--context', help='kubectl context (live fetch mode)')
    src.add_argument('--prometheus-ns', default='monitoring',
                     help='namespace of Prometheus (default: monitoring)')
    src.add_argument('--prometheus-svc', default='monitoring-kube-prometheus-prometheus',
                     help='Prometheus Service name (default: monitoring-kube-prometheus-prometheus)')
    src.add_argument('--rules-file', help='PrometheusRules JSON (offline)')
    src.add_argument('--names-file', help='Metric __name__ values JSON (offline)')
    ap.add_argument('--format', choices=['md', 'jsonl', 'summary', 'check'],
                    default='md', help='Output format (default: md)')
    args = ap.parse_args(argv)

    if args.rules_file and args.names_file:
        rules_doc = json.load(open(args.rules_file))
        names_doc = json.load(open(args.names_file))
    elif args.context:
        if not shutil.which('kubectl'):
            print('kubectl not on PATH', file=sys.stderr)
            return 2
        rules_doc = live_fetch_rules(args.context)
        names_doc = live_fetch_names(args.context, args.prometheus_ns, args.prometheus_svc)
    else:
        ap.error('must pass --context OR both --rules-file and --names-file')

    a = audit(rules_doc, names_doc)
    if args.format == 'md':
        print(fmt_md(a))
        return 0
    if args.format == 'jsonl':
        print(fmt_jsonl(a))
        return 0
    if args.format == 'summary':
        print(fmt_summary(a))
        return 0
    if args.format == 'check':
        text, code = fmt_check(a)
        print(text, end='')
        return code
    return 2


if __name__ == '__main__':
    sys.exit(main())
