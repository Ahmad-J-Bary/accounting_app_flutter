# المرحلة 1 — جسر FRB والشريحة الرأسية الأولى

تاريخ التنفيذ: 2026-10-20
الفرع: `feat/frb-bridge`

## ما تم بناؤه

### 1. `crates/bridge` كنقطة تجميع (Composition Root)

- crate جديد باسم `bridge` يعتمد على `domain` + `application` + `infrastructure` فقط.
- نُقل `AppState` كاملاً (40 حقلاً: 34 مستودعاً + 5 خدمات + `pool`) من
  `accounting-app/crates/tauri-adapter/src/bootstrap/container.rs`.
- لا يوجد أي اعتماد على `tauri` داخل الـcrate الجديد.
- أُضيفت دالتان:
  - `database_url_from_path(db_path)`: ينشئ المجلد الأب عند الحاجة ويبني رابط SQLite
    بصيغة `sqlite:<path>?mode=rwc`.
  - `ensure_default_fiscal_year(state)`: عند أول تشغيل فقط، ينشئ سنة مالية وفترة
    مالية مفتوحتين للسنة الميلادية الحالية، لأن سياسة الترحيل ترفض أي قيد خارج
    سنة/فترة مفتوحة. لا يعدّل سنوات أو فترات موجودة.

### 2. تحويل crate الـFRB إلى الـcore الحقيقي

- `packages/accounting_app_flutter_isolates/rust/Cargo.toml`:
  - أزيل الاعتماد على `accounting-core` (الـstub).
  - أضيف: `bridge`, `application`, `domain`, `serde_json`, `tokio`.
- أُعيد توليد ملفات FRB بالأداة الرسمية
  `flutter_rust_bridge_codegen 2.13.0`، ولم تُعدّل يدوياً.

### 3. واجهة FRB الجديدة

الملف: `packages/accounting_app_flutter_isolates/rust/src/api/accounting.rs`

| الدالة | الوظيفة |
|---|---|
| `init_app(db_path)` | يفتح/ينشئ قاعدة SQLite، يشغّل 115 migration، يبني `AppState`، وينشئ السنة المالية الافتراضية عند أول تشغيل |
| `list_accounts()` | يعيد دليل الحسابات من قاعدة البيانات |
| `create_journal_entry(input)` | ينشئ قيداً بحالة `Draft` عبر `CreateJournalEntryUseCase` |
| `post_journal_entry(entry_id)` | يرحّل القيد ويحدّث أرصدة الحسابات عبر `PostJournalEntryUseCase` |
| `trial_balance(from_date?, to_date?)` | يعيد ميزان المراجعة |

### 4. نقل منطق ميزان المراجعة إلى `application`

- أُنشئت `application::use_cases::reports::GetTrialBalanceUseCase`.
- نُقل المنطق حرفياً من `tauri-adapter/src/commands/report.rs` (نفس معالجة
  الرصيد الطبيعي، ونفس تقسيم opening/period عند تمرير تاريخين، ونفس الترتيب حسب
  رمز الحساب).
- الهدف: لا تتكرر قواعد التقارير في الجسر أو الـCLI أو الـAPI.

### 5. شاشة Flutter الأولى

الملفات:
- `app/lib/ledger.dart`: نماذج واجهة + `LedgerGateway` مجرّد + `RustLedgerGateway`.
- `app/lib/main.dart`: شاشة عربية RTL فيها:
  - إجمالي المدين والدائن.
  - نموذج قيد يومية (حساب مدين، حساب دائن، مبلغ، بيان).
  - جدول ميزان المراجعة.
  - حالات التحميل والخطأ وإعادة المحاولة.
- `app/integration_test/bridge_test.dart`: اختبار تكامل حقيقي على Windows.
- `app/test/widget_test.dart`: اختبارا واجهة بلا FFI (بوابة وهمية).

## ما تم إثباته فعلياً

