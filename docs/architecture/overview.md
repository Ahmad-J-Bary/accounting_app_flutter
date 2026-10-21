# Architecture Overview

This document records the architectural style that the repository already
follows, the boundaries between Rust and Flutter, and the rules that keep
accounting behaviour out of the UI. It is descriptive first: new code should
extend these boundaries rather than introduce a parallel architecture.

## Style: DDD inside a hexagonal core

The project uses **Domain-Driven Design for the accounting model** and a
**ports-and-adapters (hexagonal) boundary** around it. It is not a full
"Clean Architecture" four-ring layout, because the extra rings would duplicate
the domain/application split without adding a rule that is actually enforced.

| Layer | Crate / directory | Responsibility | Must not |
|---|---|---|---|
| Domain | `crates/domain` | Entities, value objects, double-entry rules, posting rules, money arithmetic | Read files, open SQLite, know about Flutter or HTTP |
| Application | `crates/application` | Use cases, commands/queries, DTOs, repository ports | Contain SQL or widget code |
| Infrastructure | `crates/infrastructure` | SQLite repositories, migrations, search providers, transactions | Decide accounting policy |
| Composition | `crates/bridge` | Builds `AppState` from concrete repositories and use cases | Contain accounting rules or UI code |
| FFI adapter | `packages/accounting_app_flutter_isolates/rust/src/api` | Converts bridge calls to FRB-friendly DTOs and errors | Reimplement use cases |
| Flutter app | `app/lib` | Rendering, navigation, forms, local table preferences | Compute balances, post entries, or bypass the bridge |

Dependency direction:

```text
Flutter widgets / pages
        │  (LedgerGateway)
        ▼
accounting_app_flutter_isolates (Dart + FRB generated glue)
        │
        ▼
FRB API (rust/src/api) ──► bridge::AppState ──► application use cases
                                                   │
                                                   ▼
                                             domain rules
                                                   ▲
                                                   │
                                      infrastructure ports (SQLite)
```

`crates/bridge` is the only composition root. The Axum server, the CLI and the
Flutter bridge all construct the same `AppState`, so a rule cannot diverge
between desktop, mobile and server.

## Why this style

- **Accounting rules have one home.** A rule such as "a posted voucher cannot
  be deleted" lives in the domain/application layer, not in a Flutter callback.
  The UI may hide an action, but the core still rejects it.
- **The ports are real seams.** SQLite is replaceable for tests and for the
  future sync layer; the application layer depends on traits, not `sqlx`.
- **DDD is used where it pays.** Money, accounts, journal entries, invoices and
  inventory have invariants. Generic CRUD screens do not need aggregates.
- **Full Clean Architecture was rejected.** Four concentric layers plus DTO
  mapping at every ring would add ceremony without a new boundary. Hexagonal
  ports already isolate the domain from delivery mechanisms.
- **Vertical slices are acceptable inside the application layer.** A new
  document type gets a focused use-case module instead of a broad refactor.

## Request flow

A typical write from Flutter:

1. A page calls `LedgerGateway` (`app/lib/ledger.dart`).
2. `RustLedgerGateway` ensures `RustLib.init()` ran and opens
   `accounting.db` in the application-support directory.
3. The call crosses the generated FRB binding into `rust/src/api`.
4. The API adapter calls a use case on `bridge::AppState`.
5. The use case validates domain invariants, then calls repository ports.
6. `crates/infrastructure` executes the SQL inside the transaction boundary
   chosen by the use case.
7. A DTO/result travels back through FRB; Flutter refreshes its workspace data
   from the core instead of mutating cached totals locally.

Reads follow the same path. Flutter may filter and format the returned data for
display (search, sort, currency formatting), but it never derives an
authoritative balance from raw rows.

## Accounting invariants

These rules are owned by Rust. UI work must preserve them:

- Every journal entry is balanced before it can be posted.
- Money uses decimal arithmetic, not binary floating point, at the core.
- Posted documents are immutable; corrections use the documented reversal or
  return flows.
- Master-data deletion is refused when posted history references the record.
- Migrations and multi-table writes are transactional.
- Audit-trail records are not silently deleted.
- Inventory quantities and costs are derived from posted movements.

The Flutter table, filters and pagination are presentation concerns. They may
hide a row, but they must not weaken a guard.

## Module map

| Area | Location |
|---|---|
| Journal, trial balance, opening balances | `crates/domain/src/accounting`, `app/lib/journal.dart`, `app/lib/opening_balances.dart` |
| Customers / suppliers / materials | `crates/domain/src/{customers,suppliers,inventory}`, `app/lib/features/*` |
| Sales, purchases, returns | `crates/domain/src/{sales,purchases,returns}` |
| Payments and expenses | `crates/domain/src/payments`, `app/lib/payments_expenses.dart` |
| SQLite and migrations | `crates/infrastructure/src/db`, `crates/infrastructure/src/repositories` |
| FRB API | `packages/accounting_app_flutter_isolates/rust/src/api` |
| Flutter design system | `app/lib/theme`, `app/lib/ui` |
| Workspace shell and navigation | `app/lib/app_shell.dart` |

## Adding a feature

1. Decide whether the rule belongs to the domain. If yes, add it there first
   with unit tests.
2. Add or extend an application use case and its port. Keep DTOs free of
   framework types.
3. Implement the port in infrastructure with a transaction and a test against a
   temporary SQLite database.
4. Expose the smallest possible surface through `crates/bridge` and the FRB
   `api` module.
5. Regenerate FRB bindings with the pinned version (see
   `docs/development/frb-codegen.md`).
6. Build the Flutter page with the shared design system and table. Add widget
   tests for empty, loading, error and RTL states where relevant.
7. Run the quality gates in `README.md`.

## Testing strategy

- **Domain:** pure unit tests for invariants and edge cases.
- **Application:** use-case tests with mocked ports.
- **Infrastructure:** real SQLite tests covering transactions, migrations and
  concurrency guards.
- **Bridge:** smoke tests plus the Windows FFI integration test.
- **Flutter:** widget tests for navigation, forms, tables, back handling,
  shortcuts and RTL/LTR.

The test pyramid is deliberately weighted toward Rust: that is where the
accounting risk lives.

## Known architectural debt

- The Axum/PostgreSQL sync layer is still a stub; SQLite is the local source of
  truth.
- Some legacy screens still hold page-level filtering logic. New list screens
  should use the shared `AppDataTable` contract instead.
- Generated FRB files are tracked so builds do not require codegen at compile
  time; CI verifies they are fresh.
- There is no full i18n switch yet. Arabic strings and RTL layout are the
  product default, with LTR support exercised in table tests.
