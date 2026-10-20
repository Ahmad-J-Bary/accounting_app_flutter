use application::dto::customer_dto::{CreateCustomerRequest, UpdateCustomerRequest};
use application::dto::journal_entry_dto::{CreateJournalEntryRequest, JournalLineDto};
use application::dto::material_dto::{
    CreateMaterialRequest, CreateMaterialUnitRequest, UpdateMaterialRequest,
};
use application::dto::setup_dto::SetupCompanyRequest;
use application::dto::supplier_dto::{CreateSupplierRequest, UpdateSupplierRequest};
use application::errors::AppError;
use application::use_cases::customer::{
    CreateCustomerUseCase, CustomerQueries, DeleteCustomerUseCase, UpdateCustomerUseCase,
};
use application::use_cases::journal::CreateJournalEntryUseCase;
use application::use_cases::material::{
    CreateMaterialUseCase, DeleteMaterialUseCase, MaterialQueries, UpdateMaterialUseCase,
};
use application::use_cases::reports::GetTrialBalanceUseCase;
use application::use_cases::supplier::{
    CreateSupplierUseCase, DeleteSupplierUseCase, SupplierQueries, UpdateSupplierUseCase,
};
use bridge::build_app_state_from_path;
use domain::accounting::journal_entry::JournalType;

fn line(account_id: String, currency: String, debit: &str, credit: &str) -> JournalLineDto {
    JournalLineDto {
        account_id,
        account_code: None,
        account_name: None,
        account_purpose: None,
        account_type: None,
        partner_id: None,
        currency,
        fx_rate: "1".to_string(),
        debit: debit.to_string(),
        credit: credit.to_string(),
        debit_base: None,
        credit_base: None,
        description: "bridge smoke test".to_string(),
    }
}

#[tokio::test]
async fn opens_database_seeds_accounts_and_balances_an_entry() {
    let dir = std::env::temp_dir().join(format!(
        "accounting_bridge_test_{}_{}",
        std::process::id(),
        uuid::Uuid::new_v4()
    ));
    std::fs::create_dir_all(&dir).expect("create temp dir");
    let db_path = dir.join("ledger.db");

    let state = build_app_state_from_path(db_path.to_str().expect("utf-8 path"))
        .await
        .expect("build app state");

    let accounts = state.account_repo.list_all().await.expect("list accounts");
    assert!(
        !accounts.is_empty(),
        "migrations must seed the chart of accounts"
    );

    let leaves: Vec<_> = accounts
        .into_iter()
        .filter(|account| account.is_active && account.is_final)
        .collect();
    assert!(
        leaves.len() >= 2,
        "expected at least two active leaf accounts, got {}",
        leaves.len()
    );

    let create = CreateJournalEntryUseCase::new(state.journal_entry_repo.clone());
    let entry = create
        .execute(CreateJournalEntryRequest {
            entry_number: String::new(),
            journal_type: JournalType::GeneralJournal,
            source_id: None,
            lines: vec![
                line(
                    leaves[0].id.0.to_string(),
                    leaves[0].currency.code.clone(),
                    "100",
                    "0",
                ),
                line(
                    leaves[1].id.0.to_string(),
                    leaves[1].currency.code.clone(),
                    "0",
                    "100",
                ),
            ],
            entry_date: chrono::Utc::now().to_rfc3339(),
            description: "bridge smoke test".to_string(),
        })
        .await
        .expect("create journal entry");

    assert!(!entry.entry_number.is_empty());
    assert_eq!(entry.total_base_debit, "100");
    assert_eq!(entry.total_base_credit, "100");

    bridge::ensure_default_fiscal_year(&state)
        .await
        .expect("ensure fiscal year");

    let posted = application::use_cases::journal::PostJournalEntryUseCase::new(
        state.journal_entry_repo.clone(),
        state.account_repo.clone(),
        state.fiscal_year_repo.clone(),
        state.fiscal_period_repo.clone(),
        state.pool.clone(),
    )
    .execute(entry.id.clone())
    .await
    .expect("post journal entry");
    assert_eq!(posted.status, "Posted");

    let trial =
        GetTrialBalanceUseCase::new(state.journal_entry_repo.clone(), state.account_repo.clone())
            .execute(None, None)
            .await
            .expect("trial balance");

    assert_eq!(trial.total_debit, trial.total_credit);
    assert!(!trial.lines.is_empty());

    state.pool.close().await;
    drop(state);
    let _ = std::fs::remove_dir_all(&dir);
}

