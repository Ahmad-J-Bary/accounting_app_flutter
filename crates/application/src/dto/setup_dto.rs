use serde::{Deserialize, Serialize};

/// First-run company setup input.
///
/// This is intentionally separate from [`crate::dto::settings_dto::UpdateSettingsRequest`]:
/// setup is a one-time operation that also installs the base/secondary
/// currencies and bootstraps the first fiscal year, while the settings screen
/// only edits an existing company.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SetupCompanyRequest {
    pub company_name: String,
    pub base_currency_code: String,
    pub secondary_currency_code: Option<String>,
    pub fiscal_year_start_month: u32,
    pub accounting_start_mode: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CompanySetupDto {
    pub company_name: String,
    pub base_currency_code: String,
    pub currency_symbol: String,
    pub secondary_currency_code: Option<String>,
    pub fiscal_year_start_month: u32,
    pub accounting_start_mode: String,
    pub setup_complete: bool,
}
