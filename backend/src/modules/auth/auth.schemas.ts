import { z } from 'zod';

// Messages are shown as-is in the app, so they are written for students.

const email = z
  .string({ error: 'Enter your email' })
  .trim()
  .toLowerCase()
  .pipe(z.email('Enter a valid email'));

const newPassword = z
  .string({ error: 'Choose a password' })
  .min(8, 'Use at least 8 characters')
  .max(128, 'Use at most 128 characters');

export const registerSchema = z.object({
  displayName: z
    .string({ error: 'Enter your name' })
    .trim()
    .min(1, 'Enter your name')
    .max(80, 'Name is too long'),
  email,
  password: newPassword,
});

export const loginSchema = z.object({
  identifier: z
    .string({ error: 'Enter your ENT ID or email' })
    .trim()
    .min(1, 'Enter your ENT ID or email'),
  password: z.string({ error: 'Enter your password' }).min(1, 'Enter your password'),
});

export const refreshSchema = z.object({
  refreshToken: z.string({ error: 'Missing refresh token' }).min(1, 'Missing refresh token'),
});

export const forgotPasswordSchema = z.object({ email });

export const resetPasswordSchema = z.object({
  token: z.string({ error: 'Missing reset token' }).min(1, 'Missing reset token'),
  password: newPassword,
});

export const verifyEmailSchema = z.object({
  code: z
    .string({ error: 'Enter the 6-digit code' })
    .trim()
    .regex(/^\d{6}$/, 'Enter the 6-digit code'),
});

export type RegisterInput = z.infer<typeof registerSchema>;
export type LoginInput = z.infer<typeof loginSchema>;
export type ResetPasswordInput = z.infer<typeof resetPasswordSchema>;
