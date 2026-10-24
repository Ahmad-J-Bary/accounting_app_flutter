import '../settings/settings_model.dart';

abstract class AppStrings {
  const AppStrings();

  // App / bootstrap
  String get appName;
  String get appTitle;
  String get bootstrapLoading;
  String get errorOpenDatabase;

  // Navigation
  String get navDashboard;
  String get navJournal;
  String get navSalesInvoices;
  String get navPurchaseInvoices;
  String get navSalesReturns;
  String get navPurchaseReturns;
  String get navReceipts;
  String get navPayments;
  String get navExpenses;
  String get navCustomers;
  String get navSuppliers;
  String get navMaterials;

  // Settings page
  String get settingsTitle;
  String get sectionLanguageRegion;
  String get sectionLanguageRegionSubtitle;
  String get labelInterfaceLanguage;
  String get labelLanguageArabic;
  String get labelLanguageEnglish;
  String get labelDigits;
  String get labelDigitsSubtitle;
  String get labelDigitsArabic;
  String get labelDigitsWestern;
  String get examplePrefix;
  String get sectionAppearance;

  // Settings navigation
  String get settingsDescription;
  String get settingsSectionCompany;
  String get settingsSectionPrefixes;
  String get settingsSectionCurrencies;
  String get settingsSectionFinancial;
  String get settingsSectionWarehouses;
  String get settingsSectionLocalization;
  String get settingsSectionExport;
  String get settingsSectionBackups;
  String get settingsSectionSecurity;
  String get settingsSectionAbout;
  String get settingsAppearanceCategory;
  String get settingsSectionAppearance;
  String get settingsSectionTables;
  String get settingsSectionNavbar;
  String get settingsSectionSidebarContent;
  String get settingsSectionPanel;
  String get settingsSectionPageHeader;
  String get settingsSectionTabs;
  String get settingsComingSoon;
  String get settingsCompanyComingSoon;
  String get settingsOpenAppearanceNow;

  String get labelThemeMode;
  String get labelThemeSystem;
  String get labelThemeLight;
  String get labelThemeDark;
  String get labelDensity;
  String get labelDensityCompact;
  String get labelDensityComfortable;
  String get labelDensitySpacious;
  String get labelFontScale;
  String get resetButton;
  String get resetConfirmTitle;
  String get resetConfirmBody;
  String get resetCancel;
  String get resetConfirm;

  // Misc
  String get loading;
}

class ArStrings extends AppStrings {
  const ArStrings();

  @override String get appName => 'المحاسبة';
  @override String get appTitle => 'المحاسبة';
  @override String get bootstrapLoading => 'جارٍ تهيئة قاعدة البيانات…';
  @override String get errorOpenDatabase => 'تعذّر فتح قاعدة البيانات';

  @override String get navDashboard => 'لوحة التحكم';
  @override String get navJournal => 'قيود اليومية';
  @override String get navSalesInvoices => 'فواتير البيع';
  @override String get navPurchaseInvoices => 'فواتير الشراء';
  @override String get navSalesReturns => 'مرتجعات البيع';
  @override String get navPurchaseReturns => 'مرتجعات الشراء';
  @override String get navReceipts => 'المقبوضات';
  @override String get navPayments => 'المدفوعات';
  @override String get navExpenses => 'بنود المصاريف';
  @override String get navCustomers => 'العملاء';
  @override String get navSuppliers => 'الموردون';
  @override String get navMaterials => 'المواد';

  @override String get settingsTitle => 'الإعدادات';
  @override String get sectionLanguageRegion => 'اللغة والمنطقة';
  @override String get sectionLanguageRegionSubtitle =>
      'تحديد نظام الأرقام المعروض في جميع أنحاء التطبيق.';
  @override String get labelInterfaceLanguage => 'لغة الواجهة';
  @override String get labelLanguageArabic => 'العربية';
  @override String get labelLanguageEnglish => 'English';
  @override String get labelDigits => 'نظام الأرقام';
  @override String get labelDigitsSubtitle =>
      'يُطبّق على جميع الأرقام في الجداول والتقارير والبطاقات.';
  @override String get labelDigitsArabic => 'أرقام عربية';
  @override String get labelDigitsWestern => 'أرقام أجنبية';
  @override String get examplePrefix => 'مثال';
  @override String get sectionAppearance => 'المظهر';
  @override String get labelThemeMode => 'نمط المظهر';
  @override String get labelThemeSystem => 'النظام';
  @override String get labelThemeLight => 'فاتح';
  @override String get labelThemeDark => 'داكن';
  @override String get labelDensity => 'كثافة العرض';
  @override String get labelDensityCompact => 'مضغوط';
  @override String get labelDensityComfortable => 'عادي';
  @override String get labelDensitySpacious => 'مريح';
  @override String get labelFontScale => 'حجم الخط';
  @override String get resetButton => 'إعادة ضبط الإعدادات';
  @override String get resetConfirmTitle => 'إعادة ضبط الإعدادات؟';
  @override String get resetConfirmBody =>
      'سيعود المظهر إلى القيم الافتراضية. لن تتأثر بيانات المحاسبة.';
  @override String get resetCancel => 'إلغاء';
  @override String get resetConfirm => 'إعادة الضبط';

  @override String get loading => 'جارٍ التحميل';

