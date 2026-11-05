import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';

/// In-memory fake: read states live as long as the instance.
/// Replace with a Dio-based implementation when the API exists.
class MockNotificationRepository implements NotificationRepository {
  MockNotificationRepository({
    DateTime Function()? clock,
    this.latency = const Duration(milliseconds: 400),
  }) : _items = _seed((clock ?? DateTime.now)());

  final Duration latency;
  final List<AppNotification> _items;

  static List<AppNotification> _seed(DateTime now) {
    DateTime daysAgo(int days, int h, int m) =>
        DateTime(now.year, now.month, now.day - days, h, m);
    final ago = now.subtract;

    return [
      AppNotification(
        id: 'room-change-gl',
        category: NotificationCategory.academic,
        label: 'Urgent Academic',
        title: 'Room Change: Génie Logiciel',
        body: 'Lecture today at **10:15** moved from ~~Amphi 3B~~ to '
            '==Grand Amphi C== due to faculty seminar.',
        receivedAt: ago(const Duration(minutes: 15)),
        isUrgent: true,
        attachment: const PlaceAttachment('Grand Amphi C, Pavillon Principal'),
        link: const NotificationLink(NotificationDestination.timetable),
      ),
      AppNotification(
        id: 'ride-confirmed-es-4091',
        category: NotificationCategory.covoiturage,
        label: 'Covoiturage',
        title: 'Ride Booking Confirmed with Sarra K.',
        body: 'Departure today at **13h15** from **Tunis Passage**. '
            'Tap to view car details and contact driver.',
        receivedAt: ago(const Duration(hours: 1)),
        attachment: const RideAttachment(
          driverName: 'Sarra K.',
          carLabel: 'Clio 4 · Blanc glacier',
          isDriverVerified: true,
        ),
        link: const NotificationLink(NotificationDestination.ride, id: 'es-4091'),
      ),
      AppNotification(
        id: 'exam-timetable-s8',
        category: NotificationCategory.academic,
        label: 'Registrar Notice',
        title: 'Exam Timetable Published: Session Principale',
        body: 'Check your assigned exam dates and rooms for Semester 8 exams starting '
            '**June 2nd**. Download PDF convocation before May 30.',
        receivedAt: daysAgo(1, 14, 30),
        isRead: true,
        attachment: const ScheduleAttachment(),
        link: const NotificationLink(NotificationDestination.timetable),
      ),
      AppNotification(
        id: 'grade-bdd',
        category: NotificationCategory.academic,
        label: 'Grades',
        title: 'Nouvelle note publiée : Bases de Données',
        body: 'Your **DS** mark for Bases de Données is now available. '
            'Moyenne de la classe : **12.4**.',
        receivedAt: daysAgo(1, 9, 10),
        isRead: true,
        link: const NotificationLink(NotificationDestination.grades),
      ),
      AppNotification(
        id: 'lost-found-492',
        category: NotificationCategory.lostFound,
        label: 'Lost & Found',
        title: 'Potential match for your lost item',
        body: 'A calculator matching your description (Casio fx-991EX with purple '
            'sticker) was turned in at **Bloc C reception**.',
        receivedAt: ago(const Duration(days: 2, hours: 3)),
        isRead: true,
        isUrgent: true,
        attachment: const PickupAttachment(
          availability: 'Available for pickup until 17h00',
          ticket: '492',
        ),
        link: const NotificationLink(NotificationDestination.forum),
      ),
      AppNotification(
        id: 'forum-reply',
        category: NotificationCategory.community,
        label: 'Forum',
        title: 'Nouvelle réponse à votre annonce',
        body: '**Youssef M.** a répondu à votre post covoiturage ==Passage → Ghazela==.',
        receivedAt: ago(const Duration(days: 2, hours: 6)),
        isRead: true,
        link: const NotificationLink(NotificationDestination.forum),
      ),
      AppNotification(
        id: 'job-instadeep-viewed',
        category: NotificationCategory.career,
        label: 'Career',
        title: 'Application viewed by InstaDeep',
        body: 'Your application for **Junior AI & ML Research Intern** was viewed '
            'by the recruiting team.',
        receivedAt: ago(const Duration(days: 3, hours: 2)),
        link: const NotificationLink(NotificationDestination.job, id: 'instadeep-ml'),
      ),
      AppNotification(
        id: 'course-material-gl',
        category: NotificationCategory.academic,
        label: 'Course Update',
        title: 'New course material: Génie Logiciel',
        body: 'Prof. Ben Ali uploaded **Chapitre 7 – Design Patterns** slides '
            'and the TP 5 statement.',
        receivedAt: ago(const Duration(days: 4, hours: 1)),
        isRead: true,
        link: const NotificationLink(NotificationDestination.courses),
      ),
      AppNotification(
        id: 'carpool-digest',
        category: NotificationCategory.covoiturage,
        label: 'Covoiturage',
        title: 'Weekly carpool digest',
        body: '**3 new rides** match your usual route Tunis Passage → Ghazela this week.',
        receivedAt: ago(const Duration(days: 5, hours: 4)),
        isRead: true,
        link: const NotificationLink(NotificationDestination.forum),
      ),
    ];
  }

  @override
  Future<Result<List<AppNotification>>> getNotifications() async {
    await Future<void>.delayed(latency);
    return Success(List<AppNotification>.unmodifiable(_items));
  }

  @override
  Future<Result<void>> markAsRead(String id) async {
    await Future<void>.delayed(latency);
    final index = _items.indexWhere((n) => n.id == id);
    if (index < 0) return const Err(ServerFailure('Notification not found.'));
    _items[index] = _items[index].copyWith(isRead: true);
    return const Success(null);
  }

  @override
  Future<Result<void>> markAllAsRead() async {
    await Future<void>.delayed(latency);
    for (var i = 0; i < _items.length; i++) {
      _items[i] = _items[i].copyWith(isRead: true);
    }
    return const Success(null);
  }
}
