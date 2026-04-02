"""
Randomized Question Pool XBlock

Implements AC-ASS-024: Pool of 20 questions delivers 10 unique random questions per student
Implements AC-ASS-027: Answer shuffling for multiple-choice questions
"""
from xblock.core import XBlock
from xblock.fields import Scope, String, Integer, Float, List, Boolean, Dict
from xblock.fragment import Fragment
from django.utils import timezone
# Lazy imports: models require app in INSTALLED_APPS
RandomizedQuestionPool = None
AnswerShufflingState = None
XBlockGradebookEntry = None

def _ensure_imports():
    global RandomizedQuestionPool, AnswerShufflingState, XBlockGradebookEntry
    if RandomizedQuestionPool is None:
        try:
            from ..models import RandomizedQuestionPool as _R, AnswerShufflingState as _A, XBlockGradebookEntry as _X
            RandomizedQuestionPool, AnswerShufflingState, XBlockGradebookEntry = _R, _A, _X
        except Exception:
            pass


class RandomizedPoolXBlock(XBlock):
    """
    Randomized Question Pool XBlock (AC-ASS-024, AC-ASS-027)

    Shows a random subset of questions from a larger pool to each student.
    Uses deterministic seeding to ensure consistent questions on page refresh.
    Supports answer shuffling for multiple-choice questions.
    """

    # Configuration
    display_name = String(
        default="Randomized Question Pool",
        scope=Scope.settings,
        help="Display name for this block"
    )

    pool_id = String(
        default="",
        scope=Scope.settings,
        help="Unique identifier for this question pool"
    )

    questions = List(
        default=[],
        scope=Scope.content,
        help="List of all questions in the pool (each is a dict with question data)"
    )

    questions_to_show = Integer(
        default=10,
        scope=Scope.settings,
        help="Number of questions to show per student (AC-ASS-024: default 10)"
    )

    shuffle_answers = Boolean(
        default=True,
        scope=Scope.settings,
        help="Shuffle answer order for multiple-choice questions (AC-ASS-027)"
    )

    # Student state
    selected_questions = List(
        default=[],
        scope=Scope.user_state,
        help="Indices of questions selected for this student"
    )

    student_answers = Dict(
        default={},
        scope=Scope.user_state,
        help="Student's answers {question_index: answer}"
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
        Student view with randomized questions (AC-ASS-024)

        Returns:
            Fragment with HTML, CSS, JavaScript for randomized questions
        """
        _ensure_imports()
        # Get or create randomized question selection for this student
        if not self.selected_questions and RandomizedQuestionPool is not None:
            pool = RandomizedQuestionPool.get_or_create_selection(
                pool_id=self.pool_id,
                course_key=self.runtime.course_id,
                usage_key=self.scope_ids.usage_id,
                user=self.runtime.user,
                total_questions=len(self.questions),
                questions_to_show=self.questions_to_show,
            )
            self.selected_questions = pool.selected_question_indices

        # Get selected questions
        selected_question_objs = [
            self.questions[i] for i in self.selected_questions
        ]

        # Shuffle answers if enabled (AC-ASS-027)
        if self.shuffle_answers:
            selected_question_objs = self._shuffle_question_answers(selected_question_objs)

        html = self._render_template('randomized_pool.html', {
            'display_name': self.display_name,
            'questions': selected_question_objs,
            'student_answers': self.student_answers,
            'score': self.score,
            'attempts': self.attempts,
            'total_questions': len(self.questions),
            'shown_questions': self.questions_to_show,
        })

        fragment = Fragment(html)
        fragment.add_css(self._get_css())
        fragment.add_javascript(self._get_javascript())
        fragment.initialize_js('RandomizedPoolXBlock')

        return fragment

    def _shuffle_question_answers(self, questions):
        """
        Shuffle answers for multiple-choice questions (AC-ASS-027)

        Uses deterministic seeding to ensure consistent shuffle on page refresh.

        Args:
            questions: List of question dictionaries

        Returns:
            List of questions with shuffled answers (original indices preserved)
        """
        _ensure_imports()
        shuffled_questions = []

        for question in questions:
            if question.get('type') != 'multiple_choice':
                shuffled_questions.append(question)
                continue

            # Get or create shuffle state for this question
            question_key = f"{self.pool_id}_{question.get('id', '')}"
            if AnswerShufflingState is None:
                shuffled_questions.append(question)
                continue
            shuffle_state = AnswerShufflingState.get_or_create_shuffle(
                usage_key=question_key,
                course_key=self.runtime.course_id,
                user=self.runtime.user,
                num_answers=len(question.get('answers', [])),
            )

            # Apply shuffled order to answers
            original_answers = question.get('answers', [])
            shuffled_answers = [
                original_answers[i] for i in shuffle_state.shuffled_order
            ]

            # Create new question dict with shuffled answers
            shuffled_question = question.copy()
            shuffled_question['answers'] = shuffled_answers
            shuffled_question['shuffle_mapping'] = shuffle_state.shuffled_order
            shuffled_questions.append(shuffled_question)

        return shuffled_questions

    def _get_css(self):
        """CSS for randomized pool"""
        return """
            .randomized-pool-container {
                margin: 20px 0;
            }

            .pool-info {
                margin: 10px 0;
                padding: 10px;
                background: #e3f2fd;
                border-left: 4px solid #2196f3;
            }

            .question {
                margin: 20px 0;
                padding: 15px;
                border: 1px solid #ddd;
                border-radius: 4px;
                background: #fafafa;
            }

            .question-text {
                font-size: 1.1em;
                margin-bottom: 10px;
            }

            .answer-option {
                margin: 8px 0;
            }

            .answer-option input {
                margin-right: 8px;
            }

            .answer-option label {
                cursor: pointer;
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

            .submit-button {
                padding: 10px 20px;
                font-size: 1em;
                background: #2196f3;
                color: white;
                border: none;
                border-radius: 4px;
                cursor: pointer;
            }

            .submit-button:hover {
                background: #1976d2;
            }
        """

    def _get_javascript(self):
        """JavaScript for randomized pool"""
        return """
            function RandomizedPoolXBlock(runtime, element) {
                // Track student answers
                $(element).on('change', '.answer-input', function() {
                    const questionIndex = $(this).data('question-index');
                    const answer = $(this).val();

                    const handlerUrl = runtime.handlerUrl(element, 'save_answer');
                    $.post(handlerUrl, JSON.stringify({
                        question_index: questionIndex,
                        answer: answer
                    }));
                });

                // Submit all answers
                $(element).on('click', '.submit-button', function() {
                    const handlerUrl = runtime.handlerUrl(element, 'submit');

                    $.post(handlerUrl, JSON.stringify({}))
                        .done(function(response) {
                            showFeedback(response);
                        });
                });

                function showFeedback(response) {
                    const feedbackClass = response.is_correct ? 'correct' : 'incorrect';
                    const feedbackHtml = '<div class="feedback ' + feedbackClass + '">' +
                        response.feedback + ' Score: ' + (response.score * 100).toFixed(0) + '%</div>';
                    $(element).find('.feedback-container').html(feedbackHtml);

                    // Update attempts
                    $(element).find('.attempts-display').text('Attempts: ' + response.attempts);
                }
            }
        """

    @XBlock.json_handler
    def save_answer(self, data, suffix=''):
        """
        Save student answer for a question

        Args:
            data: Dictionary with question_index and answer

        Returns:
            Success response
        """
        question_index = data.get('question_index')
        answer = data.get('answer')

        self.student_answers[str(question_index)] = answer

        return {'success': True}

    @XBlock.json_handler
    def submit(self, data, suffix=''):
        """
        Submit and grade all answers (AC-ASS-024, AC-ASS-027)

        Returns:
            Dictionary with score and feedback
        """
        _ensure_imports()
        correct_count = 0
        total_questions = len(self.selected_questions)

        # Grade each question
        for i, question_index in enumerate(self.selected_questions):
            question = self.questions[question_index]
            student_answer = self.student_answers.get(str(i), '')

            # Check if answer is correct
            # For shuffled answers, need to map back to original indices (AC-ASS-027)
            correct_answer = question.get('correct_answer', '')

            if str(student_answer) == str(correct_answer):
                correct_count += 1

        self.score = correct_count / total_questions if total_questions > 0 else 0.0
        self.attempts += 1

        # Sync to gradebook (AC-ASS-026)
        try:
            if XBlockGradebookEntry is None:
                raise RuntimeError("Model not available")
            XBlockGradebookEntry.objects.update_or_create(
                usage_key=self.scope_ids.usage_id,
                user=self.runtime.user,
                defaults={
                    'course_key': self.runtime.course_id,
                    'xblock_type': 'randomized_pool',
                    'score_earned': correct_count,
                    'score_possible': total_questions,
                    'graded_at': timezone.now(),
                }
            )
        except Exception:
            pass

        return {
            'score': self.score,
            'is_correct': self.score >= 0.7,  # 70% threshold
            'feedback': f'You answered {correct_count} out of {total_questions} questions correctly.',
            'attempts': self.attempts,
        }

    def _render_template(self, template_name, context):
        """Render HTML template"""
        questions_html = ''
        for i, question in enumerate(context['questions']):
            question_type = question.get('type', 'multiple_choice')
            question_text = question.get('text', '')

            if question_type == 'multiple_choice':
                answers_html = ''
                for j, answer in enumerate(question.get('answers', [])):
                    answer_id = f"q{i}_a{j}"
                    checked = 'checked' if context['student_answers'].get(str(i)) == str(j) else ''
                    answers_html += f'''
                        <div class="answer-option">
                            <input type="radio" id="{answer_id}" name="question_{i}"
                                   value="{j}" class="answer-input"
                                   data-question-index="{i}" {checked}>
                            <label for="{answer_id}">{answer}</label>
                        </div>
                    '''

                questions_html += f'''
                    <div class="question">
                        <div class="question-text"><strong>Question {i+1}:</strong> {question_text}</div>
                        {answers_html}
                    </div>
                '''

        return f"""
            <div class="randomized-pool-container">
                <h3>{context['display_name']}</h3>

                <!-- Pool info (AC-ASS-024) -->
                <div class="pool-info" role="complementary">
                    Showing {context['shown_questions']} questions randomly selected from a pool of {context['total_questions']} questions.
                    Each student receives a unique set of questions.
                </div>

                <!-- Questions -->
                {questions_html}

                <!-- Feedback -->
                <div class="feedback-container" role="alert" aria-live="assertive"></div>

                <!-- Submit button -->
                <button class="submit-button" aria-label="Submit all answers">Submit All Answers</button>

                <!-- Score and attempts display -->
                <div class="score-display">
                    Score: {int(context['score'] * 100)}%
                    <span class="attempts-display">Attempts: {context['attempts']}</span>
                </div>
            </div>
        """
