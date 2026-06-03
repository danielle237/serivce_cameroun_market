// ── Rôle marketplace ──────────────────────────────────────────────────────────
enum MarketplaceRole {
  boss,     // Tokos
  vendor,   // Employé Tokos
  reseller, // Revendeur prix gros
  client,   // Client normal
}

// ── Horaires vendeur ──────────────────────────────────────────────────────────
class WorkSchedule {
  final List<int> days; // 1=Lundi, 7=Dimanche
  final String startTime; // "08:00"
  final String endTime;   // "18:00"

  const WorkSchedule({
    required this.days,
    required this.startTime,
    required this.endTime,
  });

  factory WorkSchedule.fromJson(Map<String, dynamic> j) => WorkSchedule(
    days:      List<int>.from(j['days'] ?? [1, 2, 3, 4, 5, 6]),
    startTime: j['startTime'] as String? ?? '08:00',
    endTime:   j['endTime'] as String? ?? '18:00',
  );

  Map<String, dynamic> toJson() => {
    'days':      days,
    'startTime': startTime,
    'endTime':   endTime,
  };

  bool get isCurrentlyAllowed {
    final now = DateTime.now();
    final weekday = now.weekday; // 1=Lundi
    if (!days.contains(weekday)) return false;
    final currentTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return currentTime.compareTo(startTime) >= 0 &&
        currentTime.compareTo(endTime) <= 0;
  }

  String get daysLabel {
    const names = ['', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return days.map((d) => names[d]).join(', ');
  }
}

// ── Vendeur ───────────────────────────────────────────────────────────────────
class Vendor {
  final String userId;
  final String shopId;
  final MarketplaceRole role;
  final String name;
  final String phone;
  final bool isActive;
  final bool isSuspended;
  final String? suspendReason;
  final String? authorizedDeviceId;
  final WorkSchedule? schedule;
  final int failedAttempts;
  final DateTime? lastLogin;
  final DateTime createdAt;

  const Vendor({
    required this.userId,
    required this.shopId,
    required this.role,
    required this.name,
    required this.phone,
    this.isActive = true,
    this.isSuspended = false,
    this.suspendReason,
    this.authorizedDeviceId,
    this.schedule,
    this.failedAttempts = 0,
    this.lastLogin,
    required this.createdAt,
  });

  bool get canLogin {
    if (!isActive || isSuspended) return false;
    if (role == MarketplaceRole.boss) return true;
    if (schedule != null) return schedule!.isCurrentlyAllowed;
    return true;
  }

  factory Vendor.fromJson(Map<String, dynamic> j) => Vendor(
    userId:              j['userId'] as String,
    shopId:              j['shopId'] as String,
    role:                MarketplaceRole.values.firstWhere(
      (r) => r.name == j['role'],
      orElse: () => MarketplaceRole.client,
    ),
    name:                j['name'] as String,
    phone:               j['phone'] as String,
    isActive:            j['isActive'] as bool? ?? true,
    isSuspended:         j['isSuspended'] as bool? ?? false,
    suspendReason:       j['suspendReason'] as String?,
    authorizedDeviceId:  j['authorizedDeviceId'] as String?,
    schedule:            j['schedule'] != null
        ? WorkSchedule.fromJson(j['schedule']) : null,
    failedAttempts:      j['failedAttempts'] as int? ?? 0,
    lastLogin:           j['lastLogin'] != null
        ? DateTime.parse(j['lastLogin']) : null,
    createdAt:           DateTime.parse(j['createdAt'] as String),
  );
}

// ── Log sécurité ──────────────────────────────────────────────────────────────
class SecurityLog {
  final String vendorId;
  final String action;
  final bool success;
  final String? deviceId;
  final DateTime timestamp;
  final String? note;

  const SecurityLog({
    required this.vendorId,
    required this.action,
    required this.success,
    this.deviceId,
    required this.timestamp,
    this.note,
  });

  factory SecurityLog.fromJson(Map<String, dynamic> j) => SecurityLog(
    vendorId:  j['vendorId'] as String,
    action:    j['action'] as String,
    success:   j['success'] as bool,
    deviceId:  j['deviceId'] as String?,
    timestamp: DateTime.parse(j['timestamp'] as String),
    note:      j['note'] as String?,
  );
}

// ── Code promo ────────────────────────────────────────────────────────────────
class PromoCode {
  final String id;
  final String shopId;
  final String code;
  final double discountPercent;
  final double? discountAmount;
  final int? maxUses;
  final int usedCount;
  final DateTime? expiresAt;
  final bool isActive;
  final String? source; // 'tiktok', 'general'

  const PromoCode({
    required this.id,
    required this.shopId,
    required this.code,
    required this.discountPercent,
    this.discountAmount,
    this.maxUses,
    this.usedCount = 0,
    this.expiresAt,
    this.isActive = true,
    this.source,
  });

  bool get isValid {
    if (!isActive) return false;
    if (maxUses != null && usedCount >= maxUses!) return false;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) return false;
    return true;
  }

  factory PromoCode.fromJson(Map<String, dynamic> j) => PromoCode(
    id:               j['id'] as String,
    shopId:           j['shopId'] as String,
    code:             j['code'] as String,
    discountPercent:  (j['discountPercent'] as num).toDouble(),
    discountAmount:   j['discountAmount'] != null
        ? (j['discountAmount'] as num).toDouble() : null,
    maxUses:          j['maxUses'] as int?,
    usedCount:        j['usedCount'] as int? ?? 0,
    expiresAt:        j['expiresAt'] != null
        ? DateTime.parse(j['expiresAt']) : null,
    isActive:         j['isActive'] as bool? ?? true,
    source:           j['source'] as String?,
  );
}
