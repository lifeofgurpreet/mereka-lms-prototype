# Generated migration for mereka_email_preferences

from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = []

    operations = [
        migrations.CreateModel(
            name="NotificationPreference",
            fields=[
                (
                    "id",
                    models.BigAutoField(
                        auto_created=True, primary_key=True, serialize=False, verbose_name="ID"
                    ),
                ),
                (
                    "user_id",
                    models.IntegerField(
                        db_index=True, help_text="Open edX user ID (references auth_user.id)"
                    ),
                ),
                (
                    "message_type",
                    models.CharField(
                        choices=[
                            ("password_reset", "Password Reset"),
                            ("account_activation", "Account Activation"),
                            ("enrollment_confirmation", "Enrollment Confirmation"),
                            ("course_announcement", "Course Announcement"),
                            ("assignment_reminder", "Assignment Reminder"),
                            ("grade_posted", "Grade Posted"),
                            ("discussion_reply", "Discussion Reply"),
                            ("discussion_mention", "Discussion Mention"),
                            ("certificate_issued", "Certificate Issued"),
                            ("course_start_reminder", "Course Start Reminder"),
                            ("course_completion", "Course Completion"),
                            ("license_expiry_warning", "License Expiry Warning"),
                            ("enterprise_welcome", "Enterprise Welcome"),
                            ("bulk_campaign", "Bulk Campaign"),
                            ("forum_digest", "Forum Digest"),
                        ],
                        help_text="Type of notification message",
                        max_length=50,
                    ),
                ),
                (
                    "channel",
                    models.CharField(
                        choices=[
                            ("email", "Email"),
                            ("push", "Push Notification"),
                            ("in_app", "In-App Notification"),
                        ],
                        help_text="Notification channel (email, push, in_app)",
                        max_length=20,
                    ),
                ),
                (
                    "enabled",
                    models.BooleanField(
                        default=True, help_text="Whether this notification is enabled for the user"
                    ),
                ),
                (
                    "consent_version",
                    models.CharField(
                        blank=True,
                        help_text="Version of consent policy accepted by user",
                        max_length=50,
                        null=True,
                    ),
                ),
                (
                    "updated_at",
                    models.DateTimeField(auto_now=True, help_text="Timestamp of last update"),
                ),
            ],
            options={
                "verbose_name": "Notification Preference",
                "verbose_name_plural": "Notification Preferences",
                "db_table": "mereka_notification_preference",
            },
        ),
        migrations.CreateModel(
            name="PreferenceAuditLog",
            fields=[
                (
                    "id",
                    models.BigAutoField(
                        auto_created=True, primary_key=True, serialize=False, verbose_name="ID"
                    ),
                ),
                (
                    "user_id",
                    models.IntegerField(
                        db_index=True, help_text="Open edX user ID (references auth_user.id)"
                    ),
                ),
                (
                    "message_type",
                    models.CharField(
                        choices=[
                            ("password_reset", "Password Reset"),
                            ("account_activation", "Account Activation"),
                            ("enrollment_confirmation", "Enrollment Confirmation"),
                            ("course_announcement", "Course Announcement"),
                            ("assignment_reminder", "Assignment Reminder"),
                            ("grade_posted", "Grade Posted"),
                            ("discussion_reply", "Discussion Reply"),
                            ("discussion_mention", "Discussion Mention"),
                            ("certificate_issued", "Certificate Issued"),
                            ("course_start_reminder", "Course Start Reminder"),
                            ("course_completion", "Course Completion"),
                            ("license_expiry_warning", "License Expiry Warning"),
                            ("enterprise_welcome", "Enterprise Welcome"),
                            ("bulk_campaign", "Bulk Campaign"),
                            ("forum_digest", "Forum Digest"),
                        ],
                        help_text="Type of notification message",
                        max_length=50,
                    ),
                ),
                (
                    "channel",
                    models.CharField(
                        choices=[
                            ("email", "Email"),
                            ("push", "Push Notification"),
                            ("in_app", "In-App Notification"),
                        ],
                        help_text="Notification channel",
                        max_length=20,
                    ),
                ),
                (
                    "old_value",
                    models.BooleanField(
                        blank=True,
                        help_text="Previous enabled state (null if new preference)",
                        null=True,
                    ),
                ),
                ("new_value", models.BooleanField(help_text="New enabled state")),
                (
                    "consent_version",
                    models.CharField(
                        blank=True,
                        help_text="Version of consent policy at time of change",
                        max_length=50,
                        null=True,
                    ),
                ),
                (
                    "ip_address_hash",
                    models.CharField(
                        blank=True,
                        help_text="SHA256 hash of IP address (privacy)",
                        max_length=64,
                        null=True,
                    ),
                ),
                (
                    "timestamp",
                    models.DateTimeField(
                        auto_now_add=True, db_index=True, help_text="Timestamp of preference change"
                    ),
                ),
                (
                    "change_source",
                    models.CharField(
                        choices=[
                            ("api", "API"),
                            ("unsubscribe", "One-Click Unsubscribe"),
                            ("admin", "Admin"),
                            ("system", "System"),
                        ],
                        default="api",
                        help_text="Source of the preference change",
                        max_length=20,
                    ),
                ),
            ],
            options={
                "verbose_name": "Preference Audit Log",
                "verbose_name_plural": "Preference Audit Logs",
                "db_table": "mereka_preference_audit_log",
                "ordering": ["-timestamp"],
            },
        ),
        migrations.AddIndex(
            model_name="notificationpreference",
            index=models.Index(
                fields=["user_id", "message_type", "channel"], name="mereka_noti_user_id_d4e5a1_idx"
            ),
        ),
        migrations.AddIndex(
            model_name="notificationpreference",
            index=models.Index(
                fields=["user_id", "enabled"], name="mereka_noti_user_id_7f8b2c_idx"
            ),
        ),
        migrations.AlterUniqueTogether(
            name="notificationpreference",
            unique_together={("user_id", "message_type", "channel")},
        ),
        migrations.AddIndex(
            model_name="preferenceauditlog",
            index=models.Index(
                fields=["user_id", "timestamp"], name="mereka_pref_user_id_9a3d4e_idx"
            ),
        ),
        migrations.AddIndex(
            model_name="preferenceauditlog",
            index=models.Index(
                fields=["message_type", "timestamp"], name="mereka_pref_message_5b6c7f_idx"
            ),
        ),
    ]
