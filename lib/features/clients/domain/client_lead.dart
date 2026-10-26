import '../../../core/utils/date_utils.dart';
import '../../../core/utils/json_utils.dart';

class ClientLeadModel {
  const ClientLeadModel({
    required this.id,
    required this.name,
    this.sphere,
    this.problem,
    this.address,
    this.contactPerson,
    this.contactPhone,
    this.contactInstagram,
    this.contactEmail,
    this.status = 'new',
    this.nextStep,
    this.leadSource,
    this.dealPotential,
    this.interest,
    this.direction,
    this.onboardingStage,
    this.lastContactAt,
    this.lastActivityAt,
    this.nextContactAt,
    this.repeatCallAt,
    this.channel,
    this.callRequested = false,
    this.callRequestedByName,
    this.rejectionReason,
    this.ownerName,
    this.ownerAvatar,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? sphere;
  final String? problem;
  final String? address;
  final String? contactPerson;
  final String? contactPhone;
  final String? contactInstagram;
  final String? contactEmail;
  final String status;
  final String? nextStep;
  final String? leadSource;
  final double? dealPotential;
  final String? interest;
  final String? direction;
  final String? onboardingStage;
  final DateTime? lastContactAt;
  final DateTime? lastActivityAt;
  final DateTime? nextContactAt;
  final DateTime? repeatCallAt;
  final String? channel;
  final bool callRequested;
  final String? callRequestedByName;
  final String? rejectionReason;
  final String? ownerName;
  final String? ownerAvatar;
  final DateTime? createdAt;

  bool get isWon => status == 'won';
  bool get isLost => status == 'lost';
  bool get isOnHold => status == 'on_hold';
  bool get isActive => !isLost && !isOnHold;
  bool get isHot => interest == 'hot';
  bool get isSmm => direction == 'smm';
  bool get isDev => direction == 'development';

  bool get nextContactOverdue =>
      nextContactAt != null &&
      !isWon &&
      nextContactAt!.isBefore(BizDate.now());

  bool get nextContactToday =>
      nextContactAt != null && BizDate.isToday(nextContactAt) && !isWon;

  String get statusLabel => switch (status) {
        'new' => 'Новый',
        'waiting' => 'Ожидание',
        'negotiating' => 'Переговоры',
        'proposal' => 'Предложение',
        'won' => 'Клиент',
        'lost' => 'Отказ',
        'on_hold' => 'На паузе',
        'unknown' => 'Неизвестно',
        _ => status,
      };

  String get interestLabel => switch (interest) {
        'hot' => 'Горячий',
        'warm' => 'Тёплый',
        'cold' => 'Холодный',
        _ => 'Не оценён',
      };

  String get directionLabel => switch (direction) {
        'smm' => 'SMM',
        'development' => 'Разработка',
        _ => 'Направление не задано',
      };

  String get contactLabel =>
      contactPerson ?? contactPhone ?? contactEmail ?? contactInstagram ?? 'Контакт не указан';

  factory ClientLeadModel.fromJson(Map<String, dynamic> json) {
    final owner = asMap(json['owner']);
    return ClientLeadModel(
      id: asStringOr(json['id'], ''),
      name: asStringOr(json['name'], 'Клиент'),
      sphere: asString(json['sphere']),
      problem: asString(json['problem']),
      address: asString(json['address']),
      contactPerson: asString(json['contactPerson']),
      contactPhone: asString(json['contactPhone'] ?? json['contactInfo']),
      contactInstagram: asString(json['contactInstagram']),
      contactEmail: asString(json['contactEmail']),
      status: asStringOr(json['status'], 'new'),
      nextStep: asString(json['nextStep']),
      leadSource: asString(json['leadSource']),
      dealPotential: asDouble(json['dealPotential']),
      interest: asString(json['interest']),
      direction: asString(json['direction']),
      onboardingStage: asString(json['onboardingStage']),
      lastContactAt: BizDate.parse(json['lastContactAt']),
      lastActivityAt: BizDate.parse(json['lastActivityAt'] ?? json['updatedAt']),
      nextContactAt: BizDate.parse(json['nextContactAt']),
      repeatCallAt: BizDate.parse(json['repeatCallAt']),
      channel: asString(json['channel']),
      callRequested: asBool(json['callRequested']),
      callRequestedByName: asString(json['callRequestedByName']),
      rejectionReason: asString(json['rejectionReason']),
      ownerName: asString(owner?['name']),
      ownerAvatar: asString(owner?['avatar']),
      createdAt: BizDate.parse(json['createdAt']),
    );
  }
}
