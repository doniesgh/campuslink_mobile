// Real responses of the backend, printed once and pasted here as-is. The seed
// (seedForum, as in backend/test/forum.test.ts) ran with
// now = 2026-11-06T13:00:00.000Z (14:00 in Tunis). The publishing responses
// come from the same run (backend/test/forum-publish.test.ts flows): the demo
// student Dony Mansour (profile 4BI - Software Eng.) published two notices
// and an idea, then upvoted post-3; their dates are the real time of the run.
//
// The board and the Lost & Found management / matches responses were printed
// again (same seed time) by the demo student, once notices got a status, a
// reporter id, `isMine` / `canManage`, and the demo student's "lf-407".
//
// The publishing responses got the fields added since (status, reporterId,
// isMine, canManage: the API sends them on publish, see
// backend/test/forum-publish.test.ts).
//
// If the API shape changes, print them again and replace these strings.

const highlightsResponse = r'''
[{"id":"post-1","authorName":"Sarra K.","authorInfo":"5A - Informatique","category":"carpool","tag":"2 places","body":"Départ à 13h15 : Passage → ESPRIT Ghazela. Reste 2 places libres, contactez-moi en privé si intéressé(e) ! 🚗✨","place":"Passage → Ghazela","upvotes":0,"comments":0,"status":null,"postedAt":"2026-11-06T12:48:00.000Z","isUpvotedByMe":false},{"id":"post-2","authorName":"Youssef M.","authorInfo":"3B - Télécom","category":"lostFound","tag":"Trouvé","body":"Calculatrice graphique TI-84 Plus oubliée sur une table au Bloc C (salle C12). Déposée à l'accueil du bloc !","place":"Bloc C · Accueil","upvotes":0,"comments":0,"status":null,"postedAt":"2026-11-06T12:15:00.000Z","isUpvotedByMe":false},{"id":"post-3","authorName":"Amina T.","authorInfo":"4A - Data Science","category":"idea","tag":"Proposition","body":"Installation de bornes de recharge rapide supplémentaires près des espaces calmes de la bibliothèque centrale ? 💡","place":null,"upvotes":42,"comments":8,"status":"En examen BDE","postedAt":"2026-11-06T11:00:00.000Z","isUpvotedByMe":false}]
''';