  @override String get settingsDescription =>
      'تخصيص الخيارات الأساسية، الهوية البصرية، والقواعد المحاسبية.';
  @override String get settingsSectionCompany => 'بيانات الشركة';
  @override String get settingsSectionPrefixes => 'الأرقام التسلسلية';
  @override String get settingsSectionCurrencies => 'إدارة العملات';
  @override String get settingsSectionFinancial => 'الإعدادات المالية';
  @override String get settingsSectionWarehouses => 'المستودعات';
  @override String get settingsSectionLocalization => 'اللغة والمنطقة';
  @override String get settingsSectionExport => 'إعدادات التصدير';
  @override String get settingsSectionBackups => 'البيانات والنسخ الاحتياطية';
  @override String get settingsSectionSecurity => 'الأمان والوصول';
  @override String get settingsSectionAbout => 'حول التطبيق';
  @override String get settingsAppearanceCategory => 'المظهر';
  @override String get settingsSectionAppearance => 'المظهر العام';
  @override String get settingsSectionTables => 'مظهر الجداول';
  @override String get settingsSectionNavbar => 'مظهر قائمة التنقل';
  @override String get settingsSectionSidebarContent => 'محتوى وترتيب القائمة';
  @override String get settingsSectionPanel => 'لوحة العمليات والنماذج';
  @override String get settingsSectionPageHeader => 'رأس الصفحة';
  @override String get settingsSectionTabs => 'التبويبات';
  @override String get settingsComingSoon =>
      'هذا القسم قيد التطوير وسيُضاف في الإصدار القادم.';
  @override String get settingsCompanyComingSoon =>
      'بيانات الشركة ستُضاف في 1.0.4.';
  @override String get settingsOpenAppearanceNow => 'تعديل المظهر الآن';
}

class EnStrings extends AppStrings {
  const EnStrings();

  @override String get appName => 'Accounting';
  @override String get appTitle => 'Accounting';
  @override String get bootstrapLoading => 'Initializing database…';
  @override String get errorOpenDatabase => 'Could not open database';

  @override String get navDashboard => 'Dashboard';
  @override String get navJournal => 'Journal entries';
  @override String get navSalesInvoices => 'Sales invoices';
  @override String get navPurchaseInvoices => 'Purchase invoices';
  @override String get navSalesReturns => 'Sales returns';
  @override String get navPurchaseReturns => 'Purchase returns';
  @override String get navReceipts => 'Receipts';
  @override String get navPayments => 'Payments';
  @override String get navExpenses => 'Expense items';
  @override String get navCustomers => 'Customers';
  @override String get navSuppliers => 'Suppliers';
  @override String get navMaterials => 'Materials';

  @override String get settingsTitle => 'Settings';
  @override String get sectionLanguageRegion => 'Language & region';
  @override String get sectionLanguageRegionSubtitle =>
      'Choose how digits are displayed across the application.';
  @override String get labelInterfaceLanguage => 'Interface language';
  @override String get labelLanguageArabic => 'العربية';
  @override String get labelLanguageEnglish => 'English';
  @override String get labelDigits => 'Numerals';
  @override String get labelDigitsSubtitle =>
      'Applies to all numbers in tables, reports, and cards.';
  @override String get labelDigitsArabic => 'Arabic numerals';
  @override String get labelDigitsWestern => 'Western numerals';
  @override String get examplePrefix => 'Example';
  @override String get sectionAppearance => 'Appearance';
  @override String get labelThemeMode => 'Theme mode';
  @override String get labelThemeSystem => 'System';
  @override String get labelThemeLight => 'Light';
  @override String get labelThemeDark => 'Dark';
  @override String get labelDensity => 'Display density';
  @override String get labelDensityCompact => 'Compact';
  @override String get labelDensityComfortable => 'Comfortable';
  @override String get labelDensitySpacious => 'Spacious';
  @override String get labelFontScale => 'Font size';
  @override String get resetButton => 'Reset settings';
  @override String get resetConfirmTitle => 'Reset settings?';
  @override String get resetConfirmBody =>
      'Appearance returns to defaults. Accounting data is not affected.';
  @override String get resetCancel => 'Cancel';
  @override String get resetConfirm => 'Reset';

  @override String get loading => 'Loading';

  @override String get settingsDescription =>
      'Customize core options, visual identity, and accounting rules.';
  @override String get settingsSectionCompany => 'Company data';
  @override String get settingsSectionPrefixes => 'Serial numbers';
  @override String get settingsSectionCurrencies => 'Currencies';
  @override String get settingsSectionFinancial => 'Financial settings';
  @override String get settingsSectionWarehouses => 'Warehouses';
  @override String get settingsSectionLocalization => 'Language & region';
  @override String get settingsSectionExport => 'Export settings';
  @override String get settingsSectionBackups => 'Data & backups';
  @override String get settingsSectionSecurity => 'Security & access';
  @override String get settingsSectionAbout => 'About';
  @override String get settingsAppearanceCategory => 'Appearance';
  @override String get settingsSectionAppearance => 'General appearance';
  @override String get settingsSectionTables => 'Table appearance';
  @override String get settingsSectionNavbar => 'Navigation appearance';
  @override String get settingsSectionSidebarContent => 'Sidebar content & order';
  @override String get settingsSectionPanel => 'Operations & forms panel';
  @override String get settingsSectionPageHeader => 'Page header';
  @override String get settingsSectionTabs => 'Tabs';
  @override String get settingsComingSoon =>
      'This section is under development and will arrive in a future release.';
  @override String get settingsCompanyComingSoon =>
      'Company data will arrive in 1.0.4.';
  @override String get settingsOpenAppearanceNow =>
      'Customize appearance now';
}

extension AppLanguageStrings on AppLanguage {
  AppStrings get strings => this == AppLanguage.english
      ? const EnStrings()
      : const ArStrings();
}