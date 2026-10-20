use application::errors::AppError;

/// Transport-neutral error returned by every bridge call.
///
/// Flutter receives this as a Dart `ApiError` object (not an opaque string), so
/// screens can branch on `code` while still showing the Arabic `message`.
#[derive(Debug, Clone)]
pub struct ApiError {
    pub code: String,
    pub message: String,
    pub details: Option<String>,
}

impl ApiError {
    pub fn new(code: impl Into<String>, message: impl Into<String>) -> Self {
        Self {
            code: code.into(),
            message: message.into(),
            details: None,
        }
    }

    pub fn with_details(
        code: impl Into<String>,
        message: impl Into<String>,
        details: impl Into<String>,
    ) -> Self {
        Self {
            code: code.into(),
            message: message.into(),
            details: Some(details.into()),
        }
    }
}

impl From<AppError> for ApiError {
    fn from(error: AppError) -> Self {
        Self {
            code: error.code().to_string(),
            message: error.to_string(),
            details: None,
        }
    }
}

impl From<String> for ApiError {
    fn from(message: String) -> Self {
        Self::new("internal_error", message)
    }
}

impl From<&str> for ApiError {
    fn from(message: &str) -> Self {
        Self::new("internal_error", message)
    }
}

impl std::fmt::Display for ApiError {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(formatter, "{}: {}", self.code, self.message)
    }
}

impl std::error::Error for ApiError {}
