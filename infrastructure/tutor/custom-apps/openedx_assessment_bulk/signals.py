"""
Signal handlers for Assessment Bulk Operations

Handles grade override auditing and other event tracking.
"""
from django.db.models.signals import post_save, pre_save
from django.dispatch import receiver
from .models import GradeOverrideAudit


# Grade override auditing is handled via explicit GradeOverrideAudit.objects.create()
# in the grading views/APIs, not via signals, to ensure we capture all necessary context
# (original score, new score, staff user, reason).

# Example signal for future use:
# @receiver(post_save, sender=SomeGradeModel)
# def on_grade_change(sender, instance, created, **kwargs):
#     """Track grade changes"""
#     pass
