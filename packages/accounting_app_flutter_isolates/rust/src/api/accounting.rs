use application::dto::customer_dto::{CreateCustomerRequest, CustomerDto, UpdateCustomerRequest};
use application::dto::journal_entry_dto::{
    CreateJournalEntryRequest, JournalEntryDto, JournalLineDto,
};
use application::dto::material_dto::{
    CreateMaterialPriceRequest, CreateMaterialRequest, CreateMaterialSalePriceRequest,
    CreateMaterialUnitRequest, MaterialDto, UpdateMaterialRequest,
};
use application::dto::setup_dto::SetupCompanyRequest;
use application::dto::supplier_dto::{CreateSupplierRequest, SupplierDto, UpdateSupplierRequest};
use application::use_cases::customer::{
    CreateCustomerUseCase, CustomerQueries, DeleteCustomerUseCase, UpdateCustomerUseCase,
};
use application::use_cases::journal::{CreateJournalEntryUseCase, PostJournalEntryUseCase};
use application::use_cases::material::{
    CreateMaterialUseCase, DeleteMaterialUseCase, MaterialQueries, UpdateMaterialUseCase,
};
use application::use_cases::reports::GetTrialBalanceUseCase;
use application::use_cases::supplier::{
    CreateSupplierUseCase, DeleteSupplierUseCase, SupplierQueries, UpdateSupplierUseCase,
};
use application::world_currencies as world_currency_catalog;
use domain::accounting::journal_entry::JournalType;
use rust_decimal::Decimal;
use tokio::sync::OnceCell;

use bridge::AppState;

use super::error::ApiError;

static STATE: OnceCell<AppState> = OnceCell::const_new();

/// Open (or create) the SQLite ledger, run all migrations and wire the core.
///
/// On a database that is already configured, the fiscal year/period bootstrap
/// also runs so posting keeps working after a restart. A fresh database is left
/// without a fiscal year until `setup_company` runs, because only setup knows
/// the company's fiscal-year start month.
///
/// Safe to call more than once with the same path: the existing state is reused.
pub async fn init_app(db_path: String) -> Result<(), ApiError> {
    STATE
        .get_or_try_init(|| async {
            let state = bridge::build_app_state_from_path(&db_path).await?;
            if state.currency_setup.is_setup_complete().await? {
                bridge::ensure_default_fiscal_year(&state).await?;
            }
            Ok::<_, ApiError>(state)
        })
        .await
        .map(|_| ())
}

fn state() -> Result<&'static AppState, ApiError> {
    STATE.get().ok_or_else(|| {
        ApiError::new(
            "not_initialized",
            "قاعدة البيانات غير مهيأة. استدعِ initApp() أولاً.",
        )
    })
}

#[derive(Debug, Clone)]
pub struct SetupStatusView {
    pub setup_complete: bool,
    pub company_name: String,
    pub base_currency_code: String,
    pub currency_symbol: String,
    pub fiscal_year_start_month: i32,
    pub accounting_start_mode: String,
}

/// Whether a base currency and a company identity have already been installed.
pub async fn is_setup_complete() -> Result<bool, ApiError> {
    state()?
        .currency_setup
        .is_setup_complete()
        .await
        .map_err(ApiError::from)
}

/// Read the company identity and setup state in one bridge call.
pub async fn get_setup_status() -> Result<SetupStatusView, ApiError> {
    let app = state()?;
    let setup_complete = app.currency_setup.is_setup_complete().await?;
    let settings = app.settings_repo.get().await?;
    let active = app.currency_repo.list_active().await?;
    let base = active.iter().find(|currency| currency.is_base);

    Ok(SetupStatusView {
        setup_complete,
        company_name: settings.company_name,
        base_currency_code: base
            .map(|currency| currency.code.clone())
            .unwrap_or_default(),
        currency_symbol: base
            .map(|currency| currency.symbol.clone())
            .unwrap_or_default(),
        fiscal_year_start_month: settings.fiscal_year_start_month as i32,
        accounting_start_mode: settings.accounting_start_mode,
    })
}

