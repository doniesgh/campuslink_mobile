/** Makes [text] match itself literally inside a regular expression. */
export const escapeRegex = (text: string): string => text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

/** Every accented form of a base letter (lowercase; the search is also case-insensitive). */
const LETTER_VARIANTS: Record<string, string> = {
  a: 'aàáâãäå',
  c: 'cç',
  e: 'eéèêë',
  i: 'iìíîï',
  n: 'nñ',
  o: 'oòóôõö',
  u: 'uùúûü',
  y: 'yýÿ',
};

/** "Hélène" → "helene": lowercase, without accents. */
export const foldAccents = (text: string): string =>
  text.normalize('NFD').replace(/\p{M}/gu, '').toLowerCase();

/**
 * A regular expression source that finds [word] whatever its accents:
 * "helene" and "hélène" both give `h[eéèêëEÉÈÊË]l[eéèêëEÉÈÊË]n[eéèêëEÉÈÊË]`.
 * Use it with the `i` flag. MongoDB's `$regex` ignores collations, hence this.
 */
export function accentInsensitivePattern(word: string): string {
  return [...foldAccents(word)]
    .map((char) => {
      const variants = LETTER_VARIANTS[char];
      return variants ? `[${variants}${variants.toUpperCase()}]` : escapeRegex(char);
    })
    .join('');
}

/** The words of a search box, without empty ones. */
export const searchWords = (q: string | undefined): string[] =>
  (q ?? '').split(/\s+/).filter((word) => word.length > 0);
