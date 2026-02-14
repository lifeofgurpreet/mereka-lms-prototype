"""
Utilities for Advanced XBlocks

Provides OLX export/import, accessibility helpers, and grading utilities.
"""
import json
import xml.etree.ElementTree as ET
from typing import Dict, List, Any


class OLXHandler:
    """
    OLX (Open Learning XML) export/import handler (AC-ASS-025)

    Ensures all advanced XBlocks can be exported and imported without data loss.
    """

    @staticmethod
    def export_randomized_pool(pool_config: Dict[str, Any]) -> str:
        """
        Export randomized question pool to OLX

        Args:
            pool_config: Dictionary with pool configuration
                - pool_id: Unique pool identifier
                - total_questions: Total questions in pool
                - questions_to_show: Questions to show per student
                - questions: List of question content

        Returns:
            OLX XML string
        """
        root = ET.Element('randomized_pool')
        root.set('pool_id', pool_config['pool_id'])
        root.set('total_questions', str(pool_config['total_questions']))
        root.set('questions_to_show', str(pool_config['questions_to_show']))

        for i, question in enumerate(pool_config.get('questions', [])):
            question_elem = ET.SubElement(root, 'question')
            question_elem.set('index', str(i))
            question_elem.text = question

        return ET.tostring(root, encoding='unicode')

    @staticmethod
    def import_randomized_pool(olx_string: str) -> Dict[str, Any]:
        """
        Import randomized question pool from OLX

        Args:
            olx_string: OLX XML string

        Returns:
            Dictionary with pool configuration
        """
        root = ET.fromstring(olx_string)

        pool_config = {
            'pool_id': root.get('pool_id'),
            'total_questions': int(root.get('total_questions')),
            'questions_to_show': int(root.get('questions_to_show')),
            'questions': [],
        }

        for question_elem in root.findall('question'):
            pool_config['questions'].append(question_elem.text or '')

        return pool_config

    @staticmethod
    def export_drag_drop(drag_drop_config: Dict[str, Any]) -> str:
        """
        Export drag-and-drop v2 configuration to OLX

        Args:
            drag_drop_config: Dictionary with drag-drop configuration
                - items: List of draggable items
                - zones: List of drop zones
                - feedback: Feedback configuration

        Returns:
            OLX XML string
        """
        root = ET.Element('drag_and_drop_v2')

        # Export items
        items_elem = ET.SubElement(root, 'items')
        for item in drag_drop_config.get('items', []):
            item_elem = ET.SubElement(items_elem, 'item')
            item_elem.set('id', item['id'])
            item_elem.set('label', item['label'])
            if 'image_url' in item:
                item_elem.set('image_url', item['image_url'])

        # Export zones
        zones_elem = ET.SubElement(root, 'zones')
        for zone in drag_drop_config.get('zones', []):
            zone_elem = ET.SubElement(zones_elem, 'zone')
            zone_elem.set('id', zone['id'])
            zone_elem.set('label', zone['label'])
            zone_elem.set('correct_items', ','.join(zone.get('correct_items', [])))

        # Export feedback
        feedback_elem = ET.SubElement(root, 'feedback')
        feedback = drag_drop_config.get('feedback', {})
        feedback_elem.set('correct', feedback.get('correct', ''))
        feedback_elem.set('incorrect', feedback.get('incorrect', ''))

        return ET.tostring(root, encoding='unicode')

    @staticmethod
    def import_drag_drop(olx_string: str) -> Dict[str, Any]:
        """
        Import drag-and-drop v2 configuration from OLX

        Args:
            olx_string: OLX XML string

        Returns:
            Dictionary with drag-drop configuration
        """
        root = ET.fromstring(olx_string)

        drag_drop_config = {
            'items': [],
            'zones': [],
            'feedback': {},
        }

        # Import items
        items_elem = root.find('items')
        if items_elem is not None:
            for item_elem in items_elem.findall('item'):
                item = {
                    'id': item_elem.get('id'),
                    'label': item_elem.get('label'),
                }
                if item_elem.get('image_url'):
                    item['image_url'] = item_elem.get('image_url')
                drag_drop_config['items'].append(item)

        # Import zones
        zones_elem = root.find('zones')
        if zones_elem is not None:
            for zone_elem in zones_elem.findall('zone'):
                zone = {
                    'id': zone_elem.get('id'),
                    'label': zone_elem.get('label'),
                    'correct_items': zone_elem.get('correct_items', '').split(','),
                }
                drag_drop_config['zones'].append(zone)

        # Import feedback
        feedback_elem = root.find('feedback')
        if feedback_elem is not None:
            drag_drop_config['feedback'] = {
                'correct': feedback_elem.get('correct', ''),
                'incorrect': feedback_elem.get('incorrect', ''),
            }

        return drag_drop_config

    @staticmethod
    def export_math_input(math_config: Dict[str, Any]) -> str:
        """
        Export math input problem to OLX

        Args:
            math_config: Dictionary with math problem configuration
                - problem_text: Problem description
                - expected_answer: Expected LaTeX answer
                - tolerance: Numerical tolerance
                - hints: List of hints

        Returns:
            OLX XML string
        """
        root = ET.Element('math_input')

        problem_text = ET.SubElement(root, 'problem_text')
        problem_text.text = math_config.get('problem_text', '')

        expected_answer = ET.SubElement(root, 'expected_answer')
        expected_answer.text = math_config.get('expected_answer', '')

        tolerance = ET.SubElement(root, 'tolerance')
        tolerance.text = str(math_config.get('tolerance', 0.01))

        hints_elem = ET.SubElement(root, 'hints')
        for hint in math_config.get('hints', []):
            hint_elem = ET.SubElement(hints_elem, 'hint')
            hint_elem.text = hint

        return ET.tostring(root, encoding='unicode')

    @staticmethod
    def import_math_input(olx_string: str) -> Dict[str, Any]:
        """
        Import math input problem from OLX

        Args:
            olx_string: OLX XML string

        Returns:
            Dictionary with math problem configuration
        """
        root = ET.fromstring(olx_string)

        math_config = {
            'problem_text': '',
            'expected_answer': '',
            'tolerance': 0.01,
            'hints': [],
        }

        problem_text = root.find('problem_text')
        if problem_text is not None and problem_text.text:
            math_config['problem_text'] = problem_text.text

        expected_answer = root.find('expected_answer')
        if expected_answer is not None and expected_answer.text:
            math_config['expected_answer'] = expected_answer.text

        tolerance = root.find('tolerance')
        if tolerance is not None and tolerance.text:
            math_config['tolerance'] = float(tolerance.text)

        hints_elem = root.find('hints')
        if hints_elem is not None:
            for hint_elem in hints_elem.findall('hint'):
                if hint_elem.text:
                    math_config['hints'].append(hint_elem.text)

        return math_config


