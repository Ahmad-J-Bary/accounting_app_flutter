use application::dto::journal_entry_dto::{CreateJournalEntryRequest, JournalLineDto};
use application::use_cases::journal::CreateJournalEntryUseCase;
use application::use_cases::reports::GetTrialBalanceUseCase;
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
