// Helper : PostgreSQL DECIMAL/NUMERIC arrive parfois en String
double _toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

// ── Statuts commande ──────────────────────────────────────────────────────────
enum OrderStatus {
  pending,      // 🟡 En attente
  confirmed,    // 🔵 Stock confirmé
  paid,         // 🟣 Paiement validé
  preparing,    // 🟠 En préparation
  ready,        // ✅ Commande prête
  received,     // ⭐ Réceptionnée
  cancelled,    // ❌ Annulée
}

extension OrderStatusExt on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.pending:   return '🟡 En attente';
      case OrderStatus.confirmed: return '🔵 Stock confirmé';
      case OrderStatus.paid:      return '🟣 Paiement validé';
      case OrderStatus.preparing: return '🟠 En préparation';
      case OrderStatus.ready:     return '✅ Commande prête';
      case OrderStatus.received:  return '⭐ Réceptionnée';
      case OrderStatus.cancelled: return '❌ Annulée';
    }
  }

  bool get canModify =>
      this == OrderStatus.pending || this == OrderStatus.confirmed;

  bool get canCancel =>
      this == OrderStatus.pending || this == OrderStatus.confirmed;
}

// ── Mode paiement ─────────────────────────────────────────────────────────────
enum PaymentMethod { cash, mtnMomo, orangeMoney, visa, mastercard }

extension PaymentMethodExt on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.cash:        return '💵 Paiement à la livraison';
      case PaymentMethod.mtnMomo:     return '📱 MTN MoMo';
      case PaymentMethod.orangeMoney: return '🟠 Orange Money';
      case PaymentMethod.visa:        return '💳 Carte Visa';
      case PaymentMethod.mastercard:  return '💳 Carte Mastercard';
    }
  }

  bool get isMobile => this == PaymentMethod.mtnMomo || this == PaymentMethod.orangeMoney;
  bool get isCard   => this == PaymentMethod.visa || this == PaymentMethod.mastercard;
}

// ── Statut paiement ───────────────────────────────────────────────────────────
enum PaymentStatus { pending, validated, rejected }

// ── Preuve paiement MoMo ──────────────────────────────────────────────────────
class PaymentProof {
  final String reference;
  final String time;
  final String? fileUrl; // Capture écran ou PDF
  final DateTime submittedAt;
  final PaymentStatus status;
  final String? validatedBy;
  final DateTime? validatedAt;
  final String? rejectReason;

  const PaymentProof({
    required this.reference,
    required this.time,
    this.fileUrl,
    required this.submittedAt,
    this.status = PaymentStatus.pending,
    this.validatedBy,
    this.validatedAt,
    this.rejectReason,
  });

  factory PaymentProof.fromJson(Map<String, dynamic> j) => PaymentProof(
    reference:    j['reference'] as String,
    time:         j['time'] as String,
    fileUrl:      j['fileUrl'] as String?,
    submittedAt:  DateTime.parse(j['submittedAt'] as String),
    status:       PaymentStatus.values.firstWhere(
      (s) => s.name == j['status'],
      orElse: () => PaymentStatus.pending,
    ),
    validatedBy:  j['validatedBy'] as String?,
    validatedAt:  j['validatedAt'] != null
        ? DateTime.parse(j['validatedAt']) : null,
    rejectReason: j['rejectReason'] as String?,
  );
}

// ── Ligne de commande ─────────────────────────────────────────────────────────
class OrderLine {
  final String productId;
  final String productName;
  final String? productPhoto;
  final String? variant1;
  final String? variant2;
  final int qty;
  final double unitPrice;
  final bool isPartial; // Commande partielle

  const OrderLine({
    required this.productId,
    required this.productName,
    this.productPhoto,
    this.variant1,
    this.variant2,
    required this.qty,
    required this.unitPrice,
    this.isPartial = false,
  });

  double get total => qty * unitPrice;

  factory OrderLine.fromJson(Map<String, dynamic> j) => OrderLine(
    productId:    j['productId'] as String,
    productName:  j['productName'] as String,
    productPhoto: j['productPhoto'] as String?,
    variant1:     j['variant1'] as String?,
    variant2:     j['variant2'] as String?,
    qty:          j['qty'] as int,
    unitPrice:    _toDouble(j['unitPrice']),
    isPartial:    j['isPartial'] as bool? ?? false,
  );
}