/// First-run company setup through the shared application use case.
pub async fn setup_company(input: SetupCompanyInput) -> Result<CompanySetupView, ApiError> {
    let fiscal_year_start_month = u32::try_from(input.fiscal_year_start_month).map_err(|_| {
        ApiError::new(
            "invalid_fiscal_year_start_month",
            "شهر بداية السنة المالية يجب أن يكون بين 1 و 12.",
        )
    })?;

    let result = state()?
        .setup_company
        .execute(SetupCompanyRequest {
            company_name: input.company_name,
            base_currency_code: input.base_currency_code,
            secondary_currency_code: input.secondary_currency_code,
            fiscal_year_start_month,
            accounting_start_mode: input.accounting_start_mode,
        })
        .await?;

    Ok(CompanySetupView {
        company_name: result.company_name,
        base_currency_code: result.base_currency_code,
        currency_symbol: result.currency_symbol,
        secondary_currency_code: result.secondary_currency_code,
        fiscal_year_start_month: result.fiscal_year_start_month as i32,
        accounting_start_mode: result.accounting_start_mode,
        setup_complete: result.setup_complete,
    })
}

#[derive(Debug, Clone)]
pub struct SetupCompanyInput {
    pub company_name: String,
    pub base_currency_code: String,
    pub secondary_currency_code: Option<String>,
    pub fiscal_year_start_month: i32,
    pub accounting_start_mode: Option<String>,
}

#[derive(Debug, Clone)]
pub struct CompanySetupView {
    pub company_name: String,
    pub base_currency_code: String,
    pub currency_symbol: String,
    pub secondary_currency_code: Option<String>,
    pub fiscal_year_start_month: i32,
    pub accounting_start_mode: String,
    pub setup_complete: bool,
}

#[derive(Debug, Clone)]
pub struct WorldCurrencyView {
    pub code: String,
    pub name_ar: String,
    pub name_en: String,
    pub symbol: String,
    pub decimals: i32,
}

/// The currency catalogue is static Rust data, exposed so the Flutter setup
/// screen does not need a second, drifting copy.
pub fn world_currencies() -> Vec<WorldCurrencyView> {
    world_currency_catalog::get_world_currencies()
        .into_iter()
        .map(|currency| WorldCurrencyView {
            code: currency.code,
            name_ar: currency.name_ar,
            name_en: currency.name_en,
            symbol: currency.symbol,
            decimals: currency.decimals,
        })
        .collect()
}

#[derive(Debug, Clone)]
pub struct AccountItem {
    pub id: String,
    pub code: String,
    pub name_ar: String,
    pub name_en: String,
    pub account_type: String,
    pub purpose: String,
    pub currency: String,
    pub balance: String,
    pub is_active: bool,
    pub is_final: bool,
}

pub async fn list_accounts() -> Result<Vec<AccountItem>, ApiError> {
    let accounts = state()?.account_repo.list_all().await?;

    Ok(accounts
        .into_iter()
        .map(|account| AccountItem {
            id: account.id.0.to_string(),
            code: account.code,
            name_ar: account.name_ar,
            name_en: account.name_en,
            account_type: format!("{:?}", account.account_type),
            purpose: format!("{:?}", account.purpose),
            currency: account.currency.code,
            balance: account.balance.to_string(),
            is_active: account.is_active,
            is_final: account.is_final,
        })
        .collect())
}

#[derive(Debug, Clone)]
pub struct JournalLineInput {
    pub account_id: String,
    pub partner_id: Option<String>,
    pub currency: String,
    pub fx_rate: String,
    pub debit: String,
    pub credit: String,
    pub description: String,
}

#[derive(Debug, Clone)]
pub struct CreateJournalEntryInput {
    pub journal_type: String,
    pub source_id: Option<String>,
    pub entry_date: String,
    pub description: String,
    pub lines: Vec<JournalLineInput>,
}

#[derive(Debug, Clone)]
pub struct JournalEntryView {
    pub id: String,
    pub entry_number: String,
    pub journal_type: String,
    pub entry_date: String,
    pub description: String,
    pub status: String,
    pub total_debit: String,
    pub total_credit: String,
}

