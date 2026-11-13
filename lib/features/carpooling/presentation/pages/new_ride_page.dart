import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/clock_provider.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_snack.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/bottom_action_bar.dart';
import '../../../../shared/widgets/detail_top_bar.dart';
import '../../../../shared/widgets/info_banner.dart';
import '../../domain/entities/new_ride.dart';
import '../../domain/entities/ride.dart';
import '../../domain/new_ride_rules.dart';
import '../providers/carpool_providers.dart';
import '../widgets/ride_form_widgets.dart';

/// "Proposer un trajet": the student publishes a ride as its driver.
/// Route: RoutePaths.newRide. No Stitch design: built on the look of the
/// ride detail screen. On success it opens the new ride's detail.
class NewRidePage extends ConsumerStatefulWidget {
  const NewRidePage({super.key});

  @override
  ConsumerState<NewRidePage> createState() => _NewRidePageState();
}

enum _Day { today, tomorrow, other }

class _NewRidePageState extends ConsumerState<NewRidePage> {
  static const _durationStep = 5;
  static const _minDuration = 5;
  static const _maxDuration = 12 * 60;
  static const _priceStep = 0.5;

  /// How far ahead "Autre date" lets the student pick.
  static const _bookingWindow = Duration(days: 60);

  final _formKey = GlobalKey<FormState>();
  final _pickup = TextEditingController();
  final _pickupTag = TextEditingController();
  final _dropoff = TextEditingController();
  final _dropoffTag = TextEditingController();
  final _carModel = TextEditingController();
  final _carColor = TextEditingController();
  final _plate = TextEditingController();
  final _note = TextEditingController();
  final _distance = TextEditingController();

  _Day _day = _Day.today;
  DateTime? _otherDate;
  TimeOfDay? _time;
  int _duration = 30;
  int _seats = 3;
  double _price = 2;
  final _amenities = <RideAmenity>{};

  /// After the first attempt, errors follow every change.
  bool _submitted = false;
  bool _publishing = false;

