"""
Assessment Bulk Operations for Open edX

Provides enterprise-scale assessment management:
- Bulk regrade at scale (AC-ASS-029)
- Staff grade override with audit trail (AC-ASS-030)
- Multi-language support (AC-ASS-031)
- show_correctness timing controls (AC-ASS-032)
- Bulk grade export/import (AC-ASS-033, AC-ASS-034)
- IP logging for compliance (AC-ASS-035)
- Grade data isolation (AC-ASS-036)
"""

__version__ = '1.0.0'

default_app_config = 'openedx_assessment_bulk.apps.AssessmentBulkConfig'