pub async fn create_journal_entry(
    input: CreateJournalEntryInput,
) -> Result<JournalEntryView, ApiError> {
    let journal_type: JournalType = serde_json::from_value(serde_json::Value::String(
        input.journal_type.clone(),
    ))
    .map_err(|_| {
        ApiError::new(
            "invalid_journal_type",
            format!("نوع القيد غير معروف: {}", input.journal_type),
        )
    })?;

    let request = CreateJournalEntryRequest {
        entry_number: String::new(),
        journal_type,
        source_id: input.source_id,
        lines: input
            .lines
            .into_iter()
            .map(|line| JournalLineDto {
                account_id: line.account_id,
                account_code: None,
                account_name: None,
                account_purpose: None,
                account_type: None,
                partner_id: line.partner_id,
                currency: line.currency,
                fx_rate: line.fx_rate,
                debit: line.debit,
                credit: line.credit,
                debit_base: None,
                credit_base: None,
                description: line.description,
            })
            .collect(),
        entry_date: input.entry_date,
        description: input.description,
    };

    let use_case = CreateJournalEntryUseCase::new(state()?.journal_entry_repo.clone());
    let entry = use_case.execute(request).await?;

    Ok(entry_view(entry))
}

pub async fn post_journal_entry(entry_id: String) -> Result<JournalEntryView, ApiError> {
    let app = state()?;
    let use_case = PostJournalEntryUseCase::new(
        app.journal_entry_repo.clone(),
        app.account_repo.clone(),
        app.fiscal_year_repo.clone(),
        app.fiscal_period_repo.clone(),
        app.pool.clone(),
    );
    let entry = use_case.execute(entry_id).await?;

    Ok(entry_view(entry))
}

fn entry_view(entry: JournalEntryDto) -> JournalEntryView {
    JournalEntryView {
        id: entry.id,
        entry_number: entry.entry_number,
        journal_type: entry.journal_type_display,
        entry_date: entry.entry_date,
        description: entry.description,
        status: entry.status,
        total_debit: entry.total_base_debit,
        total_credit: entry.total_base_credit,
    }
}

#[derive(Debug, Clone)]
pub struct TrialBalanceLineView {
    pub account_id: String,
    pub account_code: String,
    pub account_name: String,
    pub account_type: String,
    pub debit_total: String,
    pub credit_total: String,
    pub balance: String,
}

#[derive(Debug, Clone)]
pub struct TrialBalanceView {
    pub lines: Vec<TrialBalanceLineView>,
    pub total_debit: String,
    pub total_credit: String,
    pub generated_at: String,
}

pub async fn trial_balance(
    from_date: Option<String>,
    to_date: Option<String>,
) -> Result<TrialBalanceView, ApiError> {
    let app = state()?;
    let use_case =
        GetTrialBalanceUseCase::new(app.journal_entry_repo.clone(), app.account_repo.clone());
    let report = use_case.execute(from_date, to_date).await?;

    Ok(TrialBalanceView {
        lines: report
            .lines
            .into_iter()
            .map(|line| TrialBalanceLineView {
                account_id: line.account_id,
                account_code: line.account_code,
                account_name: line.account_name,
                account_type: line.account_type,
                debit_total: line.debit_total,
                credit_total: line.credit_total,
                balance: line.balance,
            })
            .collect(),
        total_debit: report.total_debit,
        total_credit: report.total_credit,
        generated_at: report.generated_at,
    })
}

#[derive(Debug, Clone)]
pub struct CustomerItem {
    pub id: String,
    pub code: String,
    pub name: String,
    pub phone: Option<String>,
    pub address: Option<String>,
    pub account_id: Option<String>,
    pub debit: String,
    pub credit: String,
    pub opening_balance: String,
    pub balance: String,
    pub currency: String,
    pub notes: Option<String>,
    pub is_active: bool,
}

