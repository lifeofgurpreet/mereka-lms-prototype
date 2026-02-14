"""Python code grader implementation"""
import json
import logging
import socket
from .sandbox import SecureSandbox
from .models import GraderSubmission

logger = logging.getLogger(__name__)


class PythonGrader:
    """
    Python code grader with secure sandbox execution.

    Implements:
    - AC-ASS-015: Grade submissions within 30s
    - AC-ASS-019: Idempotent grading (same input = same output)
    """

    def __init__(self, timeout_seconds=30, memory_limit_mb=256):
        self.timeout_seconds = timeout_seconds
        self.memory_limit_mb = memory_limit_mb
        self.worker_hostname = socket.gethostname()

    def grade_submission(self, xqueue_header, xqueue_body):
        """
        Grade a code submission from XQueue.

        Args:
            xqueue_header (dict): XQueue header with submission_id, queue_name
            xqueue_body (dict): XQueue body with student_response, grader_payload

        Returns:
            dict: Grading result with correct, score, feedback
        """
        submission_id = xqueue_header.get('submission_id', 'unknown')
        student_response = xqueue_body.get('student_response', '')
        grader_payload = xqueue_body.get('grader_payload', '')

        logger.info(f'Grading submission: {submission_id}')

        # Calculate submission hash for idempotency check (AC-ASS-019)
        submission_hash = GraderSubmission.calculate_hash(student_response, grader_payload)

        # Check for duplicate submission
        duplicate = GraderSubmission.find_duplicate(submission_hash)
        if duplicate:
            logger.info(f'Duplicate submission detected: {submission_id} - Returning cached result')
            return {
                'correct': duplicate.correct,
                'score': float(duplicate.score) if duplicate.score else 0.0,
                'feedback': duplicate.feedback,
                'cached': True
            }

        # Create submission record
        submission = GraderSubmission.objects.create(
            xqueue_header=xqueue_header,
            xqueue_body=xqueue_body,
            submission_id=submission_id,
            submission_hash=submission_hash,
            student_response=student_response,
            grader_payload=grader_payload,
            status='pending'
        )

        # Mark as processing
        submission.mark_processing(self.worker_hostname)

        try:
            # Parse grader payload (contains test cases)
            grader_config = self._parse_grader_payload(grader_payload)

            # Execute student code in sandbox
            sandbox = SecureSandbox(
                timeout_seconds=self.timeout_seconds,
                memory_limit_mb=self.memory_limit_mb
            )

            # Validate imports before execution
            is_valid, violations = sandbox.validate_imports(student_response)
            if not is_valid:
                submission.mark_failure(f'Invalid imports: {", ".join(violations)}')
                return {
                    'correct': False,
                    'score': 0.0,
                    'feedback': f'Invalid imports detected: {", ".join(violations)}'
                }

            # Execute code with test cases
            test_cases = grader_config.get('test_cases', '')
            result = sandbox.execute_code(student_response, test_cases)

            # Check for sandbox violations
            if result.get('sandbox_error'):
                violations = result.get('violations', [])
                submission.mark_sandbox_error(violations)
                return {
                    'correct': False,
                    'score': 0.0,
                    'feedback': f'Sandbox violation: {", ".join(violations)}'
                }

            # Check for timeout
            if result.get('timed_out'):
                submission.mark_timeout()
                return {
                    'correct': False,
                    'score': 0.0,
                    'feedback': 'Code execution timed out. Please optimize your solution.'
                }

            # Evaluate test results
            grading_result = self._evaluate_results(result, grader_config)

            # Save successful result
            submission.mark_success({
                'correct': grading_result['correct'],
                'score': grading_result['score'],
                'feedback': grading_result['feedback'],
                'stdout': result['stdout'],
                'stderr': result['stderr'],
                'execution_time_ms': result['execution_time_ms'],
                'exit_code': result['exit_code']
            })

            return grading_result

        except Exception as e:
            logger.error(f'Grading error for {submission_id}: {e}', exc_info=True)
            submission.mark_failure(str(e))
            return {
                'correct': False,
                'score': 0.0,
                'feedback': f'Grading error: {str(e)}'
            }

    def _parse_grader_payload(self, grader_payload):
        """Parse grader payload JSON"""
        if not grader_payload:
            return {'test_cases': '', 'expected_output': ''}

        try:
            if isinstance(grader_payload, str):
                return json.loads(grader_payload)
            return grader_payload
        except json.JSONDecodeError:
            # If not JSON, treat as plain test cases
            return {'test_cases': grader_payload}

    def _evaluate_results(self, execution_result, grader_config):
        """
        Evaluate execution results against expected outcomes.

        Returns:
            dict: Grading result with correct, score, feedback
        """
        stdout = execution_result.get('stdout', '').strip()
        stderr = execution_result.get('stderr', '').strip()
        exit_code = execution_result.get('exit_code', -1)

        # Check if code ran successfully
        if exit_code != 0:
            return {
                'correct': False,
                'score': 0.0,
                'feedback': f'Code exited with error (exit code: {exit_code})\n\nError output:\n{stderr}'
            }

        # Check stderr for runtime errors
        if stderr and 'Traceback' in stderr:
            return {
                'correct': False,
                'score': 0.0,
                'feedback': f'Runtime error detected:\n\n{stderr}'
            }

        # Compare output with expected (if provided)
        expected_output = grader_config.get('expected_output', '').strip()

        if expected_output:
            # Normalize whitespace for comparison
            stdout_normalized = ' '.join(stdout.split())
            expected_normalized = ' '.join(expected_output.split())

            if stdout_normalized == expected_normalized:
                return {
                    'correct': True,
                    'score': 100.0,
                    'feedback': 'Correct! Your solution passed all tests.'
                }
            else:
                return {
                    'correct': False,
                    'score': 0.0,
                    'feedback': f'Output does not match expected.\n\nExpected:\n{expected_output}\n\nGot:\n{stdout}'
                }

        # If no expected output, check if test cases passed
        # Test framework output typically shows "OK" or "FAILED"
        if 'OK' in stdout or 'PASSED' in stdout:
            return {
                'correct': True,
                'score': 100.0,
                'feedback': 'Correct! Your solution passed all tests.\n\nOutput:\n' + stdout
            }

        elif 'FAILED' in stdout or 'FAIL' in stdout:
            return {
                'correct': False,
                'score': 0.0,
                'feedback': 'Some tests failed.\n\nOutput:\n' + stdout
            }

        # Default: code ran but no clear pass/fail indication
        return {
            'correct': True,
            'score': 50.0,
            'feedback': f'Code executed successfully.\n\nOutput:\n{stdout}'
        }


