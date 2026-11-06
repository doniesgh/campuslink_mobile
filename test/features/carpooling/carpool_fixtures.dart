/// Real responses printed by the backend tests (backend/test), copied as-is
/// so the app and the API stay in agreement.
library;

/// POST /carpool/rides/es-4092/reservations {"seatIds":["s3"]}, sent by a
/// student after "Sarra Kefi" booked s2. Note the integer `pricePerSeat`.
const rideJson = r'''
{"id":"es-4092","code":"ES-4092","pickup":"Ariana Ville (Station Métro 2)","dropoff":"ESPRIT Charguia 2","pickupTag":"Métro 2","dropoffTag":"ESPRIT Charguia","dropoffNote":"Drop-off at the main entrance","departure":"2026-11-07T07:00:00.000Z","arrival":"2026-11-07T07:25:00.000Z","distanceKm":9.6,"pricePerSeat":2,"driver":{"name":"Youssef M.","rating":4.8,"profile":"3rd Year Computer Science student","ridesCompleted":21,"carModel":"Peugeot 208","carColor":"Grey","plate":"195 · TN · 4410","isCarVerified":true},"seats":[{"id":"s1","label":"Youssef M.","status":"driver"},{"id":"s2","label":"Sarra Kefi","status":"booked"},{"id":"s3","label":"You","status":"booked"},{"id":"s4","label":"Seat #4","status":"free"}],"amenities":["nonSmoking","airConditioned"]}
''';

/// GET /carpool/impact after the seed.
const impactJson = '{"savedKg":1420,"goalKg":2000}';
