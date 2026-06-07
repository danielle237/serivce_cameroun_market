class AdCampaign {
  final String id;
  final String name;
  final String type;        // interstitial | banner | sponsored
  final String mediaType;   // image | video
  final String mediaUrl;
  final String? clickUrl;
  final String? ctaLabel;
  final int skipAfterSeconds;

  const AdCampaign({
    required this.id,
    required this.name,
    required this.type,
    required this.mediaType,
    required this.mediaUrl,
    this.clickUrl,
    this.ctaLabel,
    this.skipAfterSeconds = 3,
  });

  factory AdCampaign.fromJson(Map<String, dynamic> json) => AdCampaign(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    type: json['type'] as String? ?? 'interstitial',
    mediaType: json['mediaType'] as String? ?? 'image',
    mediaUrl: json['mediaUrl'] as String,
    clickUrl: json['clickUrl'] as String?,
    ctaLabel: json['ctaLabel'] as String?,
    skipAfterSeconds: (json['skipAfterSeconds'] as num?)?.toInt() ?? 3,
  );

  bool get isVideo => mediaType == 'video';
}
