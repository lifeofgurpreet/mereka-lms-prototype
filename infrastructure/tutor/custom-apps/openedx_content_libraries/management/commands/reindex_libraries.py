"""Reindex all libraries and components in Meilisearch."""
from django.core.management.base import BaseCommand

class Command(BaseCommand):
    help = 'Reindex all Content Libraries v2 in Meilisearch'

    def handle(self, *args, **options):
        from openedx_content_libraries.search import reindex_all, ensure_indexes

        self.stdout.write("Ensuring Meilisearch indexes...")
        ensure_indexes()

        self.stdout.write("Reindexing all libraries and components...")
        result = reindex_all()

        self.stdout.write(self.style.SUCCESS(
            f"Done: {result['libraries']} libraries, {result['components']} components indexed"
        ))
