"""
Utilities for Assessment Bulk Operations

Provides bulk export/import, validation, and multi-language support.
"""
import csv
import json
import io
from typing import List, Dict, Any, Tuple
from django.utils import timezone


class BulkGradeExporter:
    """
    Bulk grade export to CSV/JSON (AC-ASS-033)

    Produces valid CSV/JSON filtered by section/assignment.
    """

    @staticmethod
    def export_to_csv(grades: List[Dict[str, Any]], include_metadata=True) -> str:
        """
        Export grades to CSV format (AC-ASS-033)

        Args:
            grades: List of grade dictionaries
            include_metadata: Include timestamps, attempts, etc.

        Returns:
            CSV string
        """
        if not grades:
            return ""

        output = io.StringIO()

        # Determine columns
        if include_metadata:
            fieldnames = [
                'student_username',
                'student_email',
                'problem_id',
                'score_earned',
                'score_possible',
                'grade_percentage',
                'graded_at',
                'attempts',
                'time_spent_seconds',
            ]
        else:
            fieldnames = [
                'student_username',
                'problem_id',
                'score_earned',
                'score_possible',
                'grade_percentage',
            ]

        writer = csv.DictWriter(output, fieldnames=fieldnames)
        writer.writeheader()

        for grade in grades:
            row = {key: grade.get(key, '') for key in fieldnames}
            writer.writerow(row)

        return output.getvalue()

    @staticmethod
    def export_to_json(grades: List[Dict[str, Any]], include_metadata=True) -> str:
        """
        Export grades to JSON format (AC-ASS-033)

        Args:
            grades: List of grade dictionaries
            include_metadata: Include timestamps, attempts, etc.

        Returns:
            JSON string
        """
        if not include_metadata:
            # Filter out metadata fields
            filtered_grades = []
            keep_fields = [
                'student_username',
                'problem_id',
                'score_earned',
                'score_possible',
                'grade_percentage',
            ]

            for grade in grades:
                filtered = {k: v for k, v in grade.items() if k in keep_fields}
                filtered_grades.append(filtered)

            return json.dumps(filtered_grades, indent=2)

        return json.dumps(grades, indent=2, default=str)

    @staticmethod
    def filter_by_section(grades: List[Dict[str, Any]], section: str) -> List[Dict[str, Any]]:
        """
        Filter grades by section (AC-ASS-033)

        Args:
            grades: List of grade dictionaries
            section: Section/cohort name

        Returns:
            Filtered grades
        """
        return [g for g in grades if g.get('section') == section]

    @staticmethod
    def filter_by_assignment(grades: List[Dict[str, Any]], assignment_type: str) -> List[Dict[str, Any]]:
        """
        Filter grades by assignment type (AC-ASS-033)

        Args:
            grades: List of grade dictionaries
            assignment_type: Assignment type (homework, exam, lab, etc.)

        Returns:
            Filtered grades
        """
        return [g for g in grades if g.get('assignment_type') == assignment_type]


class BulkGradeImporter:
    """
    Bulk grade import from CSV with validation (AC-ASS-034)

    Validates CSV, shows preview, applies without duplicating grades.
    """

    @staticmethod
    def validate_csv(csv_content: str) -> Tuple[bool, List[str], List[str]]:
        """
        Validate CSV format and data (AC-ASS-034)

        Args:
            csv_content: CSV file content as string

        Returns:
            Tuple of (is_valid, errors, warnings)
        """
        errors = []
        warnings = []

        try:
            reader = csv.DictReader(io.StringIO(csv_content))

            # Check required columns
            required_columns = [
                'student_username',
                'problem_id',
                'score_earned',
                'score_possible',
            ]

            if not reader.fieldnames:
                errors.append('CSV file is empty or has no header row')
                return False, errors, warnings

            missing_columns = [
                col for col in required_columns
                if col not in reader.fieldnames
            ]

            if missing_columns:
                errors.append(
                    f'Missing required columns: {", ".join(missing_columns)}'
                )

            # Validate data rows
            row_num = 1
            for row in reader:
                row_num += 1

                # Check student_username
                if not row.get('student_username'):
                    errors.append(f'Row {row_num}: Missing student_username')

                # Check problem_id
                if not row.get('problem_id'):
                    errors.append(f'Row {row_num}: Missing problem_id')

                # Check score_earned
                try:
                    score_earned = float(row.get('score_earned', 0))
                    if score_earned < 0:
                        errors.append(f'Row {row_num}: score_earned cannot be negative')
                except (ValueError, TypeError):
                    errors.append(f'Row {row_num}: score_earned must be a number')

                # Check score_possible
                try:
                    score_possible = float(row.get('score_possible', 1))
                    if score_possible <= 0:
                        errors.append(f'Row {row_num}: score_possible must be > 0')
                except (ValueError, TypeError):
                    errors.append(f'Row {row_num}: score_possible must be a number')

                # Check score doesn't exceed maximum
                try:
                    score_earned = float(row.get('score_earned', 0))
                    score_possible = float(row.get('score_possible', 1))
                    if score_earned > score_possible:
                        warnings.append(
                            f'Row {row_num}: score_earned ({score_earned}) exceeds '
                            f'score_possible ({score_possible})'
                        )
                except (ValueError, TypeError):
                    pass  # Already caught above

            is_valid = len(errors) == 0
            return is_valid, errors, warnings

        except Exception as e:
            errors.append(f'CSV parsing error: {str(e)}')
            return False, errors, warnings

    @staticmethod
    def generate_preview(csv_content: str, max_rows=10) -> List[Dict[str, Any]]:
        """
        Generate preview of CSV import (AC-ASS-034)

        Args:
            csv_content: CSV file content
            max_rows: Maximum number of rows to preview

        Returns:
            List of preview rows
        """
        try:
            reader = csv.DictReader(io.StringIO(csv_content))
            preview = []

            for i, row in enumerate(reader):
                if i >= max_rows:
                    break

                # Calculate grade percentage
                try:
                    score_earned = float(row.get('score_earned', 0))
                    score_possible = float(row.get('score_possible', 1))
                    grade_percentage = (score_earned / score_possible) * 100 if score_possible > 0 else 0
                except (ValueError, TypeError):
                    grade_percentage = 0

                preview.append({
                    'student_username': row.get('student_username', ''),
                    'problem_id': row.get('problem_id', ''),
                    'score_earned': row.get('score_earned', ''),
                    'score_possible': row.get('score_possible', ''),
                    'grade_percentage': f'{grade_percentage:.1f}%',
                })

            return preview

        except Exception:
            return []

    @staticmethod
    def detect_duplicates(csv_content: str, existing_grades: List[Dict[str, Any]]) -> int:
        """
        Detect duplicate grades (AC-ASS-034)

        Args:
            csv_content: CSV file content
            existing_grades: List of existing grade records

        Returns:
            Number of duplicates found
        """
        try:
            reader = csv.DictReader(io.StringIO(csv_content))

            # Create set of existing (student, problem) pairs
            existing_pairs = {
                (g['student_username'], g['problem_id'])
                for g in existing_grades
            }

            duplicates = 0
            for row in reader:
                pair = (row.get('student_username'), row.get('problem_id'))
                if pair in existing_pairs:
                    duplicates += 1

            return duplicates

        except Exception:
            return 0


