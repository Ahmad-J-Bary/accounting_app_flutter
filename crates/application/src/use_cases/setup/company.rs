use std::sync::Arc;

use crate::dto::settings_dto::UpdateSettingsRequest;
use crate::dto::setup_dto::{CompanySetupDto, SetupCompanyRequest};
use crate::errors::AppError;
use crate::ports::fiscal_period_repository::FiscalPeriodRepository;
use crate::ports::fiscal_year_repository::FiscalYearRepository;
use crate::ports::settings_repository::SettingsRepository;
use crate::use_cases::currency::setup::CurrencySetupUseCase;
use crate::use_cases::fiscal_year::ensure_default::EnsureDefaultFiscalYearUseCase;
use crate::use_cases::settings::update::UpdateSettingsUseCase;
use crate::world_currencies;
use domain::settings::{START_MODE_EXISTING, START_MODE_NEW};

/// One-time company setup: install the base/secondary currency, persist the
/// company identity and bootstrap the first fiscal year.
///
/// Keeping this in the application layer means the Flutter bridge, the Axum
/// server and the CLI all run the same validation and the same accounting
/// bootstrap instead of re-implementing it per transport.
pub struct SetupCompanyUseCase {
    currency_setup: Arc<CurrencySetupUseCase>,
    settings_repo: Arc<dyn SettingsRepository>,
    update_settings: UpdateSettingsUseCase,
    ensure_fiscal_year: EnsureDefaultFiscalYearUseCase,
}

impl SetupCompanyUseCase {
    pub fn new(
        currency_setup: Arc<CurrencySetupUseCase>,
        settings_repo: Arc<dyn SettingsRepository>,
        fiscal_year_repo: Arc<dyn FiscalYearRepository>,
        fiscal_period_repo: Arc<dyn FiscalPeriodRepository>,
    ) -> Self {
        Self {
            currency_setup,
            update_settings: UpdateSettingsUseCase::new(settings_repo.clone()),
            settings_repo,
            ensure_fiscal_year: EnsureDefaultFiscalYearUseCase::new(
                fiscal_year_repo,
                fiscal_period_repo,
            ),
        }
    }

    pub async fn execute(&self, request: SetupCompanyRequest) -> Result<CompanySetupDto, AppError> {
        let company_name = request.company_name.trim().to_string();
        if company_name.is_empty() {
            return Err(AppError::Invalid("اسم الشركة مطلوب".to_string()));
        }
        if !(1..=12).contains(&request.fiscal_year_start_month) {
            return Err(AppError::Invalid(
                "شهر بداية السنة المالية يجب أن يكون بين 1 و 12".to_string(),
            ));
        }

        if self.currency_setup.is_setup_complete().await? {
            return Err(AppError::Conflict(
                "تم إعداد الشركة مسبقاً. استخدم شاشة الإعدادات لتعديل البيانات.".to_string(),
            ));
        }

        let base_code = request.base_currency_code.trim().to_uppercase();
        let secondary_code = request
            .secondary_currency_code
            .map(|code| code.trim().to_uppercase())
            .filter(|code| !code.is_empty() && *code != base_code);

        self.currency_setup
            .setup_currencies(&base_code, secondary_code.as_deref())
            .await?;

        let existing = self.settings_repo.get().await?;
        let symbol = world_currencies::get_world_currencies()
            .into_iter()
            .find(|currency| currency.code == base_code)
            .map(|currency| currency.symbol)
            .unwrap_or_else(|| base_code.clone());

        let start_mode = request
            .accounting_start_mode
            .unwrap_or_else(|| existing.accounting_start_mode.clone());
        if start_mode != START_MODE_NEW && start_mode != START_MODE_EXISTING {
            return Err(AppError::Invalid(
                "طريقة بدء المحاسبة غير صالحة".to_string(),
            ));
        }

        let updated = self
            .update_settings
            .execute(UpdateSettingsRequest {
                company_name: company_name.clone(),
                company_name_en: existing.company_name_en,
                tax_number: existing.tax_number,
                commercial_register: existing.commercial_register,
                address: existing.address,
                phone: existing.phone,
                email: existing.email,
                currency: base_code.clone(),
                currency_symbol: symbol.clone(),
                tax_rate: decimal_to_f64(existing.tax_rate),
                invoice_prefix: existing.invoice_prefix,
                purchase_prefix: existing.purchase_prefix,
                journal_prefix: existing.journal_prefix,
                fiscal_year_start_month: request.fiscal_year_start_month,
                purchase_warehouse_id: existing.purchase_warehouse_id,
                sales_warehouse_id: existing.sales_warehouse_id,
                numeral_system: existing.numeral_system,
                accounting_start_mode: Some(start_mode.clone()),
            })
            .await?;

        self.ensure_fiscal_year
            .execute(updated.fiscal_year_start_month)
            .await?;

        Ok(CompanySetupDto {
            company_name: updated.company_name,
            base_currency_code: base_code,
            currency_symbol: symbol,
            secondary_currency_code: secondary_code,
            fiscal_year_start_month: updated.fiscal_year_start_month,
            accounting_start_mode: start_mode,
            setup_complete: self.currency_setup.is_setup_complete().await?,
        })
    }
}

fn decimal_to_f64(value: rust_decimal::Decimal) -> f64 {
    value.to_string().parse::<f64>().unwrap_or(0.0)
}