// ── Historique étape commande ─────────────────────────────────────────────────
class OrderHistoryEntry {
  final OrderStatus status;
  final DateTime timestamp;
  final String actorId;
  final String actorName;
  final String actorRole;
  final String? comment;
  final String? photoUrl;

  const OrderHistoryEntry({
    required this.status,
    required this.timestamp,
    required this.actorId,
    required this.actorName,
    required this.actorRole,
    this.comment,
    this.photoUrl,
  });

  factory OrderHistoryEntry.fromJson(Map<String, dynamic> j) =>
      OrderHistoryEntry(
        status:    OrderStatus.values.firstWhere(
          (s) => s.name == j['status'],
          orElse: () => OrderStatus.pending,
        ),
        timestamp: DateTime.parse(j['timestamp'] as String),
        actorId:   j['actorId'] as String,
        actorName: j['actorName'] as String,
        actorRole: j['actorRole'] as String,
        comment:   j['comment'] as String?,
        photoUrl:  j['photoUrl'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'status':    status.name,
    'timestamp': timestamp.toIso8601String(),
    'actorId':   actorId,
    'actorName': actorName,
    'actorRole': actorRole,
    'comment':   comment,
    'photoUrl':  photoUrl,
  };
}

// ── Commande ──────────────────────────────────────────────────────────────────
class Order {
  final String id;
  final String shopId;
  final String clientId;
  final String clientName;
  final String clientPhone;
  final List<OrderLine> lines;
  final OrderStatus status;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final PaymentProof? paymentProof;
  final double totalAmount;
  final String? promoCode;
  final double? discount;
  final String? cancelReason;
  final List<OrderHistoryEntry> history;
  final String? source; // 'tiktok', 'app', 'qr'
  final DateTime createdAt;
  final DateTime updatedAt;

  const Order({
    required this.id,
    required this.shopId,
    required this.clientId,
    required this.clientName,
    required this.clientPhone,
    required this.lines,
    required this.status,
    required this.paymentMethod,
    this.paymentStatus = PaymentStatus.pending,
    this.paymentProof,
    required this.totalAmount,
    this.promoCode,
    this.discount,
    this.cancelReason,
    this.history = const [],
    this.source,
    required this.createdAt,
    required this.updatedAt,
  });

  // Peut modifier dans les 30 min
  bool get canModify {
    final diff = DateTime.now().difference(createdAt).inMinutes;
    return status.canModify && diff <= 30;
  }

  bool get needsBossValidation => totalAmount > 50000;

  factory Order.fromJson(Map<String, dynamic> j) => Order(
    id:            j['id'] as String,
    shopId:        j['shopId'] as String,
    clientId:      j['clientId'] as String,
    clientName:    j['clientName'] as String,
    clientPhone:   j['clientPhone'] as String,
    lines:         (j['lines'] as List? ?? [])
        .map((l) => OrderLine.fromJson(l)).toList(),
    status:        OrderStatus.values.firstWhere(
      (s) => s.name == j['status'],
      orElse: () => OrderStatus.pending,
    ),
    paymentMethod: PaymentMethod.values.firstWhere(
      (m) => m.name == j['paymentMethod'],
      orElse: () => PaymentMethod.cash,
    ),
    paymentStatus: PaymentStatus.values.firstWhere(
      (s) => s.name == j['paymentStatus'],
      orElse: () => PaymentStatus.pending,
    ),
    paymentProof:  j['paymentProof'] != null
        ? PaymentProof.fromJson(j['paymentProof']) : null,
    totalAmount:   _toDouble(j['totalAmount']),
    promoCode:     j['promoCode'] as String?,
    discount:      j['discount'] != null ? _toDouble(j['discount']) : null,
    cancelReason:  j['cancelReason'] as String?,
    history:       (j['history'] as List? ?? [])
        .map((h) => OrderHistoryEntry.fromJson(h)).toList(),
    source:        j['source'] as String?,
    createdAt:     DateTime.parse(j['createdAt'] as String),
    updatedAt:     DateTime.parse(j['updatedAt'] as String),
  );
}