fn customer_item(customer: CustomerDto) -> CustomerItem {
    CustomerItem {
        id: customer.id,
        code: customer.code,
        name: customer.name,
        phone: customer.phone,
        address: customer.address,
        account_id: customer.account_id,
        debit: customer.debit,
        credit: customer.credit,
        opening_balance: customer.opening_balance,
        balance: customer.balance,
        currency: customer.currency,
        notes: customer.notes,
        is_active: customer.is_active,
    }
}

pub async fn list_customers() -> Result<Vec<CustomerItem>, ApiError> {
    let app = state()?;
    let customers = CustomerQueries::new(app.customer_repo.clone())
        .list_all()
        .await?;

    Ok(customers.into_iter().map(customer_item).collect())
}

#[derive(Debug, Clone)]
pub struct CustomerCreateInput {
    pub name: String,
    pub phone: Option<String>,
    pub address: Option<String>,
    pub notes: Option<String>,
    pub currency: String,
    pub opening_balance: String,
}

#[derive(Debug, Clone)]
pub struct CustomerUpdateInput {
    pub id: String,
    pub code: String,
    pub name: String,
    pub phone: Option<String>,
    pub address: Option<String>,
    pub notes: Option<String>,
    pub is_active: bool,
}

pub async fn create_customer(input: CustomerCreateInput) -> Result<CustomerItem, ApiError> {
    let app = state()?;
    let opening = parse_non_negative(&input.opening_balance, "الرصيد الافتتاحي")?;
    let currency = resolve_currency(app, &input.currency).await?;

    let customer = CreateCustomerUseCase::new(
        app.customer_repo.clone(),
        app.account_repo.clone(),
        app.journal_entry_repo.clone(),
        app.opening_migration_repo.clone(),
    )
    .execute(CreateCustomerRequest {
        code: String::new(),
        name: input.name,
        phone: input.phone,
        address: input.address,
        account_id: None,
        debit: Some(opening.to_string()),
        credit: None,
        opening_balance: Some(opening.to_string()),
        currency: Some(currency),
        exchange_rate: None,
        notes: input.notes,
    })
    .await?;

    Ok(customer_item(customer))
}

pub async fn update_customer(input: CustomerUpdateInput) -> Result<CustomerItem, ApiError> {
    let app = state()?;
    let customer = UpdateCustomerUseCase::new(
        app.customer_repo.clone(),
        app.account_repo.clone(),
        app.currency_repo.clone(),
        app.journal_entry_repo.clone(),
        app.opening_migration_repo.clone(),
    )
    .execute(UpdateCustomerRequest {
        id: input.id,
        code: input.code,
        name: input.name,
        phone: input.phone,
        address: input.address,
        account_id: None,
        debit: None,
        credit: None,
        opening_balance: None,
        currency: None,
        notes: input.notes,
        is_active: input.is_active,
    })
    .await?;

    Ok(customer_item(customer))
}

pub async fn delete_customer(id: String) -> Result<(), ApiError> {
    let app = state()?;
    DeleteCustomerUseCase::new(app.customer_repo.clone(), app.journal_entry_repo.clone())
        .execute(id)
        .await?;
    Ok(())
}

#[derive(Debug, Clone)]
pub struct SupplierItem {
    pub id: String,
    pub code: String,
    pub name: String,
    pub phone: Option<String>,
    pub address: Option<String>,
    pub account_id: Option<String>,
    pub debit: String,
    pub credit: String,
    pub opening_balance: String,
    pub balance: String,
    pub currency: String,
    pub notes: Option<String>,
    pub is_active: bool,
}

fn supplier_item(supplier: SupplierDto) -> SupplierItem {
    SupplierItem {
        id: supplier.id,
        code: supplier.code,
        name: supplier.name,
        phone: supplier.phone,
        address: supplier.address,
        account_id: supplier.account_id,
        debit: supplier.debit,
        credit: supplier.credit,
        opening_balance: supplier.opening_balance,
        balance: supplier.balance,
        currency: supplier.currency,
        notes: supplier.notes,
        is_active: supplier.is_active,
    }
}

pub async fn list_suppliers() -> Result<Vec<SupplierItem>, ApiError> {
    let app = state()?;
    let suppliers = SupplierQueries::new(app.supplier_repo.clone())
        .list_all()
        .await?;

    Ok(suppliers.into_iter().map(supplier_item).collect())
}

