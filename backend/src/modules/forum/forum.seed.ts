import type { Types } from 'mongoose';

import { ForumPostModel } from './forum-post.model';
import { LostItemModel } from './lost-item.model';
import { LostItemRequestModel } from './lost-item-request.model';

/*
 * Demo content, ported from the app's MockForumRepository (same ids, same
 * text). The mock dates are relative to "now" ("12 min ago", "Hier, 16h30"),
 * so they are computed when the seed runs: running it again refreshes them.
 * Wall-clock times ("yesterday at 16:30") are campus time (Tunis).
 */

const MINUTE_MS = 60 * 1000;
const HOUR_MS = 60 * MINUTE_MS;

// Tunisia is UTC+1 all year (no daylight saving).
const CAMPUS_UTC_OFFSET_MS = HOUR_MS;

const minutesAgo = (now: Date, minutes: number) => new Date(now.getTime() - minutes * MINUTE_MS);

/** [hours] before [now], rounded down to the hour (the mock's "3 h ago, on the hour"). */
function hoursAgoOnTheHour(now: Date, hours: number): Date {
  const date = new Date(now.getTime() - hours * HOUR_MS);
  date.setUTCMinutes(0, 0, 0);
  return date;
}

/** [days] days before [now]'s campus date, at [hour]:[minute] campus time. */
function daysAgoAt(now: Date, days: number, hour: number, minute = 0): Date {
  const campusNow = new Date(now.getTime() + CAMPUS_UTC_OFFSET_MS);
  const campusWallClock = Date.UTC(
    campusNow.getUTCFullYear(),
    campusNow.getUTCMonth(),
    campusNow.getUTCDate() - days,
    hour,
    minute,
  );
  return new Date(campusWallClock - CAMPUS_UTC_OFFSET_MS);
}

function demoPosts(now: Date) {
  return [
    {
      _id: 'post-1',
      authorName: 'Sarra K.',
      authorInfo: '5A - Informatique',
      category: 'carpool',
      tag: '2 places',
      body:
        'Départ à 13h15 : Passage → ESPRIT Ghazela. Reste 2 places libres, ' +
        'contactez-moi en privé si intéressé(e) ! 🚗✨',
      place: 'Passage → Ghazela',
      postedAt: minutesAgo(now, 12),
    },
    {
      _id: 'post-2',
      authorName: 'Youssef M.',
      authorInfo: '3B - Télécom',
      category: 'lostFound',
      tag: 'Trouvé',
      body:
        'Calculatrice graphique TI-84 Plus oubliée sur une table au Bloc C ' +
        "(salle C12). Déposée à l'accueil du bloc !",
      place: 'Bloc C · Accueil',
      postedAt: minutesAgo(now, 45),
    },
    {
      _id: 'post-3',
      authorName: 'Amina T.',
      authorInfo: '4A - Data Science',
      category: 'idea',
      tag: 'Proposition',
      body:
        'Installation de bornes de recharge rapide supplémentaires près des ' +
        'espaces calmes de la bibliothèque centrale ? 💡',
      upvotes: 42,
      comments: 8,
      status: 'En examen BDE',
      postedAt: minutesAgo(now, 120),
    },
  ];
}

function demoLostItems(now: Date) {
  return [
    {
      _id: 'lf-409',
      kind: 'found',
      title: 'Calculatrice TI-84 Plus CE',
      category: 'calculator',
      zone: 'Bloc C',
      location: 'Salle C12 (Ghazela)',
      place: 'classroom',
      reporterName: 'Youssef M.',
      reportedAt: minutesAgo(now, 45),
      reference: 'TF-409',
      photoCount: 1,
      dropOffNote: "Déposé à l'accueil Bloc C",
      pickupDesk: 'Accueil Bloc C - Salle C12',
    },
    {
      _id: 'lf-411',
      kind: 'found',
      title: 'Sony WH-1000XM4 (Étui)',
      category: 'audio',
      zone: 'Bibliothèque',
      location: 'Bibliothèque centrale (Étage 1)',
      place: 'library',
      reporterName: 'Bibliothèque Staff',
      reporterIsStaff: true,
      reportedAt: hoursAgoOnTheHour(now, 3),
      photoCount: 2,
      pickupDesk: 'Bibliothèque centrale - Guichet Prêt',
      isSerialHidden: true,
    },
    {
      _id: 'lf-406',
      kind: 'lost',
      title: 'Clés Peugeot + Porte-clé ESPRIT',
      category: 'keys',
      zone: 'Parking',
      location: 'Parking Amphi A (Ghazela)',
      place: 'parking',
      reporterName: 'Meriem B.',
      reportedAt: daysAgoAt(now, 1, 16, 30),
      photoCount: 1,
      isUrgent: true,
      reward: 'Café offert ☕',
      distinctiveDetail: 'Boîtier 3 boutons noir',
    },
    {
      _id: 'lf-404',
      kind: 'lost',
      title: "Carte d'étudiant ESPRIT",
      category: 'card',
      zone: 'Bloc E',
      location: 'Hall Bloc E (Charguia)',
      place: 'other',
      reporterName: 'Rami T.',
      reportedAt: daysAgoAt(now, 1, 9, 45),
      distinctiveDetail: 'Pochette transparente bleue',
    },
    {
      _id: 'lf-402',
      kind: 'found',
      title: 'Gourde isotherme bleue',
      category: 'bottle',
      zone: 'Cafétéria',
      location: 'Cafétéria centrale (Ghazela)',
      place: 'cafeteria',
      reporterName: 'Agent de sécurité',
      reporterIsStaff: true,
      reportedAt: daysAgoAt(now, 2, 13),
      reference: 'TF-402',
      photoCount: 1,
      dropOffNote: "Déposé à l'accueil Bloc C",
      pickupDesk: 'Accueil Bloc C',
    },
    {
      _id: 'lf-398',
      kind: 'lost',
      title: 'Sac à dos Eastpak noir',
      category: 'bag',
      zone: 'Bloc H',
      location: 'Salle H204 (Ghazela)',
      place: 'classroom',
      reporterName: 'Ines K.',
      reportedAt: daysAgoAt(now, 3, 17),
      distinctiveDetail: 'Porte-clé drapeau Tunisie',
    },
  ];
}

/**
 * Demo data for this module. Called by `npm run seed` with the demo
 * student's id. Idempotent: the demo posts and items are replaced (fresh
 * dates), and the demo student's requests are cleared so the claim flow can
 * be shown again. Other students' requests and other posts are kept.
 */
export async function seedForum(demoUserId: Types.ObjectId, now = new Date()): Promise<void> {
  const posts = demoPosts(now);
  const items = demoLostItems(now);

  await ForumPostModel.deleteMany({ _id: { $in: posts.map((p) => p._id) } });
  await ForumPostModel.insertMany(posts);

  await LostItemModel.deleteMany({ _id: { $in: items.map((i) => i._id) } });
  await LostItemModel.insertMany(items);

  await LostItemRequestModel.deleteMany({ userId: demoUserId });
}
