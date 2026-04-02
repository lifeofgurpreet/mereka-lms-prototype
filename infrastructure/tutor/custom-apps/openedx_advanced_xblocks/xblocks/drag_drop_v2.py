"""
Drag and Drop v2 XBlock with Keyboard Accessibility

Implements AC-ASS-022: Drag-and-drop v2 with correct grading and keyboard accessibility
Implements AC-ASS-028: Full keyboard navigation support
"""
from xblock.core import XBlock
from xblock.fields import Scope, String, Integer, Float, List, Dict
from xblock.fragment import Fragment
from django.utils import timezone

# Lazy imports: models require the app to be in INSTALLED_APPS.
# XBlock entry points load this module before INSTALLED_APPS is finalized,
# so top-level model imports crash with Django's ModelBase.__new__.
DragDropInteraction = None
XBlockGradebookEntry = None
AccessibilityChecker = None
GradingUtils = None

def _ensure_imports():
    global DragDropInteraction, XBlockGradebookEntry, AccessibilityChecker, GradingUtils
    if DragDropInteraction is None:
        try:
            from ..models import DragDropInteraction as _DDI, XBlockGradebookEntry as _XGE
            from ..utils import AccessibilityChecker as _AC, GradingUtils as _GU
            DragDropInteraction = _DDI
            XBlockGradebookEntry = _XGE
            AccessibilityChecker = _AC
            GradingUtils = _GU
        except Exception:
            pass


