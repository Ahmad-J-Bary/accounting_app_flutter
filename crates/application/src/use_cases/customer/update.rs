use chrono::Utc;
use domain::customers::Customer;
use domain::shared::ids::{AccountId, CustomerId};
use rust_decimal::Decimal;
use std::sync::Arc;

use crate::dto::customer_dto::{CustomerDto, UpdateCustomerRequest};
use crate::errors::AppError;
use crate::ports::account_repository::AccountRepository;
use crate::ports::currency_repository::CurrencyRepository;
use crate::ports::customer_repository::CustomerRepository;
use crate::ports::journal_entry_repository::JournalEntryRepository;
use crate::ports::opening_migration_repository::OpeningMigrationRepository;
use crate::use_cases::opening_balance::opening_window_active;
use crate::use_cases::shared::partner_account::{PartnerKind, build_balance_adjustment_entry};

pub struct UpdateCustomerUseCase {
    customer_repo: Arc<dyn CustomerRepository>,
    account_repo: Arc<dyn AccountRepository>,
    currency_repo: Arc<dyn CurrencyRepository>,
    journal_repo: Arc<dyn JournalEntryRepository>,
    opening_migration_repo: Arc<dyn OpeningMigrationRepository>,
}

impl UpdateCustomerUseCase {
    pub fn new(
        customer_repo: Arc<dyn CustomerRepository>,
        account_repo: Arc<dyn AccountRepository>,
        currency_repo: Arc<dyn CurrencyRepository>,
        journal_repo: Arc<dyn JournalEntryRepository>,
        opening_migration_repo: Arc<dyn OpeningMigrationRepository>,
    ) -> Self {
        Self {
            customer_repo,
            account_repo,
            currency_repo,
            journal_repo,
            opening_migration_repo,
        }
    }

    pub async fn execute(&self, req: UpdateCustomerRequest) -> Result<CustomerDto, AppError> {
        let cid = req
            .id
            .parse::<CustomerId>()
            .map_err(|_| AppError::NotFound("معرف العميل غير صالح".into()))?;
        let mut customer = self
            .customer_repo
            .find_by_id(&cid)
            .await?
            .ok_or_else(|| AppError::NotFound("العميل غير موجود".into()))?;

        let old_debit = customer.debit;
        let old_credit = customer.credit;
        let direct_balance_update = req.debit.is_some() || req.credit.is_some();

        customer
            .update_info(
                req.name.clone(),
                req.phone.clone(),
                req.address.clone(),
                req.notes.clone(),
            )
            .map_err(|e| AppError::Invalid(e.to_string()))?;

        customer.code = crate::utils::ensure_code(Some(req.code), customer.code);

        if let Some(ref acc_id_str) = req.account_id {
            let account_id = acc_id_str
                .parse::<AccountId>()
                .map_err(|_| AppError::Invalid("معرف الحساب غير صالح".into()))?;
            customer.link_account(account_id);
        }

        if let Some(ref d) = req.debit {
            customer.debit = crate::utils::parse_decimal(Some(d), "المدين")?;
            customer.balance = customer.debit - customer.credit;
        }
        if let Some(ref c) = req.credit {
            customer.credit = crate::utils::parse_decimal(Some(c), "الدائن")?;
            customer.balance = customer.debit - customer.credit;
        }

        if let Some(ref ob) = req.opening_balance {
            let new_opening = crate::utils::parse_decimal(Some(ob), "رصيد الافتتاح")?;
            if direct_balance_update {
                customer.opening_balance = new_opening;
            } else {
                apply_opening_balance_delta(&mut customer, new_opening);
            }
        }

        if let Some(ref cur) = req.currency {
            customer.currency = crate::utils::parse_currency(Some(cur));
        }

        if req.is_active {
            customer.activate();
        } else {
            customer.deactivate();
        }

        // balance = debit − credit for customers
        let new_balance = customer.debit - customer.credit;
        let old_balance = old_debit - old_credit;
        let balance_change = new_balance - old_balance;

        // While an opening-balance migration window is open the migration's
        // aggregate journal owns the ledger (same rule as partner create). The
        // linked account stays static (no balance drift) and no per-entity
        // balance-adjustment journal is posted — a later real journal would
        // double-count the same opening balance (R1). Entity edits such as the
        // opening balance are still persisted; they feed the wizard derivation.
        let opening_window = opening_window_active(&self.opening_migration_repo).await?;

        // Sync the linked account name in memory (persisted atomically below).
        // During the window the balance keeps its static value.
        let mut synced_account = None;
        if let Some(account_id) = &customer.account_id {
            let mut account = self
                .account_repo
                .find_by_id(account_id)
                .await
                .map_err(|e| AppError::Infrastructure(e.to_string()))?
                .ok_or_else(|| AppError::NotFound("معرف الحساب غير صالح".into()))?;
            account.name_ar = customer.name.clone();
            account.name_en = customer.name.clone();
            if !opening_window {
                account.balance = customer.balance;
            }
            account.updated_at = Utc::now();
            synced_account = Some(account);
        }

        // Build the balance-adjustment journal entry in memory (no write yet).
        // Deferred to the migration while the opening window is open; only
        // partners that actually have a linked ledger account produce one.
        let adjustment_entry = if !opening_window {
            if let Some(account) = synced_account.as_ref() {
                build_balance_adjustment_entry(
                    account.id,
                    &customer.name,
                    &customer.id.to_string(),
                    balance_change,
                    PartnerKind::Customer,
                    &self.account_repo,
                    &self.journal_repo,
                    &self.currency_repo,
                )
                .await?
            } else {
                None
            }
        } else {
            None
        };

        let mut entries = Vec::new();
        if let Some(entry) = adjustment_entry {
            entries.push(entry);
        }

        // Persist customer + account sync + adjustment journal in ONE txn
        self.customer_repo
            .update_with_accounting(&customer, synced_account.as_ref(), &entries)
            .await?;

        Ok(CustomerDto::from(customer))
    }
}