def process_xqueue_submission(xqueue_body_str):
    """
    Process a submission from XQueue.

    This is the entry point called by XQueue worker daemon.

    Args:
        xqueue_body_str (str): JSON string from XQueue

    Returns:
        dict: Response to send back to XQueue
    """
    try:
        # Parse XQueue body
        xqueue_body = json.loads(xqueue_body_str)
        xqueue_header = xqueue_body.get('xqueue_header', {})
        xqueue_files = xqueue_body.get('xqueue_files', {})

        # Extract student code
        student_response = xqueue_body.get('student_response', '')
        grader_payload = xqueue_body.get('grader_payload', '')

        # Grade the submission
        grader = PythonGrader(timeout_seconds=30, memory_limit_mb=256)
        result = grader.grade_submission(xqueue_header, {
            'student_response': student_response,
            'grader_payload': grader_payload
        })

        # Format response for XQueue
        response = {
            'correct': result['correct'],
            'score': result['score'],
            'msg': result['feedback']
        }

        logger.info(f'Grading complete: {xqueue_header.get("submission_id")} - Score: {result["score"]}')

        return json.dumps(response)

    except Exception as e:
        logger.error(f'Error processing XQueue submission: {e}', exc_info=True)
        error_response = {
            'correct': False,
            'score': 0.0,
            'msg': f'Grading system error: {str(e)}'
        }
        return json.dumps(error_response)
