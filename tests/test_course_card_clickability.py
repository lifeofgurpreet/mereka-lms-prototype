from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
COURSE_CARD_TEMPLATE = (
    REPO_ROOT
    / "infrastructure/tutor/themes/mereka/lms/templates/discovery/course_card.underscore"
)


def test_discovery_course_card_is_single_keyboard_link():
    template = COURSE_CARD_TEMPLATE.read_text()

    assert template.lstrip().startswith('<a href="/courses/<%- course %>/about"')
    assert 'class="course course-card-premium"' in template
    assert 'aria-label="<%- interpolate(' in template
    assert '<a href=' not in template[1:]
    assert '<span class="learn-more" aria-hidden="true">' in template
    assert 'class="learn-more"' in template


def test_discovery_course_card_preserves_about_url_contract():
    template = COURSE_CARD_TEMPLATE.read_text()

    assert '/courses/<%- course %>/about' in template
    assert "Explore Course" in template
