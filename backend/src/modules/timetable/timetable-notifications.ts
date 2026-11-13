import type { Locale } from '../../lib/i18n';
import { NotificationModel } from '../notifications/notification.model';
import { pushInBackground } from '../push/push.service';
import { localeOfUser, ROLES_WITH_CLASSES, UserModel } from '../users/user.model';
import type { TimetableSlot } from './timetable.model';

// When an admin adds, changes or removes a class of the weekly timetable,
// every student and teacher of the class group (everyone, for now: see
// classGroupOf) gets an in-app notification, pushed to their phones, in their
// language (French uses "tu"). Same wording as the PWA's timetable changes.

/** What an admin did to a class. */
export type SlotChange =
  | { type: 'created'; slot: TimetableSlot }
  | { type: 'updated'; before: TimetableSlot; after: TimetableSlot }
  | { type: 'deleted'; slot: TimetableSlot };

interface Text {
  title: string;
  body: string;
}

const WEEKDAYS: Record<Locale, string[]> = {
  en: ['Mondays', 'Tuesdays', 'Wednesdays', 'Thursdays', 'Fridays', 'Saturdays', 'Sundays'],
  fr: ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'],
};

const BADGE: Record<Locale, string> = { en: 'Timetable', fr: 'Emploi du temps' };

const isOnline = (s: TimetableSlot) => s.mode === 'online';

/** Where the class takes place: "in room B12" / "online" (or nothing known). */
function where(locale: Locale, s: TimetableSlot): string {
  const fr = locale === 'fr';
  if (isOnline(s)) return fr ? 'en ligne' : 'online';
  return fr ? `en salle ${s.room}` : `in room ${s.room}`;
}

/** The place in a "B12 → Online" change. */
const place = (locale: Locale, s: TimetableSlot): string =>
  isOnline(s) ? (locale === 'fr' ? 'En ligne' : 'Online') : s.room || '—';

