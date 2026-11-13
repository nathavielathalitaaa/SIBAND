import 'package:flutter/material.dart';

/// Pemetaan nama tipe catatan kejadian ke bahasa Indonesia sesuai spesifikasi.
String getEventTypeName(String type) {
  switch (type.toLowerCase()) {
    case 'suara_keras':
      return 'Suara keras';
    case 'perubahan_aktivitas':
      return 'Perubahan aktivitas';
    case 'transisi':
      return 'Transisi kegiatan';
    case 'aktivitas_sulit':
      return 'Aktivitas sulit';
    case 'interaksi_sosial':
      return 'Interaksi sosial';
    case 'lainnya':
      return 'Lainnya';
    case 'meltdown':
      return 'Meltdown';
    case 'aktivitas_fisik':
      return 'Aktivitas fisik';
    default:
      return type;
  }
}

/// Daftar tipe event note lengkap dengan ikon dan label untuk form input.
final List<Map<String, dynamic>> kEventTypes = [
  {
    'type': 'suara_keras',
    'label': 'Suara keras',
    'icon': Icons.volume_up_outlined,
  },
  {
    'type': 'perubahan_aktivitas',
    'label': 'Perubahan aktivitas',
    'icon': Icons.alt_route_rounded,
  },
  {
    'type': 'transisi',
    'label': 'Transisi kegiatan',
    'icon': Icons.swap_horiz_rounded,
  },
  {
    'type': 'aktivitas_sulit',
    'label': 'Aktivitas sulit',
    'icon': Icons.sentiment_dissatisfied_outlined,
  },
  {
    'type': 'interaksi_sosial',
    'label': 'Interaksi sosial',
    'icon': Icons.people_outline_rounded,
  },
  {
    'type': 'lainnya',
    'label': 'Lainnya',
    'icon': Icons.more_horiz_rounded,
  },
];

/// Pemetaan ikon untuk tipe catatan kejadian.
IconData getEventTypeIcon(String type) {
  for (final item in kEventTypes) {
    if (item['type'] == type && item['icon'] is IconData) {
      return item['icon'] as IconData;
    }
  }
  switch (type.toLowerCase()) {
    case 'aktivitas_fisik':
      return Icons.directions_run_rounded;
    case 'meltdown':
      return Icons.warning_amber_rounded;
    default:
      return Icons.bookmark_border_rounded;
  }
}

