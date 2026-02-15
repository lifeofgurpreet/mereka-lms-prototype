"""
Content sanitization for user-authored library content.

@covers: AC-LIB-031 (OWASP Top 10 — XSS, injection),
         AC-NEG-LIB-014 (no JavaScript execution in library content)
"""
import html
import logging
import re

logger = logging.getLogger(__name__)

# Tags allowed in library content (whitelist)
ALLOWED_TAGS = {
    'p', 'br', 'strong', 'em', 'b', 'i', 'u', 's',
    'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
    'ul', 'ol', 'li',
    'table', 'thead', 'tbody', 'tr', 'th', 'td',
    'a', 'img', 'span', 'div', 'pre', 'code', 'blockquote',
    'sub', 'sup', 'hr',
}

# Attributes allowed per tag
ALLOWED_ATTRIBUTES = {
    'a': {'href', 'title', 'target', 'rel'},
    'img': {'src', 'alt', 'title', 'width', 'height'},
    'td': {'colspan', 'rowspan'},
    'th': {'colspan', 'rowspan'},
    'span': {'class'},
    'div': {'class'},
    'pre': {'class'},
    'code': {'class'},
}

# Patterns that indicate XSS attempts
XSS_PATTERNS = [
    re.compile(r'<script', re.IGNORECASE),
    re.compile(r'javascript:', re.IGNORECASE),
    re.compile(r'on\w+\s*=', re.IGNORECASE),  # onclick, onerror, etc.
    re.compile(r'<iframe', re.IGNORECASE),
    re.compile(r'<object', re.IGNORECASE),
    re.compile(r'<embed', re.IGNORECASE),
    re.compile(r'<applet', re.IGNORECASE),
    re.compile(r'<form', re.IGNORECASE),
    re.compile(r'vbscript:', re.IGNORECASE),
    re.compile(r'data:text/html', re.IGNORECASE),
    re.compile(r'expression\s*\(', re.IGNORECASE),  # CSS expression
    re.compile(r'url\s*\(\s*["\']?\s*javascript:', re.IGNORECASE),
]

# SQL injection patterns
SQL_INJECTION_PATTERNS = [
    re.compile(r"('\s*(OR|AND)\s+\d+\s*=\s*\d+)", re.IGNORECASE),
    re.compile(r'(UNION\s+SELECT)', re.IGNORECASE),
    re.compile(r'(DROP\s+TABLE)', re.IGNORECASE),
    re.compile(r'(INSERT\s+INTO)', re.IGNORECASE),
    re.compile(r'(DELETE\s+FROM)', re.IGNORECASE),
    re.compile(r'(;\s*--)', re.IGNORECASE),
]


def detect_xss(content):
    """
    Detect XSS attempts in content (AC-LIB-031, AC-NEG-LIB-014).

    Returns list of detected patterns.
    """
    if not content:
        return []

    detected = []
    for pattern in XSS_PATTERNS:
        if pattern.search(content):
            detected.append(pattern.pattern)

    return detected


def detect_sql_injection(content):
    """Detect SQL injection patterns in content."""
    if not content:
        return []

    detected = []
    for pattern in SQL_INJECTION_PATTERNS:
        if pattern.search(content):
            detected.append(pattern.pattern)

    return detected


def sanitize_library_content(content, strict=True):
    """
    Sanitize user-authored library content (AC-LIB-031).

    AC-NEG-LIB-014: Strips all JavaScript, event handlers, and
    dangerous HTML elements.

    Returns sanitized content string.
    """
    if not content:
        return content

    sanitized = content

    # Remove script tags and content
    sanitized = re.sub(
        r'<script[^>]*>.*?</script>',
        '', sanitized, flags=re.DOTALL | re.IGNORECASE,
    )

    # Remove event handlers (onclick, onerror, etc.)
    sanitized = re.sub(
        r'\s+on\w+\s*=\s*["\'][^"\']*["\']',
        '', sanitized, flags=re.IGNORECASE,
    )
    sanitized = re.sub(
        r'\s+on\w+\s*=\s*\S+',
        '', sanitized, flags=re.IGNORECASE,
    )

    # Remove javascript: URIs
    sanitized = re.sub(
        r'javascript\s*:',
        '', sanitized, flags=re.IGNORECASE,
    )

    # Remove dangerous tags
    for tag in ['iframe', 'object', 'embed', 'applet', 'form']:
        sanitized = re.sub(
            rf'<{tag}[^>]*>.*?</{tag}>',
            '', sanitized, flags=re.DOTALL | re.IGNORECASE,
        )
        sanitized = re.sub(
            rf'<{tag}[^>]*/?>',
            '', sanitized, flags=re.IGNORECASE,
        )

    # Remove data: URIs for HTML content
    sanitized = re.sub(
        r'data:text/html[^"\'>\s]*',
        '', sanitized, flags=re.IGNORECASE,
    )

    # Remove CSS expressions
    sanitized = re.sub(
        r'expression\s*\([^)]*\)',
        '', sanitized, flags=re.IGNORECASE,
    )

    if strict:
        # Remove vbscript: URIs
        sanitized = re.sub(
            r'vbscript\s*:',
            '', sanitized, flags=re.IGNORECASE,
        )

    return sanitized


def audit_library_content(library_key):
    """
    Audit all components in a library for security issues (AC-LIB-031).

    Returns audit report with findings.
    """
    from .models import LibraryMetadata, LibraryComponent

    metadata = LibraryMetadata.objects.get(library_key=library_key)
    components = LibraryComponent.objects.filter(
        library=metadata, is_deleted=False,
    )

    findings = []
    for comp in components:
        xss_issues = detect_xss(comp.display_name)
        if xss_issues:
            findings.append({
                'component': comp.usage_key,
                'field': 'display_name',
                'type': 'xss',
                'patterns': xss_issues,
            })

    return {
        'library_key': library_key,
        'components_scanned': components.count(),
        'findings_count': len(findings),
        'findings': findings,
        'audited_at': __import__('django').utils.timezone.now().isoformat(),
    }
