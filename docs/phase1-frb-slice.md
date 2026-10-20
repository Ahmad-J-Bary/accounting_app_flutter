# المرحلة 1 — جسر FRB والشريحة الرأسية الأولى

تاريخ التنفيذ: 2026-10-20
الفرع: `feat/frb-bridge`

## الخلاصة التنفيذية

اكتملت المرحلة 0 محلياً (Flutter 3.41.9 متاح الآن عبر FVM)، واكتملت
قائمة قبول المرحلة 1 التي طلبتها:

1. `init_app` يفتح قاعدة SQLite حقيقية ويشغّل الـmigrations.
2. `setup_company` يحفظ هوية الشركة والعملة الأساسية/الثانوية، ويُنشئ أول
   سنة وفترة مالية حسب شهر البداية المختار.
3. `is_setup_complete` و`get_setup_status` يعيدان حالة الإعداد.
4. الخطأ الموحّد `ApiError { code, message, details }` يعبر FRB ككائن Dart
   وليس كنص غامض.
5. شاشة Flutter تعرض **«جاهز»** بعد نجاح `init_app` + `setup_company`، مع اسم
   الشركة والعملة الأساسية.
6. إنشاء قيد يومية وترحيله وقراءة ميزان المراجعة من Rust.
7. قوائم قراءة للعملاء والموردين والمواد فوق نفس `AppState`.

> ملاحظة مهمة: ما زال إنشاء ملف APK محلياً متعذراً بسبب شبكة هذه البيئة.
> ترجمة Rust لأندرويد نجحت سابقاً للبنى الثلاث، لكن التحقق النهائي من `.so`
> داخل APK يحتاج CI. لا يُعتبر APK القديم دليلاً على المرحلة 1.

## ما تم بناؤه

### 1. `crates/bridge` كنقطة تجميع (Composition Root)

- crate جديد باسم `bridge` يعتمد على `domain` + `application` + `infrastructure` فقط.
- نُقل `AppState` كاملاً (40 حقلاً: 34 مستودعاً + 5 خدمات + `pool`) من
  `accounting-app/crates/tauri-adapter/src/bootstrap/container.rs`.
- لا يوجد أي اعتماد على `tauri` داخل الـcrate الجديد.
- أُضيفت دالتان:
  - `database_url_from_path(db_path)`: ينشئ المجلد الأب عند الحاجة ويبني رابط
    SQLite بصيغة `sqlite:<path>?mode=rwc`.
  - `ensure_default_fiscal_year(state)`: يقرأ `settings.fiscal_year_start_month`
    وينشئ سنة وفترة مالية مفتوحتين إذا لم تكن موجودة. لا يعدّل أي سنة أو فترة
    موجودة، وهو no-op بعد الإعداد.
- `init_app` يستدعي bootstrap السنة المالية فقط إذا كانت الشركة مُعدّة مسبقاً.
  قاعدة البيانات الجديدة تنتظر `setup_company` لأن شهر البداية لا يُعرف قبله.

### 2. تحويل crate الـFRB إلى الـcore الحقيقي

- `packages/accounting_app_flutter_isolates/rust/Cargo.toml`:
  - أزيل الاعتماد على `accounting-core` (الـstub).
  - أضيف: `bridge`, `application`, `domain`, `serde_json`, `tokio`.
- أُعيد توليد ملفات FRB بالأداة الرسمية
  `flutter_rust_bridge_codegen 2.13.0`، ولم تُعدّل يدوياً.

### 3. واجهة FRB

الملف: `packages/accounting_app_flutter_isolates/rust/src/api/accounting.rs`

| الدالة | الوظيفة |
|---|---|
| `init_app(db_path)` | يفتح/ينشئ SQLite، يشغّل 115 migration، يبني `AppState`، ويستعيد bootstrap السنة المالية للشركة المُعدّة |
| `is_setup_complete()` | هل توجد عملة أساسية وهوية شركة؟ |
| `get_setup_status()` | اسم الشركة، العملة الأساسية ورمزها، شهر بداية السنة، حالة الإعداد |
| `setup_company(input)` | إعداد أول مرة: عملات + إعدادات + سنة/فترة مالية |
| `world_currencies()` | كتالوج العملات من Rust (لا نسخة ثانية في Dart) |
| `list_accounts()` | دليل الحسابات من قاعدة البيانات |
| `list_customers()` | قائمة العملاء (قراءة) |
| `list_suppliers()` | قائمة الموردين (قراءة) |
| `list_materials()` | قائمة المواد مع ملخص المخزون (قراءة) |
| `create_journal_entry(input)` | ينشئ قيداً بحالة `Draft` عبر `CreateJournalEntryUseCase` |
| `post_journal_entry(entry_id)` | يرحّل القيد ويحدّث أرصدة الحسابات عبر `PostJournalEntryUseCase` |
| `trial_balance(from_date?, to_date?)` | يعيد ميزان المراجعة |

