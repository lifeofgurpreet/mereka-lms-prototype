# @covers AC-033, AC-034, AC-035
# @spec: email-notifications-pipeline_spec.md
"""
Management command to process AWS SES bounce and complaint notifications.

AC-033: Hard bounce suppression list processing
AC-034: Soft bounce (3 within 7 days) treatment
AC-035: Complaint handling and preference disabling

Usage:
    python manage.py process_ses_notification --notification-json '{"notificationType": "Bounce", ...}'

    OR read from SNS webhook payload:
    python manage.py process_ses_notification --sns-json '{"Message": "{...}"}'
"""

import json
import logging

from django.core.management.base import BaseCommand, CommandError
from django.utils import timezone

from mereka_email_suppression.models import EmailSuppression

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = 'Process AWS SES bounce and complaint notifications from SNS'

    def add_arguments(self, parser):
        parser.add_argument(
            '--notification-json',
            type=str,
            help='Raw SES notification JSON string',
        )
        parser.add_argument(
            '--sns-json',
            type=str,
            help='SNS message JSON string (will extract Message field)',
        )

    def handle(self, *args, **options):
        notification_json = options.get('notification_json')
        sns_json = options.get('sns_json')

        if not notification_json and not sns_json:
            raise CommandError('Either --notification-json or --sns-json is required')

        try:
            # Parse SNS message if provided
            if sns_json:
                sns_message = json.loads(sns_json)
                notification_json = sns_message.get('Message', '{}')

            # Parse SES notification
            notification = json.loads(notification_json)
            notification_type = notification.get('notificationType')

            if notification_type == 'Bounce':
                self._process_bounce(notification)
            elif notification_type == 'Complaint':
                self._process_complaint(notification)
            else:
                self.stdout.write(
                    self.style.WARNING(
                        f'Ignoring notification type: {notification_type}'
                    )
                )

        except json.JSONDecodeError as e:
            raise CommandError(f'Invalid JSON: {e}')
        except Exception as e:
            logger.exception('Error processing SES notification')
            raise CommandError(f'Error processing notification: {e}')

    def _process_bounce(self, notification):
        """Process bounce notification."""
        bounce = notification.get('bounce', {})
        bounce_type = bounce.get('bounceType', '')
        bounced_recipients = bounce.get('bouncedRecipients', [])

        for recipient in bounced_recipients:
            email_address = recipient.get('emailAddress', '').lower()
            if not email_address:
                continue

            # Hard bounce: permanent failure
            if bounce_type == 'Permanent':
                suppression, created = EmailSuppression.objects.get_or_create(
                    email=email_address,
                    defaults={
                        'reason': 'hard_bounce',
                        'bounced_at': timezone.now(),
                    }
                )

                if not created:
                    suppression.reason = 'hard_bounce'
                    suppression.bounced_at = timezone.now()
                    suppression.save()

                self.stdout.write(
                    self.style.SUCCESS(
                        f'Added hard bounce suppression for {email_address}'
                    )
                )

            # Soft bounce: temporary failure
            elif bounce_type in ['Transient', 'Undetermined']:
                suppression, created = EmailSuppression.objects.get_or_create(
                    email=email_address,
                    defaults={
                        'reason': 'soft_bounce',
                        'bounce_count': 1,
                        'bounced_at': timezone.now(),
                    }
                )

                if not created:
                    # Reset count if last bounce was more than 7 days ago
                    if suppression.bounced_at:
                        days_since_last_bounce = (timezone.now() - suppression.bounced_at).days
                        if days_since_last_bounce > 7:
                            suppression.bounce_count = 1
                        else:
                            suppression.bounce_count += 1
                    else:
                        suppression.bounce_count = 1

                    suppression.bounced_at = timezone.now()
                    suppression.save()

                status_msg = f'Soft bounce for {email_address} (count: {suppression.bounce_count})'
                if suppression.bounce_count >= 3:
                    self.stdout.write(
                        self.style.WARNING(f'{status_msg} - SUPPRESSED')
                    )
                else:
                    self.stdout.write(self.style.SUCCESS(status_msg))

    def _process_complaint(self, notification):
        """Process complaint notification."""
        complaint = notification.get('complaint', {})
        complained_recipients = complaint.get('complainedRecipients', [])

        for recipient in complained_recipients:
            email_address = recipient.get('emailAddress', '').lower()
            if not email_address:
                continue

            suppression, created = EmailSuppression.objects.get_or_create(
                email=email_address,
                defaults={
                    'reason': 'complaint',
                    'bounced_at': timezone.now(),
                }
            )

            if not created:
                suppression.reason = 'complaint'
                suppression.bounced_at = timezone.now()
                suppression.save()

            self.stdout.write(
                self.style.SUCCESS(
                    f'Added complaint suppression for {email_address}'
                )
            )