#[derive(Debug, Clone)]
pub struct SupplierCreateInput {
    pub name: String,
    pub phone: Option<String>,
    pub address: Option<String>,
    pub notes: Option<String>,
    pub currency: String,
    pub opening_balance: String,
}

#[derive(Debug, Clone)]
pub struct SupplierUpdateInput {
    pub id: String,
    pub code: String,
    pub name: String,
    pub phone: Option<String>,
    pub address: Option<String>,
    pub notes: Option<String>,
}

pub async fn create_supplier(input: SupplierCreateInput) -> Result<SupplierItem, ApiError> {
    let app = state()?;
    let opening = parse_non_negative(&input.opening_balance, "الرصيد الافتتاحي")?;
    let currency = resolve_currency(app, &input.currency).await?;

    let supplier = CreateSupplierUseCase::new(
        app.supplier_repo.clone(),
        app.account_repo.clone(),
        app.journal_entry_repo.clone(),
        app.opening_migration_repo.clone(),
    )
    .execute(CreateSupplierRequest {
        code: String::new(),
        name: input.name,
        phone: input.phone,
        address: input.address,
        account_id: None,
        debit: None,
        credit: Some(opening.to_string()),
        opening_balance: Some(opening.to_string()),
        currency: Some(currency),
        exchange_rate: None,
        notes: input.notes,
    })
    .await?;

    Ok(supplier_item(supplier))
}

pub async fn update_supplier(input: SupplierUpdateInput) -> Result<SupplierItem, ApiError> {
    let app = state()?;
    let supplier = UpdateSupplierUseCase::new(
        app.supplier_repo.clone(),
        app.account_repo.clone(),
        app.currency_repo.clone(),
        app.journal_entry_repo.clone(),
        app.opening_migration_repo.clone(),
    )
    .execute(UpdateSupplierRequest {
        id: input.id,
        code: input.code,
        name: input.name,
        phone: input.phone,
        address: input.address,
        account_id: None,
        debit: None,
        credit: None,
        opening_balance: None,
        currency: None,
        notes: input.notes,
    })
    .await?;

    Ok(supplier_item(supplier))
}

pub async fn delete_supplier(id: String) -> Result<(), ApiError> {
    let app = state()?;
    DeleteSupplierUseCase::new(app.supplier_repo.clone(), app.journal_entry_repo.clone())
        .execute(id)
        .await?;
    Ok(())
}

#[derive(Debug, Clone)]
pub struct MaterialItem {
    pub id: String,
    pub name: String,
    pub name_en: String,
    pub barcode: String,
    pub code: String,
    pub category_ids: Vec<String>,
    pub minimum_stock: String,
    pub total_received: String,
    pub total_sold: String,
    pub total_available: String,
    pub total_damaged: String,
    pub last_purchase_price: String,
    pub last_sale_price: String,
    pub average_cost: String,
    pub average_cost_base: String,
    pub units_count: i32,
    pub has_expiry: bool,
    pub expiry_alert_before_days: i32,
    pub costing_method: String,
    pub purchase_price: String,
    pub sale_price: String,
    pub currency: String,
    pub notes: Option<String>,
    pub unit_name: String,
    pub conversion_factor: String,
}

