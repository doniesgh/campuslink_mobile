/// Monthly CO2 savings shown in the "impact" card.
class CarpoolImpact {
  const CarpoolImpact({required this.savedKg, required this.goalKg});

  final double savedKg;
  final double goalKg;

  double get progress => goalKg <= 0 ? 0 : (savedKg / goalKg).clamp(0.0, 1.0);
  int get percent => (progress * 100).round();
}