  @override
  void dispose() {
    for (final c in [
      _pickup, _pickupTag, _dropoff, _dropoffTag, _carModel, _carColor, _plate, _note, _distance,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  DateTime _now() => ref.read(clockProvider).valueOrNull ?? DateTime.now();

  DateTime? _date(DateTime now) => switch (_day) {
        _Day.today => DateTime(now.year, now.month, now.day),
        _Day.tomorrow => DateTime(now.year, now.month, now.day + 1),
        _Day.other => _otherDate,
      };

  DateTime? _departure(DateTime now) {
    final date = _date(now);
    final time = _time;
    if (date == null || time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  NewRide? _ride(DateTime now) {
    final departure = _departure(now);
    if (departure == null) return null;
    return NewRide(
      pickup: _pickup.text.trim(),
      pickupTag: _pickupTag.text.trim(),
      dropoff: _dropoff.text.trim(),
      dropoffTag: _dropoffTag.text.trim(),
      departure: departure,
      arrival: departure.add(Duration(minutes: _duration)),
      seatCount: _seats,
      pricePerSeat: _price,
      carModel: _carModel.text.trim(),
      carColor: _carColor.text.trim(),
      plate: _plate.text.trim(),
      amenities: [for (final a in RideAmenity.values) if (_amenities.contains(a)) a],
      dropoffNote: _note.text.trim(),
      distanceKm: NewRideRules.parseDistance(_distance.text),
    );
  }

  Future<void> _pickDay(DateTime now) async {
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _otherDate ?? today.add(const Duration(days: 2)),
      firstDate: today,
      lastDate: today.add(_bookingWindow),
      helpText: 'Jour du départ',
    );
    if (picked == null || !mounted) return;
    setState(() {
      switch (picked.difference(today).inDays) {
        case 0:
          _day = _Day.today;
        case 1:
          _day = _Day.tomorrow;
        default:
          _day = _Day.other;
          _otherDate = picked;
      }
    });
  }

  Future<void> _pickTime(DateTime now) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? _suggestedTime(now),
      helpText: 'Heure de départ',
      // Campus times are 24-hour ("13h15").
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _time = picked);
  }

  /// About an hour from [now], on the quarter: 10:07 -> 11:15.
  static TimeOfDay _suggestedTime(DateTime now) {
    final inAnHour = now.add(const Duration(hours: 1));
    final minutes = inAnHour.hour * 60 + ((inAnHour.minute + 14) ~/ 15) * 15;
    return TimeOfDay(hour: (minutes ~/ 60) % 24, minute: minutes % 60);
  }

  Future<void> _publish() async {
    if (_publishing) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitted = true);

    final now = _now();
    final ride = _ride(now);
    // In the order of the form: bring the first error into view.
    final invalid = _formKey.currentState!.validateGranularly();
    if (invalid.isNotEmpty || ride == null) {
      if (invalid.isNotEmpty) {
        Scrollable.ensureVisible(
          invalid.first.context,
          alignment: 0.2,
          duration: const Duration(milliseconds: 300),
        );
      }
      return;
    }
    // The same rules as the server, on the whole ride.
    final errors = validateNewRide(ride, now: now);
    if (errors.isNotEmpty) {
      showAppSnack(context, errors.values.first);
      return;
    }

    setState(() => _publishing = true);
    final result = await ref.read(carpoolRepositoryProvider).createRide(ride);
    if (!mounted) return;
    setState(() => _publishing = false);

    result.when(
      success: (created) {
        ref.invalidate(ridesProvider);
        showAppSnack(context, 'Trajet publié ! Les étudiants peuvent réserver vos places.');
        context.pushReplacement(RoutePaths.ride(created.id));
      },
      failure: (f) => showAppSnack(context, f.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: Form(
                key: _formKey,
                autovalidateMode:
                    _submitted ? AutovalidateMode.always : AutovalidateMode.disabled,
                // Not a ListView: a lazy list would leave the fields below the
                // fold out of the form's validation.
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const DetailTopBar(
                        backLabel: 'Forum',
                        fallbackPath: RoutePaths.forum,
                        trailing: [
                          Flexible(
                            child: AppBadge(
                              'Covoiturage',
                              tone: BadgeTone.neutral,
                              icon: Icons.directions_car_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text('Proposer un trajet', style: theme.textTheme.headlineSmall),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Partagez votre trajet : les étudiants ESPRIT réservent vos places libres.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _routeSection(),
                      const SizedBox(height: AppSpacing.md),
                      _scheduleSection(now),
                      const SizedBox(height: AppSpacing.md),
                      _seatsSection(),
                      const SizedBox(height: AppSpacing.md),
                      _carSection(),
                      const SizedBox(height: AppSpacing.md),
                      _amenitiesSection(),
                      const SizedBox(height: AppSpacing.md),
                      _detailsSection(),
                     
                    ],
                  ),
                ),
              ),
            ),
            BottomActionBar(
              leading: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'PAR PLACE',
                    style: theme.textTheme.labelSmall?.copyWith(color: muted),
                  ),
                  Text(_priceLabel(_price), style: theme.textTheme.titleLarge),
                  Text(
                    _seats == 1 ? '1 place proposée' : '$_seats places proposées',
                    style: theme.textTheme.labelSmall?.copyWith(color: muted),
                  ),
                ],
              ),
              action: AppButton(
                label: 'Publier',
                icon: Icons.check_rounded,
                variant: AppButtonVariant.accent,
                isLoading: _publishing,
                onPressed: _publish,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _priceLabel(double price) =>
      price == 0 ? 'Gratuit' : '${price.toStringAsFixed(1)} TND';

  Widget _routeSection() => RideFormSection(
        icon: Icons.alt_route,
        title: 'Itinéraire',
        subtitle: "Les repères courts s'affichent sur la carte du trajet.",
        children: [
          AppTextField(
            controller: _pickup,
            label: 'Départ',
            hint: 'Ex : Tunis Centre (Passage)',
            prefixIcon: Icons.trip_origin,
            textInputAction: TextInputAction.next,
            validator: NewRideRules.pickup,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _pickupTag,
            label: 'Repère du départ',
            hint: 'Ex : Passage',
            prefixIcon: Icons.label_outline,
            textInputAction: TextInputAction.next,
            validator: NewRideRules.pickupTag,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _dropoff,
            label: 'Destination',
            hint: 'Ex : ESPRIT Ghazela (Bloc H)',
            prefixIcon: Icons.school_outlined,
            textInputAction: TextInputAction.next,
            validator: NewRideRules.dropoff,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _dropoffTag,
            label: 'Repère de la destination',
            hint: 'Ex : ESPRIT Bloc H',
            prefixIcon: Icons.label_outline,
            textInputAction: TextInputAction.next,
            validator: NewRideRules.dropoffTag,
          ),
        ],
      );

  Widget _scheduleSection(DateTime now) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final departure = _departure(now);
    final arrival = departure?.add(Duration(minutes: _duration));
    final nextDay = departure != null &&
        arrival != null &&
        DateUtils.dateOnly(arrival).isAfter(DateUtils.dateOnly(departure));

    return RideFormSection(
      icon: Icons.schedule,
      title: 'Horaire',
      children: [
        const RideFieldLabel('Jour'),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            ChoiceChip(
              label: const Text("Aujourd'hui"),
              selected: _day == _Day.today,
              onSelected: (_) => setState(() => _day = _Day.today),
            ),
            ChoiceChip(
              label: const Text('Demain'),
              selected: _day == _Day.tomorrow,
              onSelected: (_) => setState(() => _day = _Day.tomorrow),
            ),
            ChoiceChip(
              avatar: const Icon(Icons.calendar_month_outlined, size: 18),
              label: Text(
                _day == _Day.other && _otherDate != null
                    ? _shortDate(_otherDate!)
                    : 'Autre date',
              ),
              selected: _day == _Day.other,
              onSelected: (_) => _pickDay(now),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        // The departure is checked with the rest of the form.
        FormField<void>(
          validator: (_) => NewRideRules.departure(departure, now: now),
          builder: (field) => RidePickerTile(
            label: 'Heure de départ',
            value: _time == null ? 'Choisir une heure' : _formatTime(_time!),
            placeholder: _time == null,
            icon: Icons.access_time,
            errorText: field.errorText,
            onTap: () => _pickTime(now),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        RideStepper(
          label: 'Durée du trajet',
          value: formatShortDuration(Duration(minutes: _duration)),
          caption: arrival == null
              ? 'Arrivée estimée : choisissez le départ'
              : 'Arrivée estimée : ${formatHm(arrival)}${nextDay ? ' (le lendemain)' : ''}',
          decrementTooltip: 'Raccourcir',
          incrementTooltip: 'Allonger',
          onDecrement: _duration <= _minDuration
              ? null
              : () => setState(() => _duration -= _durationStep),
          onIncrement: _duration >= _maxDuration
              ? null
              : () => setState(() => _duration += _durationStep),
        ),
        if (departure != null) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(Icons.event_outlined, size: 16, color: muted),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  formatDepartureLabel(departure, now: now),
                  style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _seatsSection() => RideFormSection(
        icon: Icons.event_seat_outlined,
        title: 'Places et prix',
        children: [
          RideStepper(
            label: 'Places passagers',
            caption: 'Sans compter la vôtre',
            value: '$_seats',
            decrementTooltip: 'Une place de moins',
            incrementTooltip: 'Une place de plus',
            onDecrement: _seats <= NewRideRules.minSeats ? null : () => setState(() => _seats--),
            onIncrement: _seats >= NewRideRules.maxSeats ? null : () => setState(() => _seats++),
          ),
          const Divider(height: AppSpacing.xl),
          RideStepper(
            label: 'Prix par place',
            caption: 'Par pas de 0,5 TND · 0 = gratuit',
            value: _priceLabel(_price),
            decrementTooltip: 'Baisser le prix',
            incrementTooltip: 'Augmenter le prix',
            onDecrement: _price <= 0 ? null : () => setState(() => _price -= _priceStep),
            onIncrement: _price >= NewRideRules.maxPricePerSeat
                ? null
                : () => setState(() => _price += _priceStep),
          ),
        ],
      );

  Widget _carSection() => RideFormSection(
        icon: Icons.directions_car_outlined,
        title: 'Véhicule',
        children: [
          AppTextField(
            controller: _carModel,
            label: 'Modèle',
            hint: 'Ex : Renault Clio 4',
            prefixIcon: Icons.directions_car_filled_outlined,
            textInputAction: TextInputAction.next,
            validator: NewRideRules.carModel,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _carColor,
            label: 'Couleur',
            hint: 'Ex : Blanche',
            prefixIcon: Icons.palette_outlined,
            textInputAction: TextInputAction.next,
            validator: NewRideRules.carColor,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _plate,
            label: 'Plaque',
            hint: 'Ex : 218 TN 9812',
            prefixIcon: Icons.pin_outlined,
            textInputAction: TextInputAction.next,
            validator: NewRideRules.plate,
          ),
        ],
      );

  Widget _amenitiesSection() => RideFormSection(
        icon: Icons.tune,
        title: 'Options du trajet',
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final a in RideAmenity.values)
                FilterChip(
                  avatar: Icon(_amenityIcon(a), size: 18),
                  label: Text(_amenityLabel(a)),
                  showCheckmark: false,
                  selected: _amenities.contains(a),
                  onSelected: (on) => setState(() => on ? _amenities.add(a) : _amenities.remove(a)),
                ),
            ],
          ),
        ],
      );

  Widget _detailsSection() => RideFormSection(
        icon: Icons.notes,
        title: 'Détails (facultatif)',
        children: [
          AppTextField(
            controller: _note,
            label: 'Note pour le dépôt',
            hint: 'Ex : Dépôt devant le Bloc H',
            prefixIcon: Icons.place_outlined,
            textInputAction: TextInputAction.next,
            validator: NewRideRules.dropoffNote,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _distance,
            label: 'Distance (km)',
            hint: 'Ex : 14,2',
            prefixIcon: Icons.straighten,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            validator: NewRideRules.distanceText,
          ),
        ],
      );

  static String _amenityLabel(RideAmenity a) => switch (a) {
        RideAmenity.nonSmoking => 'Non-fumeur',
        RideAmenity.airConditioned => 'Climatisé',
        RideAmenity.musicOk => 'Musique OK',
      };

  static IconData _amenityIcon(RideAmenity a) => switch (a) {
        RideAmenity.nonSmoking => Icons.smoke_free,
        RideAmenity.airConditioned => Icons.ac_unit,
        RideAmenity.musicOk => Icons.music_note,
      };

  static String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static const _weekdays = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];

  /// "sam. 08/11"
  static String _shortDate(DateTime d) =>
      '${_weekdays[d.weekday - 1]} ${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}';
}