#[tokio::test]
async fn setup_company_configures_currency_settings_and_fiscal_year() {
    let dir = std::env::temp_dir().join(format!(
        "accounting_setup_test_{}_{}",
        std::process::id(),
        uuid::Uuid::new_v4()
    ));
    std::fs::create_dir_all(&dir).expect("create temp dir");
    let db_path = dir.join("ledger.db");

    let state = build_app_state_from_path(db_path.to_str().expect("utf-8 path"))
        .await
        .expect("build app state");

    assert!(
        !state
            .currency_setup
            .is_setup_complete()
            .await
            .expect("read setup state"),
        "a fresh database must not report a completed setup"
    );

    let request = || SetupCompanyRequest {
        company_name: "شركة الاختبار".to_string(),
        base_currency_code: "SYP".to_string(),
        secondary_currency_code: Some("USD".to_string()),
        fiscal_year_start_month: 1,
        accounting_start_mode: None,
    };

    let setup = state
        .setup_company
        .execute(request())
        .await
        .expect("setup company");

    assert!(setup.setup_complete);
    assert_eq!(setup.company_name, "شركة الاختبار");
    assert_eq!(setup.base_currency_code, "SYP");
    assert_eq!(setup.currency_symbol, "ل.س");
    assert_eq!(setup.secondary_currency_code.as_deref(), Some("USD"));

    assert!(
        state
            .currency_setup
            .is_setup_complete()
            .await
            .expect("read setup state")
    );

    let settings = state.settings_repo.get().await.expect("read settings");
    assert_eq!(settings.company_name, "شركة الاختبار");
    assert_eq!(settings.currency, "SYP");
    assert_eq!(settings.currency_symbol, "ل.س");
    assert_eq!(settings.fiscal_year_start_month, 1);

    assert_eq!(
        state
            .fiscal_year_repo
            .list()
            .await
            .expect("fiscal years")
            .len(),
        1,
        "setup must bootstrap exactly one fiscal year"
    );
    assert_eq!(
        state
            .fiscal_period_repo
            .list()
            .await
            .expect("fiscal periods")
            .len(),
        1,
        "setup must bootstrap exactly one fiscal period"
    );

    let trial =
        GetTrialBalanceUseCase::new(state.journal_entry_repo.clone(), state.account_repo.clone())
            .execute(None, None)
            .await
            .expect("trial balance");
    assert_eq!(trial.total_debit, "0");
    assert_eq!(trial.total_credit, "0");

    let second = state.setup_company.execute(request()).await;
    assert!(
        matches!(second, Err(AppError::Conflict(_))),
        "setup must not silently reconfigure an existing company"
    );

    state.pool.close().await;
    drop(state);
    let _ = std::fs::remove_dir_all(&dir);
}

