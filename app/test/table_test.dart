import 'package:accounting_app_flutter/theme/app_theme.dart';
import 'package:accounting_app_flutter/ui/app_ui.dart';
import 'package:accounting_app_flutter/ui/table/table_preferences.dart';
import 'package:accounting_app_flutter/ui/table/table_preferences_store_stub.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Row {
  const _Row(this.id, this.name, this.score);

  final String id;
  final String name;
  final int score;
}

List<AppTableColumn<_Row>> _columns() => [
  AppTableColumn<_Row>(
    id: 'id',
    label: 'الرمز',
    canHide: false,
    sortable: true,
    sortValue: (row) => row.id,
    builder: (context, row) => Text(row.id),
  ),
  AppTableColumn<_Row>(
    id: 'name',
    label: 'الاسم',
    sortable: true,
    sortValue: (row) => row.name,
    builder: (context, row) => Text(row.name),
  ),
  AppTableColumn<_Row>(
    id: 'score',
    label: 'الدرجة',
    alignment: AlignmentDirectional.centerEnd,
    headerAlignment: AlignmentDirectional.centerEnd,
    sortable: true,
    sortValue: (row) => row.score,
    builder: (context, row) => Text('${row.score}'),
  ),
];

Widget _wrap(Widget child, {TextDirection direction = TextDirection.rtl}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Directionality(
      textDirection: direction,
      child: Scaffold(
        body: Center(child: SizedBox(width: 900, height: 620, child: child)),
      ),
    ),
  );
}

AppDataTable<_Row> _table({
  required List<_Row> rows,
  String? tableId,
  TablePreferencesStore? store,
  bool paginate = false,
  int pageSize = 25,
  bool loading = false,
  String? error,
  VoidCallback? onRetry,
  bool enableSelection = false,
  ValueChanged<Set<Object>>? onSelectionChanged,
  ValueChanged<_Row>? onRowTap,
  String emptyTitle = 'لا توجد بيانات',
}) {
  return AppDataTable<_Row>(
    tableId: tableId,
    preferencesStore: store,
    columns: _columns(),
    rows: rows,
    rowId: (row) => row.id,
    onRowTap: onRowTap,
    paginate: paginate,
    pageSize: pageSize,
    loading: loading,
    error: error,
    onRetry: onRetry,
    enableSelection: enableSelection,
    onSelectionChanged: onSelectionChanged,
    emptyTitle: emptyTitle,
    emptyMessage: 'أضف صفاً جديداً.',
  );
}