const lostItemsResponse = r'''
[{"id":"lf-409","kind":"found","title":"Calculatrice TI-84 Plus CE","category":"calculator","zone":"Bloc C","location":"Salle C12 (Ghazela)","place":"classroom","reporterName":"Youssef M.","reporterIsStaff":false,"reportedAt":"2026-11-06T12:15:00.000Z","reference":"TF-409","photoCount":1,"isUrgent":false,"reward":null,"distinctiveDetail":null,"dropOffNote":"Déposé à l'accueil Bloc C","pickupDesk":"Accueil Bloc C - Salle C12","isSerialHidden":false,"status":"active","reporterId":null,"isMine":false,"canManage":false},{"id":"lf-411","kind":"found","title":"Sony WH-1000XM4 (Étui)","category":"audio","zone":"Bibliothèque","location":"Bibliothèque centrale (Étage 1)","place":"library","reporterName":"Bibliothèque Staff","reporterIsStaff":true,"reportedAt":"2026-11-06T10:00:00.000Z","reference":null,"photoCount":2,"isUrgent":false,"reward":null,"distinctiveDetail":null,"dropOffNote":null,"pickupDesk":"Bibliothèque centrale - Guichet Prêt","isSerialHidden":true,"status":"active","reporterId":null,"isMine":false,"canManage":false},{"id":"lf-406","kind":"lost","title":"Clés Peugeot + Porte-clé ESPRIT","category":"keys","zone":"Parking","location":"Parking Amphi A (Ghazela)","place":"parking","reporterName":"Meriem B.","reporterIsStaff":false,"reportedAt":"2026-11-05T15:30:00.000Z","reference":null,"photoCount":1,"isUrgent":true,"reward":"Café offert ☕","distinctiveDetail":"Boîtier 3 boutons noir","dropOffNote":null,"pickupDesk":null,"isSerialHidden":false,"status":"active","reporterId":null,"isMine":false,"canManage":false},{"id":"lf-407","kind":"lost","title":"Calculatrice graphique TI-84","category":"calculator","zone":"Bloc C","location":"Salle C10 (Ghazela)","place":"classroom","reporterName":"Dony Mansour","reporterIsStaff":false,"reportedAt":"2026-11-05T10:00:00.000Z","reference":null,"photoCount":0,"isUrgent":false,"reward":null,"distinctiveDetail":"Étiquette « D.M. » au dos","dropOffNote":null,"pickupDesk":null,"isSerialHidden":false,"status":"active","reporterId":"6af7375843ec09d651cca07e","isMine":true,"canManage":true},{"id":"lf-404","kind":"lost","title":"Carte d'étudiant ESPRIT","category":"card","zone":"Bloc E","location":"Hall Bloc E (Charguia)","place":"other","reporterName":"Rami T.","reporterIsStaff":false,"reportedAt":"2026-11-05T08:45:00.000Z","reference":null,"photoCount":0,"isUrgent":false,"reward":null,"distinctiveDetail":"Pochette transparente bleue","dropOffNote":null,"pickupDesk":null,"isSerialHidden":false,"status":"active","reporterId":null,"isMine":false,"canManage":false},{"id":"lf-402","kind":"found","title":"Gourde isotherme bleue","category":"bottle","zone":"Cafétéria","location":"Cafétéria centrale (Ghazela)","place":"cafeteria","reporterName":"Agent de sécurité","reporterIsStaff":true,"reportedAt":"2026-11-04T12:00:00.000Z","reference":"TF-402","photoCount":1,"isUrgent":false,"reward":null,"distinctiveDetail":null,"dropOffNote":"Déposé à l'accueil Bloc C","pickupDesk":"Accueil Bloc C","isSerialHidden":false,"status":"active","reporterId":null,"isMine":false,"canManage":false},{"id":"lf-398","kind":"lost","title":"Sac à dos Eastpak noir","category":"bag","zone":"Bloc H","location":"Salle H204 (Ghazela)","place":"classroom","reporterName":"Ines K.","reporterIsStaff":false,"reportedAt":"2026-11-03T16:00:00.000Z","reference":null,"photoCount":0,"isUrgent":false,"reward":null,"distinctiveDetail":"Porte-clé drapeau Tunisie","dropOffNote":null,"pickupDesk":null,"isSerialHidden":false,"status":"active","reporterId":null,"isMine":false,"canManage":false}]
''';

/// POST /forum/lost-items (lost item, 201).
const publishedLostItemResponse = r'''
{"id":"6aee35e06e9f2cab09553bb5","kind":"lost","title":"AirPods Pro (boîtier blanc)","category":"audio","zone":"Bloc E","location":"Salle E204 (Charguia)","place":"classroom","reporterName":"Dony Mansour","reporterIsStaff":false,"reportedAt":"2026-11-06T20:17:36.673Z","reference":"LF-412","photoCount":0,"isUrgent":true,"reward":"Café offert ☕","distinctiveDetail":"Gravure « D.M. » sur le boîtier","dropOffNote":null,"pickupDesk":null,"isSerialHidden":false,"status":"active","reporterId":"6af7375843ec09d651cca07e","isMine":true,"canManage":true}
''';

/// POST /forum/lost-items (found item, 201).
const publishedFoundItemResponse = r'''
{"id":"6aee35e06e9f2cab09553bb6","kind":"found","title":"Parapluie noir","category":"other","zone":"Bibliothèque","location":"Bibliothèque centrale (Étage 1)","place":"library","reporterName":"Dony Mansour","reporterIsStaff":false,"reportedAt":"2026-11-06T20:17:36.685Z","reference":"LF-413","photoCount":0,"isUrgent":false,"reward":null,"distinctiveDetail":null,"dropOffNote":null,"pickupDesk":"Accueil Bloc C","isSerialHidden":false,"status":"active","reporterId":"6af7375843ec09d651cca07e","isMine":true,"canManage":true}
''';

