// lib/src/features/transaction/presentation/widgets/levy_invoice_card.dart

import 'package:flutter/material.dart';

/// Kartu rincian tagihan retribusi resmi turis Bali (Phase 3).
class LevyInvoiceCard extends StatelessWidget {
  final String fullName;
  final String passportMasked;
  final String btidNumber;
  final bool isPaid;

  const LevyInvoiceCard({
    super.key,
    required this.fullName,
    required this.passportMasked,
    required this.btidNumber,
    required this.isPaid,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        children: [
          // Amount Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'TOTAL DUE',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'IDR 150,000',
                      style: TextStyle(
                        color: Color(0xFF2DD4BF),
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isPaid
                        ? const Color(0xFF065F46).withValues(alpha: 0.5)
                        : const Color(0xFF78350F).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isPaid
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF59E0B),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPaid ? Icons.check_circle_rounded : Icons.pending_rounded,
                        color: isPaid ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isPaid ? 'PAID' : 'PAYMENT DUE',
                        style: TextStyle(
                          color: isPaid ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Details List
          Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              children: [
                _buildInfoRow('Traveler', fullName),
                const Divider(color: Color(0xFF1F2937), height: 18),
                _buildInfoRow('Passport', passportMasked),
                const Divider(color: Color(0xFF1F2937), height: 18),
                _buildInfoRow('Tourist ID', btidNumber),
                const Divider(color: Color(0xFF1F2937), height: 18),
                _buildInfoRow('Treasury Entity', 'Bapenda Bali On-Chain Pool'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