كل دالة تعيد `Result<T, ApiError>`. `ApiError` يُولَّد كـDart class ويُرمى
مباشرة، ما يسمح للواجهة بالتفريق بين `not_initialized` و`conflict` و
`invalid` دون تحليل نص.

### 4. منطق الإعداد والتقارير في `application`

- `application::use_cases::reports::GetTrialBalanceUseCase`: منقول حرفياً من
  `tauri-adapter/src/commands/report.rs` (نفس الرصيد الطبيعي، نفس تقسيم
  opening/period، ونفس الترتيب حسب رمز الحساب).
- `application::use_cases::setup::SetupCompanyUseCase`: يتحقق من الاسم والشهر،
  يثبّت العملات عبر `CurrencySetupUseCase`، يحدّث الإعدادات، ثم يستدعي
  `EnsureDefaultFiscalYearUseCase`. يرفض إعادة الإعداد لتجنّب حذف عملات
  قائمة.
- `application::use_cases::fiscal_year::EnsureDefaultFiscalYearUseCase`: يبني
  نافذة السنة من أول يوم في شهر البداية حتى ثانية قبل نفس اليوم من السنة
  التالية، ويستخدم `CreateFiscalYearUseCase` و`CreateFiscalPeriodUseCase`
  الموجودين (بما فيهما فحص التداخل).
- النتيجة: Flutter وAxum وCLI سيستدعون نفس القواعد، لا نسخاً لكل ناقل.

### 5. شاشات Flutter

الملفات:
- `app/lib/ledger.dart`: نماذج الواجهة + `LedgerGateway` مجرّد +
  `RustLedgerGateway` + `describeError`.
- `app/lib/setup.dart`: معالج إعداد الشركة (اسم، عملة أساسية، عملة ثانوية
  اختيارية، شهر بداية السنة المالية).
- `app/lib/main.dart`: شاشة عربية RTL فيها:
  - شريط **«جاهز»** أخضر مع اسم الشركة والعملة الأساسية.
  - إجمالي المدين والدائن.
  - نموذج قيد يومية (حساب مدين، حساب دائن، مبلغ، بيان).
  - جدول ميزان المراجعة.
  - حالات التحميل والخطأ وإعادة المحاولة.
- `app/lib/directory.dart`: صفحة «البيانات الأساسية» بثلاثة تبويبات
  (العملاء، الموردون، المواد) مع بحث بالاسم/الرمز/الباركود.
- `app/integration_test/bridge_test.dart`: اختبار تكامل حقيقي على Windows.
- `app/test/widget_test.dart`: أربعة اختبارات واجهة بلا FFI.

### 6. توحيد رموز العملات

`application/src/world_currencies.rs` كان يستخدم رمز الريال القديم `﷼` لأربع
عملات، ويكتب «كرونا» بدل «كرونة». تم توحيد الرموز العربية لتكون واضحة في
الإعدادات والفواتير (مثل `ر.س` للريال السعودي، `ر.ق` للقطري، `ر.ع` للعماني،
`ر.ي` لليمني، `د.أ` للأردني) وتصحيح الإملاء. هذا يمنع حفظ رمز ملتبس في
`settings.currency_symbol` عند الإعداد.

## ما تم إثباته فعلياً

| الفحص | النتيجة |
|---|---|
| `cargo check -p bridge` | نجح |
| `cargo check -p accounting_app_flutter_isolates` | نجح |
| `cargo test -p bridge --test smoke` | نجح: اختبار الشريحة + اختبار إعداد الشركة (عملات، إعدادات، سنة/فترة، رفض إعادة الإعداد) |
| `cargo test --workspace --quiet` | نجح: **500 اختباراً**، 0 فشل |
| `cargo clippy --workspace --all-targets -- -D warnings` | نجح |
| `cargo fmt --all -- --check` | نجح |
| `fvm flutter analyze` | `No issues found` (Flutter 3.41.9 / Dart 3.11.5) |
| `fvm flutter test` | نجح: **4/4** |
| `fvm flutter test integration_test/bridge_test.dart -d windows` | نجح: Dart→Rust حقيقي، SQLite، migrations، `isSetupComplete=false`، `setupCompany`، `isSetupComplete=true`، قراءة العملاء/الموردين/المواد، **التقاط `ApiError` مكتوب**، إنشاء وترحيل قيد، ميزان متوازن |
| بناء Windows DLL | نجح: `app/build/windows/x64/runner/Debug/accounting_app_flutter_isolates.dll` |
| ترجمة Rust لأندرويد | نجحت سابقاً للبنى الثلاث: arm64-v8a، armeabi-v7a، x86_64 |