fn material_item(material: MaterialDto) -> MaterialItem {
    let base_unit = material
        .units
        .iter()
        .find(|unit| unit.is_base)
        .or_else(|| material.units.first());
    let unit_name = base_unit.map(|unit| unit.name.clone()).unwrap_or_default();
    let conversion_factor = base_unit
        .map(|unit| unit.conversion_factor.to_string())
        .unwrap_or_else(|| "1".to_string());
    let purchase_price = material
        .purchase_prices
        .first()
        .map(|price| price.price.clone())
        .unwrap_or_else(|| material.average_cost.clone());
    let sale_price = material
        .sale_prices
        .first()
        .map(|price| price.price.clone())
        .unwrap_or_else(|| material.last_sale_price.clone());
    let currency = material
        .purchase_prices
        .first()
        .map(|price| price.currency.clone())
        .or_else(|| material.default_purchase_currency.clone())
        .unwrap_or_default();

    MaterialItem {
        id: material.id,
        name: material.name,
        name_en: material.name_en,
        barcode: material.barcode,
        code: material.code,
        category_ids: material.category_ids,
        minimum_stock: material.minimum_stock,
        total_received: material.total_received,
        total_sold: material.total_sold,
        total_available: material.total_available,
        total_damaged: material.total_damaged,
        last_purchase_price: material.last_purchase_price,
        last_sale_price: material.last_sale_price,
        average_cost: material.average_cost,
        average_cost_base: material.average_cost_base,
        units_count: material.units.len() as i32,
        has_expiry: material.has_expiry,
        expiry_alert_before_days: material.expiry_alert_before_days,
        costing_method: material.costing_method,
        purchase_price,
        sale_price,
        currency,
        notes: material.notes,
        unit_name,
        conversion_factor,
    }
}

pub async fn list_materials() -> Result<Vec<MaterialItem>, ApiError> {
    let app = state()?;
    let materials = MaterialQueries::new(
        app.material_repo.clone(),
        app.stock_movement_repo.clone(),
        app.unified_invoice_repo.clone(),
    )
    .with_lot_repo(app.inventory_lot_repo.clone())
    .list_all()
    .await?;

    Ok(materials.into_iter().map(material_item).collect())
}

#[derive(Debug, Clone)]
pub struct MaterialCreateInput {
    pub name: String,
    pub name_en: Option<String>,
    pub barcode: Option<String>,
    pub code: Option<String>,
    pub minimum_stock: String,
    pub unit_name: String,
    pub conversion_factor: String,
    pub purchase_price: Option<String>,
    pub sale_price: Option<String>,
    pub currency: String,
    pub notes: Option<String>,
    pub has_expiry: bool,
    pub expiry_alert_before_days: i32,
}

#[derive(Debug, Clone)]
pub struct MaterialUpdateInput {
    pub id: String,
    pub name: String,
    pub name_en: String,
    pub barcode: String,
    pub code: String,
    pub minimum_stock: String,
    pub notes: Option<String>,
    pub purchase_price: Option<String>,
    pub sale_price: Option<String>,
    pub currency: Option<String>,
    pub has_expiry: bool,
    pub expiry_alert_before_days: i32,
}

pub async fn create_material(input: MaterialCreateInput) -> Result<MaterialItem, ApiError> {
    let app = state()?;
    let currency = resolve_currency(app, &input.currency).await?;
    let unit_name = input.unit_name.trim().to_string();
    if unit_name.is_empty() {
        return Err(ApiError::new("unit_required", "اسم الوحدة مطلوب."));
    }

    let minimum_stock = parse_non_negative(&input.minimum_stock, "الحد الأدنى للمخزون")?;
    let conversion_factor = if input.conversion_factor.trim().is_empty() {
        Decimal::ONE
    } else {
        parse_positive(&input.conversion_factor, "معامل التحويل")?
    };
    if input.expiry_alert_before_days < 0 {
        return Err(ApiError::new(
            "invalid_expiry_days",
            "أيام تنبيه الصلاحية لا يمكن أن تكون سالبة.",
        ));
    }
    let purchase_price = normalize_price(input.purchase_price, "سعر الشراء")?;
    let sale_price = normalize_price(input.sale_price, "سعر البيع")?;

    let code = match input
        .code
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
    {
        Some(code) => Some(code),
        None => Some(
            app.material_code_use_cases
                .generate_code(domain::inventory::category::DEFAULT_CATEGORY_ID.to_string())
                .await?,
        ),
    };

    let purchase_prices = purchase_price
        .map(|price| {
            vec![CreateMaterialPriceRequest {
                unit_id: unit_name.clone(),
                price: price.clone(),
                price_base: price,
                currency: currency.clone(),
            }]
        })
        .unwrap_or_default();

    let sale_prices = sale_price
        .map(|price| {
            vec![CreateMaterialSalePriceRequest {
                unit_id: unit_name.clone(),
                tier: "Retail".to_string(),
                price: price.clone(),
                price_base: price.clone(),
                min_price: price.clone(),
                min_price_base: price,
                max_quantity: "0".to_string(),
                max_quantity_unit_id: None,
                currency: currency.clone(),
            }]
        })
        .unwrap_or_default();

    let material = CreateMaterialUseCase::new(app.material_repo.clone(), app.category_repo.clone())
        .execute(CreateMaterialRequest {
            name: input.name,
            name_en: input.name_en,
            barcode: input.barcode,
            code,
            minimum_stock: minimum_stock.to_string(),
            units: vec![CreateMaterialUnitRequest {
                name: unit_name.clone(),
                conversion_factor: conversion_factor.to_string(),
                barcode: None,
            }],
            category_ids: vec![],
            notes: input.notes,
            image_path: None,
            default_purchase_unit_id: Some(unit_name.clone()),
            default_sale_unit_id: Some(unit_name),
            default_purchase_currency: Some(currency.clone()),
            default_sale_currency: Some(currency),
            default_warehouse_id: None,
            has_expiry: Some(input.has_expiry),
            expiry_alert_before_days: Some(input.expiry_alert_before_days),
            purchase_prices,
            sale_prices,
        })
        .await?;

    Ok(material_item(material))
}

