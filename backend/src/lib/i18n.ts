import type { Request } from 'express';
import { z } from 'zod';

/**
 * The languages of the app and of what the server writes for a user (emails,
 * notifications). French is the default, as in the PWA.
 */
export const LOCALES = ['fr', 'en'] as const;
export type Locale = (typeof LOCALES)[number];
export const DEFAULT_LOCALE: Locale = 'fr';

/** [value] when it is a supported locale ("FR" and "en-GB" count), else null. */
export function pickLocale(value: unknown): Locale | null {
  if (typeof value !== 'string') return null;
  const language = value.trim().toLowerCase().split(/[-_]/)[0];
  return LOCALES.find((locale) => locale === language) ?? null;
}

/**
 * The first supported language of an `Accept-Language` header, honouring the
 * q-values ("en-US,en;q=0.9,fr;q=0.8" gives "en"), or null.
 */
export function localeFromAcceptLanguage(header: string | undefined): Locale | null {
  if (!header) return null;
  const ranked = header
    .split(',')
    .map((part, index) => {
      const [tag, ...params] = part.trim().split(';');
      const q = params.map((p) => /^\s*q=([\d.]+)\s*$/.exec(p)?.[1]).find(Boolean);
      return { tag, q: q === undefined ? 1 : Number(q), index };
    })
    .filter(({ q }) => Number.isFinite(q) && q > 0)
    .sort((a, b) => b.q - a.q || a.index - b.index);
  for (const { tag } of ranked) {
    const locale = pickLocale(tag);
    if (locale) return locale;
  }
  return null;
}

/**
 * The language of a request: the `Accept-Language` header the app sends
 * (`fr` or `en`), else [fallback]. For signed-out routes; once the user is
 * known, use their `locale`.
 */
export const localeOf = (req: Request, fallback: Locale = DEFAULT_LOCALE): Locale =>
  localeFromAcceptLanguage(req.get('accept-language')) ?? fallback;

/** A `locale` field of a body: "fr" or "en", any case. */
export const localeSchema = z.preprocess(
  (value) => (typeof value === 'string' ? value.trim().toLowerCase() : value),
  z.enum(LOCALES, { error: 'Language: choose fr or en' }),
);
