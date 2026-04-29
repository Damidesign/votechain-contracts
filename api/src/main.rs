use axum::{extract::{Path, Query, State}, http::StatusCode, routing::{get, post}, Router};
use std::{net::SocketAddr, sync::{Arc, RwLock}};
use tracing_subscriber::{fmt, prelude::*};
use votechain_indexer_api::{self as api, Event, Indexer, ProposalListParams};

#[tokio::main]
async fn main() {
    tracing_subscriber::registry()
        .with(fmt::layer())
        .init();

    let state = api::AppState {
        indexer: Arc::new(RwLock::new(Indexer::new())),
    };

    let app = Router::new()
        .route("/proposals", get(api::list_proposals))
        .route("/proposals/:id", get(api::get_proposal))
        .route("/proposals/:id/votes", get(api::get_proposal_votes))
        .route("/voters/:address/votes", get(api::get_voter_votes))
        .route("/events", post(api::ingest_event))
        .route("/openapi.json", get(api::openapi_json))
        .with_state(state);

    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));
    tracing::info!(%addr, "starting VoteChain indexer API");
    axum::Server::bind(&addr)
        .serve(app.into_make_service())
        .await
        .unwrap();
}
