/// Basic diagnostic endpoint for the shared accounting core.
pub fn health_check() -> &'static str {
    "accounting-core: ok"
}
