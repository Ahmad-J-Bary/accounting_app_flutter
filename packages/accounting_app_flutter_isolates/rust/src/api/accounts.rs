use std::str::FromStr;

use application::constants::EXPENSES_PARENT_ID;
use application::dto::account_dto::AccountDto;
use application::use_cases::account::{
    AccountQueries, CreateAccountCommand, CreateAccountUseCase, DeleteAccountUseCase,
    UpdateAccountUseCase,
};
use domain::accounting::account::{Account, AccountCategory, AccountType};
use domain::shared::ids::AccountId;

use super::accounting::{AccountItem, account_item};
use super::error::ApiError;

#[derive(Debug, Clone)]
pub struct ExpenseItemInput {
    pub id: Option<String>,
    pub code: String,
    pub name_ar: String,
    pub name_en: String,
    pub opening_balance: String,
    pub debit: String,
    pub credit: String,
    pub currency: String,
    pub exchange_rate: String,
    pub notes: Option<String>,
}

fn expenses_parent_id() -> Result<AccountId, ApiError> {
    AccountId::from_str(EXPENSES_PARENT_ID)
        .map_err(|_| ApiError::new("invalid_account_id", "معرف حساب المصاريف غير صالح."))
}

async fn expense_account(id: &str) -> Result<AccountId, ApiError> {
    AccountId::from_str(id)
        .map_err(|_| ApiError::new("invalid_account_id", "معرف بند المصاريف غير صالح."))
}

async fn parent_level() -> Result<i32, ApiError> {
    let app = super::accounting::state()?;
    let parent = app
        .account_repo
        .find_by_id(&expenses_parent_id()?)
        .await?
        .ok_or_else(|| ApiError::new("account_not_found", "حساب المصاريف الأب غير موجود."))?;
    Ok(parent.level + 1)
}

/// Rejects any account that is not a direct child of the expenses root so the
/// bridge cannot be used to mutate unrelated parts of the chart of accounts.
async fn require_expense_child(id: &AccountId) -> Result<Account, ApiError> {
    let app = super::accounting::state()?;
    let account = app
        .account_repo
        .find_by_id(id)
        .await?
        .ok_or_else(|| ApiError::new("account_not_found", "بند المصاريف غير موجود."))?;
    if account.parent_id.as_ref() != Some(&expenses_parent_id()?) {
        return Err(ApiError::new(
            "not_an_expense_item",
            "الحساب المحدد ليس بند مصاريف.",
        ));
    }
    Ok(account)
}

/// Expense items (بنود المصاريف) are detail accounts under the expenses root.
pub async fn list_expense_items() -> Result<Vec<AccountItem>, ApiError> {
    let app = super::accounting::state()?;
    let accounts = AccountQueries::new(app.account_repo.clone(), app.journal_entry_repo.clone())
        .get_expense_items()
        .await
        .map_err(|e| ApiError::new("account_query_failed", e.to_string()))?;
    Ok(accounts.into_iter().map(account_item).collect())
}

pub async fn create_expense_item(input: ExpenseItemInput) -> Result<AccountItem, ApiError> {
    let app = super::accounting::state()?;
    let parent_id = expenses_parent_id()?;
    let parent = app
        .account_repo
        .find_by_id(&parent_id)
        .await?
        .ok_or_else(|| ApiError::new("account_not_found", "حساب المصاريف الأب غير موجود."))?;

    let code = if input.code.trim().is_empty() {
        app.account_repo.get_next_child_code(&parent.code).await?
    } else {
        input.code
    };

    let command = CreateAccountCommand {
        code,
        name_ar: input.name_ar,
        name_en: input.name_en,
        account_type: AccountType::Expenses,
        parent_id: Some(parent_id),
        category: AccountCategory::Detail,
        level: parent.level + 1,
        opening_balance: input.opening_balance,
        notes: input.notes,
        linked_customer_id: None,
        linked_supplier_id: None,
        phone: None,
        address: None,
        debit: Some(input.debit),
        credit: Some(input.credit),
        currency: Some(input.currency),
        exchange_rate: Some(input.exchange_rate),
    };

    let account = CreateAccountUseCase::new(
        app.account_repo.clone(),
        app.journal_entry_repo.clone(),
        Some(app.customer_repo.clone()),
        Some(app.supplier_repo.clone()),
        app.currency_repo.clone(),
        app.opening_migration_repo.clone(),
    )
    .execute(command)
    .await
    .map_err(|e| ApiError::new("account_create_failed", e.to_string()))?;

    Ok(account_item(AccountDto::from(account)))
}

pub async fn update_expense_item(input: ExpenseItemInput) -> Result<AccountItem, ApiError> {
    let app = super::accounting::state()?;
    let id = input
        .id
        .ok_or_else(|| ApiError::new("missing_account_id", "معرف بند المصاريف مطلوب."))?;
    let account_id = expense_account(&id).await?;
    let existing = require_expense_child(&account_id).await?;
    let level = parent_level().await?;

    let command = CreateAccountCommand {
        code: if input.code.trim().is_empty() {
            existing.code
        } else {
            input.code
        },
        name_ar: input.name_ar,
        name_en: input.name_en,
        account_type: AccountType::Expenses,
        parent_id: Some(expenses_parent_id()?),
        category: AccountCategory::Detail,
        level,
        opening_balance: existing.opening_balance.to_string(),
        notes: input.notes,
        linked_customer_id: None,
        linked_supplier_id: None,
        phone: None,
        address: None,
        // Expense items never carry manual debit/credit totals; their balance
        // comes from posted vouchers, so preserve the stored values.
        debit: None,
        credit: None,
        currency: Some(if input.currency.trim().is_empty() {
            existing.currency.code.clone()
        } else {
            input.currency
        }),
        exchange_rate: Some(existing.exchange_rate.to_string()),
    };

    let account = UpdateAccountUseCase::new(
        app.account_repo.clone(),
        Some(app.customer_repo.clone()),
        Some(app.supplier_repo.clone()),
        app.currency_repo.clone(),
        app.journal_entry_repo.clone(),
        app.opening_migration_repo.clone(),
    )
    .execute(account_id, command)
    .await
    .map_err(|e| ApiError::new("account_update_failed", e.to_string()))?;

    Ok(account_item(AccountDto::from(account)))
}

pub async fn delete_expense_item(id: String) -> Result<(), ApiError> {
    let app = super::accounting::state()?;
    let account_id = expense_account(&id).await?;
    require_expense_child(&account_id).await?;
    DeleteAccountUseCase::new(
        app.account_repo.clone(),
        app.journal_entry_repo.clone(),
        Some(app.customer_repo.clone()),
        Some(app.supplier_repo.clone()),
    )
    .delete(account_id)
    .await
    .map_err(|e| ApiError::new("account_delete_failed", e.to_string()))
}
