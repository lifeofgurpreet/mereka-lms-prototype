"""Security audit for all library content."""
from django.core.management.base import BaseCommand

class Command(BaseCommand):
    help = 'Audit all library content for XSS and injection vulnerabilities'

    def add_arguments(self, parser):
        parser.add_argument('--library-key', help='Audit specific library only')

    def handle(self, *args, **options):
        from openedx_content_libraries.sanitize import audit_library_content, detect_xss
        from openedx_content_libraries.models import LibraryMetadata

        library_key = options.get('library_key')

        if library_key:
            libraries = [LibraryMetadata.objects.get(library_key=library_key)]
        else:
            libraries = LibraryMetadata.objects.filter(is_deleted=False)

        total_findings = 0
        for lib in libraries:
            report = audit_library_content(lib.library_key)
            if report['findings_count'] > 0:
                self.stderr.write(
                    f"  FINDINGS in {lib.library_key}: {report['findings_count']} issues"
                )
                total_findings += report['findings_count']
            else:
                self.stdout.write(f"  OK: {lib.library_key} ({report['components_scanned']} components)")

        if total_findings:
            self.stderr.write(self.style.WARNING(f"\nTotal findings: {total_findings}"))
        else:
            self.stdout.write(self.style.SUCCESS("\nNo security findings"))
