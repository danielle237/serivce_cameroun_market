class Shop {
  final String id;
  final String name;
  final String? logo;
  final String? banner;
  final String? description;
  final String ownerId;
  final String ownerName;
  final String? phone;
  final String? city;
  final bool isActive;
  final DateTime createdAt;

  const Shop({
    required this.id,
    required this.name,
    this.logo,
    this.banner,
    this.description,
    required this.ownerId,
    required this.ownerName,
    this.phone,
    this.city,
    this.isActive = true,
    required this.createdAt,
  });

  factory Shop.fromJson(Map<String, dynamic> j) => Shop(
    id:          j['id'] as String,
    name:        j['name'] as String,
    logo:        j['logo'] as String?,
    banner:      j['banner'] as String?,
    description: j['description'] as String?,
    ownerId:     j['ownerId'] as String,
    ownerName:   j['ownerName'] as String,
    phone:       j['phone'] as String?,
    city:        j['city'] as String?,
    isActive:    j['isActive'] as bool? ?? true,
    createdAt:   DateTime.parse(j['createdAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id':          id,
    'name':        name,
    'logo':        logo,
    'banner':      banner,
    'description': description,
    'ownerId':     ownerId,
    'ownerName':   ownerName,
    'phone':       phone,
    'city':        city,
    'isActive':    isActive,
    'createdAt':   createdAt.toIso8601String(),
  };
}
