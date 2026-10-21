# Navigation, Back Handling and Shortcuts

The workspace is a single shell with section pages. Customers, suppliers and
materials are independent pages and routes-in-shell; there is no
`selectedEntityType` mega-page.

## Sections

`WorkspaceSection` in `app/lib/app_shell.dart` lists every destination:
dashboard, journal, sales/purchase invoices, sales/purchase returns, receipts,
payments, expenses, customers, suppliers, materials.

Selection rules:

- Selecting the current section is a no-op; it does not push a duplicate
  history entry.
- Selecting a different section pushes the previous section onto `_history`.
- `_history` is bounded to 50 entries; the oldest entry is dropped first.
- Dashboard cards and the command palette use the same `_select` path, so back
  behaviour is identical from every entry point.

## Back navigation

There are four supported ways to go back, and they all converge on `_goBack()`:

| Source | Behaviour |
|---|---|
| Top-bar back button | Visible only when history is non-empty. Icon flips in RTL (`arrow_forward`) and LTR (`arrow_back`). Tooltip: `رجوع`. |
| Android system back | `PopScope(canPop: !_canGoBack)`. With history, the pop is intercepted and `_goBack()` runs; with no history, the app exits normally. |
| `Alt+Left` | Shell-level `CallbackShortcuts`. |
| `Escape` | Shell-level `CallbackShortcuts`; dialogs and other focused routes handle their own Escape first. |

### Dialog and panel behaviour

Dialogs, drawers, command palette and form routes are separate routes. Their
own `Navigator.pop` / barrier handling runs before the shell shortcut. The shell
only receives back/escape when no child route has consumed it. This is why the
shell does not try to close dialogs imperatively.

### Unsaved changes

`UnsavedChangesGuard` (`app/lib/ui/unsaved_changes.dart`) wraps the customer,
supplier and material forms. It uses `PopScope`:

- `canPop` is false while the form is dirty.
- A back attempt shows `تغييرات غير محفوظة` with `البقاء` and
  `مغادرة دون حفظ`.
- Choosing discard pops the form; choosing stay leaves it open.
- Saving sets the dirty flag to false before popping, so the guard does not
  prompt after a successful save.

Dirty tracking is driven by `Form.onChanged` plus the controls that do not
participate in form validation (switches, add/remove extra units). If a new
control is added to a form, mark the form dirty from its callback as well.

## Keyboard shortcuts

| Shortcut | Action | Scope |
|---|---|---|
| `Ctrl+K` | Open the command palette | Shell |
| `Alt+Left` | Go to the previous section | Shell |
| `Escape` | Go to the previous section | Shell, when no dialog/route consumes it |
| `Tab` / `Shift+Tab` | Move focus | Standard Flutter focus traversal |
| `Enter` / `Space` | Activate focused control | Standard Material behaviour |

Guidelines:

- Do not add a global single-letter shortcut; text fields must keep receiving
  input.
- Prefer `CallbackShortcuts` on the shell for navigation and local
  `Shortcuts`/`Actions` for page-specific commands.
- A new shortcut needs a widget test that sends the real key event, not just a
  direct method call.

## RTL and LTR

- The app defaults to RTL for Arabic.
- Use directional icons and `AlignmentDirectional`/`EdgeInsetsDirectional`.
- The back icon flips; next/previous pagination icons use the table's
  direction-aware logic.
- Horizontal scrolling and column order are unchanged by text direction; only
  alignment and directional icons flip.

## Testing

`app/test/widget_test.dart` covers:

- opening customers, suppliers and materials as independent pages;
- in-app back to the previous section;
- Android system back (`handlePopRoute`);
- `Alt+Left` and `Escape`;
- unsaved-change warning, stay and discard.

When adding a section, update `_sectionLabel`, `_content`, the sidebar, the
command palette and the navigation tests together.
