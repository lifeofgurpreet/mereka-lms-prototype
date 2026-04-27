// Mock data mirrors Open edX API response shape so pages can be built
// before the real backend is wired up. Swap by flipping VITE_USE_MOCK_DATA.

export function mockCourses() {
  return {
    results: [
      {
        id: 'course-v1:Mereka+DESIGN101+2026',
        name: 'Design Thinking Foundations',
        org: 'Mereka',
        short_description: 'Learn the fundamentals of design thinking for problem-solving.',
        media: { course_image: { uri: '/assets/mock/design101.jpg' } },
        start: '2026-01-15T00:00:00Z',
        end: null,
        enrollment_start: '2025-12-01T00:00:00Z',
        pacing: 'self',
      },
      {
        id: 'course-v1:Mereka+ENTR201+2026',
        name: 'Entrepreneurship for Creators',
        org: 'Mereka',
        short_description: 'Turn your creative passion into a sustainable business.',
        media: { course_image: { uri: '/assets/mock/entr201.jpg' } },
        start: '2026-03-01T00:00:00Z',
        end: null,
        pacing: 'instructor',
      },
      {
        id: 'course-v1:Mereka+CRAFT301+2026',
        name: 'Sustainable Craft Production',
        org: 'Mereka',
        short_description: 'Build a craft business aligned with circular economy principles.',
        media: { course_image: { uri: '/assets/mock/craft301.jpg' } },
        start: '2026-02-10T00:00:00Z',
        end: null,
        pacing: 'self',
      },
    ],
    pagination: { count: 3, num_pages: 1, current_page: 1 },
  };
}

export function mockCourse(courseId) {
  const course = mockCourses().results.find((c) => c.id === courseId) ?? mockCourses().results[0];
  return {
    ...course,
    overview: 'Full course description would load here from Open edX.',
    effort: '4–6 hours/week',
    outline: {
      course_blocks: {
        blocks: {
          module_1: { id: 'module_1', display_name: 'Module 1: Introduction', children: ['unit_1', 'unit_2'] },
          unit_1: { id: 'unit_1', display_name: 'Welcome', type: 'vertical' },
          unit_2: { id: 'unit_2', display_name: 'Course expectations', type: 'vertical' },
        },
      },
    },
  };
}
