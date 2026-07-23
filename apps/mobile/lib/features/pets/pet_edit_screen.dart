import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../core/theme.dart';
import '../../models.dart';
import 'pet_form.dart';

class PetEditScreen extends StatefulWidget {
  final String? petId;
  const PetEditScreen({super.key, this.petId});
  @override
  State<PetEditScreen> createState() => _PetEditScreenState();
}

class _PetEditScreenState extends State<PetEditScreen> {
  Pet? _pet;
  bool _loading = true;

  bool get _isEdit => widget.petId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      Api.getPet(widget.petId!).then((p) => setState(() { _pet = p; _loading = false; }));
    } else {
      _loading = false;
    }
  }

  void _done() {
    if (context.canPop()) context.pop();
    context.go('/pets');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit ${_pet?.name ?? ''}' : 'New pet'),
        actions: [
          if (_isEdit && _pet != null)
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'toggle') {
                  await Api.setPetActive(_pet!.id, !_pet!.isActive);
                  _done();
                } else if (v == 'delete') {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: Text('Delete ${_pet!.name}?'),
                      content: const Text('This permanently removes the profile, its matches and chats.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                        TextButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Delete', style: TextStyle(color: PawdColors.danger))),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await Api.deletePet(_pet!.id);
                    _done();
                  }
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'toggle', child: Text(_pet!.isActive ? 'Hide from discovery' : 'Show in discovery')),
                const PopupMenuItem(value: 'delete', child: Text('Delete pet', style: TextStyle(color: PawdColors.danger))),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: PawdColors.brand))
          : PetForm(existing: _pet, onSaved: (_) => _done()),
    );
  }
}
