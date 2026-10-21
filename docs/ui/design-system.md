# UI Design System and Data Table

The Flutter app uses one shared visual language and one shared table contract.
Pages compose these pieces; they do not fork their own buttons, table headers or
empty states.

## Tokens and theme

| Concern | Location |
|---|---|
| Theme, colours, typography | `app/lib/theme/app_theme.dart` |
| Spacing / radius tokens | `AppSpacing`, `AppRadius` in the theme module |
| Semantic colours | `context.semanticColors` (success, info, warning, sidebar) |
| Font | Bundled Cairo family declared in `app/pubspec.yaml` |
| Shared widgets | `app/lib/ui/app_ui.dart` |

Rules:

- Use `Theme.of(context)` and semantic tokens. Do not hard-code colours in a
  page.
- Use directional alignment (`AlignmentDirectional`, `EdgeInsetsDirectional`)
  so the same widget works in RTL and LTR.
- Prefer existing widgets (`AppCard`, `AppPageHeader`, `AppMetricCard`,
  `AppEmptyState`, `AppErrorState`, `AppBadge`, `AppIconTile`,
  `MasterDataSearchBar`) over new one-off containers.
- Keep touch targets at least 44×44 logical pixels; icon buttons already use
  Material's 48 px minimum.

## Shared components

`app/lib/ui/app_ui.dart` provides:

- Layout: `AppCard`, `AppSectionCard`, `AppPageHeader`, `AppMetricGrid`,
  `AppMetricCard`.
- Feedback: `AppBadge`, `AppEmptyState`, `AppErrorState`, `AppLoadingState`,
  `AppIconTile`.
- Input: `AppSearchField`.
- Data: `AppTableColumn<T>`, `AppDataTable<T>`, `AppTableText`.
- Master-data helpers: `MasterDataPageLayout`, `MasterDataSearchBar`, delete
  confirmation and snackbar helpers in
  `app/lib/features/master_data/master_data_shared.dart`.

## `AppDataTable` contract

`AppDataTable<T>` is a controlled presentation widget. The page owns the data,
filtering and refresh; the table owns presentation state and (optionally)
preferences.

### Required inputs

- `columns`: ordered `AppTableColumn<T>` definitions.
- `rows`: already filtered/sorted-by-source rows. Filtering is deliberately
  outside the table so the same widget works for local and future remote data.
- `rowId`: stable identity. Required when `enableSelection` is true.

### Column identity

Every new column must provide a stable `id` (for example `customer.code`).
The id, not the label or index, is what preferences and tests use. If an old
call site omits `id`, the table falls back to the label; do not rely on that in
new code.

A column may declare:

- `flex`, `width`, `minWidth`: sizing. Fixed `width` wins; otherwise flexible
  columns share the remaining space and respect `minWidth`.
- `sortable` + `sortValue`: client-side sorting. Null values sort last.
- `searchText`: available to page-level search helpers.
- `visibleByDefault`, `canHide`: visibility. At least one column always stays
  visible.
- `canResize`: whether the column menu exposes width controls.
- `alignment` / `headerAlignment`: use directional values.

### Behaviour

| Feature | Behaviour |
|---|---|
| Sorting | Click a sortable header; second click reverses. Sorting is by the column's `sortValue`, never by rendered text. |
| Column menu | Show/hide, move left/right, reset widths/order/visibility, or restore every hidden column with «إظهار الكل». Required columns cannot be hidden. Hidden columns stop reserving width, so the remaining columns share the freed space. A badge on the toolbar icon shows how many columns are hidden. |
| Resize | Drag the handle at the column edge; widths clamp to 56–720 px. |
| Pagination | Optional local pagination with page sizes 10/25/50/100. Footer shows the visible range and stacks into two rows below 520 px so it never overflows on phones. |
| Selection | Optional checkboxes with select-all; `onSelectionChanged` reports stable `rowId` values, not row indices. Space toggles the focused row. |
| Keyboard | Focus the table (click any part of it), then: ↑/↓ move the row cursor, Home/End jump to the first/last row, PageUp/PageDown move by a viewport, Enter opens the row (`onRowTap`), Space toggles selection. The focused row is outlined and scrolled into view. |
| Scrolling | Rows scroll vertically; columns scroll horizontally with an interactive scrollbar at the bottom edge. |
| Long text | Use `AppTableText` for every single-line cell: it clamps to one line with an ellipsis, so a long name never produces a vertical overflow inside the fixed row height. |
| Loading | Replaces the body with a progress indicator while headers remain available. |
| Error | Shows the message and an optional retry action. |
| Empty | Shows title/message/action; distinguish "no data yet" from "no matches". |
| RTL/LTR | Directional alignment and icons; horizontal scrolling works in both directions. |
| Long lists | Rows are built lazily with `ListView.builder` when height is bounded. Page or sort changes jump the vertical scroll back to the top. |
| Footer | Horizontally scrollable and at least `minWidth` wide, so totals do not overflow on phones. |

