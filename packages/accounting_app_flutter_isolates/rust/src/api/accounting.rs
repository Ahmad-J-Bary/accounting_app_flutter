use application::dto::journal_entry_dto::{
    CreateJournalEntryRequest, JournalEntryDto, JournalLineDto,
};
use application::use_cases::journal::{CreateJournalEntryUseCase, PostJournalEntryUseCase};
use application::use_cases::reports::GetTrialBalanceUseCase;
use domain::accounting::journal_entry::JournalType;
use tokio::sync::OnceCell;

use bridge::AppState;

static STATE: OnceCell<AppState> = OnceCell::const_new();

/// Open (or create) the SQLite ledger, run all migrations and wire the core.
///
/// On a fresh database, an open fiscal year/period for the current calendar
/// year is created so entries can be posted. Safe to call more than once with
/// the same path: the existing state is reused.
pub async fn init_app(db_path: String) -> Result<(), String> {
    STATE
        .get_or_try_init(|| async {
            let state = bridge::build_app_state_from_path(&db_path).await?;
            bridge::ensure_default_fiscal_year(&state).await?;
            Ok::<_, String>(state)
        })
        .await
        .map(|_| ())
}

fn state() -> Result<&'static AppState, String> {
    STATE
        .get()
        .ok_or_else(|| "Database is not initialized. Call initApp() first.".to_string())
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

pub async fn list_accounts() -> Result<Vec<AccountItem>, String> {
    let accounts = state()?
        .account_repo
        .list_all()
        .await
        .map_err(|e| e.to_string())?;

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
) -> Result<JournalEntryView, String> {
    let journal_type: JournalType =
        serde_json::from_value(serde_json::Value::String(input.journal_type.clone()))
            .map_err(|_| format!("Unknown journal type: {}", input.journal_type))?;

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
    let entry = use_case.execute(request).await.map_err(|e| e.to_string())?;

    Ok(entry_view(entry))
}

pub async fn post_journal_entry(entry_id: String) -> Result<JournalEntryView, String> {
    let app = state()?;
    let use_case = PostJournalEntryUseCase::new(
        app.journal_entry_repo.clone(),
        app.account_repo.clone(),
        app.fiscal_year_repo.clone(),
        app.fiscal_period_repo.clone(),
        app.pool.clone(),
    );
    let entry = use_case
        .execute(entry_id)
        .await
        .map_err(|e| e.to_string())?;

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
) -> Result<TrialBalanceView, String> {
    let app = state()?;
    let use_case =
        GetTrialBalanceUseCase::new(app.journal_entry_repo.clone(), app.account_repo.clone());
    let report = use_case
        .execute(from_date, to_date)
        .await
        .map_err(|e| e.to_string())?;

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
