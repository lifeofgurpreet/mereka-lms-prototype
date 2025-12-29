#!/usr/bin/env node
/**
 * Extract video information from MCT course_content.ndjson export
 *
 * Outputs a JSON file with all video details for Mux migration
 */

import fs from 'node:fs';
import path from 'node:path';

const CONTENT_FILE = path.resolve('./exports/mct/structure/course_content.ndjson');
const OUTPUT_FILE = path.resolve('./exports/mct/videos_for_mux.json');

const videos = [];
const captions = [];

// Read course content
const lines = fs.readFileSync(CONTENT_FILE, 'utf8').split('\n').filter(Boolean);

for (const line of lines) {
  const course = JSON.parse(line);
  const { courseId, categoryId, categoryName } = course;

  if (!course.CourseItems) continue;

  for (const item of course.CourseItems) {
    if (item.ItemType !== 'Lesson') continue;
    const data = item.Data;
    if (!data || data.FileType !== 'Video') continue;

    const video = {
      // MCT identifiers
      mctLessonId: data.Id,
      mctCourseId: courseId,
      mctCategoryId: categoryId,
      mctCategoryName: categoryName.trim(),
      mctUuid: data.Uuid,

      // Video metadata
      title: data.Title || 'Untitled',
      description: data.Description || '',

      // URLs (with fresh SAS tokens)
      downloadUrl: data.DownloadUrl,
      playbackUrl: data.PlaybackUrl,
      thumbnailUrl: data.ThumbnailUrl,

      // Captions/subtitles
      textTracks: null,
    };

    // Parse captions if available
    if (data.VideoTextTracks) {
      try {
        const tracks = JSON.parse(data.VideoTextTracks);
        if (tracks.textTracks && tracks.textTracks.length > 0) {
          video.textTracks = tracks.textTracks;
          captions.push({
            videoId: data.Id,
            title: data.Title,
            tracks: tracks.textTracks
          });
        }
      } catch (e) {
        // Ignore parse errors
      }
    }

    videos.push(video);
  }
}

// Sort by category and course
videos.sort((a, b) => {
  if (a.mctCategoryId !== b.mctCategoryId) {
    return a.mctCategoryId - b.mctCategoryId;
  }
  return a.mctCourseId - b.mctCourseId;
});

// Generate statistics
const stats = {
  totalVideos: videos.length,
  videosWithCaptions: captions.length,
  byCategory: {},
};

for (const video of videos) {
  const cat = video.mctCategoryName;
  if (!stats.byCategory[cat]) {
    stats.byCategory[cat] = 0;
  }
  stats.byCategory[cat]++;
}

// Output
const output = {
  generatedAt: new Date().toISOString(),
  sasTokenExpiry: '~6 hours from generation',
  statistics: stats,
  videos: videos,
};

fs.writeFileSync(OUTPUT_FILE, JSON.stringify(output, null, 2));

console.log('Video Extraction Summary');
console.log('========================');
console.log(`Total videos: ${stats.totalVideos}`);
console.log(`Videos with captions: ${stats.videosWithCaptions}`);
console.log('\nBy Category:');
const sorted = Object.entries(stats.byCategory).sort((a, b) => b[1] - a[1]);
for (const [cat, count] of sorted) {
  console.log(`  ${cat}: ${count}`);
}
console.log(`\nOutput: ${OUTPUT_FILE}`);
