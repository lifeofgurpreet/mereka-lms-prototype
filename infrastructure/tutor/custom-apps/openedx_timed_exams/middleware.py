"""Middleware for timed exam enforcement and multi-device detection"""
import logging
from django.http import JsonResponse
from django.utils import timezone
from .models import ExamSession

logger = logging.getLogger(__name__)


class TimedExamEnforcementMiddleware:
    """
    Middleware for server-side timer enforcement and multi-device detection.

    Responsibilities:
    1. Check if user is accessing timed exam content
    2. Verify active exam session exists
    3. Enforce server-side timer (reject if expired)
    4. Detect multi-device attempts (concurrent sessions)
    5. Auto-submit expired sessions
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # Only check authenticated requests to exam content
        if not request.user.is_authenticated:
            return self.get_response(request)

        # Check if this is an exam-related request
        if self._is_exam_request(request):
            # Get exam identifier from request
            usage_key = self._extract_usage_key(request)

            if usage_key:
                # Check for active session
                session = ExamSession.get_active_session(request.user, usage_key)

                if session:
                    # Check if session expired
                    if session.is_expired:
                        # Auto-submit expired session
                        session.auto_submit()
                        logger.warning(
                            f'Exam session expired and auto-submitted: '
                            f'{request.user.username} - {usage_key}'
                        )

                        return JsonResponse({
                            'error': 'exam_expired',
                            'message': 'Your exam time has expired. Your exam has been auto-submitted.',
                            'auto_submitted': True,
                            'session_key': session.session_key
                        }, status=403)

                    # Check for multi-device access
                    device_fingerprint = self._get_device_fingerprint(request)
                    other_session = ExamSession.detect_multi_device(
                        request.user,
                        usage_key,
                        device_fingerprint
                    )

                    if other_session:
                        # Terminate the existing session
                        other_session.terminate(reason='multi_device')

                        logger.warning(
                            f'Multi-device exam access detected and blocked: '
                            f'{request.user.username} - {usage_key} - '
                            f'Device: {device_fingerprint[:12]}... vs {other_session.device_fingerprint[:12]}...'
                        )

                        return JsonResponse({
                            'error': 'multi_device_detected',
                            'message': (
                                'Multiple device access detected. Your exam session on another device '
                                'has been terminated. Please contact your instructor if you need assistance.'
                            ),
                            'terminated_session': other_session.session_key
                        }, status=403)

                    # Update last activity
                    session.last_activity_at = timezone.now()
                    session.save(update_fields=['last_activity_at'])

        response = self.get_response(request)
        return response

    def _is_exam_request(self, request):
        """Check if request is for exam content"""
        path = request.path.lower()

        # Exam-related paths in Open edX
        exam_paths = [
            '/xblock/',  # XBlock handler (includes exam problems)
            '/courses/',  # Course content (may include exam subsections)
            '/api/courseware/',  # Courseware API
        ]

        for exam_path in exam_paths:
            if exam_path in path:
                return True

        return False

    def _extract_usage_key(self, request):
        """Extract usage key from request"""
        # Try to get from request parameters
        usage_key = request.GET.get('usage_key') or request.POST.get('usage_key')

        if usage_key:
            return usage_key

        # Try to parse from URL path
        # Example: /xblock/block-v1:Org+Course+Run+type@sequential+block@exam_subsection
        path = request.path
        if 'block-v1:' in path:
            try:
                # Extract block usage key
                start = path.index('block-v1:')
                end = path.find('/', start)
                if end == -1:
                    end = len(path)
                usage_key = path[start:end]
                return usage_key
            except (ValueError, IndexError):
                pass

        return None

    def _get_device_fingerprint(self, request):
        """Generate device fingerprint from request"""
        user_agent = request.META.get('HTTP_USER_AGENT', '')
        client_hints = request.META.get('HTTP_SEC_CH_UA', '')
        fingerprint_str = f"{user_agent}|{client_hints}"
        return ExamSession.hash_value(fingerprint_str)
