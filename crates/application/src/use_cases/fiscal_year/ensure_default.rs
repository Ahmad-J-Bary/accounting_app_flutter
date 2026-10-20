use std::sync::Arc;

use chrono::{DateTime, Datelike, TimeZone, Utc};

use crate::errors::AppError;
use crate::ports::fiscal_period_repository::FiscalPeriodRepository;
use crate::ports::fiscal_year_repository::FiscalYearRepository;
use crate::use_cases::fiscal_period::create::CreateFiscalPeriodUseCase;
use crate::use_cases::fiscal_period::types::CreateFiscalPeriodCommand;
use crate::use_cases::fiscal_year::create::CreateFiscalYearUseCase;
use crate::use_cases::fiscal_year::types::CreateFiscalYearCommand;

/// Bootstrap the first fiscal year/period for a company.
///
/// The window starts on the first day of `start_month` and ends one second
/// before the same day in the following year. This is a no-op when a fiscal
/// year and a fiscal period already exist, so it is safe to call on every
/// startup of an already-configured database.
pub struct EnsureDefaultFiscalYearUseCase {
    year_repo: Arc<dyn FiscalYearRepository>,
    period_repo: Arc<dyn FiscalPeriodRepository>,
}

impl EnsureDefaultFiscalYearUseCase {
    pub fn new(
        year_repo: Arc<dyn FiscalYearRepository>,
        period_repo: Arc<dyn FiscalPeriodRepository>,
    ) -> Self {
        Self {
            year_repo,
            period_repo,
        }
    }

    pub async fn execute(&self, start_month: u32) -> Result<(), AppError> {
        let years = self.year_repo.list().await?;
        let periods = self.period_repo.list().await?;

        if !years.is_empty() && !periods.is_empty() {
            return Ok(());
        }

        let (start, end) = fiscal_window(start_month)?;

        if years.is_empty() {
            CreateFiscalYearUseCase::new(self.year_repo.clone())
                .execute(CreateFiscalYearCommand {
                    company_id: None,
                    label: fiscal_year_label(start, end),
                    start_date: start.to_rfc3339(),
                    end_date: end.to_rfc3339(),
                    previous_fiscal_year_id: None,
                })
                .await?;
        }

        if periods.is_empty() {
            let (period_start, period_end) = years
                .first()
                .map(|year| (year.start_date, year.end_date))
                .unwrap_or((start, end));

            CreateFiscalPeriodUseCase::new(self.period_repo.clone())
                .execute(CreateFiscalPeriodCommand {
                    company_id: None,
                    start_date: period_start.to_rfc3339(),
                    end_date: period_end.to_rfc3339(),
                })
                .await?;
        }

        Ok(())
    }
}

fn fiscal_window(start_month: u32) -> Result<(DateTime<Utc>, DateTime<Utc>), AppError> {
    if !(1..=12).contains(&start_month) {
        return Err(AppError::Invalid(
            "شهر بداية السنة المالية يجب أن يكون بين 1 و 12".to_string(),
        ));
    }

    let now = Utc::now();
    let start_year = if now.month() >= start_month {
        now.year()
    } else {
        now.year() - 1
    };
    let end_year = start_year + 1;

    let start = Utc
        .with_ymd_and_hms(start_year, start_month, 1, 0, 0, 0)
        .single()
        .ok_or_else(|| AppError::Invalid("تاريخ بداية السنة المالية غير صالح".to_string()))?;
    let end = Utc
        .with_ymd_and_hms(end_year, start_month, 1, 0, 0, 0)
        .single()
        .ok_or_else(|| AppError::Invalid("تاريخ نهاية السنة المالية غير صالح".to_string()))?
        - chrono::Duration::seconds(1);

    Ok((start, end))
}

fn fiscal_year_label(start: DateTime<Utc>, end: DateTime<Utc>) -> String {
    format!("السنة المالية {}-{}", start.year(), end.year())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::mocks::{MockFiscalPeriodRepository, MockFiscalYearRepository};

    #[tokio::test]
    async fn creates_year_and_period_once() {
        let year_repo = Arc::new(MockFiscalYearRepository::new());
        let period_repo = Arc::new(MockFiscalPeriodRepository::new());
        let use_case = EnsureDefaultFiscalYearUseCase::new(year_repo.clone(), period_repo.clone());

        use_case.execute(1).await.unwrap();
        assert_eq!(year_repo.list().await.unwrap().len(), 1);
        assert_eq!(period_repo.list().await.unwrap().len(), 1);

        use_case.execute(1).await.unwrap();
        assert_eq!(year_repo.list().await.unwrap().len(), 1);
        assert_eq!(period_repo.list().await.unwrap().len(), 1);
    }

    #[tokio::test]
    async fn rejects_invalid_start_month() {
        let year_repo = Arc::new(MockFiscalYearRepository::new());
        let period_repo = Arc::new(MockFiscalPeriodRepository::new());
        let use_case = EnsureDefaultFiscalYearUseCase::new(year_repo, period_repo);

        assert!(matches!(
            use_case.execute(0).await,
            Err(AppError::Invalid(_))
        ));
        assert!(matches!(
            use_case.execute(13).await,
            Err(AppError::Invalid(_))
        ));
    }
}
