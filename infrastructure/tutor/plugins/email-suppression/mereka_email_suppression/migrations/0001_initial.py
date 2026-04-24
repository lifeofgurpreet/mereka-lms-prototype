# @covers AC-033, AC-034, AC-035
# @spec: email-notifications-pipeline_spec.md
"""
Initial migration for email suppression app.
"""

from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = []

    operations = [
        migrations.CreateModel(
            name="EmailSuppression",
            fields=[
                (
                    "id",
                    models.BigAutoField(
                        auto_created=True, primary_key=True, serialize=False, verbose_name="ID"
                    ),
                ),
                (
                    "email",
                    models.EmailField(
                        db_index=True,
                        help_text="Email address to suppress from sending",
                        max_length=254,
                        unique=True,
                    ),
                ),
                (
                    "reason",
                    models.CharField(
                        choices=[
                            ("hard_bounce", "Hard Bounce"),
                            ("soft_bounce", "Soft Bounce"),
                            ("complaint", "Complaint"),
                        ],
                        help_text="Reason for suppression",
                        max_length=20,
                    ),
                ),
                (
                    "bounce_count",
                    models.IntegerField(
                        default=0, help_text="Number of soft bounces within the last 7 days"
                    ),
                ),
                (
                    "bounced_at",
                    models.DateTimeField(
                        blank=True, help_text="Timestamp of most recent bounce event", null=True
                    ),
                ),
                (
                    "created_at",
                    models.DateTimeField(
                        auto_now_add=True, help_text="Timestamp when suppression was first added"
                    ),
                ),
                (
                    "updated_at",
                    models.DateTimeField(auto_now=True, help_text="Timestamp of last update"),
                ),
            ],
            options={
                "verbose_name": "Email Suppression",
                "verbose_name_plural": "Email Suppressions",
                "db_table": "mereka_email_suppression",
            },
        ),
        migrations.AddIndex(
            model_name="emailsuppression",
            index=models.Index(fields=["email", "reason"], name="mereka_emai_email_d5e3f7_idx"),
        ),
        migrations.AddIndex(
            model_name="emailsuppression",
            index=models.Index(fields=["bounced_at"], name="mereka_emai_bounced_0a2c3d_idx"),
        ),
    ]