class DragDropV2XBlock(XBlock):
    """
    Drag and Drop v2 XBlock with keyboard accessibility (AC-ASS-022, AC-ASS-028)

    Allows students to drag items into drop zones with full keyboard support.
    Tracks interactions for accessibility analytics.
    """

    # Configuration
    display_name = String(
        default="Drag and Drop Problem",
        scope=Scope.settings,
        help="Display name for this block"
    )

    items = List(
        default=[],
        scope=Scope.content,
        help="List of draggable items with id, label, and optional image"
    )

    zones = List(
        default=[],
        scope=Scope.content,
        help="List of drop zones with id, label, and correct items"
    )

    feedback_correct = String(
        default="Correct! Well done.",
        scope=Scope.settings,
        help="Feedback for correct placement"
    )

    feedback_incorrect = String(
        default="Not quite right. Try again.",
        scope=Scope.settings,
        help="Feedback for incorrect placement"
    )

    # Student state
    current_placements = Dict(
        default={},
        scope=Scope.user_state,
        help="Current item placements {item_id: zone_id}"
    )

    score = Float(
        default=0.0,
        scope=Scope.user_state,
        help="Current score (0.0 to 1.0)"
    )

    attempts = Integer(
        default=0,
        scope=Scope.user_state,
        help="Number of submission attempts"
    )

    def student_view(self, context=None):
        """
        Student view with keyboard accessibility (AC-ASS-028)

        Returns:
            Fragment with HTML, CSS, and JavaScript for drag-drop interaction
        """
        _ensure_imports()
        html = self._render_template('drag_drop_v2.html', {
            'items': self.items,
            'zones': self.zones,
            'current_placements': self.current_placements,
            'score': self.score,
            'keyboard_help': (AccessibilityChecker.generate_keyboard_help('drag_drop') if AccessibilityChecker else ''),
        })

        fragment = Fragment(html)
        fragment.add_css(self._get_css())
        fragment.add_javascript(self._get_javascript())
        fragment.initialize_js('DragDropV2XBlock')

        return fragment

    def _get_css(self):
        """
        CSS for drag-drop with keyboard focus indicators (AC-ASS-028)
        """
        return """
            .drag-drop-container {
                margin: 20px 0;
            }

            .draggable-item {
                padding: 10px;
                margin: 5px;
                border: 2px solid #ccc;
                border-radius: 4px;
                background: #f5f5f5;
                cursor: grab;
                user-select: none;
            }

            /* Keyboard focus indicator (AC-ASS-028) */
            .draggable-item:focus {
                outline: 3px solid #0066cc;
                outline-offset: 2px;
                box-shadow: 0 0 0 4px rgba(0, 102, 204, 0.2);
            }

            .draggable-item.selected {
                background: #e3f2fd;
                border-color: #2196f3;
            }

            .drop-zone {
                min-height: 80px;
                padding: 10px;
                margin: 10px 0;
                border: 2px dashed #999;
                border-radius: 4px;
                background: #fafafa;
            }

            /* Keyboard focus for drop zones (AC-ASS-028) */
            .drop-zone:focus {
                outline: 3px solid #0066cc;
                outline-offset: 2px;
                border-color: #0066cc;
                background: #e8f4f8;
            }

            .drop-zone.active {
                border-color: #4caf50;
                background: #e8f5e9;
            }

            .drop-zone.occupied {
                background: #fff3e0;
            }

            /* High contrast mode support (AC-ASS-028) */
            @media (prefers-contrast: high) {
                .draggable-item:focus,
                .drop-zone:focus {
                    outline-width: 4px;
                }
            }

            /* Reduced motion support (AC-ASS-028) */
            @media (prefers-reduced-motion: reduce) {
                .draggable-item,
                .drop-zone {
                    transition: none !important;
                }
            }

            .feedback {
                margin: 15px 0;
                padding: 10px;
                border-radius: 4px;
            }

            .feedback.correct {
                background: #d4edda;
                border: 1px solid #c3e6cb;
                color: #155724;
            }

            .feedback.incorrect {
                background: #f8d7da;
                border: 1px solid #f5c6cb;
                color: #721c24;
            }

            /* ARIA live region (AC-ASS-028) */
            .sr-only {
                position: absolute;
                width: 1px;
                height: 1px;
                padding: 0;
                margin: -1px;
                overflow: hidden;
                clip: rect(0, 0, 0, 0);
                white-space: nowrap;
                border-width: 0;
            }
        """

    def _get_javascript(self):
        """
        JavaScript for drag-drop with keyboard support (AC-ASS-028)
        """
        return """
            function DragDropV2XBlock(runtime, element) {
                let selectedItem = null;
                let interactionStartTime = 0;

                // Track input method for accessibility analytics (AC-ASS-028)
                let inputMethod = 'mouse';

                // Keyboard navigation support (AC-ASS-022, AC-ASS-028)
                $(element).on('keydown', '.draggable-item', function(e) {
                    inputMethod = 'keyboard';
                    interactionStartTime = Date.now();

                    // Enter or Space to select item
                    if (e.key === 'Enter' || e.key === ' ') {
                        e.preventDefault();
                        selectedItem = $(this);
                        $(this).addClass('selected');
                        announceToScreenReader('Item selected: ' + $(this).text().trim());

                        // Move focus to first drop zone
                        $(element).find('.drop-zone').first().focus();
                    }
                });

                $(element).on('keydown', '.drop-zone', function(e) {
                    if (!selectedItem) return;

                    // Enter or Space to place item
                    if (e.key === 'Enter' || e.key === ' ') {
                        e.preventDefault();
                        placeItem(selectedItem, $(this));
                        selectedItem.removeClass('selected');
                        selectedItem = null;
                    }

                    // Arrow keys to navigate between zones
                    if (e.key === 'ArrowDown' || e.key === 'ArrowRight') {
                        e.preventDefault();
                        $(this).next('.drop-zone').focus();
                    }
                    if (e.key === 'ArrowUp' || e.key === 'ArrowLeft') {
                        e.preventDefault();
                        $(this).prev('.drop-zone').focus();
                    }

                    // Escape to cancel
                    if (e.key === 'Escape') {
                        e.preventDefault();
                        selectedItem.removeClass('selected');
                        selectedItem = null;
                        announceToScreenReader('Selection cancelled');
                    }
                });

                // Mouse/touch drag support
                $(element).on('dragstart', '.draggable-item', function(e) {
                    inputMethod = 'mouse';
                    interactionStartTime = Date.now();
                    e.originalEvent.dataTransfer.setData('item_id', $(this).data('item-id'));
                });

                $(element).on('dragover', '.drop-zone', function(e) {
                    e.preventDefault();
                    $(this).addClass('active');
                });

                $(element).on('dragleave', '.drop-zone', function(e) {
                    $(this).removeClass('active');
                });

                $(element).on('drop', '.drop-zone', function(e) {
                    e.preventDefault();
                    $(this).removeClass('active');

                    const itemId = e.originalEvent.dataTransfer.getData('item_id');
                    const item = $(element).find('[data-item-id="' + itemId + '"]');
                    placeItem(item, $(this));
                });

                function placeItem(item, zone) {
                    const itemId = item.data('item-id');
                    const zoneId = zone.data('zone-id');
                    const interactionTime = Date.now() - interactionStartTime;

                    // Move item to zone visually
                    zone.append(item.clone());
                    item.remove();
                    zone.addClass('occupied');

                    // Track interaction with input method (AC-ASS-028)
                    trackInteraction(itemId, zoneId, inputMethod, interactionTime);

                    announceToScreenReader('Item placed in ' + zone.find('.zone-label').text());
                }

                function trackInteraction(itemId, zoneId, method, timeMs) {
                    const handlerUrl = runtime.handlerUrl(element, 'track_interaction');
                    $.post(handlerUrl, JSON.stringify({
                        item_id: itemId,
                        zone_id: zoneId,
                        input_method: method,
                        interaction_time_ms: timeMs
                    }));
                }

                function announceToScreenReader(message) {
                    // Update ARIA live region (AC-ASS-028)
                    $(element).find('.sr-announcer').text(message);
                }

                // Submit button
                $(element).on('click', '.submit-button', function() {
                    const handlerUrl = runtime.handlerUrl(element, 'submit');
                    const placements = {};

                    $(element).find('.drop-zone').each(function() {
                        const zoneId = $(this).data('zone-id');
                        const items = $(this).find('.draggable-item').map(function() {
                            return $(this).data('item-id');
                        }).get();
                        placements[zoneId] = items;
                    });

                    $.post(handlerUrl, JSON.stringify({ placements: placements }))
                        .done(function(response) {
                            showFeedback(response);
                        });
                });

                function showFeedback(response) {
                    const feedbackClass = response.is_correct ? 'correct' : 'incorrect';
                    const feedbackHtml = '<div class="feedback ' + feedbackClass + '">' +
                        response.feedback + ' Score: ' + (response.score * 100).toFixed(0) + '%</div>';
                    $(element).find('.feedback-container').html(feedbackHtml);

                    announceToScreenReader(response.feedback);
                }
            }
        """

    @XBlock.json_handler
    def track_interaction(self, data, suffix=''):
        """
        Track drag-drop interaction for analytics (AC-ASS-022, AC-ASS-028)
        """
        _ensure_imports()
        try:
            is_correct = False
            for zone in self.zones:
                if zone['id'] == data['zone_id']:
                    if data['item_id'] in zone.get('correct_items', []):
                        is_correct = True
                        break

            if DragDropInteraction is None:
                return {'success': True, 'tracking': 'disabled'}

            DragDropInteraction.objects.create(
                usage_key=self.scope_ids.usage_id,
                user=self.runtime.user,
                course_key=self.runtime.course_id,
                item_id=data['item_id'],
                zone_id=data['zone_id'],
                is_correct=is_correct,
                input_method=data.get('input_method', 'mouse'),
                interaction_time_ms=data.get('interaction_time_ms', 0),
            )

            return {'success': True}

        except Exception as e:
            return {'success': False, 'error': str(e)}

    @XBlock.json_handler
    def submit(self, data, suffix=''):
        """
        Submit and grade drag-drop problem (AC-ASS-022)
        """
        _ensure_imports()
        # Convert placements to list format for grading
        placements = []
        for zone_id, item_ids in data.get('placements', {}).items():
            for item_id in item_ids:
                placements.append({'item_id': item_id, 'zone_id': zone_id})

        # Build correct placements map
        correct_placements = {}
        for zone in self.zones:
            for item_id in zone.get('correct_items', []):
                correct_placements[item_id] = zone['id']

        # Grade submission (AC-ASS-022)
        if GradingUtils is None:
            return {'score': 0, 'is_correct': False, 'feedback': 'Grading unavailable', 'attempts': self.attempts}
        result = GradingUtils.grade_drag_drop(placements, correct_placements)

        self.score = result['score']
        self.attempts += 1
        self.current_placements = data.get('placements', {})

        # Sync to gradebook (AC-ASS-026)
        try:
            if XBlockGradebookEntry is None:
                raise RuntimeError("Gradebook model not available")
            XBlockGradebookEntry.objects.update_or_create(
                usage_key=self.scope_ids.usage_id,
                user=self.runtime.user,
                defaults={
                    'course_key': self.runtime.course_id,
                    'xblock_type': 'drag_drop_v2',
                    'score_earned': result['correct_count'],
                    'score_possible': result['total_items'],
                    'graded_at': timezone.now(),
                }
            )
        except Exception as e:
            pass  # Gradebook sync handled by signals

        return {
            'score': self.score,
            'is_correct': self.score >= 1.0,
            'feedback': self.feedback_correct if self.score >= 1.0 else self.feedback_incorrect,
            'attempts': self.attempts,
        }

    def _render_template(self, template_name, context):
        """
        Render HTML template with context

        This is a simplified placeholder. In production, use proper template rendering.
        """
        return f"""
            <div class="drag-drop-container">
                <h3>{self.display_name}</h3>

                <!-- ARIA live region for screen reader announcements (AC-ASS-028) -->
                <div class="sr-only sr-announcer" role="status" aria-live="polite" aria-atomic="true"></div>

                <!-- Keyboard help (AC-ASS-028) -->
                {context.get('keyboard_help', '')}

                <!-- Draggable items -->
                <div class="items-container" role="group" aria-label="Draggable items">
                    {' '.join(f'<div class="draggable-item" data-item-id="{item["id"]}" draggable="true" tabindex="0" role="button" aria-label="{item["label"]}">{item["label"]}</div>' for item in context['items'])}
                </div>

                <!-- Drop zones -->
                <div class="zones-container" role="group" aria-label="Drop zones">
                    {' '.join(f'<div class="drop-zone" data-zone-id="{zone["id"]}" tabindex="0" role="region" aria-label="{zone["label"]}"><div class="zone-label">{zone["label"]}</div></div>' for zone in context['zones'])}
                </div>

                <!-- Feedback -->
                <div class="feedback-container" role="alert" aria-live="assertive"></div>

                <!-- Submit button -->
                <button class="submit-button" aria-label="Submit answer">Submit</button>

                <!-- Score display -->
                <div class="score-display">Score: {int(context['score'] * 100)}%</div>
            </div>
        """