/// GET /forum/lost-items after publishing: the two new notices first (the
/// rest of the board is cut).
const lostItemsAfterPublishingResponse = r'''
[{"id":"6aee35e06e9f2cab09553bb6","kind":"found","title":"Parapluie noir","category":"other","zone":"Bibliothèque","location":"Bibliothèque centrale (Étage 1)","place":"library","reporterName":"Dony Mansour","reporterIsStaff":false,"reportedAt":"2026-11-06T20:17:36.685Z","reference":"LF-413","photoCount":0,"isUrgent":false,"reward":null,"distinctiveDetail":null,"dropOffNote":null,"pickupDesk":"Accueil Bloc C","isSerialHidden":false,"status":"active","reporterId":"6af7375843ec09d651cca07e","isMine":true,"canManage":true},{"id":"6aee35e06e9f2cab09553bb5","kind":"lost","title":"AirPods Pro (boîtier blanc)","category":"audio","zone":"Bloc E","location":"Salle E204 (Charguia)","place":"classroom","reporterName":"Dony Mansour","reporterIsStaff":false,"reportedAt":"2026-11-06T20:17:36.673Z","reference":"LF-412","photoCount":0,"isUrgent":true,"reward":"Café offert ☕","distinctiveDetail":"Gravure « D.M. » sur le boîtier","dropOffNote":null,"pickupDesk":null,"isSerialHidden":false,"status":"active","reporterId":"6af7375843ec09d651cca07e","isMine":true,"canManage":true}]
''';

/// POST /forum/ideas (201).
const publishedIdeaResponse = r'''
{"id":"6aee35e06e9f2cab09553bb7","authorName":"Dony Mansour","authorInfo":"4BI - Software Eng.","category":"idea","tag":"Vie de campus","body":"Un distributeur de boissons chaudes au Bloc E pour les cours du soir ?","place":null,"upvotes":0,"comments":0,"status":null,"postedAt":"2026-11-06T20:17:36.696Z","isUpvotedByMe":false}
''';

/// POST /forum/ideas/post-3/upvote by the demo student.
const ideaUpvoteResponse = r'''
{"upvotes":43,"isUpvotedByMe":true}
''';

/// GET /forum/ideas, seen by the demo student after the upvote.
const ideasResponse = r'''
[{"id":"post-3","authorName":"Amina T.","authorInfo":"4A - Data Science","category":"idea","tag":"Proposition","body":"Installation de bornes de recharge rapide supplémentaires près des espaces calmes de la bibliothèque centrale ? 💡","place":null,"upvotes":43,"comments":8,"status":"En examen BDE","postedAt":"2026-11-06T11:00:00.000Z","isUpvotedByMe":true},{"id":"6aee35e06e9f2cab09553bb7","authorName":"Dony Mansour","authorInfo":"4BI - Software Eng.","category":"idea","tag":"Vie de campus","body":"Un distributeur de boissons chaudes au Bloc E pour les cours du soir ?","place":null,"upvotes":0,"comments":0,"status":null,"postedAt":"2026-11-06T20:17:36.696Z","isUpvotedByMe":false}]
''';

/// GET /forum/highlights, seen by the demo student after the upvote.
const highlightsAfterVotingResponse = r'''
[{"id":"6aee35e06e9f2cab09553bb7","authorName":"Dony Mansour","authorInfo":"4BI - Software Eng.","category":"idea","tag":"Vie de campus","body":"Un distributeur de boissons chaudes au Bloc E pour les cours du soir ?","place":null,"upvotes":0,"comments":0,"status":null,"postedAt":"2026-11-06T20:17:36.696Z","isUpvotedByMe":false},{"id":"post-1","authorName":"Sarra K.","authorInfo":"5A - Informatique","category":"carpool","tag":"2 places","body":"Départ à 13h15 : Passage → ESPRIT Ghazela. Reste 2 places libres, contactez-moi en privé si intéressé(e) ! 🚗✨","place":"Passage → Ghazela","upvotes":0,"comments":0,"status":null,"postedAt":"2026-11-06T12:48:00.000Z","isUpvotedByMe":false},{"id":"post-2","authorName":"Youssef M.","authorInfo":"3B - Télécom","category":"lostFound","tag":"Trouvé","body":"Calculatrice graphique TI-84 Plus oubliée sur une table au Bloc C (salle C12). Déposée à l'accueil du bloc !","place":"Bloc C · Accueil","upvotes":0,"comments":0,"status":null,"postedAt":"2026-11-06T12:15:00.000Z","isUpvotedByMe":false},{"id":"post-3","authorName":"Amina T.","authorInfo":"4A - Data Science","category":"idea","tag":"Proposition","body":"Installation de bornes de recharge rapide supplémentaires près des espaces calmes de la bibliothèque centrale ? 💡","place":null,"upvotes":43,"comments":8,"status":"En examen BDE","postedAt":"2026-11-06T11:00:00.000Z","isUpvotedByMe":true}]
''';

