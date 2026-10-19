use std::collections::HashMap;
use std::sync::Arc;

use chrono::{DateTime, NaiveDate, Utc};
use rust_decimal::Decimal;

use crate::dto::report_dto::{TrialBalanceDto, TrialBalanceLineDto};
use crate::errors::AppError;
use crate::ports::account_repository::AccountRepository;
use crate::ports::journal_entry_repository::JournalEntryRepository;
use domain::accounting::account::{AccountType, NormalBalance};

/// Trial Balance: aggregated debit/credit per account across all posted,
/// non-reversed journal lines.
///
/// When `from_date` / `to_date` are provided (`YYYY-MM-DD`), the response
/// includes opening/period splits for the window. When omitted, the opening
/// fields default to the cumulative totals and the period fields are zero.
pub struct GetTrialBalanceUseCase {
    journal_repo: Arc<dyn JournalEntryRepository>,
    account_repo: Arc<dyn AccountRepository>,
}

impl GetTrialBalanceUseCase {
    pub fn new(
        journal_repo: Arc<dyn JournalEntryRepository>,
        account_repo: Arc<dyn AccountRepository>,
    ) -> Self {
        Self {
            journal_repo,
            account_repo,
        }
    }

    pub async fn execute(
        &self,
        from_date: Option<String>,
        to_date: Option<String>,
    ) -> Result<TrialBalanceDto, AppError> {
        let agg_rows = self.journal_repo.aggregate_by_account().await?;

        let period_agg = match (&from_date, &to_date) {
            (Some(from), Some(to)) => {
                let from_utc = parse_boundary(from, false)?;
                let to_utc = parse_boundary(to, true)?;
                Some(
                    self.journal_repo
                        .aggregate_by_account_for_period(from_utc, to_utc)
                        .await?,
                )
            }
            _ => None,
        };

        let account_ids: Vec<_> = agg_rows.iter().map(|row| row.account_id).collect();
        let accounts = self.account_repo.find_by_ids(&account_ids).await?;
        let account_map: HashMap<_, _> = accounts.into_iter().map(|a| (a.id, a)).collect();

        let period_map: HashMap<_, _> = period_agg
            .as_ref()
            .map(|rows| {
                rows.iter()
                    .map(|row| {
                        (
                            row.account_id,
                            (row.total_debit_base, row.total_credit_base),
                        )
                    })
                    .collect()
            })
            .unwrap_or_default();

        let mut total_debit = Decimal::ZERO;
        let mut total_credit = Decimal::ZERO;
        let mut total_opening_debit = Decimal::ZERO;
        let mut total_opening_credit = Decimal::ZERO;
        let mut total_period_debit = Decimal::ZERO;
        let mut total_period_credit = Decimal::ZERO;

        let mut lines: Vec<TrialBalanceLineDto> = agg_rows
            .into_iter()
            .filter_map(|row| {
                let account = account_map.get(&row.account_id)?;
                let normal = normal_balance(&account.account_type);
                let net = row.total_debit_base - row.total_credit_base;
                let (debit_total, credit_total) = split_by_normal_balance(net, normal);

                let (opening_debit, opening_credit, period_debit, period_credit) =
                    if let Some((period_debit_total, period_credit_total)) =
                        period_map.get(&row.account_id)
                    {
                        let period_net = *period_debit_total - *period_credit_total;
                        let opening_net = net - period_net;
                        let (opening_debit, opening_credit) =
                            split_by_normal_balance(opening_net, normal);
                        let (period_debit, period_credit) =
                            split_by_normal_balance(period_net, normal);
                        (opening_debit, opening_credit, period_debit, period_credit)
                    } else {
                        (debit_total, credit_total, Decimal::ZERO, Decimal::ZERO)
                    };

                total_debit += debit_total;
                total_credit += credit_total;
                total_opening_debit += opening_debit;
                total_opening_credit += opening_credit;
                total_period_debit += period_debit;
                total_period_credit += period_credit;

                Some(TrialBalanceLineDto {
                    account_id: account.id.0.to_string(),
                    account_code: account.code.clone(),
                    account_name: account.name_ar.clone(),
                    account_type: format!("{:?}", account.account_type),
                    debit_total: debit_total.to_string(),
                    credit_total: credit_total.to_string(),
                    balance: net.to_string(),
                    opening_debit: opening_debit.to_string(),
                    opening_credit: opening_credit.to_string(),
                    period_debit: period_debit.to_string(),
                    period_credit: period_credit.to_string(),
                })
            })
            .collect();

        lines.sort_by(|a, b| a.account_code.cmp(&b.account_code));

        Ok(TrialBalanceDto {
            lines,
            total_debit: total_debit.to_string(),
            total_credit: total_credit.to_string(),
            generated_at: Utc::now().to_rfc3339(),
            total_opening_debit: total_opening_debit.to_string(),
            total_opening_credit: total_opening_credit.to_string(),
            total_period_debit: total_period_debit.to_string(),
            total_period_credit: total_period_credit.to_string(),
        })
    }
}

fn normal_balance(account_type: &AccountType) -> NormalBalance {
    match account_type {
        AccountType::Assets | AccountType::Expenses => NormalBalance::Debit,
        AccountType::Liabilities | AccountType::Equity | AccountType::Revenue => {
            NormalBalance::Credit
        }
    }
}

fn split_by_normal_balance(net: Decimal, normal: NormalBalance) -> (Decimal, Decimal) {
    match normal {
        NormalBalance::Debit => {
            if net > Decimal::ZERO {
                (net, Decimal::ZERO)
            } else {
                (Decimal::ZERO, -net)
            }
        }
        NormalBalance::Credit => {
            if net > Decimal::ZERO {
                (Decimal::ZERO, net)
            } else {
                (-net, Decimal::ZERO)
            }
        }
    }
}

fn parse_boundary(value: &str, end_of_day: bool) -> Result<DateTime<Utc>, AppError> {
    let date = NaiveDate::parse_from_str(value, "%Y-%m-%d")
        .map_err(|e| AppError::Invalid(format!("Invalid date '{value}': {e}")))?;
    let time = if end_of_day {
        date.and_hms_opt(23, 59, 59)
    } else {
        date.and_hms_opt(0, 0, 0)
    }
    .ok_or_else(|| AppError::Invalid(format!("Invalid time for date '{value}'")))?;
    Ok(time.and_utc())
}
