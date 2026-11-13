/// Real responses printed by the backend tests (backend/test), copied as-is
/// so the app and the API stay in agreement.
library;

/// POST /carpool/rides/es-4092/reservations {"seatIds":["s3"]}, sent by a
/// student after "Sarra Kefi" booked s2. Note the integer `pricePerSeat`.
const rideJson = r'''
{"id":"es-4092","code":"ES-4092","pickup":"Ariana Ville (Station Métro 2)","dropoff":"ESPRIT Charguia 2","pickupTag":"Métro 2","dropoffTag":"ESPRIT Charguia","dropoffNote":"Drop-off at the main entrance","departure":"2026-11-07T07:00:00.000Z","arrival":"2026-11-07T07:25:00.000Z","distanceKm":9.6,"pricePerSeat":2,"driver":{"name":"Youssef M.","rating":4.8,"profile":"3rd Year Computer Science student","ridesCompleted":21,"carModel":"Peugeot 208","carColor":"Grey","plate":"195 · TN · 4410","isCarVerified":true},"seats":[{"id":"s1","label":"Youssef M.","status":"driver"},{"id":"s2","label":"Sarra Kefi","status":"booked"},{"id":"s3","label":"You","status":"booked"},{"id":"s4","label":"Seat #4","status":"free"}],"amenities":["nonSmoking","airConditioned"],"isMine":false}
''';

/// The body of POST /carpool/rides sent for [createdRideJson] (no note, no
/// distance). [NewRideModel.toJson] must produce exactly this.
const newRideRequestJson = r'''
{"pickup":"Lac 2 (Tunis City)","pickupTag":"Lac 2","dropoff":"ESPRIT Ghazela (Bloc E)","dropoffTag":"ESPRIT Bloc E","departure":"2026-11-07T07:30:00.000Z","arrival":"2026-11-07T08:05:00.000Z","seatCount":3,"pricePerSeat":2.5,"carModel":"Volkswagen Polo","carColor":"Blue","plate":"231 TN 1187","amenities":["nonSmoking","musicOk"]}
''';

/// 201 answer to [newRideRequestJson], sent by "Dony Mansour", a 4th-year
/// Software Engineering student: a new driver (rating 0, 0 rides), an
/// unverified car, an empty note and a distance of 0 (not given).
const createdRideJson = r'''
{"id":"es-4094","code":"ES-4094","pickup":"Lac 2 (Tunis City)","dropoff":"ESPRIT Ghazela (Bloc E)","pickupTag":"Lac 2","dropoffTag":"ESPRIT Bloc E","dropoffNote":"","departure":"2026-11-07T07:30:00.000Z","arrival":"2026-11-07T08:05:00.000Z","distanceKm":0,"pricePerSeat":2.5,"driver":{"name":"Dony Mansour","rating":0,"profile":"4th Year Software Engineering student","ridesCompleted":0,"carModel":"Volkswagen Polo","carColor":"Blue","plate":"231 TN 1187","isCarVerified":false},"seats":[{"id":"s1","label":"Dony Mansour","status":"driver"},{"id":"s2","label":"Seat #2","status":"free"},{"id":"s3","label":"Seat #3","status":"free"},{"id":"s4","label":"Seat #4","status":"free"}],"amenities":["nonSmoking","musicOk"],"isMine":true}
''';

/// 422 answer to [newRideRequestJson] with `"seatCount": 5`.
const invalidRideJson = '{"message":"Proposez entre 1 et 4 places."}';

/// 409 answer when the driver of [createdRideJson] books its seat s2.
const ownRideJson = '{"message":"You can\'t book a seat in your own ride."}';
