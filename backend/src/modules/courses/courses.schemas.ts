import { z } from 'zod';

// Messages are shown as-is in the app, so they are written for students.

/**
 * Lab submissions must be an https link to a repository (host + owner +
 * name, e.g. https://github.com/you/docker-lab). Same rule as the app's
 * isValidRepoUrl (course_logic.dart).
 */
export function isValidRepoUrl(value: string): boolean {
  const v = value.trim();
  if (!v || /\s/.test(v) || !/^https:\/\//i.test(v)) return false;
  let url: URL;
  try {
    url = new URL(v);
  } catch {
    return false;
  }
  if (url.protocol !== 'https:' || !url.hostname.includes('.')) return false;
  return url.pathname.split('/').filter((s) => s.length > 0).length >= 2;
}

export const attendanceSchema = z.object({
  present: z.boolean({ error: 'Say whether you were present (true or false)' }),
});

const repoUrlMessage = 'Enter a valid https:// repository link.';

export const submissionSchema = z.object({
  repoUrl: z
    .string({ error: repoUrlMessage })
    .trim()
    .max(500, 'This link is too long.')
    .refine(isValidRepoUrl, repoUrlMessage),
});

export type AttendanceInput = z.infer<typeof attendanceSchema>;
export type SubmissionInput = z.infer<typeof submissionSchema>;
