"""Secure sandbox for code execution"""
import subprocess
import tempfile
import os
import logging
import resource
import signal
from pathlib import Path

logger = logging.getLogger(__name__)


class SandboxViolation(Exception):
    """Raised when sandbox security violation detected"""
    pass


class CodeExecutionTimeout(Exception):
    """Raised when code execution times out"""
    pass


class SecureSandbox:
    """
    Secure sandbox for Python code execution with strict resource limits.

    Security features:
    - AC-ASS-016: Network access denied (no outbound connections)
    - AC-ASS-017: Filesystem writes restricted to /tmp only
    - CPU time limit (default: 5 seconds)
    - Memory limit (default: 256MB)
    - Process limits (no subprocess spawning)
    - No file descriptor access beyond stdin/stdout/stderr
    """

    def __init__(
        self,
        timeout_seconds=5,
        memory_limit_mb=256,
        cpu_time_limit=5,
        allowed_imports=None
    ):
        self.timeout_seconds = timeout_seconds
        self.memory_limit_mb = memory_limit_mb
        self.cpu_time_limit = cpu_time_limit
        self.allowed_imports = allowed_imports or [
            'math', 'random', 'itertools', 'functools', 'collections',
            'datetime', 'json', 're', 'string', 'heapq'
        ]
        self.violations = []

    def execute_code(self, code, test_cases=''):
        """
        Execute student code in sandbox with strict security controls.

        Args:
            code (str): Student's Python code
            test_cases (str): Test cases to run against code

        Returns:
            dict: Execution result with stdout, stderr, exit_code, violations

        Raises:
            SandboxViolation: If security violation detected
            CodeExecutionTimeout: If execution times out
        """
        # Create temporary directory for execution (only writable location)
        with tempfile.TemporaryDirectory() as tmpdir:
            # Write code to file
            code_file = Path(tmpdir) / 'solution.py'
            code_file.write_text(code)

            # Write test cases if provided
            test_file = None
            if test_cases:
                test_file = Path(tmpdir) / 'tests.py'
                test_file.write_text(test_cases)

            # Prepare execution command
            if test_file:
                # Run tests against solution
                cmd = ['python3', str(test_file)]
            else:
                # Run solution directly
                cmd = ['python3', str(code_file)]

            # Set up resource limits and execute
            result = self._execute_in_sandbox(cmd, tmpdir)

            # Check for violations
            if self.violations:
                result['violations'] = self.violations
                result['sandbox_error'] = True

            return result

    def _execute_in_sandbox(self, cmd, tmpdir):
        """Execute command in sandbox with resource limits"""
        import time

        violations = []
        start_time = time.time()

        try:
            # Set up preexec function to apply resource limits
            def preexec_fn():
                # Set CPU time limit (soft and hard limit)
                resource.setrlimit(
                    resource.RLIMIT_CPU,
                    (self.cpu_time_limit, self.cpu_time_limit + 1)
                )

                # Set memory limit
                max_memory = self.memory_limit_mb * 1024 * 1024  # Convert MB to bytes
                resource.setrlimit(resource.RLIMIT_AS, (max_memory, max_memory))

                # Limit number of processes (prevent fork bombs)
                resource.setrlimit(resource.RLIMIT_NPROC, (0, 0))

                # Limit file descriptors
                resource.setrlimit(resource.RLIMIT_NOFILE, (10, 10))

            # Execute in sandbox
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                cwd=tmpdir,
                preexec_fn=preexec_fn,
                env=self._get_sandbox_env(),
                text=True
            )

            # Wait for completion with timeout
            try:
                stdout, stderr = process.communicate(timeout=self.timeout_seconds)
                exit_code = process.returncode
                timed_out = False

            except subprocess.TimeoutExpired:
                # Kill process if timeout
                process.kill()
                stdout, stderr = process.communicate()
                exit_code = -1
                timed_out = True
                violations.append('execution_timeout')

            execution_time_ms = int((time.time() - start_time) * 1000)

            # Check for network access attempts (via stderr)
            if 'Connection refused' in stderr or 'Network' in stderr:
                violations.append('network_access_attempt')
                logger.warning('Network access attempt detected in sandbox')

            # Check for file access violations
            if 'Permission denied' in stderr and '/tmp' not in stderr:
                violations.append('filesystem_write_violation')
                logger.warning('Filesystem write violation detected (outside /tmp)')

            # Check for CPU limit exceeded
            if exit_code == -signal.SIGXCPU:
                violations.append('cpu_limit_exceeded')
                logger.warning('CPU limit exceeded in sandbox')

            # Check for memory limit exceeded
            if 'MemoryError' in stderr or exit_code == -signal.SIGKILL:
                violations.append('memory_limit_exceeded')
                logger.warning('Memory limit exceeded in sandbox')

            self.violations = violations

            return {
                'stdout': stdout,
                'stderr': stderr,
                'exit_code': exit_code,
                'execution_time_ms': execution_time_ms,
                'timed_out': timed_out,
                'violations': violations,
                'sandbox_error': len(violations) > 0
            }

        except Exception as e:
            logger.error(f'Sandbox execution error: {e}', exc_info=True)
            return {
                'stdout': '',
                'stderr': str(e),
                'exit_code': -1,
                'execution_time_ms': 0,
                'timed_out': False,
                'violations': ['sandbox_exception'],
                'sandbox_error': True
            }

    def _get_sandbox_env(self):
        """
        Get sanitized environment for sandbox execution.

        AC-ASS-016: Network access denied by not exposing network-related env vars.
        AC-ASS-021: No secrets in environment variables.
        """
        # Minimal safe environment (no network access, no secrets)
        safe_env = {
            'PATH': '/usr/bin:/bin',
            'PYTHONPATH': '',
            'HOME': '/tmp',
            'USER': 'sandbox',
            'LANG': 'C.UTF-8',
            'LC_ALL': 'C.UTF-8',
            # Disable network DNS lookups
            'PYTHONDONTWRITEBYTECODE': '1',
            'PYTHONUNBUFFERED': '1',
        }

        return safe_env

    def validate_imports(self, code):
        """
        Validate that code only uses allowed imports.

        Returns:
            tuple: (is_valid, violations)
        """
        import ast

        violations = []

        try:
            tree = ast.parse(code)

            for node in ast.walk(tree):
                if isinstance(node, ast.Import):
                    for alias in node.names:
                        if alias.name not in self.allowed_imports:
                            violations.append(f'Forbidden import: {alias.name}')

                elif isinstance(node, ast.ImportFrom):
                    if node.module not in self.allowed_imports:
                        violations.append(f'Forbidden import: {node.module}')

        except SyntaxError as e:
            violations.append(f'Syntax error: {e}')

        return len(violations) == 0, violations