#[tokio::test]
async fn master_data_crud_round_trips_through_the_bridge_state() {
    let dir = std::env::temp_dir().join(format!(
        "accounting_master_data_test_{}_{}",
        std::process::id(),
        uuid::Uuid::new_v4()
    ));
    std::fs::create_dir_all(&dir).expect("create temp dir");
    let db_path = dir.join("ledger.db");

    let state = build_app_state_from_path(db_path.to_str().expect("utf-8 path"))
        .await
        .expect("build app state");

    // Customers: create, list, update and delete.
    let customer = CreateCustomerUseCase::new(
        state.customer_repo.clone(),
        state.account_repo.clone(),
        state.journal_entry_repo.clone(),
        state.opening_migration_repo.clone(),
    )
    .execute(CreateCustomerRequest {
        code: String::new(),
        name: "عميل اختبار".to_string(),
        phone: Some("0990000000".to_string()),
        address: None,
        account_id: None,
        debit: Some("0".to_string()),
        credit: Some("0".to_string()),
        opening_balance: Some("0".to_string()),
        currency: Some("SYP".to_string()),
        exchange_rate: None,
        notes: None,
    })
    .await
    .expect("create customer");

    assert!(!customer.code.is_empty());
    assert!(
        CustomerQueries::new(state.customer_repo.clone())
            .list_all()
            .await
            .expect("list customers")
            .iter()
            .any(|item| item.id == customer.id)
    );

    let updated_customer = UpdateCustomerUseCase::new(
        state.customer_repo.clone(),
        state.account_repo.clone(),
        state.currency_repo.clone(),
        state.journal_entry_repo.clone(),
        state.opening_migration_repo.clone(),
    )
    .execute(UpdateCustomerRequest {
        id: customer.id.clone(),
        code: customer.code.clone(),
        name: "عميل اختبار محدّث".to_string(),
        phone: customer.phone.clone(),
        address: None,
        account_id: None,
        debit: None,
        credit: None,
        opening_balance: None,
        currency: None,
        notes: None,
        is_active: true,
    })
    .await
    .expect("update customer");
    assert_eq!(updated_customer.name, "عميل اختبار محدّث");

    DeleteCustomerUseCase::new(
        state.customer_repo.clone(),
        state.journal_entry_repo.clone(),
    )
    .execute(customer.id.clone())
    .await
    .expect("delete customer");
    assert!(
        !CustomerQueries::new(state.customer_repo.clone())
            .list_all()
            .await
            .expect("list customers after delete")
            .iter()
            .any(|item| item.id == customer.id)
    );

    // Suppliers: create, list, update and delete.
    let supplier = CreateSupplierUseCase::new(
        state.supplier_repo.clone(),
        state.account_repo.clone(),
        state.journal_entry_repo.clone(),
        state.opening_migration_repo.clone(),
    )
    .execute(CreateSupplierRequest {
        code: String::new(),
        name: "مورد اختبار".to_string(),
        phone: None,
        address: None,
        account_id: None,
        debit: Some("0".to_string()),
        credit: Some("0".to_string()),
        opening_balance: Some("0".to_string()),
        currency: Some("SYP".to_string()),
        exchange_rate: None,
        notes: None,
    })
    .await
    .expect("create supplier");

    assert!(
        SupplierQueries::new(state.supplier_repo.clone())
            .list_all()
            .await
            .expect("list suppliers")
            .iter()
            .any(|item| item.id == supplier.id)
    );

    let updated_supplier = UpdateSupplierUseCase::new(
        state.supplier_repo.clone(),
        state.account_repo.clone(),
        state.currency_repo.clone(),
        state.journal_entry_repo.clone(),
        state.opening_migration_repo.clone(),
    )
    .execute(UpdateSupplierRequest {
        id: supplier.id.clone(),
        code: supplier.code.clone(),
        name: "مورد اختبار محدّث".to_string(),
        phone: None,
        address: None,
        account_id: None,
        debit: None,
        credit: None,
        opening_balance: None,
        currency: None,
        notes: None,
    })
    .await
    .expect("update supplier");
    assert_eq!(updated_supplier.name, "مورد اختبار محدّث");

    DeleteSupplierUseCase::new(
        state.supplier_repo.clone(),
        state.journal_entry_repo.clone(),
    )
    .execute(supplier.id.clone())
    .await
    .expect("delete supplier");
    assert!(
        !SupplierQueries::new(state.supplier_repo.clone())
            .list_all()
            .await
            .expect("list suppliers after delete")
            .iter()
            .any(|item| item.id == supplier.id)
    );

    // Materials: create, list, update and delete.
    let material =
        CreateMaterialUseCase::new(state.material_repo.clone(), state.category_repo.clone())
            .execute(CreateMaterialRequest {
                name: "مادة اختبار".to_string(),
                name_en: Some("Test material".to_string()),
                barcode: Some("TEST-001".to_string()),
                code: None,
                minimum_stock: "5".to_string(),
                units: vec![CreateMaterialUnitRequest {
                    name: "كغ".to_string(),
                    conversion_factor: "1".to_string(),
                    barcode: None,
                }],
                category_ids: vec![],
                notes: None,
                image_path: None,
                default_purchase_unit_id: Some("كغ".to_string()),
                default_sale_unit_id: Some("كغ".to_string()),
                default_purchase_currency: Some("SYP".to_string()),
                default_sale_currency: Some("SYP".to_string()),
                default_warehouse_id: None,
                has_expiry: Some(false),
                expiry_alert_before_days: Some(30),
                purchase_prices: vec![],
                sale_prices: vec![],
            })
            .await
            .expect("create material");

    assert!(!material.code.is_empty());
    let material_queries = || {
        MaterialQueries::new(
            state.material_repo.clone(),
            state.stock_movement_repo.clone(),
            state.unified_invoice_repo.clone(),
        )
        .with_lot_repo(state.inventory_lot_repo.clone())
    };
    assert!(
        material_queries()
            .list_all()
            .await
            .expect("list materials")
            .iter()
            .any(|item| item.id == material.id)
    );

    let updated_material = UpdateMaterialUseCase::new(
        state.material_repo.clone(),
        state.stock_movement_repo.clone(),
    )
    .execute(UpdateMaterialRequest {
        id: material.id.clone(),
        name: "مادة اختبار محدّثة".to_string(),
        name_en: "Test material".to_string(),
        barcode: "TEST-001".to_string(),
        code: material.code.clone(),
        minimum_stock: "8".to_string(),
        category_ids: material.category_ids.clone(),
        notes: None,
        image_path: None,
        default_purchase_unit_id: Some("كغ".to_string()),
        default_sale_unit_id: Some("كغ".to_string()),
        default_purchase_currency: Some("SYP".to_string()),
        default_sale_currency: Some("SYP".to_string()),
        default_warehouse_id: None,
        has_expiry: Some(false),
        expiry_alert_before_days: Some(30),
        purchase_prices: vec![],
        sale_prices: vec![],
    })
    .await
    .expect("update material");
    assert_eq!(updated_material.name, "مادة اختبار محدّثة");
    assert_eq!(updated_material.minimum_stock, "8");

    DeleteMaterialUseCase::new(
        state.material_repo.clone(),
        state.stock_movement_repo.clone(),
    )
    .execute(material.id.clone())
    .await
    .expect("delete material");
    assert!(
        !material_queries()
            .list_all()
            .await
            .expect("list materials after delete")
            .iter()
            .any(|item| item.id == material.id)
    );

    state.pool.close().await;
    drop(state);
    let _ = std::fs::remove_dir_all(&dir);
}
