import 'package:flutter/material.dart';

/// Shared trip card widget — ใช้ร่วมกันทั้งหน้าหลักและหน้าประวัติ
///
/// Layout 3 rows:
/// - Row 1: 🎫 เลขที่ตั๋ว + ปลายทาง + วันที่
/// - Row 2: 🚗 รถ (ซ้าย) | 🕐 เวลา (ขวา)
/// - Row 3: ระยะทาง + ค่าใช้จ่าย
class TripCard extends StatelessWidget {
  const TripCard({
    super.key,
    required this.trip,
    required this.formatDate,
    required this.formatTime,
    this.onTap,
  });

  final Map<String, dynamic> trip;
  final String Function(DateTime) formatDate;
  final String Function(DateTime) formatTime;
  final VoidCallback? onTap;

  String _formatMoney(dynamic v) =>
      v is num ? v.toDouble().toStringAsFixed(0) : '-';

  @override
  Widget build(BuildContext context) {
    final startTime = DateTime.parse(trip['start_time'] as String).toLocal();
    final endTime = trip['end_time'] == null
        ? null
        : DateTime.parse(trip['end_time'] as String).toLocal();
    final vehicle = trip['vehicles'] as Map<String, dynamic>?;
    final plate = vehicle?['vehicle_plate'] as String? ?? '';
    final province = vehicle?['province'] as String?;
    final ticketNumber = trip['ticket_number'] as String? ?? '';
    final distance = trip['distance'] is num
        ? (trip['distance'] as num).toDouble()
        : null;
    final ticketPrice = trip['ticket_price'];
    final tollFee = trip['toll_fee'];
    final totalCost = (ticketPrice is num ? ticketPrice.toDouble() : 0) +
        (tollFee is num ? tollFee.toDouble() : 0);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Ticket + Destination + Date
              Row(
                children: [
                  if (ticketNumber.isNotEmpty) ...[
                    Icon(Icons.confirmation_number_outlined,
                        size: 14, color: const Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      ticketNumber,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      trip['destination'] as String? ?? '-',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatDate(startTime),
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Row 2: Car (left) + Time (right)
              Row(
                children: [
                  if (plate.isNotEmpty) ...[
                    Icon(Icons.directions_car_outlined,
                        size: 13, color: const Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Text(
                      '$plate${province == null ? '' : ' $province'}',
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Icon(Icons.schedule_outlined,
                      size: 13, color: const Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Text(
                    endTime == null
                        ? formatTime(startTime)
                        : '${formatTime(startTime)} – ${formatTime(endTime)}',
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Row 3: Distance + Cost
              Row(
                children: [
                  if (distance != null)
                    Text(
                      '${distance.toStringAsFixed(1)} กม.',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    )
                  else
                    const Text(
                      '-',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  const Spacer(),
                  if (totalCost > 0)
                    Text(
                      '${_formatMoney(totalCost)} บาท',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