### Sizing and scrolling

- Set `minWidth` to the smallest width at which the columns remain readable.
  The table scrolls horizontally below that width.
- Do not wrap the table in an unbounded-height scroll view. Give it a bounded
  height (for example `Expanded`) so lazy row building is used.
- The table recomputes its content width from the resolved column widths; this
  prevents the "10 px RenderFlex overflow" class of bugs when minimum widths
  and flex distribution disagree.
- Keep the page chrome above the table fixed (`MasterDataPageLayout`): the table
  owns the remaining height and scrolls internally.

### Master-data page layout

`MasterDataPageLayout` owns the shared chrome of the customers, suppliers and
materials pages:

- Header (`AppPageHeader`) and search strip stay fixed above the table.
- Metric cards are shown from 720 px upward. On a phone the three cards stack
  into a single column taller than the viewport and would push the table off
  screen, so they are hidden below that breakpoint.
- At 430×900 the customers page keeps a usable table plus the compact
  two-row pagination bar; a widget test guards against overflow regressions.

### Page integration checklist

1. Give every column a stable `id`.
2. Give the table a stable `tableId` if preferences should persist.
3. Provide `rowId` when selection is enabled.
4. Pass filtered rows and keep the filter state in the page.
5. Set a realistic `minWidth`.
6. Provide distinct empty titles for "no data" and "no matches".
7. Wire `loading`, `error` and `onRetry` to the gateway state.
8. Add a widget test for sorting/pagination/visibility if the page customises
   the table beyond the defaults.

## Table preferences

Files:

- `app/lib/ui/table/table_preferences.dart` — validated model and controller.
- `app/lib/ui/table/table_preferences_store.dart` — conditional export.
- `app/lib/ui/table/table_preferences_store_io.dart` — JSON file store.
- `app/lib/ui/table/table_preferences_store_stub.dart` — in-memory store for
  web and tests.

### Storage

On desktop/mobile the IO store writes `table_preferences.json` in the same
application-support directory as `accounting.db`:

```json
{
  "version": 1,
  "tables": {
    "customers": {
      "order": ["code", "name", "phone"],
      "hidden": ["phone"],
      "widths": {"name": 240},
      "pageSize": 25,
      "sortColumnId": "name",
      "sortAscending": true
    }
  }
}
```

Writes are atomic: the store writes a temporary file and renames it. A corrupt
or unreadable file is treated as "no preferences" and never blocks accounting
work.

### Validation and stale data

Preferences are untrusted input from an older build. On load:

- Unknown column ids are dropped.
- New columns are appended to the stored order.
- Required columns are never hidden.
- Widths are clamped to 56–720 px.
- Page size must be one of 10/25/50/100.
- A sort column that no longer exists is cleared.
- If every column would be hidden, the first column is kept visible.

A failed load or save only logs a debug message and keeps the in-memory
defaults. Preferences are a convenience, not accounting data.

### Persistence timing

Changes are applied immediately and saved after a 350 ms debounce. Disposing
the table flushes the latest value. `reset()` restores defaults and clears the
stored entry.

## Accessibility and RTL

- Every icon-only action has a tooltip (for example `إعدادات الأعمدة`,
  `الصفحة التالية`, `رجوع`).
- Table headers expose the sort action through an `InkWell` wrapped in
  `Semantics(button: ...)`; keep the label readable and avoid icon-only headers.
- The select-all checkbox announces «تحديد كل الصفوف في هذه الصفحة».
- The table is reachable with Tab and fully operable with the keyboard (see the
  keyboard row in the behaviour table); the focused row is visible, not just
  selected.
- Use `AppTableText` (or an explicit `maxLines: 1` + `TextOverflow.ellipsis`)
  for fixed-width cells and keep the full value in the row detail/form.
- Verify both `TextDirection.rtl` and `TextDirection.ltr` in tests. Icons that
  imply direction (back/next) must flip with the direction.
- Do not encode meaning in colour alone; badges also carry text/icons.

## Performance guidance

- Keep `columns` definitions stable in shape. Rebuilding the list with the same
  ids is fine; changing ids at runtime is treated as a schema change.
- Do not do expensive formatting in `builder`; precompute per-row display
  strings when the list is large.
- Prefer client-side filtering for the current local SQLite dataset. If a page
  moves to server-side paging, keep `AppDataTable` controlled and pass only the
  current page.
- Avoid nesting the table inside another vertical `ListView`; use `Expanded` or
  a fixed height.

## Tests

`app/test/table_test.dart` covers sorting, keyboard navigation (arrows, Enter,
End, Space), column hiding (including width redistribution, «إظهار الكل» and
restoring the column), adopting saved preferences when the table id changes,
pagination, selection, loading/error/empty states, RTL/LTR, single-line cell
ellipsis, width persistence and stale preference sanitisation. Page-level tests
live in `app/test/widget_test.dart`, including the 430×900 customers-page
layout.