/// PATCH /forum/lost-items/lf-407 by its reporter (the demo student), with
/// the edit form's body (LostItemDraft.toUpdateJson).
const editedLostItemResponse = r'''
{"id":"lf-407","kind":"lost","title":"Calculatrice graphique TI-84 Plus","category":"calculator","zone":"Bloc C","location":"Salle C10 (Ghazela)","place":"classroom","reporterName":"Dony Mansour","reporterIsStaff":false,"reportedAt":"2026-11-05T10:00:00.000Z","reference":null,"photoCount":0,"isUrgent":true,"reward":"Café offert ☕","distinctiveDetail":"Étiquette « D.M. » au dos","dropOffNote":null,"pickupDesk":null,"isSerialHidden":false,"status":"active","reporterId":"6af7375843ec09d651cca07e","isMine":true,"canManage":true}
''';

/// PATCH /forum/lost-items/lf-407 { "status": "resolved" } right after.
const resolvedLostItemResponse = r'''
{"id":"lf-407","kind":"lost","title":"Calculatrice graphique TI-84 Plus","category":"calculator","zone":"Bloc C","location":"Salle C10 (Ghazela)","place":"classroom","reporterName":"Dony Mansour","reporterIsStaff":false,"reportedAt":"2026-11-05T10:00:00.000Z","reference":null,"photoCount":0,"isUrgent":true,"reward":"Café offert ☕","distinctiveDetail":"Étiquette « D.M. » au dos","dropOffNote":null,"pickupDesk":null,"isSerialHidden":false,"status":"resolved","reporterId":"6af7375843ec09d651cca07e","isMine":true,"canManage":true}
''';

/// GET /forum/lost-items/lf-407/matches, rules only (no AI configured).
const lostItemMatchesResponse = r'''
{"items":[{"item":{"id":"lf-409","kind":"found","title":"Calculatrice TI-84 Plus CE","category":"calculator","zone":"Bloc C","location":"Salle C12 (Ghazela)","place":"classroom","reporterName":"Youssef M.","reporterIsStaff":false,"reportedAt":"2026-11-06T12:15:00.000Z","reference":"TF-409","photoCount":1,"isUrgent":false,"reward":null,"distinctiveDetail":null,"dropOffNote":"Déposé à l'accueil Bloc C","pickupDesk":"Accueil Bloc C - Salle C12","isSerialHidden":false,"status":"active","reporterId":null,"isMine":false,"canManage":false},"score":86,"reason":"Même catégorie · 1 jour d'écart · Lieu proche · Description proche","reasons":["Même catégorie","1 jour d'écart","Lieu proche","Description proche"],"ai":false}],"ai":false,"model":null}
''';

/// GET /forum/lost-items/lf-407/matches with the AI (a fake OpenRouter
/// answering 92 for lf-409): 0.3 x 86 + 0.7 x 92 = 90, the AI's reason.
const lostItemAiMatchesResponse = r'''
{"items":[{"item":{"id":"lf-409","kind":"found","title":"Calculatrice TI-84 Plus CE","category":"calculator","zone":"Bloc C","location":"Salle C12 (Ghazela)","place":"classroom","reporterName":"Youssef M.","reporterIsStaff":false,"reportedAt":"2026-11-06T12:15:00.000Z","reference":"TF-409","photoCount":1,"isUrgent":false,"reward":null,"distinctiveDetail":null,"dropOffNote":"Déposé à l'accueil Bloc C","pickupDesk":"Accueil Bloc C - Salle C12","isSerialHidden":false,"status":"active","reporterId":null,"isMine":false,"canManage":false},"score":90,"reason":"Même modèle TI-84, trouvée au Bloc C le lendemain.","reasons":["Même catégorie","1 jour d'écart","Lieu proche","Description proche"],"ai":true}],"ai":true,"model":"anthropic/claude-haiku-4.5"}
''';
