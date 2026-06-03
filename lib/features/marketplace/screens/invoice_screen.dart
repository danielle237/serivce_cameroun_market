import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/order.dart';
import '../providers/marketplace_providers.dart';
import '../providers/extras_providers.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/app_config.dart';

class InvoiceScreen extends ConsumerWidget {
  final String orderId;
  const InvoiceScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Facture'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          orderAsync.when(
            data: (order) => IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => _shareInvoice(context, order),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (order) => Column(
          children: [
            Expanded(child: _InvoicePreview(order: order)),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, MediaQuery.of(context).padding.bottom + 12),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _printInvoice(context, order),
                    icon: const Icon(Icons.print),
                    label: const Text('Imprimer'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _shareInvoice(context, order),
                    icon: const Icon(Icons.share),
                    label: const Text('Partager PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Future<pw.Document> _buildPdf(Order order) async {
    final doc = pw.Document();
    final ref = order.id.substring(0, 8).toUpperCase();

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // En-tête
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('TCHOKOS', style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900)),
                  pw.Text('Boutique en ligne — W2D',
                      style: const pw.TextStyle(color: PdfColors.grey)),
                  pw.Text(AppConfig.shopLink(AppConfig.shopId),
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('FACTURE', style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.Text('#$ref',
                      style: const pw.TextStyle(color: PdfColors.grey)),
                  pw.Text(_formatDate(order.createdAt),
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Divider(),
          pw.SizedBox(height: 12),

          // Client
          pw.Text('Facturé à :', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(order.clientName),
          pw.Text(order.clientPhone),
          pw.SizedBox(height: 20),

          // Tableau produits
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(4),
              1: const pw.FixedColumnWidth(60),
              2: const pw.FixedColumnWidth(90),
              3: const pw.FixedColumnWidth(90),
            },
            children: [
              // En-tête tableau
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue900),
                children: [
                  _cell('Produit', header: true),
                  _cell('Qté', header: true),
                  _cell('Prix unit.', header: true),
                  _cell('Total', header: true),
                ],
              ),
              // Lignes
              ...order.lines.map((line) => pw.TableRow(
                children: [
                  _cell('${line.productName}'
                      '${line.variant1 != null ? ' (${line.variant1})' : ''}'),
                  _cell('${line.qty}'),
                  _cell('${_fmt(line.unitPrice)} FCFA'),
                  _cell('${_fmt(line.total)} FCFA'),
                ],
              )),
            ],
          ),
          pw.SizedBox(height: 12),

          // Totaux
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 220,
              child: pw.Column(children: [
                if (order.discount != null && order.discount! > 0) ...[
                  _totalRow('Sous-total', '${_fmt(order.totalAmount + order.discount!)} FCFA'),
                  _totalRow('Code ${order.promoCode ?? ''}', '- ${_fmt(order.discount!)} FCFA',
                      color: PdfColors.green),
                ],
                pw.Divider(),
                _totalRow('TOTAL', '${_fmt(order.totalAmount)} FCFA', bold: true),
              ]),
            ),
          ),
          pw.SizedBox(height: 20),

          // Paiement
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Informations de paiement',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('Mode : ${order.paymentMethod.label}'),
                pw.Text('Statut : ${_paymentLabel(order.paymentStatus)}'),
              ],
            ),
          ),
          pw.Spacer(),

          // Pied de page
          pw.Divider(),
          pw.Center(
            child: pw.Text(
              'Merci de votre confiance — Tchokos par W2D',
              style: const pw.TextStyle(color: PdfColors.grey),
            ),
          ),
        ],
      ),
    ));

    return doc;
  }

  Future<void> _printInvoice(BuildContext context, Order order) async {
    final doc = await _buildPdf(order);
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  Future<void> _shareInvoice(BuildContext context, Order order) async {
    final doc = await _buildPdf(order);
    final bytes = await doc.save();
    final ref = order.id.substring(0, 8).toUpperCase();

    if (kIsWeb) {
      await Printing.sharePdf(bytes: bytes,
          filename: 'Facture_Tchokos_$ref.pdf');
    } else {
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/Facture_Tchokos_$ref.pdf');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)],
          text: 'Facture commande Tchokos #$ref');
    }
  }

  pw.Widget _cell(String text, {bool header = false}) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(text,
            style: pw.TextStyle(
              color: header ? PdfColors.white : PdfColors.black,
              fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: 10,
            )),
      );

  pw.Widget _totalRow(String label, String value,
      {bool bold = false, PdfColor? color}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: pw.TextStyle(
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
            pw.Text(value, style: pw.TextStyle(
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: color)),
          ],
        ),
      );

  String _fmt(double v) => v.toInt().toString()
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  String _paymentLabel(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.pending:   return 'En attente';
      case PaymentStatus.validated: return 'Payé';
      case PaymentStatus.rejected:  return 'Rejeté';
    }
  }
}

// ── Aperçu de la facture ──────────────────────────────────────────────────────
class _InvoicePreview extends StatelessWidget {
  final Order order;
  const _InvoicePreview({required this.order});

  @override
  Widget build(BuildContext context) {
    final ref = order.id.substring(0, 8).toUpperCase();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TCHOKOS', style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold,
                          color: Color(0xFF1A237E))),
                      Text('Boutique W2D',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('FACTURE', style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('#$ref',
                          style: const TextStyle(color: Colors.grey)),
                      Text(_formatDate(order.createdAt),
                          style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),
              Text(order.clientName,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(order.clientPhone,
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 16),

              // Produits
              ...order.lines.map((line) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(child: Text(
                    '${line.productName}'
                    '${line.variant1 != null ? ' (${line.variant1})' : ''}',
                    style: const TextStyle(fontSize: 13),
                  )),
                  Text('x${line.qty}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(width: 12),
                  Text('${_fmt(line.total)} FCFA',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
              )),

              const Divider(height: 20),
              if (order.discount != null && order.discount! > 0) ...[
                _row('Code ${order.promoCode ?? ''}',
                    '- ${_fmt(order.discount!)} FCFA',
                    color: Colors.green),
              ],
              _row('TOTAL', '${_fmt(order.totalAmount)} FCFA', bold: true),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${order.paymentMethod.label} — ${_paymentLabel(order.paymentStatus)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
            Text(value, style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: color,
                fontSize: bold ? 16 : 14)),
          ],
        ),
      );

  String _fmt(double v) => v.toInt().toString()
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  String _paymentLabel(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.pending:   return 'En attente';
      case PaymentStatus.validated: return 'Payé';
      case PaymentStatus.rejected:  return 'Rejeté';
    }
  }
}