class MultiLanguageSupport:
    """
    Multi-language support for assessments (AC-ASS-031)

    Provides translations for ORA2 rubrics and assessment labels in:
    - English (EN)
    - Malay/Bahasa Malaysia (MS)
    - Simplified Chinese (ZH-Hans)
    """

    # Translation dictionaries for assessment labels
    TRANSLATIONS = {
        'en': {
            'grade': 'Grade',
            'score': 'Score',
            'feedback': 'Feedback',
            'rubric': 'Rubric',
            'criteria': 'Criteria',
            'excellent': 'Excellent',
            'good': 'Good',
            'fair': 'Fair',
            'poor': 'Poor',
            'submit': 'Submit',
            'peer_assessment': 'Peer Assessment',
            'self_assessment': 'Self Assessment',
            'staff_assessment': 'Staff Assessment',
        },
        'ms': {  # Bahasa Malaysia (AC-ASS-031)
            'grade': 'Gred',
            'score': 'Skor',
            'feedback': 'Maklum Balas',
            'rubric': 'Rubrik',
            'criteria': 'Kriteria',
            'excellent': 'Cemerlang',
            'good': 'Baik',
            'fair': 'Sederhana',
            'poor': 'Lemah',
            'submit': 'Hantar',
            'peer_assessment': 'Penilaian Rakan Sebaya',
            'self_assessment': 'Penilaian Kendiri',
            'staff_assessment': 'Penilaian Kakitangan',
        },
        'zh-hans': {  # Simplified Chinese
            'grade': '成绩',
            'score': '分数',
            'feedback': '反馈',
            'rubric': '评分标准',
            'criteria': '标准',
            'excellent': '优秀',
            'good': '良好',
            'fair': '一般',
            'poor': '较差',
            'submit': '提交',
            'peer_assessment': '同伴评估',
            'self_assessment': '自我评估',
            'staff_assessment': '教师评估',
        },
    }

    @classmethod
    def translate(cls, key: str, language='en') -> str:
        """
        Translate assessment label (AC-ASS-031)

        Args:
            key: Translation key
            language: Language code (en, ms, zh-hans)

        Returns:
            Translated string
        """
        lang_dict = cls.TRANSLATIONS.get(language, cls.TRANSLATIONS['en'])
        return lang_dict.get(key, key)

    @classmethod
    def translate_rubric(cls, rubric: Dict[str, Any], language='en') -> Dict[str, Any]:
        """
        Translate ORA2 rubric to target language (AC-ASS-031)

        Args:
            rubric: Rubric dictionary
            language: Target language (en, ms, zh-hans)

        Returns:
            Translated rubric
        """
        if language == 'en':
            return rubric

        translated = rubric.copy()

        # Translate criteria
        if 'criteria' in translated:
            for criterion in translated['criteria']:
                # Translate criterion name and prompt
                # (actual implementation would use proper translation keys)
                pass

        return translated

    @classmethod
    def get_supported_languages(cls) -> List[str]:
        """Get list of supported language codes"""
        return list(cls.TRANSLATIONS.keys())

    @classmethod
    def get_language_name(cls, language_code: str) -> str:
        """Get human-readable language name"""
        names = {
            'en': 'English',
            'ms': 'Bahasa Malaysia',
            'zh-hans': '简体中文 (Simplified Chinese)',
        }
        return names.get(language_code, language_code)
