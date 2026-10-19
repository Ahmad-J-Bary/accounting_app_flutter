use axum::{routing::get, Router};

#[tokio::main]
async fn main() {
    let app = Router::new().route("/health", get(|| async { "accounting-server: ok" }));

    // Bind to localhost for the initial development smoke test.
    let listener = tokio::net::TcpListener::bind("127.0.0.1:8080")
        .await
        .expect("Failed to bind HTTP listener");

    println!("Server listening on http://127.0.0.1:8080");

    axum::serve(listener, app)
        .await
        .expect("HTTP server failed");
}
