class CancellationPreviewModel {
  final bool allowed;
  final double totalPenalty;
  final List<BlockPenaltyDetail> blockDetails;

  const CancellationPreviewModel({
    required this.allowed,
    required this.totalPenalty,
    required this.blockDetails,
  });

  bool get hasPenalty => totalPenalty > 0;

  factory CancellationPreviewModel.fromJson(Map<String, dynamic> json) {
    final details = (json['block_details'] as List<dynamic>? ?? [])
        .map((e) => BlockPenaltyDetail.fromJson(e as Map<String, dynamic>))
        .toList();
    return CancellationPreviewModel(
      allowed: json['allowed'] as bool? ?? false,
      totalPenalty: double.tryParse(json['total_penalty']?.toString() ?? '0') ?? 0,
      blockDetails: details,
    );
  }
}

enum PenaltyTier {
  noPenalty,
  low,
  medium,
  high,
  unknown;

  static PenaltyTier fromString(String? value) => switch (value?.toLowerCase()) {
    'no_penalty' => noPenalty,
    'low' || 'low_penalty' => low,
    'medium' || 'medium_penalty' => medium,
    'high' || 'high_penalty' || 'late_cancellation' => high,
    _ => unknown,
  };

  String get label => switch (this) {
    noPenalty => 'No Penalty',
    low => 'Low Penalty',
    medium => 'Moderate Penalty',
    high => 'Late Cancellation',
    unknown => 'Penalty Applies',
  };
}

class BlockPenaltyDetail {
  final int blockId;
  final double penalty;
  final PenaltyTier tier;
  final double hoursBeforeStart;
  final double blockAmount;

  const BlockPenaltyDetail({
    required this.blockId,
    required this.penalty,
    required this.tier,
    required this.hoursBeforeStart,
    required this.blockAmount,
  });

  factory BlockPenaltyDetail.fromJson(Map<String, dynamic> json) {
    return BlockPenaltyDetail(
      blockId: (json['block_id'] as num?)?.toInt() ?? 0,
      penalty: double.tryParse(json['penalty']?.toString() ?? '0') ?? 0,
      tier: PenaltyTier.fromString(json['tier'] as String?),
      hoursBeforeStart: double.tryParse(json['hours_before_start']?.toString() ?? '0') ?? 0,
      blockAmount: double.tryParse(json['block_amount']?.toString() ?? '0') ?? 0,
    );
  }
}