اختبار Windows هو الدليل الحاسم: لم يكن اختبار واجهة فقط، بل حمّل مكتبة Rust
المترجمة، ونفّذ عدة دوال عبر FFI، وكتب في قاعدة SQLite فعلية على القرص.

## المرحلة 0 — الحالة النهائية

| البند | الحالة |
|---|---|
| Flutter 3.41.9 محلياً | **متاح** عبر `C:\Users\ahmad\fvm\versions\3.41.9` (junction إلى SDK المحلي) |
| `cargo fmt` / clippy / 500 اختبار | نجح |
| `flutter analyze` / `flutter test` | نجح |
| CI لـPhase 0 (run `39334342514`) | أخضر سابقاً: Windows + Android + فحص DLL/`.so` |
| APK جديد بعد تغييرات Phase 1 | **غير مُثبت محلياً**؛ يحتاج CI بسبب 404 من `dl.google.com` |
| CI للـcommit الحالي | لم يُشغّل بعد؛ الفرع غير مدفوع |

## ما لم يُثبت بعد

1. **حزمة APK بعد تغييرات الجسر**: ترجمة Rust لأندرويد نجحت للبنى الثلاث،
   لكن تجميع APK محلياً توقف عند تحميل AndroidX من `dl.google.com` (404 في
   هذه البيئة: `lifecycle-common:2.7.0`، `fragment:1.7.1`، وغيرها). الـAPK
   الموجود حالياً عمره من Phase 0 ولا يحتوي المكتبة الجديدة. يحتاج CI إلى
   إكمال التغليف والتحقق من `.so` داخل APK.
2. **أوامر الكتابة للبيانات الأساسية**: المنقول للعملاء/الموردين/المواد هو
   القراءة فقط (`list_*`). لا توجد بعد `create/update/delete` عبر FRB.
3. **بقية الأوامر**: 147 أمراً يستدعيها React لم تُنقل بعد. الـ68 غير المستخدمة
   لم تُراجع، والأربعة المفقودة (`delete_role`, `update_role`,
   `update_sales_return`, `update_purchase_return`) لم تُعالج.
4. **الواجهة**: لا يوجد shell كامل، ولا تنقّل دائم، ولا i18n switching، ولا
   themes، ولا RBAC، ولا تدقيق واجهة. صفحة البيانات الأساسية قراءة فقط.
5. **الفلاتر الزمنية**: `trial_balance` يدعم `from_date/to_date`، لكن الشاشة
   لا تعرضهما بعد.
6. **إدارة السنة المالية**: يوجد إنشاء أول سنة/فترة فقط؛ لا توجد واجهة
   للإغلاق أو إعادة الفتح أو إضافة سنوات لاحقة.
7. **تعدد قواعد البيانات**: `init_app` يستخدم `OnceCell` واحداً؛ لا يدعم فتح
   أكثر من قاعدة/شركة في نفس العملية.
8. **الأداء**: لم يُقس حجم قاعدة البيانات ولا زمن فتحها مع بيانات كبيرة،
   و`list_materials` ما زال يقوم باستعلامات ملخص لكل مادة (N+1) كما في
   المحول القديم.
9. **CI للفرع الحالي**: لم يُدفع `feat/frb-bridge` بعد، لذلك لا يوجد run جديد
   يثبت هذه التغييرات على Windows/Android.

## الخطوة التالية

1. إضافة `create/update/delete` للعملاء والموردين والمواد عبر FRB، وربطها
   بنماذج الواجهة، مع اختبارات تكامل.
2. دفع الفرع وتشغيل CI لإنتاج APK يحتوي `.so` للبنى الثلاث والتحقق منه.
3. مراجعة الأوامر الـ68 غير المستخدمة والأوامر الأربعة المفقودة.
4. إضافة فلاتر التاريخ إلى شاشة ميزان المراجعة، ثم الانتقال إلى Phase 3
   (نظام التصميم والـshell) أو Phase 6 (Axum/PostgreSQL/auth/sync) حسب
   الأولوية.
