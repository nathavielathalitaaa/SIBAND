import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/child_model.dart';
import '../services/api_service.dart';

class ManageChildrenScreen extends StatefulWidget {
  final VoidCallback? onChildrenUpdated;

  const ManageChildrenScreen({
    super.key,
    this.onChildrenUpdated,
  });

  @override
  State<ManageChildrenScreen> createState() => _ManageChildrenScreenState();
}

class _ManageChildrenScreenState extends State<ManageChildrenScreen> {
  final ApiService _apiService = ApiService();
  List<ChildModel> _children = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchChildren();
  }

  Future<void> _fetchChildren() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _apiService.getChildren();
      if (!mounted) return;
      setState(() {
        _children = list;
        _isLoading = false;
      });
      widget.onChildrenUpdated?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal memuat daftar anak: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddOrEditDialog({ChildModel? childToEdit}) async {
    final nicknameController = TextEditingController(text: childToEdit?.nickname ?? '');
    final birthYearController = TextEditingController(
      text: childToEdit != null ? childToEdit.birthYear.toString() : '',
    );
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                childToEdit == null ? 'Tambah Anak' : 'Ubah Data Anak',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: const Color(0xFF1E2A24),
                ),
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nicknameController,
                        decoration: InputDecoration(
                          labelText: 'Nama Panggilan',
                          hintText: 'Contoh: Bima',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nama tidak boleh kosong';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: birthYearController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Tahun Lahir',
                          hintText: 'Contoh: 2018',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Tahun lahir tidak boleh kosong';
                          }
                          final year = int.tryParse(value.trim());
                          if (year == null || year < 1900 || year > DateTime.now().year) {
                            return 'Masukkan tahun yang valid';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: Text(
                    'Batal',
                    style: GoogleFonts.inter(color: const Color(0xFF6F7B74)),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() {
                            isSaving = true;
                          });

                          final nickname = nicknameController.text.trim();
                          final birthYear = int.parse(birthYearController.text.trim());

                          final messenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(ctx);

                          bool success = false;
                          if (childToEdit == null) {
                            final res = await _apiService.createChild(
                              nickname: nickname,
                              birthYear: birthYear,
                            );
                            success = res != null;
                          } else {
                            final res = await _apiService.updateChild(
                              id: childToEdit.id,
                              nickname: nickname,
                              birthYear: birthYear,
                            );
                            success = res != null;
                          }

                          navigator.pop();
                          if (!mounted) return;

                          if (success) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  childToEdit == null
                                      ? 'Anak berhasil ditambahkan'
                                      : 'Data anak berhasil diperbarui',
                                ),
                                backgroundColor: const Color(0xFF1F5C4A),
                              ),
                            );
                            _fetchChildren();
                          } else {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Gagal menyimpan data anak'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F5C4A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(ChildModel child) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Hapus Data Anak',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus data "${child.nickname}"?',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: GoogleFonts.inter(color: const Color(0xFF6F7B74))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _apiService.deleteChild(child.id);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data anak berhasil dihapus'),
            backgroundColor: Color(0xFF1F5C4A),
          ),
        );
        _fetchChildren();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menghapus data anak'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F4EF),
      appBar: AppBar(
        title: Text(
          'Kelola Anak',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E2A24),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E2A24)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1F5C4A)))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: GoogleFonts.inter(color: Colors.redAccent),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchChildren,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : _children.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.child_care_rounded, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'Belum ada anak terdaftar',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E2A24),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tambahkan profil anak untuk mulai memantau detak jantungnya.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: const Color(0xFF6F7B74),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () => _showAddOrEditDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('Tambah Anak'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1F5C4A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      itemCount: _children.length,
                      itemBuilder: (context, index) {
                        final child = _children[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFFD9DED6)),
                          ),
                          color: Colors.white,
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3EEDF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.face_rounded,
                                color: Color(0xFF1F5C4A),
                              ),
                            ),
                            title: Text(
                              child.nickname,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E2A24),
                              ),
                            ),
                            subtitle: Text(
                              'Tahun lahir: ${child.birthYear}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: const Color(0xFF6F7B74),
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  onPressed: () => _showAddOrEditDialog(childToEdit: child),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                  onPressed: () => _confirmDelete(child),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: _children.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _showAddOrEditDialog(),
              backgroundColor: const Color(0xFF1F5C4A),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: Text(
                'Tambah Anak',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            )
          : null,
    );
  }
}
