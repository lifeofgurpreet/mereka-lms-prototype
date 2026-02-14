"""
Models for Advanced XBlocks

Tracks randomization state, drag-drop interactions, accessibility preferences,
and gradebook integration for advanced assessment types.
"""
import hashlib
import random
from django.db import models
from django.contrib.auth import get_user_model
from django.utils import timezone
from opaque_keys.edx.django.models import UsageKeyField, CourseKeyField

User = get_user_model()


class RandomizedQuestionPool(models.Model):
    """
    Track randomized question pools for exam integrity (AC-ASS-024)

    Each student gets a unique random subset of questions from a larger pool.
    Uses deterministic seeding (user_id + pool_id) for consistent question sets.
    """
    pool_id = models.CharField(
        max_length=255,
        db_index=True,
        help_text="Unique identifier for the question pool"
    )
    course_key = CourseKeyField(max_length=255, db_index=True)
    usage_key = UsageKeyField(
        max_length=255,
        db_index=True,
        help_text="XBlock usage key for the problem containing this pool"
    )
    user = models.ForeignKey(User, on_delete=models.CASCADE)

    # Pool configuration
    total_questions = models.IntegerField(
        help_text="Total number of questions in pool"
    )
    questions_to_show = models.IntegerField(
        help_text="Number of questions to show per student"
    )

    # Student-specific randomization
    randomization_seed = models.CharField(
        max_length=64,
        help_text="SHA-256 hash of user_id + pool_id for deterministic randomization"
    )
    selected_question_indices = models.JSONField(
        help_text="List of question indices shown to this student"
    )

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = [['pool_id', 'user']]
        indexes = [
            models.Index(fields=['course_key', 'user']),
            models.Index(fields=['usage_key', 'user']),
        ]

    def __str__(self):
        return f"Pool {self.pool_id} for {self.user.username}"

    @staticmethod
    def generate_seed(user_id, pool_id):
        """
        Generate deterministic seed for randomization

        Uses SHA-256 hash of user_id + pool_id to ensure same questions
        are shown on page refresh (AC-ASS-024)
        """
        content = f"{user_id}|{pool_id}"
        return hashlib.sha256(content.encode('utf-8')).hexdigest()

    @classmethod
    def get_or_create_selection(cls, pool_id, course_key, usage_key, user,
                                 total_questions, questions_to_show):
        """
        Get or create randomized question selection for student

        Returns consistent set of question indices for the same student + pool.
        Example: Pool of 20 questions, show 10 → returns [2, 5, 7, 9, 11, 13, 15, 16, 18, 19]
        """
        seed = cls.generate_seed(user.id, pool_id)

        pool, created = cls.objects.get_or_create(
            pool_id=pool_id,
            user=user,
            defaults={
                'course_key': course_key,
                'usage_key': usage_key,
                'total_questions': total_questions,
                'questions_to_show': questions_to_show,
                'randomization_seed': seed,
                'selected_question_indices': [],
            }
        )

        if created or not pool.selected_question_indices:
            # Generate random selection using deterministic seed
            rng = random.Random(seed)
            all_indices = list(range(total_questions))
            selected = sorted(rng.sample(all_indices, questions_to_show))
            pool.selected_question_indices = selected
            pool.save()

        return pool


class AnswerShufflingState(models.Model):
    """
    Track answer shuffling for multiple-choice questions (AC-ASS-027)

    Each student sees answers in a different random order, but order
    remains consistent on page refresh using deterministic seeding.
    """
    usage_key = UsageKeyField(
        max_length=255,
        db_index=True,
        help_text="XBlock usage key for the multiple-choice problem"
    )
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    course_key = CourseKeyField(max_length=255, db_index=True)

    # Original answer order from course author
    original_order = models.JSONField(
        help_text="Original answer indices [0, 1, 2, 3]"
    )

    # Shuffled order for this student
    shuffled_order = models.JSONField(
        help_text="Shuffled answer indices [2, 0, 3, 1]"
    )

    randomization_seed = models.CharField(
        max_length=64,
        help_text="SHA-256 hash for deterministic shuffling"
    )

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = [['usage_key', 'user']]
        indexes = [
            models.Index(fields=['course_key', 'user']),
        ]

    def __str__(self):
        return f"Shuffle for {self.user.username} on {self.usage_key}"

    @staticmethod
    def generate_seed(user_id, usage_key):
        """Generate deterministic seed for answer shuffling"""
        content = f"{user_id}|{usage_key}"
        return hashlib.sha256(content.encode('utf-8')).hexdigest()

    @classmethod
    def get_or_create_shuffle(cls, usage_key, course_key, user, num_answers):
        """
        Get or create shuffled answer order for student

        Returns consistent shuffle for same student + problem.
        Example: 4 answers [0,1,2,3] → [2,0,3,1] (same every time)
        """
        seed = cls.generate_seed(user.id, str(usage_key))

        state, created = cls.objects.get_or_create(
            usage_key=usage_key,
            user=user,
            defaults={
                'course_key': course_key,
                'randomization_seed': seed,
                'original_order': list(range(num_answers)),
                'shuffled_order': [],
            }
        )

        if created or not state.shuffled_order:
            # Generate shuffled order using deterministic seed
            rng = random.Random(seed)
            shuffled = list(range(num_answers))
            rng.shuffle(shuffled)
            state.shuffled_order = shuffled
            state.save()

        return state


