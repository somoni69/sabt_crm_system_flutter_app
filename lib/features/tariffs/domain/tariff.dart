import '../../../core/utils/json_utils.dart';

class Tariff {
  const Tariff({
    required this.id,
    required this.name,
    this.description,
    this.monthlyPrice = 0,
    this.storiesPerMonth = 0,
    this.reelsPerMonth = 0,
    this.postsPerMonth = 0,
    this.designsPerMonth = 0,
    this.shootingDaysPerMonth = 0,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String? description;
  final double monthlyPrice;
  final int storiesPerMonth;
  final int reelsPerMonth;
  final int postsPerMonth;
  final int designsPerMonth;
  final int shootingDaysPerMonth;
  final bool isActive;

  factory Tariff.fromJson(Map<String, dynamic> json) => Tariff(
        id: asStringOr(json['id'], ''),
        name: asStringOr(json['name'], 'Тариф'),
        description: asString(json['description']),
        monthlyPrice: asDoubleOr(json['monthlyPrice'] ?? json['price'], 0),
        storiesPerMonth: asIntOr(json['storiesPerMonth'], 0),
        reelsPerMonth: asIntOr(json['reelsPerMonth'], 0),
        postsPerMonth: asIntOr(json['postsPerMonth'], 0),
        designsPerMonth: asIntOr(json['designsPerMonth'], 0),
        shootingDaysPerMonth: asIntOr(json['shootingDaysPerMonth'], 0),
        isActive: asBool(json['isActive'], fallback: true),
      );
}
