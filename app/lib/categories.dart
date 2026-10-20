import 'package:flutter/material.dart';

import 'ledger.dart';

/// A readable label for a category, including its parent when it is a
/// sub-category.
String categoryLabel(LedgerCategory category, List<LedgerCategory> all) {
  LedgerCategory? parent;
  for (final item in all) {
    if (item.id == category.parentId) {
      parent = item;
      break;
    }
  }
  if (parent == null) {
    return category.name;
  }
  return '${parent.name} / ${category.name}';
}

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key, required this.gateway});

  final LedgerGateway gateway;

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  late Future<List<LedgerCategory>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.gateway.loadCategories();
  }

  void _refresh() {
    setState(() {
      _future = widget.gateway.loadCategories();
    });
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(Object error) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(describeError(error)),
          duration: const Duration(seconds: 6),
        ),
      );
  }

  Future<void> _openForm(
    List<LedgerCategory> categories, [
    LedgerCategory? category,
  ]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CategoryFormPage(
          gateway: widget.gateway,
          categories: categories,
          category: category,
        ),
      ),
    );
    if (saved == true) {
      _showMessage(
        category == null ? 'تم إنشاء التصنيف.' : 'تم تحديث التصنيف.',
      );
      _refresh();
    }
  }

  Future<void> _delete(LedgerCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف التصنيف'),
        content: Text(
          'سيتم حذف التصنيف «${category.name}». '
          'إذا كان تصنيفًا رئيسيًا فستُحذف تصنيفاته الفرعية أيضًا، '
          'وستُنقل المواد المرتبطة به إلى تصنيف «غير مصنف».',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    try {
      final result = await widget.gateway.deleteCategory(category.id);
      _showMessage(
        'تم حذف التصنيف. '
        'المواد المنقولة: ${result.materialsReassigned}، '
        'التصنيفات الفرعية المحذوفة: ${result.subsDeleted}.',
      );
      _refresh();
    } catch (error) {
      _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LedgerCategory>>(
      future: _future,
      builder: (context, snapshot) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('تصنيفات المواد'),
            actions: [
              IconButton(
                tooltip: 'تحديث',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: _buildBody(snapshot),
          floatingActionButton: snapshot.hasData
              ? FloatingActionButton.extended(
                  onPressed: () => _openForm(snapshot.data!),
                  icon: const Icon(Icons.add),
                  label: const Text('تصنيف جديد'),
                )
              : null,
        );
      },
    );
  }

  Widget _buildBody(AsyncSnapshot<List<LedgerCategory>> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(
                'تعذّر تحميل التصنيفات.\n${describeError(snapshot.error!)}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _refresh,
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    final categories = snapshot.data!;
    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.category_outlined, size: 48),
            const SizedBox(height: 8),
            const Text('لا توجد تصنيفات بعد.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _openForm(categories),
              icon: const Icon(Icons.add),
              label: const Text('تصنيف جديد'),
            ),
          ],
        ),
      );
    }

    final ordered = _ordered(categories);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
      itemCount: ordered.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final category = ordered[index];
        final isSub = category.parentId != null;
        return ListTile(
          contentPadding: EdgeInsetsDirectional.only(
            start: isSub ? 40 : 16,
            end: 4,
          ),
          onTap: () => _openForm(categories, category),
          leading: Icon(
            isSub ? Icons.subdirectory_arrow_left : Icons.category_outlined,
            color: category.isActive ? null : Theme.of(context).disabledColor,
          ),
          title: Text(
            category.name,
            style: category.isActive
                ? null
                : TextStyle(color: Theme.of(context).disabledColor),
          ),
          subtitle: Text(
            [
              if (category.codePrefix != null &&
                  category.codePrefix!.isNotEmpty)
                'البادئة: ${category.codePrefix}',
              'المواد: ${category.materialCount}',
              if (!category.isActive) 'غير نشط',
              if (category.isSystem) 'تصنيف نظامي',
            ].join(' • '),
          ),
          trailing: PopupMenuButton<String>(
            tooltip: 'خيارات',
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  _openForm(categories, category);
                case 'delete':
                  _delete(category);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined),
                    SizedBox(width: 8),
                    Text('تعديل'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                enabled: !category.isSystem,
                child: const Row(
                  children: [
                    Icon(Icons.delete_outline),
                    SizedBox(width: 8),
                    Text('حذف'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<LedgerCategory> _ordered(List<LedgerCategory> categories) {
    final roots = categories.where((c) => c.parentId == null).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final result = <LedgerCategory>[];
    for (final root in roots) {
      result.add(root);
      final subs = categories.where((c) => c.parentId == root.id).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      result.addAll(subs);
    }
    for (final category in categories) {
      if (!result.contains(category)) {
        result.add(category);
      }
    }
    return result;
  }
}

class CategoryFormPage extends StatefulWidget {
  const CategoryFormPage({
    super.key,
    required this.gateway,
    required this.categories,
    this.category,
  });

  final LedgerGateway gateway;
  final List<LedgerCategory> categories;
  final LedgerCategory? category;

  @override
  State<CategoryFormPage> createState() => _CategoryFormPageState();
}

class _CategoryFormPageState extends State<CategoryFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _prefix;
  String? _parentId;
  bool _isActive = true;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.category != null;
  bool get _isSystem => widget.category?.isSystem ?? false;

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    _name = TextEditingController(text: category?.name ?? '');
    _prefix = TextEditingController(text: category?.codePrefix ?? '');
    _parentId = category?.parentId;
    _isActive = category?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _prefix.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final prefix = _prefix.text.trim().isEmpty ? null : _prefix.text.trim();
      if (_isEdit) {
        await widget.gateway.updateCategory(
          id: widget.category!.id,
          name: _name.text.trim(),
          parentId: widget.category!.parentId,
          isActive: _isActive,
          codePrefix: prefix,
        );
      } else {
        await widget.gateway.createCategory(
          name: _name.text.trim(),
          parentId: _parentId,
          codePrefix: prefix,
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = describeError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final parentOptions =
        widget.categories
            .where((c) => c.parentId == null && !c.isSystem && c.isActive)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final parentName = _parentName(widget.categories, widget.category);

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'تعديل تصنيف' : 'تصنيف جديد')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null) ...[
                _CategoryErrorBanner(message: _error!),
                const SizedBox(height: 12),
              ],
              if (_isSystem) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'هذا تصنيف نظامي لا يمكن حذفه أو تغيير اسمه. '
                      'يمكن تعديل بادئة الترميز فقط.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _name,
                enabled: !_isSystem,
                autofocus: !_isEdit,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'اسم التصنيف',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'يجب إدخال اسم التصنيف.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              if (_isEdit)
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'التصنيف الأب',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(parentName ?? 'تصنيف رئيسي'),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _parentId ?? '',
                  decoration: const InputDecoration(
                    labelText: 'التصنيف الأب',
                    helperText: 'اتركه فارغًا لإنشاء تصنيف رئيسي.',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('تصنيف رئيسي'),
                    ),
                    ...parentOptions.map(
                      (category) => DropdownMenuItem<String>(
                        value: category.id,
                        child: Text(category.name),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(
                    () => _parentId = value == null || value.isEmpty
                        ? null
                        : value,
                  ),
                ),
              if ((_isEdit &&
                      (widget.category!.parentId != null || _isSystem)) ||
                  (!_isEdit && _parentId != null)) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _prefix,
                  maxLength: 1,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'بادئة الترميز (اختياري)',
                    helperText: 'حرف واحد يُستخدم في توليد أكواد المواد.',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              if (_isEdit) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('نشط'),
                  value: _isActive,
                  onChanged: _isSystem
                      ? null
                      : (value) => setState(() => _isActive = value),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _parentName(List<LedgerCategory> all, LedgerCategory? category) {
    if (category?.parentId == null) {
      return null;
    }
    for (final item in all) {
      if (item.id == category!.parentId) {
        return item.name;
      }
    }
    return null;
  }
}

class _CategoryErrorBanner extends StatelessWidget {
  const _CategoryErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
