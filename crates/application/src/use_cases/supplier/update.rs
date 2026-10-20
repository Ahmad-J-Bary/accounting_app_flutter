use chrono::Utc;
use domain::shared::ids::{AccountId, SupplierId};
use domain::suppliers::Supplier;
use rust_decimal::Decimal;
use std::sync::Arc;

use crate::dto::supplier_dto::{SupplierDto, UpdateSupplierRequest};
use crate::errors::AppError;
use crate::ports::account_repository::AccountRepository;
use crate::ports::currency_repository::CurrencyRepository;
use crate::ports::journal_entry_repository::JournalEntryRepository;
use crate::ports::opening_migration_repository::OpeningMigrationRepository;
use crate::ports::supplier_repository::SupplierRepository;
use crate::use_cases::opening_balance::opening_window_active;
use crate::use_cases::shared::partner_account::{PartnerKind, build_balance_adjustment_entry};

pub struct UpdateSupplierUseCase {
    supplier_repo: Arc<dyn SupplierRepository>,
    account_repo: Arc<dyn AccountRepository>,
    currency_repo: Arc<dyn CurrencyRepository>,
    journal_repo: Arc<dyn JournalEntryRepository>,
    opening_migration_repo: Arc<dyn OpeningMigrationRepository>,
}

impl UpdateSupplierUseCase {
    pub fn new(
        supplier_repo: Arc<dyn SupplierRepository>,
        account_repo: Arc<dyn AccountRepository>,
        currency_repo: Arc<dyn CurrencyRepository>,
        journal_repo: Arc<dyn JournalEntryRepository>,
        opening_migration_repo: Arc<dyn OpeningMigrationRepository>,
    ) -> Self {
        Self {
            supplier_repo,
            account_repo,
            currency_repo,
            journal_repo,
            opening_migration_repo,
        }
    }

    pub async fn execute(&self, req: UpdateSupplierRequest) -> Result<SupplierDto, AppError> {
        let sid = req
            .id
            .parse::<SupplierId>()
            .map_err(|_| AppError::NotFound("معرف المورد غير صالح".into()))?;
        let mut supplier = self
            .supplier_repo
            .find_by_id(&sid)
            .await?
            .ok_or_else(|| AppError::NotFound("المورد غير موجود".into()))?;

        let old_debit = supplier.debit;
        let old_credit = supplier.credit;
        let direct_balance_update = req.debit.is_some() || req.credit.is_some();

        supplier
            .update_info(
                req.name.clone(),
                req.phone.clone(),
                req.address.clone(),
                req.notes.clone(),
            )
            .map_err(|e| AppError::Invalid(e.to_string()))?;

        supplier.code = crate::utils::ensure_code(Some(req.code), supplier.code);

        if req.is_active {
            supplier.activate();
        } else {
            supplier.deactivate();
        }

        if let Some(ref acc_id_str) = req.account_id {
            let account_id = acc_id_str
                .parse::<AccountId>()
                .map_err(|_| AppError::Invalid("معرف الحساب غير صالح".into()))?;
            supplier.link_account(account_id);
        }

        if let Some(ref d) = req.debit {
            supplier.debit = crate::utils::parse_decimal(Some(d), "المدين")?;
            supplier.balance = supplier.credit - supplier.debit;
        }
        if let Some(ref c) = req.credit {
            supplier.credit = crate::utils::parse_decimal(Some(c), "الدائن")?;
            supplier.balance = supplier.credit - supplier.debit;
        }

        if let Some(ref ob) = req.opening_balance {
            let new_opening = crate::utils::parse_decimal(Some(ob), "رصيد الافتتاح")?;
            if direct_balance_update {
                supplier.opening_balance = new_opening;
            } else {
                apply_opening_balance_delta(&mut supplier, new_opening);
            }
        }

        if let Some(ref cur) = req.currency {
            supplier.currency = crate::utils::parse_currency(Some(cur));
        }

        // balance = credit − debit for suppliers
        let new_balance = supplier.credit - supplier.debit;
        let old_balance = old_credit - old_debit;
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
        if let Some(account_id) = &supplier.account_id {
            let mut account = self
                .account_repo
                .find_by_id(account_id)
                .await
                .map_err(|e| AppError::Infrastructure(e.to_string()))?
                .ok_or_else(|| AppError::NotFound("معرف الحساب غير صالح".into()))?;
            account.name_ar = supplier.name.clone();
            account.name_en = supplier.name.clone();
            if !opening_window {
                account.balance = supplier.balance;
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
                    &supplier.name,
                    &supplier.id.to_string(),
                    balance_change,
                    PartnerKind::Supplier,
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

        // Persist supplier + account sync + adjustment journal in ONE txn
        self.supplier_repo
            .update_with_accounting(&supplier, synced_account.as_ref(), &entries)
            .await?;

        Ok(SupplierDto::from(supplier))
    }
}

/// Applies an opening-balance change as a delta so later activity is kept.
/// Supplier balances are credit − debit, so a positive opening delta increases
/// credit first and a negative delta reduces it (or increases debit).
fn apply_opening_balance_delta(supplier: &mut Supplier, new_opening: Decimal) {
    let delta = new_opening - supplier.opening_balance;
    supplier.opening_balance = new_opening;

    if delta > Decimal::ZERO {
        supplier.credit += delta;
    } else if delta < Decimal::ZERO {
        let decrease = -delta;
        if supplier.credit >= decrease {
            supplier.credit -= decrease;
        } else {
            let remainder = decrease - supplier.credit;
            supplier.credit = Decimal::ZERO;
            supplier.debit += remainder;
        }
    }

    supplier.balance = supplier.credit - supplier.debit;
}

#[cfg(test)]
mod tests {
    use super::*;
    use domain::shared::currency::Currency;
    use rust_decimal_macros::dec;

    fn sample_supplier(debit: Decimal, credit: Decimal, opening: Decimal) -> Supplier {
        let mut supplier = Supplier::new(
            "S1".into(),
            "Test supplier".into(),
            None,
            None,
            None,
            debit,
            credit,
            opening,
            Currency::new("SYP", "ليرة سورية", "Syrian Pound", "ل.س", 2, true),
            None,
        )
        .expect("valid supplier");
        supplier.balance = credit - debit;
        supplier
    }

    #[test]
    fn increasing_opening_balance_adds_to_credit_and_preserves_activity() {
        let mut supplier = sample_supplier(dec!(20), dec!(80), dec!(50));
        apply_opening_balance_delta(&mut supplier, dec!(70));
        assert_eq!(supplier.opening_balance, dec!(70));
        assert_eq!(supplier.credit, dec!(100));
        assert_eq!(supplier.debit, dec!(20));
        assert_eq!(supplier.balance, dec!(80));
    }

    #[test]
    fn decreasing_opening_balance_moves_excess_to_debit() {
        let mut supplier = sample_supplier(dec!(20), dec!(10), dec!(50));
        apply_opening_balance_delta(&mut supplier, dec!(20));
        assert_eq!(supplier.opening_balance, dec!(20));
        assert_eq!(supplier.credit, Decimal::ZERO);
        assert_eq!(supplier.debit, dec!(40));
        assert_eq!(supplier.balance, dec!(-40));
    }
}