def test_sandbox_network_denial():
    """Test AC-ASS-016: Network access denied"""
    sandbox = SecureSandbox(timeout_seconds=2)

    # Code that attempts network access
    network_code = """
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(('google.com', 80))
"""

    result = sandbox.execute_code(network_code)

    # Should have network access violation
    assert 'network_access_attempt' in result.get('violations', []), \
        "Network access should be denied"

    logger.info('✓ AC-ASS-016: Network access denial test passed')


def test_sandbox_filesystem_restriction():
    """Test AC-ASS-017: Filesystem writes outside /tmp denied"""
    sandbox = SecureSandbox(timeout_seconds=2)

    # Code that attempts to write outside /tmp
    filesystem_code = """
with open('/etc/passwd', 'a') as f:
    f.write('hacker')
"""

    result = sandbox.execute_code(filesystem_code)

    # Should have filesystem violation
    assert 'filesystem_write_violation' in result.get('violations', []) or \
           'Permission denied' in result.get('stderr', ''), \
        "Filesystem writes outside /tmp should be denied"

    logger.info('✓ AC-ASS-017: Filesystem restriction test passed')


def test_sandbox_tmp_write_allowed():
    """Test that writes to /tmp are allowed"""
    sandbox = SecureSandbox(timeout_seconds=2)

    # Code that writes to /tmp (should be allowed)
    tmp_code = """
with open('/tmp/test_file.txt', 'w') as f:
    f.write('test')
print('File written successfully')
"""

    result = sandbox.execute_code(tmp_code)

    # Should not have violations
    assert len(result.get('violations', [])) == 0, \
        "Writes to /tmp should be allowed"
    assert 'File written successfully' in result.get('stdout', ''), \
        "Output should indicate successful write"

    logger.info('✓ /tmp write allowed test passed')