void main() {
  const rows = <_Row>[
    _Row('C', 'جمال', 20),
    _Row('A', 'أحمد', 50),
    _Row('B', 'بشار', 10),
  ];

  testWidgets('sorts rows by a stable column id and reverses direction', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_table(rows: rows)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('الاسم'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('أحمد')).dy,
      lessThan(tester.getTopLeft(find.text('بشار')).dy),
    );

    await tester.tap(find.text('الاسم'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('جمال')).dy,
      lessThan(tester.getTopLeft(find.text('بشار')).dy),
    );
  });

  testWidgets('keeps source order for rows with equal sort keys', (
    tester,
  ) async {
    final tied = [
      for (var index = 0; index < 40; index++)
        _Row('r$index', 'r$index', index % 2),
    ];
    await tester.pumpWidget(_wrap(_table(rows: tied)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('الدرجة'));
    await tester.pumpAndSettle();

    // Score 0 rows must stay in source order: r0, r2, r4…
    final y0 = tester.getTopLeft(find.text('r0').first).dy;
    final y2 = tester.getTopLeft(find.text('r2').first).dy;
    final y4 = tester.getTopLeft(find.text('r4').first).dy;
    expect(y0, lessThan(y2));
    expect(y2, lessThan(y4));
  });

  testWidgets('hides a column, redistributes width and restores it', (
    tester,
  ) async {
    final store = MemoryTablePreferencesStore();
    await tester.pumpWidget(
      _wrap(_table(rows: rows, tableId: 'columns', store: store)),
    );
    await tester.pumpAndSettle();

    double headerWidth(String label) => tester
        .getSize(
          find
              .ancestor(of: find.text(label), matching: find.byType(SizedBox))
              .first,
        )
        .width;

    expect(find.text('الرمز'), findsOneWidget);
    final fullWidth = headerWidth('الرمز');

    await tester.tap(find.byTooltip('إعدادات الجدول'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تم'));
    await tester.pumpAndSettle();

    expect(find.text('الاسم'), findsNothing);
    expect(find.text('الرمز'), findsOneWidget);
    // A hidden column must not reserve its share of the table width.
    expect(headerWidth('الرمز'), greaterThan(fullWidth * 1.4));

    await tester.tap(find.byTooltip('إعدادات الجدول'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تم'));
    await tester.pumpAndSettle();

    expect(find.text('الاسم'), findsOneWidget);
    expect(headerWidth('الرمز'), closeTo(fullWidth, 1));
  });

  testWidgets('restores every hidden column with show all', (tester) async {
    final store = MemoryTablePreferencesStore({
      'show-all': {
        'order': ['id', 'name', 'score'],
        'hidden': ['name', 'score'],
      },
    });
    await tester.pumpWidget(
      _wrap(_table(rows: rows, tableId: 'show-all', store: store)),
    );
    await tester.pumpAndSettle();

    expect(find.text('الاسم'), findsNothing);
    await tester.tap(find.byTooltip('إعدادات الجدول'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إظهار الكل'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تم'));
    await tester.pumpAndSettle();

    expect(find.text('الاسم'), findsOneWidget);
    expect(find.text('الدرجة'), findsOneWidget);
  });

  testWidgets('navigates and activates rows with the keyboard', (tester) async {
    final tapped = <String>[];
    Set<Object>? selected;
    await tester.pumpWidget(
      _wrap(
        _table(
          rows: rows,
          enableSelection: true,
          onSelectionChanged: (value) => selected = value,
          onRowTap: (row) => tapped.add(row.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('الرمز'));
    await tester.pumpAndSettle();
    // Sorting by code puts A, B, C in this order.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(tapped, ['A']);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(selected, contains('B'));

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(tapped, ['A', 'C']);
    expect(find.byType(Scrollbar), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ellipsises long cell values instead of overflowing', (
    tester,
  ) async {
    final long = _Row('A', 'اسم طويل جداً ' * 20, 1);
    await tester.pumpWidget(
      _wrap(
        AppDataTable<_Row>(
          columns: [
            AppTableColumn<_Row>(
              id: 'name',
              label: 'الاسم',
              builder: (context, row) => AppTableText(row.name),
            ),
          ],
          rows: [long],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('اسم طويل'), findsOneWidget);
  });

  testWidgets('adopts saved preferences when the table id changes', (
    tester,
  ) async {
    final many = [
      for (var index = 0; index < 12; index++)
        _Row('R$index', 'صف ${index.toString().padLeft(2, '0')}', index),
    ];
    final store = MemoryTablePreferencesStore({
      'first': {
        'pageSize': 10,
        'sortColumnId': 'score',
        'sortAscending': false,
      },
      'second': {'pageSize': 25, 'sortColumnId': 'name', 'sortAscending': true},
    });

    await tester.pumpWidget(
      _wrap(_table(rows: many, tableId: 'first', store: store, paginate: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 / 2'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('صف 11')).dy,
      lessThan(tester.getTopLeft(find.text('صف 10')).dy),
    );

    // Rebuilding with another table id must adopt that table's own saved
    // preferences instead of keeping the previous table's sort and page size.
    await tester.pumpWidget(
      _wrap(
        _table(rows: many, tableId: 'second', store: store, paginate: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 / 1'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('صف 00')).dy,
      lessThan(tester.getTopLeft(find.text('صف 01')).dy),
    );
  });

  testWidgets('paginates with an explicit page size', (tester) async {
    final many = [
      for (var index = 0; index < 25; index++)
        _Row('R$index', 'صف $index', index),
    ];
    await tester.pumpWidget(
      _wrap(_table(rows: many, paginate: true, pageSize: 10)),
    );
    await tester.pumpAndSettle();

    expect(find.text('عرض 1–10 من 25'), findsOneWidget);
    await tester.tap(find.byTooltip('الصفحة التالية'));
    await tester.pumpAndSettle();

    expect(find.text('عرض 11–20 من 25'), findsOneWidget);
    expect(find.text('صف 10'), findsOneWidget);
    expect(find.text('صف 0'), findsNothing);
  });

  testWidgets('selects rows and reports stable ids', (tester) async {
    Set<Object>? selected;
    await tester.pumpWidget(
      _wrap(
        _table(
          rows: rows,
          enableSelection: true,
          onSelectionChanged: (value) => selected = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();

    expect(selected, isNotNull);
    expect(selected!.length, 1);
    expect(selected, contains('B'));
  });

  testWidgets('shows loading, error and empty states', (tester) async {
    await tester.pumpWidget(_wrap(_table(rows: const [], loading: true)));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    var retried = false;
    await tester.pumpWidget(
      _wrap(
        _table(
          rows: const [],
          error: 'تعذّر الاتصال',
          onRetry: () => retried = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('تعذّر الاتصال'), findsOneWidget);
    await tester.tap(find.text('إعادة المحاولة'));
    expect(retried, isTrue);

    await tester.pumpWidget(
      _wrap(_table(rows: const [], emptyTitle: 'لا يوجد عملاء')),
    );
    await tester.pumpAndSettle();
    expect(find.text('لا يوجد عملاء'), findsOneWidget);
  });

  testWidgets('renders in both RTL and LTR directions', (tester) async {
    await tester.pumpWidget(
      _wrap(_table(rows: rows), direction: TextDirection.rtl),
    );
    await tester.pumpAndSettle();
    expect(find.text('الاسم'), findsOneWidget);

    await tester.pumpWidget(
      _wrap(_table(rows: rows), direction: TextDirection.ltr),
    );
    await tester.pumpAndSettle();
    expect(find.text('الاسم'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('persists widths across controller instances', (tester) async {
    final store = MemoryTablePreferencesStore();
    final first = TablePreferencesController(
      tableId: 'persisted',
      columnIds: const ['id', 'name', 'score'],
      store: store,
    );
    await first.load();
    first.setWidth('name', 240);
    await tester.pump(const Duration(milliseconds: 400));

    final second = TablePreferencesController(
      tableId: 'persisted',
      columnIds: const ['id', 'name', 'score'],
      store: store,
    );
    await second.load();
    expect(second.value.widths['name'], 240);

    first.dispose();
    second.dispose();
  });

  test('drops stale ids and clamps invalid preferences', () async {
    final store = MemoryTablePreferencesStore({
      'stale': {
        'order': ['ghost', 'name'],
        'hidden': ['ghost', 'id'],
        'widths': {'ghost': 9999, 'name': 10},
        'pageSize': 999,
        'sortColumnId': 'ghost',
        'sortAscending': false,
      },
    });
    final controller = TablePreferencesController(
      tableId: 'stale',
      columnIds: const ['id', 'name'],
      requiredColumnIds: const {'id'},
      store: store,
    );
    await controller.load();

    expect(controller.value.order, const ['name', 'id']);
    expect(controller.value.hidden, isEmpty);
    expect(controller.value.widths['name'], TablePreferences.minWidth);
    expect(controller.value.widths.containsKey('ghost'), isFalse);
    expect(controller.value.pageSize, 25);
    expect(controller.value.sortColumnId, isNull);

    controller.dispose();
  });

  testWidgets('extracts every sort key once instead of once per comparison', (
    tester,
  ) async {
    var extractions = 0;
    final many = [
      for (var index = 0; index < 200; index++)
        _Row('r$index', 'اسم $index', index),
    ];
    await tester.pumpWidget(
      _wrap(
        AppDataTable<_Row>(
          columns: [
            AppTableColumn<_Row>(
              id: 'score',
              label: 'الدرجة',
              sortable: true,
              sortValue: (row) {
                extractions++;
                return row.score;
              },
              builder: (context, row) => Text('${row.score}'),
            ),
          ],
          rows: many,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      extractions,
      0,
      reason: 'sorting starts only when a header is tapped',
    );

    await tester.tap(find.text('الدرجة'));
    await tester.pumpAndSettle();

    // One extraction per row. A comparator that reads the key on every
    // comparison would call it O(n log n) times.
    expect(extractions, many.length);

    // Reversing the direction reuses the extracted keys.
    await tester.tap(find.text('الدرجة'));
    await tester.pumpAndSettle();
    expect(extractions, many.length);
  });

  testWidgets('rebuilds only the rows touched by the keyboard cursor', (
    tester,
  ) async {
    var builds = 0;
    final many = [
      for (var index = 0; index < 40; index++)
        _Row('r$index', 'اسم $index', index),
    ];
    await tester.pumpWidget(
      _wrap(
        AppDataTable<_Row>(
          columns: [
            AppTableColumn<_Row>(
              id: 'name',
              label: 'الاسم',
              builder: (context, row) {
                builds++;
                return Text(row.name);
              },
            ),
          ],
          rows: many,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Only the visible rows are built: the list is virtualised.
    expect(builds, lessThan(many.length));

    builds = 0;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    // The cursor moved to the first row, so only that row repaints.
    expect(builds, lessThanOrEqualTo(2));

    builds = 0;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    // Now two rows change: the one that lost the cursor and the one that got
    // it. The rest of the viewport is untouched.
    expect(builds, lessThanOrEqualTo(4));
    expect(builds, lessThan(many.length));
  });

  testWidgets('applies the stored density to the row height', (tester) async {
    final store = MemoryTablePreferencesStore({
      'dense': {'density': 'compact'},
    });
    await tester.pumpWidget(
      _wrap(_table(rows: rows, tableId: 'dense', store: store)),
    );
    await tester.pumpAndSettle();

    final gap =
        tester.getTopLeft(find.text('A')).dy -
        tester.getTopLeft(find.text('C')).dy;
    expect(gap, closeTo(TableDensity.compact.rowHeight, 1));
  });

  testWidgets('switches the row density from the column settings', (
    tester,
  ) async {
    final store = MemoryTablePreferencesStore();
    await tester.pumpWidget(
      _wrap(_table(rows: rows, tableId: 'density-switch', store: store)),
    );
    await tester.pumpAndSettle();

    double rowGap() =>
        tester.getTopLeft(find.text('A')).dy -
        tester.getTopLeft(find.text('C')).dy;
    expect(rowGap(), closeTo(TableDensity.comfortable.rowHeight, 1));

    await tester.tap(find.byTooltip('إعدادات الجدول'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مدمج'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تم'));
    await tester.pumpAndSettle();

    expect(rowGap(), closeTo(TableDensity.compact.rowHeight, 1));
  });

  testWidgets('renders a summary row aligned with the columns', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AppDataTable<_Row>(
          columns: [
            AppTableColumn<_Row>(
              id: 'name',
              label: 'الاسم',
              builder: (context, row) => Text(row.name),
            ),
            AppTableColumn<_Row>(
              id: 'score',
              label: 'الدرجة',
              alignment: AlignmentDirectional.centerEnd,
              summary: (rows) =>
                  '${rows.fold<int>(0, (sum, row) => sum + row.score)}',
              builder: (context, row) => Text('${row.score}'),
            ),
          ],
          rows: rows,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The label sits in the first column and the total in the second one.
    expect(find.text('الإجمالي'), findsOneWidget);
    expect(find.text('80'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('80')).dx,
      lessThan(tester.getTopLeft(find.text('الإجمالي')).dx),
    );
  });

  testWidgets('toggles the zebra rows and the column dividers', (tester) async {
    final store = MemoryTablePreferencesStore();
    await tester.pumpWidget(
      _wrap(_table(rows: rows, tableId: 'appearance', store: store)),
    );
    await tester.pumpAndSettle();

    BoxDecoration? rowDecoration(String label) {
      final container = tester.widget<Container>(
        find
            .ancestor(of: find.text(label), matching: find.byType(Container))
            .first,
      );
      return container.decoration is BoxDecoration
          ? container.decoration as BoxDecoration
          : null;
    }

    expect(rowDecoration('A')?.color, isNull);

    await tester.tap(find.byTooltip('إعدادات الجدول'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('صفوف متناوبة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تم'));
    await tester.pumpAndSettle();

    // The second row of the list is tinted, the first one is not.
    expect(rowDecoration('A')?.color, isNotNull);
    expect(rowDecoration('C')?.color, isNull);

    // Every column but the first one is separated by a vertical line.
    final dividers = find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).border != null,
    );
    expect(dividers, findsWidgets);
  });

  testWidgets('resets a resized column on a double click', (tester) async {
    final store = MemoryTablePreferencesStore();
    await tester.pumpWidget(
      _wrap(_table(rows: rows, tableId: 'resize', store: store)),
    );
    await tester.pumpAndSettle();

    double headerWidth(String label) => tester
        .getSize(
          find
              .ancestor(of: find.text(label), matching: find.byType(SizedBox))
              .first,
        )
        .width;

    final before = headerWidth('الاسم');
    final handle = find.byKey(const ValueKey<String>('app-table-resize-name'));
    expect(handle, findsOneWidget);

    // In RTL the handle sits on the left edge of the column and dragging it
    // to the left widens the column.
    await tester.timedDragFrom(
      tester.getCenter(handle),
      const Offset(-70, 0),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();
    expect(headerWidth('الاسم'), greaterThan(before));

    await tester.tap(handle);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(handle);
    await tester.pumpAndSettle();

    expect(headerWidth('الاسم'), closeTo(before, 1));
  });
}