class DragDropInteraction(models.Model):
    """
    Track drag-and-drop v2 interactions for analytics (AC-ASS-022)

    Records each placement attempt for learning analytics and
    debugging accessibility issues.
    """
    usage_key = UsageKeyField(max_length=255, db_index=True)
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    course_key = CourseKeyField(max_length=255, db_index=True)

    # Interaction details
    item_id = models.CharField(
        max_length=255,
        help_text="ID of draggable item"
    )
    zone_id = models.CharField(
        max_length=255,
        help_text="ID of drop zone"
    )

    is_correct = models.BooleanField(
        help_text="Whether placement was correct"
    )

    # Accessibility tracking (AC-ASS-028)
    input_method = models.CharField(
        max_length=20,
        choices=[
            ('mouse', 'Mouse/Touch'),
            ('keyboard', 'Keyboard Only'),
            ('screen_reader', 'Screen Reader'),
        ],
        default='mouse',
        help_text="Input method used for this interaction"
    )

    interaction_time_ms = models.IntegerField(
        help_text="Time taken for this placement (milliseconds)"
    )

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(fields=['usage_key', 'user', '-created_at']),
            models.Index(fields=['course_key', 'input_method']),
        ]

    def __str__(self):
        return f"{self.user.username}: {self.item_id} → {self.zone_id}"


class MathInputSubmission(models.Model):
    """
    Track math input submissions for analytics (AC-ASS-023)

    Stores LaTeX expressions and grading results for debugging
    and learning analytics.
    """
    usage_key = UsageKeyField(max_length=255, db_index=True)
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    course_key = CourseKeyField(max_length=255, db_index=True)

    # Student input
    latex_input = models.TextField(
        help_text="LaTeX expression entered by student"
    )

    # Grading
    expected_answer = models.TextField(
        help_text="Expected LaTeX answer"
    )
    is_correct = models.BooleanField()
    tolerance = models.FloatField(
        default=0.01,
        help_text="Numerical tolerance for grading (if applicable)"
    )

    # Rendering validation
    mathjax_render_success = models.BooleanField(
        default=True,
        help_text="Whether MathJax successfully rendered the input"
    )
    render_error = models.TextField(
        blank=True,
        help_text="MathJax rendering error (if any)"
    )

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(fields=['usage_key', 'user', '-created_at']),
            models.Index(fields=['course_key', 'is_correct']),
        ]

    def __str__(self):
        return f"{self.user.username}: {self.latex_input[:50]}"


class XBlockAccessibilitySettings(models.Model):
    """
    Per-user accessibility preferences for XBlocks (AC-ASS-028)

    Stores preferences for keyboard navigation, screen readers,
    high contrast mode, etc.
    """
    user = models.OneToOneField(User, on_delete=models.CASCADE)

    # Keyboard navigation preferences
    enable_keyboard_shortcuts = models.BooleanField(
        default=True,
        help_text="Enable keyboard shortcuts for drag-drop and interactions"
    )
    keyboard_focus_indicator = models.CharField(
        max_length=20,
        choices=[
            ('default', 'Default Browser Focus'),
            ('high_contrast', 'High Contrast Outline'),
            ('custom', 'Custom Color'),
        ],
        default='default'
    )

    # Screen reader settings
    announce_all_interactions = models.BooleanField(
        default=True,
        help_text="Announce all drag-drop placements via ARIA live regions"
    )

    # Visual preferences
    reduce_motion = models.BooleanField(
        default=False,
        help_text="Disable animations and transitions"
    )
    high_contrast_mode = models.BooleanField(
        default=False,
        help_text="Enable high contrast mode for all XBlocks"
    )

    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Accessibility settings for {self.user.username}"


class XBlockGradebookEntry(models.Model):
    """
    Track XBlock grades for gradebook integration (AC-ASS-026)

    Ensures all advanced XBlocks properly record grades in the gradebook.
    Provides audit trail for grade changes.
    """
    usage_key = UsageKeyField(max_length=255, db_index=True)
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    course_key = CourseKeyField(max_length=255, db_index=True)

    xblock_type = models.CharField(
        max_length=50,
        choices=[
            ('drag_drop_v2', 'Drag and Drop v2'),
            ('math_input', 'Math Input'),
            ('randomized_pool', 'Randomized Pool'),
            ('problem_builder', 'Problem Builder'),
        ],
        help_text="Type of XBlock"
    )

    # Grade details
    score_earned = models.FloatField()
    score_possible = models.FloatField()
    grade_percentage = models.FloatField(
        help_text="Calculated as (earned / possible) * 100"
    )

    # Audit trail
    graded_at = models.DateTimeField(default=timezone.now)
    gradebook_synced = models.BooleanField(
        default=False,
        help_text="Whether grade has been synced to Open edX gradebook"
    )
    sync_error = models.TextField(
        blank=True,
        help_text="Error message if gradebook sync failed"
    )

    class Meta:
        unique_together = [['usage_key', 'user']]
        indexes = [
            models.Index(fields=['course_key', 'user', '-graded_at']),
            models.Index(fields=['gradebook_synced', 'graded_at']),
        ]

    def __str__(self):
        return f"{self.user.username}: {self.score_earned}/{self.score_possible}"

    def calculate_percentage(self):
        """Calculate grade percentage"""
        if self.score_possible > 0:
            return (self.score_earned / self.score_possible) * 100
        return 0.0

    def save(self, *args, **kwargs):
        """Auto-calculate grade percentage on save"""
        self.grade_percentage = self.calculate_percentage()
        super().save(*args, **kwargs)
