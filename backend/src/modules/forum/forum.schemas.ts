import { z } from 'zod';

import { LOST_ITEM_CATEGORIES, LOST_ITEM_KINDS, LOST_ITEM_PLACES } from './lost-item.model';

// Messages are shown as-is in the app, so they are written for students.
// The forum section is in French: messages added for publishing are too.

const PROOF_MISSING = 'Please add a detail that identifies the item.';

export const lostItemRequestSchema = z.object({
  proof: z
    .string({ error: PROOF_MISSING })
    .trim()
    .min(1, PROOF_MISSING)
    .max(500, 'Keep the detail under 500 characters.'),
});

export type LostItemRequestInput = z.infer<typeof lostItemRequestSchema>;

/** Required text, trimmed. */
const requiredText = (missing: string, max: number, tooLong: string) =>
  z.string({ error: missing }).trim().min(1, missing).max(max, tooLong);

/** Optional text, trimmed: missing, null or blank becomes null. */
const optionalText = (invalid: string, max: number, tooLong: string) =>
  z
    .string({ error: invalid })
    .trim()
    .max(max, tooLong)
    .nullish()
    .transform((value) => value || null);

/** Limits shared with the app's form (lib/features/forum/domain/forum_rules.dart). */
export const LOST_ITEM_LIMITS = {
  title: 80,
  zone: 40,
  location: 120,
  distinctiveDetail: 200,
  reward: 60,
  dropOffNote: 120,
  pickupDesk: 120,
} as const;

const L = LOST_ITEM_LIMITS;

/**
 * A Lost & Found notice published by a student. The fields are checked in
 * the order of the form, so the first message is about the first field to
 * fix. Kind-specific fields are refused on the other kind rather than
 * silently dropped.
 */
export const publishLostItemSchema = z
  .object({
    kind: z.enum(LOST_ITEM_KINDS, { error: "Indiquez si l'objet est perdu ou trouvé." }),
    title: requiredText(
      "Donnez un titre à l'annonce (ex : Calculatrice TI-84).",
      L.title,
      `Le titre ne doit pas dépasser ${L.title} caractères.`,
    ),
    category: z.enum(LOST_ITEM_CATEGORIES, { error: "Choisissez une catégorie d'objet." }),
    zone: requiredText(
      'Indiquez la zone (ex : Bloc C).',
      L.zone,
      `La zone ne doit pas dépasser ${L.zone} caractères.`,
    ),
    location: requiredText(
      'Précisez le lieu (ex : Salle C12).',
      L.location,
      `Le lieu ne doit pas dépasser ${L.location} caractères.`,
    ),
    place: z.enum(LOST_ITEM_PLACES, { error: 'Choisissez le type de lieu.' }),
    distinctiveDetail: optionalText(
      'Le détail distinctif doit être un texte.',
      L.distinctiveDetail,
      `Le détail distinctif ne doit pas dépasser ${L.distinctiveDetail} caractères.`,
    ),
    reward: optionalText(
      'La récompense doit être un texte.',
      L.reward,
      `La récompense ne doit pas dépasser ${L.reward} caractères.`,
    ),
    isUrgent: z
      .boolean({ error: 'Indiquez si la recherche est urgente (oui ou non).' })
      .nullish()
      .transform((value) => value ?? false),
    dropOffNote: optionalText(
      'La note de dépôt doit être un texte.',
      L.dropOffNote,
      `La note de dépôt ne doit pas dépasser ${L.dropOffNote} caractères.`,
    ),
    pickupDesk: optionalText(
      'Le lieu de retrait doit être un texte.',
      L.pickupDesk,
      `Le lieu de retrait ne doit pas dépasser ${L.pickupDesk} caractères.`,
    ),
  })
  .superRefine((item, ctx) => {
    const refuse = (path: string, message: string) =>
      ctx.addIssue({ code: 'custom', path: [path], message });

    if (item.kind === 'lost') {
      if (item.dropOffNote || item.pickupDesk) {
        refuse('pickupDesk', 'Le lieu de dépôt concerne uniquement les objets trouvés.');
      }
      return;
    }
    if (item.reward) refuse('reward', 'Une récompense concerne uniquement les objets perdus.');
    if (item.isUrgent) refuse('isUrgent', 'Seul un objet perdu peut être marqué urgent.');
    if (!item.dropOffNote && !item.pickupDesk) {
      refuse('pickupDesk', "Indiquez où l'objet a été déposé (ex : Accueil Bloc C).");
    }
  });

export type PublishLostItemInput = z.infer<typeof publishLostItemSchema>;

/** Limits shared with the app's form (lib/features/forum/domain/forum_rules.dart). */
export const IDEA_LIMITS = { bodyMin: 10, bodyMax: 500, tag: 24 } as const;

/** Badge of an idea published without a theme. */
export const DEFAULT_IDEA_TAG = 'Proposition';

const BODY_MISSING = 'Décrivez votre idée.';

/** An idea published by a student: the text, and an optional theme shown as its badge. */
export const publishIdeaSchema = z.object({
  body: z
    .string({ error: BODY_MISSING })
    .trim()
    .min(1, BODY_MISSING)
    .min(
      IDEA_LIMITS.bodyMin,
      `Votre idée est trop courte : ${IDEA_LIMITS.bodyMin} caractères minimum.`,
    )
    .max(
      IDEA_LIMITS.bodyMax,
      `Votre idée ne doit pas dépasser ${IDEA_LIMITS.bodyMax} caractères.`,
    ),
  tag: z
    .string({ error: 'Le thème doit être un texte.' })
    .trim()
    .max(IDEA_LIMITS.tag, `Le thème ne doit pas dépasser ${IDEA_LIMITS.tag} caractères.`)
    .nullish()
    .transform((value) => value || DEFAULT_IDEA_TAG),
});

export type PublishIdeaInput = z.infer<typeof publishIdeaSchema>;