/** The title and body of [change] for a reader in [locale], or null when nothing changed. */
export function changeText(locale: Locale, change: SlotChange): Text | null {
  const fr = locale === 'fr';
  const day = (s: TimetableSlot) => WEEKDAYS[locale][s.weekday - 1] ?? '';
  const prefix = (s: TimetableSlot) => (fr ? `${s.course} : ` : `${s.course}: `);
  /** "Mondays, 08:30–10:00" / "lundi de 08:30 à 10:00" */
  const when = (s: TimetableSlot) =>
    fr ? `${day(s)} de ${s.start} à ${s.end}` : `${day(s)}, ${s.start}–${s.end}`;

  if (change.type === 'created') {
    const s = change.slot;
    return {
      title: fr
        ? `${prefix(s)}nouveau cours le ${day(s)}, ${s.start}–${s.end}`
        : `${prefix(s)}new class on ${day(s)}, ${s.start}–${s.end}`,
      body: fr
        ? `Un nouveau cours est dans ton emploi du temps : **${s.course}** le ${when(s)}, ${where(locale, s)}.`
        : `A new class is in your timetable: **${s.course}** on ${when(s)}, ${where(locale, s)}.`,
    };
  }

  if (change.type === 'deleted') {
    const s = change.slot;
    return {
      title: fr
        ? `${prefix(s)}cours supprimé (${day(s)}, ${s.start})`
        : `${prefix(s)}class removed (${day(s)}, ${s.start})`,
      body: fr
        ? `Ton cours du ${when(s)} ne fait plus partie de ton emploi du temps.`
        : `Your class on ${when(s)} is no longer in your timetable.`,
    };
  }

  const { before: b, after: a } = change;
  const timeChanged = b.weekday !== a.weekday || b.start !== a.start || b.end !== a.end;
  if (timeChanged) {
    const title =
      b.weekday === a.weekday
        ? fr
          ? `${prefix(a)}horaire changé ${b.start} → ${a.start} (${day(a)})`
          : `${prefix(a)}time changed ${b.start} → ${a.start} (${day(a)})`
        : fr
          ? `${prefix(a)}cours déplacé ${day(b)}, ${b.start} → ${day(a)}, ${a.start}`
          : `${prefix(a)}class moved ${day(b)}, ${b.start} → ${day(a)}, ${a.start}`;
    return {
      title,
      body: fr
        ? `Désormais, ton cours a lieu le ${when(a)}, ${where(locale, a)}.`
        : `From now on, your class takes place on ${when(a)}, ${where(locale, a)}.`,
    };
  }

  const placeChanged = b.mode !== a.mode || (!isOnline(a) && b.room !== a.room);
  if (placeChanged) {
    return {
      title: fr
        ? `${prefix(a)}salle changée ${place(locale, b)} → ${place(locale, a)} (${day(a)}, ${a.start})`
        : `${prefix(a)}room changed ${place(locale, b)} → ${place(locale, a)} (${day(a)}, ${a.start})`,
      body: fr
        ? `Ton cours du ${when(a)} a désormais lieu ${where(locale, a)}.`
        : `Your class on ${when(a)} now takes place ${where(locale, a)}.`,
    };
  }

  if (isOnline(a) && b.meetUrl !== a.meetUrl) {
    return {
      title: fr
        ? `${prefix(a)}nouveau lien Google Meet (${day(a)}, ${a.start})`
        : `${prefix(a)}new Google Meet link (${day(a)}, ${a.start})`,
      body: fr
        ? `Ton cours en ligne du ${when(a)} a un nouveau lien Google Meet : ouvre l'emploi du temps pour le rejoindre.`
        : `Your online class on ${when(a)} has a new Google Meet link: open the timetable to join it.`,
    };
  }

  const detailsChanged =
    b.course !== a.course ||
    b.teacher !== a.teacher ||
    b.kind !== a.kind ||
    b.room !== a.room ||
    (b.notes ?? null) !== (a.notes ?? null) ||
    (b.coefficient ?? null) !== (a.coefficient ?? null);
  if (!detailsChanged) return null;
  return {
    title: fr
      ? `${prefix(a)}cours modifié (${day(a)}, ${a.start})`
      : `${prefix(a)}class updated (${day(a)}, ${a.start})`,
    body: fr
      ? `Les détails de ton cours du ${when(a)} ont changé : ouvre l'emploi du temps pour les voir.`
      : `The details of your class on ${when(a)} changed: open the timetable to see them.`,
  };
}

const slotIdOf = (change: SlotChange): string =>
  change.type === 'updated' ? change.after.slotId : change.slot.slotId;

/**
 * Tells every student and teacher about [change] (one notification each,
 * which replaces the previous one about the same class) and pushes it.
 * Returns how many people were notified (0 when nothing changed).
 */
export async function notifySlotChange(change: SlotChange): Promise<number> {
  const fr = changeText('fr', change);
  const en = changeText('en', change);
  if (!fr || !en) return 0;
  const texts: Record<Locale, Text> = { fr, en };

  const users = await UserModel.find({ role: { $in: ROLES_WITH_CLASSES } })
    .select('_id locale')
    .lean();
  if (users.length === 0) return 0;

  const key = `timetable-${slotIdOf(change)}`;
  await NotificationModel.deleteMany({ key, userId: { $in: users.map((u) => u._id) } });
  const receivedAt = new Date();
  const notifications = await NotificationModel.insertMany(
    users.map((user) => {
      const locale = localeOfUser(user);
      const text = texts[locale];
      return {
        userId: user._id,
        key,
        category: 'academic',
        label: BADGE[locale],
        title: text.title,
        body: text.body,
        receivedAt,
        isRead: false,
        isUrgent: false,
        link: { destination: 'timetable', id: null },
      };
    }),
  );
  await pushInBackground(notifications);
  return notifications.length;
}
