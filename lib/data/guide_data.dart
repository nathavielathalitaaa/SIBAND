class GuideChecklistItem {
  final String id;
  final String title;
  final String description;
  final String doneText;

  const GuideChecklistItem({
    required this.id,
    required this.title,
    required this.description,
    required this.doneText,
  });
}

const List<GuideChecklistItem> kCalmingChecklistItems = [
  GuideChecklistItem(
    id: 'pastikan_aman',
    title: 'Pastikan aman',
    description: 'Jauhkan benda berbahaya dan beri ruang aman.',
    doneText: 'Menjaga lingkungan tetap aman',
  ),
  GuideChecklistItem(
    id: 'kurangi_rangsangan',
    title: 'Kurangi rangsangan',
    description: 'Kurangi suara, keramaian, dan cahaya.',
    doneText: 'Mengurangi rangsangan',
  ),
  GuideChecklistItem(
    id: 'tetap_tenang',
    title: 'Tetap tenang',
    description: 'Gunakan suara lembut dan kalimat singkat.',
    doneText: 'Menjaga suara tetap lembut',
  ),
  GuideChecklistItem(
    id: 'jangan_memaksa',
    title: 'Jangan memaksa',
    description: 'Hindari berdebat atau memaksa anak bicara.',
    doneText: 'Tidak memaksa anak',
  ),
  GuideChecklistItem(
    id: 'tawarkan_pilihan',
    title: 'Tawarkan pilihan',
    description: 'Beri waktu dan tawarkan tempat nyaman.',
    doneText: 'Memberi waktu dan ruang',
  ),
  GuideChecklistItem(
    id: 'setelah_mereda',
    title: 'Setelah mereda',
    description: 'Validasi perasaan; catat pemicu dan hal membantu.',
    doneText: 'Memvalidasi perasaan anak',
  ),
];
