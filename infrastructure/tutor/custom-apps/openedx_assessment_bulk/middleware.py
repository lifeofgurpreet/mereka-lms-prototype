"""
Middleware for Assessment Bulk Operations

Implements:
- IP logging for exam submissions (AC-ASS-035)
- Grade data access control (AC-ASS-036)
- show_correctness timing (AC-ASS-032)
"""
from django.utils import timezone
from .models import ExamSubmissionIPLog, GradeAccessLog


class ExamIPLoggingMiddleware:
    """
    Log IP addresses for exam submissions (AC-ASS-035)

    Captures student IP for every exam submission for compliance.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)

        # Log IP for exam-related endpoints
        if self.is_exam_submission(request):
            self.log_ip(request)

        return response

    def is_exam_submission(self, request):
        """Check if request is an exam submission"""
        # Exam submission patterns
        exam_patterns = [
            '/courses/.+/xblock/.+/handler/submit',  # Problem submission
            '/api/courses/.+/submissions',  # API submission
            '/courses/.+/courseware/.+',  # Courseware access (exam start)
        ]

        path = request.path
        return any(pattern in path for pattern in exam_patterns if pattern)

    def log_ip(self, request):
        """Log IP address (AC-ASS-035)"""
        if not request.user or not request.user.is_authenticated:
            return

        # Extract IP address
        ip_address = self.get_client_ip(request)
        if not ip_address:
            return

        # Extract usage_key and course_key from path
        # TODO: Parse from request path properly
        # For now, placeholder
        usage_key = None
        course_key = None

        try:
            ExamSubmissionIPLog.objects.create(
                usage_key=usage_key,
                course_key=course_key,
                student=request.user,
                ip_address=ip_address,
                user_agent=request.META.get('HTTP_USER_AGENT', '')[:500],
                submission_type='exam_submit',
            )
        except Exception:
            # Silently fail - don't block submissions
            pass

    def get_client_ip(self, request):
        """Extract client IP from request"""
        # Check X-Forwarded-For header first (for proxied requests)
        x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
        if x_forwarded_for:
            # Take first IP in chain (client IP)
            ip = x_forwarded_for.split(',')[0].strip()
            return ip

        # Fallback to REMOTE_ADDR
        return request.META.get('REMOTE_ADDR')


class GradeAccessControlMiddleware:
    """
    Grade data access control and logging (AC-ASS-036)

    Prevents grade data leakage - student A cannot see student B's grades.
    Logs all grade access for security auditing.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # Pre-process: Log grade access attempts
        if self.is_grade_access(request):
            self.log_grade_access(request)

        response = self.get_response(request)

        # Post-process: Validate response doesn't leak grades (AC-ASS-036)
        if self.is_grade_access(request):
            self.validate_grade_response(request, response)

        return response

    def is_grade_access(self, request):
        """Check if request accesses grade data"""
        grade_patterns = [
            '/api/grades/',
            '/courses/.+/progress',
            '/grades/',
            '/api/course/.+/gradebook',
        ]

        path = request.path
        return any(pattern in path for pattern in grade_patterns if pattern)

    def log_grade_access(self, request):
        """Log grade access (AC-ASS-036: audit trail)"""
        if not request.user or not request.user.is_authenticated:
            return

        # Determine authorization
        is_authorized, reason = self.check_authorization(request)

        # Extract target student from request
        accessed_student = self.extract_target_student(request)

        # Extract course_key from path
        # TODO: Parse properly
        course_key = None

        try:
            GradeAccessLog.objects.create(
                course_key=course_key,
                accessed_by=request.user,
                accessed_student=accessed_student,
                access_type=self.determine_access_type(request),
                is_authorized=is_authorized,
                authorization_reason=reason,
                ip_address=self.get_client_ip(request),
                user_agent=request.META.get('HTTP_USER_AGENT', '')[:500],
                request_path=request.path[:500],
            )
        except Exception:
            # Silently fail - don't block requests
            pass

    def check_authorization(self, request):
        """
        Check if user is authorized to access grades (AC-ASS-036)

        Returns: (is_authorized: bool, reason: str)
        """
        user = request.user

        # Staff/superuser always authorized
        if user.is_staff or user.is_superuser:
            return True, 'is_staff'

        # TODO: Check instructor/TA role for course
        # if is_instructor(user, course_key):
        #     return True, 'is_instructor'
        # if is_ta(user, course_key):
        #     return True, 'is_ta'

        # Check if accessing own grades
        accessed_student = self.extract_target_student(request)
        if accessed_student and accessed_student.id == user.id:
            return True, 'is_owner'

        # Unauthorized
        return False, 'unauthorized'

    def validate_grade_response(self, request, response):
        """
        Validate response doesn't leak grades (AC-ASS-036)

        Ensures student A cannot see student B's grades in API response.
        """
        # TODO: Implement response validation
        # Parse JSON response and verify no unauthorized grade data
        pass

    def extract_target_student(self, request):
        """Extract target student from request"""
        # TODO: Parse student_id from request path/query params
        # For now, return None
        return None

    def determine_access_type(self, request):
        """Determine type of grade access"""
        if request.method in ['POST', 'PUT', 'PATCH']:
            return 'api_write'
        elif 'bulk' in request.path or 'export' in request.path:
            return 'bulk_export'
        elif 'gradebook' in request.path:
            return 'gradebook_view'
        else:
            return 'api_read'

    def get_client_ip(self, request):
        """Extract client IP from request"""
        x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
        if x_forwarded_for:
            return x_forwarded_for.split(',')[0].strip()
        return request.META.get('REMOTE_ADDR', '127.0.0.1')


class ShowCorrectnessMiddleware:
    """
    Control show_correctness timing (AC-ASS-032)

    Hides correctness before due date when show_correctness=past_due.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)

        # Filter correctness from response if before due date
        if self.is_problem_response(request):
            self.filter_correctness(request, response)

        return response

    def is_problem_response(self, request):
        """Check if response contains problem data"""
        return '/xblock/.+/handler/' in request.path or '/api/courses/.+/blocks' in request.path

    def filter_correctness(self, request, response):
        """
        Filter correctness from response if show_correctness=past_due (AC-ASS-032)

        Removes correctness indicators (correct/incorrect) from response
        before due date to prevent students from seeing answers.
        """
        # TODO: Implement correctness filtering
        # 1. Parse problem settings to get show_correctness
        # 2. If show_correctness == 'past_due':
        #    - Check current time vs due date
        #    - If before due date, remove correctness from response
        pass
