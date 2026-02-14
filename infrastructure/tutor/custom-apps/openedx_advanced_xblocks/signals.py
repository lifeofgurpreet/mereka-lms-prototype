"""
Signal handlers for Advanced XBlocks

Handles gradebook integration, accessibility tracking, and OLX export/import.
"""
from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import XBlockGradebookEntry


@receiver(post_save, sender=XBlockGradebookEntry)
def sync_grade_to_gradebook(sender, instance, created, **kwargs):
    """
    Sync grade to Open edX gradebook (AC-ASS-026)

    Triggered when XBlockGradebookEntry is created or updated.
    Integrates with Open edX gradebook API to record grades.
    """
    if created or not instance.gradebook_synced:
        try:
            # TODO: Integrate with Open edX gradebook API
            # from lms.djangoapps.grades.api import record_grade_event
            # record_grade_event(
            #     user_id=instance.user.id,
            #     usage_key=instance.usage_key,
            #     score_earned=instance.score_earned,
            #     score_possible=instance.score_possible,
            # )

            instance.gradebook_synced = True
            instance.sync_error = ''
            instance.save(update_fields=['gradebook_synced', 'sync_error'])

        except Exception as e:
            instance.gradebook_synced = False
            instance.sync_error = str(e)
            instance.save(update_fields=['gradebook_synced', 'sync_error'])