/// Applies an opening-balance change as a delta so later activity (invoices,
/// payments, returns) is preserved. The linked account and adjustment journal
/// follow the resulting balance change, which equals the opening delta.
fn apply_opening_balance_delta(customer: &mut Customer, new_opening: Decimal) {
    let delta = new_opening - customer.opening_balance;
    customer.opening_balance = new_opening;

    if delta > Decimal::ZERO {
        customer.debit += delta;
    } else if delta < Decimal::ZERO {
        let decrease = -delta;
        if customer.debit >= decrease {
            customer.debit -= decrease;
        } else {
            let remainder = decrease - customer.debit;
            customer.debit = Decimal::ZERO;
            customer.credit += remainder;
        }
    }

    customer.balance = customer.debit - customer.credit;
}

#[cfg(test)]
mod tests {
    use super::*;
    use domain::shared::currency::Currency;
    use rust_decimal_macros::dec;

    fn sample_customer(debit: Decimal, credit: Decimal, opening: Decimal) -> Customer {
        let mut customer = Customer::new(
            "C1".into(),
            "Test customer".into(),
            None,
            None,
            None,
            debit,
            credit,
            opening,
            Currency::new("SYP", "ليرة سورية", "Syrian Pound", "ل.س", 2, true),
            None,
        )
        .expect("valid customer");
        customer.balance = debit - credit;
        customer
    }

    #[test]
    fn increasing_opening_balance_adds_to_debit_and_preserves_activity() {
        let mut customer = sample_customer(dec!(80), dec!(20), dec!(50));
        apply_opening_balance_delta(&mut customer, dec!(70));
        assert_eq!(customer.opening_balance, dec!(70));
        assert_eq!(customer.debit, dec!(100));
        assert_eq!(customer.credit, dec!(20));
        assert_eq!(customer.balance, dec!(80));
    }

    #[test]
    fn decreasing_opening_balance_moves_excess_to_credit() {
        let mut customer = sample_customer(dec!(10), dec!(20), dec!(50));
        apply_opening_balance_delta(&mut customer, dec!(20));
        assert_eq!(customer.opening_balance, dec!(20));
        assert_eq!(customer.debit, Decimal::ZERO);
        assert_eq!(customer.credit, dec!(40));
        assert_eq!(customer.balance, dec!(-40));
    }
}