class AccessibilityChecker:
    """
    Accessibility validation for XBlocks (AC-ASS-028)

    Validates WCAG 2.1 AA compliance for keyboard navigation and ARIA attributes.
    """

    @staticmethod
    def validate_keyboard_navigation(element_config: Dict[str, Any]) -> List[str]:
        """
        Validate keyboard navigation for interactive elements

        Args:
            element_config: Dictionary with element configuration
                - type: Element type (button, draggable, dropzone)
                - tabindex: Tab index value
                - aria_label: ARIA label
                - keyboard_shortcuts: Supported keyboard shortcuts

        Returns:
            List of accessibility violations (empty if compliant)
        """
        violations = []

        # Check tabindex
        if 'tabindex' not in element_config:
            violations.append('Missing tabindex attribute')
        elif element_config['tabindex'] < 0:
            violations.append('Negative tabindex removes element from tab order')

        # Check ARIA label
        if 'aria_label' not in element_config or not element_config['aria_label']:
            violations.append('Missing aria-label for screen readers')

        # Check keyboard shortcuts
        if element_config.get('type') in ['draggable', 'dropzone']:
            required_shortcuts = ['Enter', 'Space', 'ArrowKeys']
            supported = element_config.get('keyboard_shortcuts', [])

            for shortcut in required_shortcuts:
                if shortcut not in supported:
                    violations.append(f'Missing keyboard shortcut: {shortcut}')

        return violations

    @staticmethod
    def validate_aria_attributes(xblock_html: str) -> List[str]:
        """
        Validate ARIA attributes in XBlock HTML

        Args:
            xblock_html: HTML string of XBlock content

        Returns:
            List of accessibility violations
        """
        violations = []

        # Check for ARIA live regions (required for drag-drop feedback)
        if 'aria-live' not in xblock_html and 'role="status"' not in xblock_html:
            violations.append('Missing ARIA live region for dynamic content')

        # Check for role attributes on interactive elements
        interactive_elements = ['button', 'draggable', 'dropzone']
        for element in interactive_elements:
            if element in xblock_html and 'role=' not in xblock_html:
                violations.append(f'Missing role attribute on {element}')

        return violations

    @staticmethod
    def generate_keyboard_help(xblock_type: str) -> str:
        """
        Generate keyboard navigation help text for XBlock

        Args:
            xblock_type: Type of XBlock (drag_drop, math_input, etc.)

        Returns:
            HTML string with keyboard help
        """
        help_texts = {
            'drag_drop': '''
                <div class="keyboard-help" role="complementary" aria-label="Keyboard navigation help">
                    <h3>Keyboard Navigation</h3>
                    <ul>
                        <li><kbd>Tab</kbd> - Navigate between items and zones</li>
                        <li><kbd>Enter</kbd> or <kbd>Space</kbd> - Select item or place in zone</li>
                        <li><kbd>Arrow Keys</kbd> - Move selected item between zones</li>
                        <li><kbd>Escape</kbd> - Cancel current selection</li>
                    </ul>
                </div>
            ''',
            'math_input': '''
                <div class="keyboard-help" role="complementary" aria-label="Keyboard navigation help">
                    <h3>Math Input</h3>
                    <ul>
                        <li>Type LaTeX expressions directly (e.g., \\frac{1}{2})</li>
                        <li><kbd>Tab</kbd> - Navigate between input fields</li>
                        <li><kbd>Enter</kbd> - Submit answer</li>
                    </ul>
                </div>
            ''',
        }

        return help_texts.get(xblock_type, '')