pub async fn update_material(input: MaterialUpdateInput) -> Result<MaterialItem, ApiError> {
    let app = state()?;
    let minimum_stock = parse_non_negative(&input.minimum_stock, "الحد الأدنى للمخزون")?;
    if input.expiry_alert_before_days < 0 {
        return Err(ApiError::new(
            "invalid_expiry_days",
            "أيام تنبيه الصلاحية لا يمكن أن تكون سالبة.",
        ));
    }
    let queries = MaterialQueries::new(
        app.material_repo.clone(),
        app.stock_movement_repo.clone(),
        app.unified_invoice_repo.clone(),
    )
    .with_lot_repo(app.inventory_lot_repo.clone());

    let current = queries.get_by_id(input.id.clone()).await?;
    let currency = input
        .currency
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
        .or_else(|| current.default_purchase_currency.clone())
        .or_else(|| {
            current
                .purchase_prices
                .first()
                .map(|price| price.currency.clone())
        })
        .unwrap_or_default();
    if currency.is_empty() {
        return Err(ApiError::new(
            "currency_required",
            "حدد عملة الشراء أو البيع أولاً.",
        ));
    }

    let unit_id = current
        .units
        .iter()
        .find(|unit| unit.is_base)
        .or_else(|| current.units.first())
        .map(|unit| unit.id.clone())
        .ok_or_else(|| ApiError::new("unit_required", "لا توجد وحدة لهذه المادة."))?;

    let mut purchase_prices: Vec<CreateMaterialPriceRequest> = current
        .purchase_prices
        .iter()
        .map(|price| CreateMaterialPriceRequest {
            unit_id: price.unit_id.clone(),
            price: price.price.clone(),
            price_base: price.price_base.clone(),
            currency: price.currency.clone(),
        })
        .collect();

    if let Some(price) = normalize_price(input.purchase_price, "سعر الشراء")? {
        if let Some(existing) = purchase_prices
            .iter_mut()
            .find(|item| item.unit_id == unit_id && item.currency == currency)
        {
            existing.price = price.clone();
            existing.price_base = price;
        } else {
            purchase_prices.push(CreateMaterialPriceRequest {
                unit_id: unit_id.clone(),
                price: price.clone(),
                price_base: price,
                currency: currency.clone(),
            });
        }
    }

    let mut sale_prices: Vec<CreateMaterialSalePriceRequest> = current
        .sale_prices
        .iter()
        .map(|price| CreateMaterialSalePriceRequest {
            unit_id: price.unit_id.clone(),
            tier: price.tier.clone(),
            price: price.price.clone(),
            price_base: price.price_base.clone(),
            min_price: price.min_price.clone(),
            min_price_base: price.min_price_base.clone(),
            max_quantity: price.max_quantity.clone(),
            max_quantity_unit_id: price.max_quantity_unit_id.clone(),
            currency: price.currency.clone(),
        })
        .collect();

    if let Some(price) = normalize_price(input.sale_price, "سعر البيع")? {
        if let Some(existing) = sale_prices
            .iter_mut()
            .find(|item| item.unit_id == unit_id && item.currency == currency)
        {
            existing.price = price.clone();
            existing.price_base = price.clone();
            existing.min_price = price.clone();
            existing.min_price_base = price;
        } else {
            sale_prices.push(CreateMaterialSalePriceRequest {
                unit_id,
                tier: "Retail".to_string(),
                price: price.clone(),
                price_base: price.clone(),
                min_price: price.clone(),
                min_price_base: price,
                max_quantity: "0".to_string(),
                max_quantity_unit_id: None,
                currency: currency.clone(),
            });
        }
    }

    let material =
        UpdateMaterialUseCase::new(app.material_repo.clone(), app.stock_movement_repo.clone())
            .execute(UpdateMaterialRequest {
                id: input.id,
                name: input.name,
                name_en: input.name_en,
                barcode: input.barcode,
                code: input.code,
                minimum_stock: minimum_stock.to_string(),
                category_ids: current.category_ids,
                notes: input.notes,
                image_path: current.image_path,
                default_purchase_unit_id: current.default_purchase_unit_id,
                default_sale_unit_id: current.default_sale_unit_id,
                default_purchase_currency: Some(currency.clone()),
                default_sale_currency: Some(currency),
                default_warehouse_id: current.default_warehouse_id,
                has_expiry: Some(input.has_expiry),
                expiry_alert_before_days: Some(input.expiry_alert_before_days),
                purchase_prices,
                sale_prices,
            })
            .await?;

    Ok(material_item(material))
}