| الفحص | النتيجة |
|---|---|
| `cargo check -p bridge` | نجح |
| `cargo check -p accounting_app_flutter_isolates` | نجح |
| `cargo test -p bridge` | نجح: فتح قاعدة جديدة، زرع دليل الحسابات، إنشاء قيد، ترحيله، وميزان متوازن |
| `cargo test --workspace --quiet` | نجح: 496 اختباراً، 0 فشل |
| `cargo fmt --all -- --check` | نجح |
| `flutter analyze` | `No issues found` |
| `flutter test` | نجح: 2/2 |
| `flutter test integration_test/bridge_test.dart -d windows` | نجح: استدعاء Dart→Rust حقيقي، SQLite، migrations، إنشاء وترحيل قيد، وقراءة ميزان المراجعة |
| بناء Rust لأندرويد | نجح للبنى الثلاث: `arm64-v8a` (9.59 MB)، `armeabi-v7a` (7.31 MB)، `x86_64` (9.50 MB) |

اختبار Windows هو الدليل الحاسم: لم يكن اختبار واجهة فقط، بل حمّل مكتبة Rust
المترجمة، ونفّذ عدة دوال عبر FFI، وكتب في قاعدة SQLite فعلية على القرص.

## ما لم يُثبت بعد

1. **Flutter 3.41.9 محلياً**: لا يزال غير متاح. المحلي 3.41.7/Dart 3.11.5،
   وCI يستخدم 3.41.9. `fvm install` ما زال يفشل (شبكة)، وأداة FRB تحاول
   تشغيله ثم تكمل بعد فشله.
2. **حزمة APK بعد تغييرات الجسر**: تُرجمت مكتبة Rust بنجاح للبنى الثلاث
   (arm64-v8a / armeabi-v7a / x86_64)، لكن تجميع APK محلياً توقف عند تحميل
   AndroidX من `dl.google.com` (404 في هذه البيئة: `lifecycle-common:2.7.0`،
   `fragment:1.7.1`، وغيرها). الـAPK الموجود حالياً عمره من Phase 0 ولا يحتوي
   المكتبة الجديدة. يحتاج CI إلى إكمال التغليف والتحقق من `.so` داخل APK.
   ملاحظة: إضافة `integration_test` تجعل Flutter يطلب AGP 8.11.0؛ استُخدم
   محلياً ملف init مؤقت لفرض 8.11.1 ثم حُذف، ولم يُرفع للمستودع.
3. **بقية الأوامر**: 147 أمراً يستدعيها React لم تُنقل بعد؛ المنقول حالياً 5
   دوال فقط. الأوامر الـ68 غير المستخدمة لم تُراجع.
4. **الواجهة**: شاشة واحدة فقط. لا يوجد shell، ولا تنقّل، ولا i18n switching،
   ولا themes، ولا RBAC، ولا تدقيق واجهة.
5. **الفلاتر الزمنية**: `trial_balance` يدعم `from_date/to_date`، لكن الشاشة لا
   تعرضهما بعد.
6. **السنة المالية**: الإنشاء الافتراضي هو سنة ميلادية واحدة. لا توجد واجهة
   لإدارة السنوات/الفترات أو الإغلاق.
7. **تعدد قواعد البيانات**: `init_app` يستخدم `OnceCell` واحداً؛ لا يدعم فتح
   أكثر من قاعدة/شركة في نفس العملية.
8. **الأداء**: لم يُقس حجم قاعدة البيانات ولا زمن فتحها مع بيانات كبيرة.

## الخطوة التالية

1. نقل أوامر دليل الحسابات والعملاء والموردين والمواد (الأكثر استخداماً في
   React) إلى واجهة FRB فوق نفس `AppState`.
2. إضافة شاشات القوائم الأساسية فوق الشريحة الحالية.
3. إعادة بناء Android APK والتحقق من `.so` بعد تغييرات الجسر.
4. مراجعة الأوامر الـ68 غير المستخدمة والأوامر الأربعة المفقودة
   (`delete_role`, `update_role`, `update_sales_return`, `update_purchase_return`).
5. الانتقال إلى Phase 3 (نظام التصميم والـshell) أو Phase 6 (Axum/PostgreSQL)
   حسب الأولوية.