class GradingUtils:
    """
    Grading utilities for advanced XBlocks (AC-ASS-022, AC-ASS-023)
    """

    @staticmethod
    def grade_drag_drop(placements: List[Dict[str, str]],
                         correct_placements: Dict[str, str]) -> Dict[str, Any]:
        """
        Grade drag-and-drop v2 problem

        Args:
            placements: List of {item_id: zone_id} placements
            correct_placements: Dictionary of correct {item_id: zone_id}

        Returns:
            Dictionary with score and feedback
        """
        correct_count = 0
        total_items = len(correct_placements)

        for placement in placements:
            item_id = placement.get('item_id')
            zone_id = placement.get('zone_id')

            if correct_placements.get(item_id) == zone_id:
                correct_count += 1

        score = correct_count / total_items if total_items > 0 else 0.0

        return {
            'score': score,
            'correct_count': correct_count,
            'total_items': total_items,
            'feedback': f'You placed {correct_count} out of {total_items} items correctly.'
        }

    @staticmethod
    def grade_math_input(student_answer: str,
                          expected_answer: str,
                          tolerance: float = 0.01) -> Dict[str, Any]:
        """
        Grade math input problem with LaTeX expressions

        Args:
            student_answer: Student's LaTeX answer
            expected_answer: Expected LaTeX answer
            tolerance: Numerical tolerance for approximate answers

        Returns:
            Dictionary with score and feedback
        """
        # TODO: Implement LaTeX expression comparison
        # This would use sympy or similar library to:
        # 1. Parse LaTeX to symbolic expressions
        # 2. Simplify both expressions
        # 3. Compare symbolically or numerically with tolerance

        # For now, simple string comparison (placeholder)
        is_correct = student_answer.strip() == expected_answer.strip()

        return {
            'score': 1.0 if is_correct else 0.0,
            'is_correct': is_correct,
            'feedback': 'Correct!' if is_correct else 'Incorrect. Try again.',
        }