pub async fn delete_material(id: String) -> Result<(), ApiError> {
    let app = state()?;
    DeleteMaterialUseCase::new(app.material_repo.clone(), app.stock_movement_repo.clone())
        .execute(id)
        .await?;
    Ok(())
}

fn parse_non_negative(value: &str, field: &str) -> Result<Decimal, ApiError> {
    let parsed = application::utils::parse_decimal(Some(value), field).map_err(ApiError::from)?;
    if parsed < Decimal::ZERO {
        return Err(ApiError::new(
            "invalid_amount",
            format!("{field} لا يمكن أن يكون سالباً."),
        ));
    }
    Ok(parsed)
}

fn parse_positive(value: &str, field: &str) -> Result<Decimal, ApiError> {
    let parsed = application::utils::parse_decimal(Some(value), field).map_err(ApiError::from)?;
    if parsed <= Decimal::ZERO {
        return Err(ApiError::new(
            "invalid_amount",
            format!("{field} يجب أن يكون أكبر من صفر."),
        ));
    }
    Ok(parsed)
}

async fn resolve_currency(app: &AppState, requested: &str) -> Result<String, ApiError> {
    let requested = requested.trim();
    if !requested.is_empty() {
        return Ok(requested.to_uppercase());
    }

    let active = app.currency_repo.list_active().await?;
    if let Some(base) = active.iter().find(|currency| currency.is_base) {
        return Ok(base.code.clone());
    }

    let settings = app.settings_repo.get().await?;
    let code = settings.currency.trim();
    if code.is_empty() {
        Err(ApiError::new(
            "currency_required",
            "حدد العملة أولاً من إعدادات الشركة.",
        ))
    } else {
        Ok(code.to_string())
    }
}

fn normalize_price(value: Option<String>, field: &str) -> Result<Option<String>, ApiError> {
    let value = value
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty());

    match value {
        Some(value) => {
            let parsed: Decimal = value
                .parse()
                .map_err(|_| ApiError::new("invalid_price", format!("{field} غير صالح.")))?;
            if parsed < Decimal::ZERO {
                return Err(ApiError::new(
                    "invalid_price",
                    format!("{field} لا يمكن أن يكون سالباً."),
                ));
            }
            Ok(Some(parsed.to_string()))
        }
        None => Ok(None),
    }
}
