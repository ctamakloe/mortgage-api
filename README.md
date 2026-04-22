# Mortgage Assessment API

A production-style Ruby on Rails API for submitting mortgage applications and computing affordability assessments asynchronously.

This project demonstrates a production-oriented API design with authentication, observability, and clear domain modelling.

---

## Features

- Submit mortgage applications
- Asynchronous affordability assessment processing
- Versioned assessments with audit trail (events)
- Per-client API key authentication
- Request logging for observability
- Per-client rate limiting
- Public UUIDs for external resource identification

---

## Tech Stack

- Ruby on Rails 8 (API mode)
- PostgreSQL
- Docker and Docker Compose
- RSpec

---

## Setup

```bash
docker-compose up --build
docker-compose exec web bin/setup
```

This will:

- Install dependencies
- Prepare development and test databases

## Running the API

The server starts automatically via Docker. The API is then available at:

```
http://localhost:3000
```

## Resetting the Database

```bash
docker-compose exec web bin/rails db:reset
```

## Running Tests

```bash
docker-compose exec web bin/test
```

## Authentication

All endpoints require an API key via:

```
Authorization: Bearer <api_key>
```

### Create a test API key

```bash
docker-compose exec web bin/rails console
```

```ruby
key = ApiClient.generate_raw_key
ApiClient.create!(
  name: "Test Client",
  api_key_digest: ApiClient.digest(key),
  active: true
)
puts key
```

Use the printed key in your requests.

---

## API Endpoints

### Create Mortgage Application

```
POST /api/v1/mortgage_applications
```

Request body:

```json
{
  "mortgage_application": {
    "annual_income": 80000,
    "monthly_expenses": 1500,
    "deposit": 50000,
    "property_value": 250000,
    "term_years": 25
  }
}
```

Response:

```json
{
  "id": "uuid",
  "status": "processing"
}
```

The `id` returned is a public UUID (not the internal database ID).

The assessment is computed asynchronously. Use the `/assessment` endpoint to retrieve the result.

### Get Mortgage Application

```
GET /api/v1/mortgage_applications/:id
```

Returns application details (including current processing status).

### Get Latest Assessment

```
GET /api/v1/mortgage_applications/:id/assessment
```

- 200 OK — assessment available
- 202 Accepted — still processing

If processing fails, the returned assessment will contain a "failed" decision with failure details.

### Get Assessment History

```
GET /api/v1/mortgage_applications/:id/assessments
```

Returns latest-first ordered list (max 10).

---

## Design Decisions

### Public IDs

A `public_id` (UUID) is used instead of exposing database IDs to:

- avoid leaking internal implementation details
- prevent resource enumeration

### Asynchronous Processing

Assessments are computed via background jobs to:

- keep API responsive
- simulate real-world processing pipelines

Jobs are retried automatically on failure (up to 3 attempts) before being marked as failed.

### Versioned Assessments

Each assessment is stored with:

- version number
- computed metrics
- failures
- explanation

This allows:

- historical tracking
- auditability

### Assessment Events (Audit Trail)

Each assessment generates events (e.g. `assessment_computed`) to provide:

- traceability
- future extensibility (e.g. event-driven systems)

### Authentication

- Per-client API keys
- Keys are hashed using SHA256 (not stored in plaintext)
- Simple and efficient lookup

### Request Logging

All requests are logged with:

- API client (if authenticated)
- method, path, status
- metadata (IP, user agent, duration)

This enables:

- observability
- debugging
- usage analysis

### Rate Limiting

- Implemented per API client (e.g. N requests per minute)
- Backed by database (simple implementation)

Exceeding the rate limit returns:

```
429 Too Many Requests
```

Production improvement:

- move to Redis for atomic counters and performance

---

## Trade-offs and Future Improvements

- Replace DB-based rate limiting with Redis
- Add pagination to assessment history
- Introduce serializers for cleaner response formatting
- Add request correlation IDs
- Implement retry/backoff strategy for background jobs

---

## Example Request

```bash
curl -X POST http://localhost:3000/api/v1/mortgage_applications \
  -H "Authorization: Bearer <api_key>" \
  -H "Content-Type: application/json" \
  -d '{
    "mortgage_application": {
      "annual_income": 80000,
      "monthly_expenses": 1500,
      "deposit": 50000,
      "property_value": 250000,
      "term_years": 25
    }
  }'
```

```bash
curl http://localhost:3000/api/v1/mortgage_applications/<id>/assessment \
  -H "Authorization: Bearer <api_key>"
```

---

## Notes

- Designed as a production-style API with clear separation of concerns
- Focused on correctness, observability, and extensibility


Returns latest-first ordered list (max 10).

---

## Example Requests

```bash
curl -X POST http://localhost:3000/api/v1/mortgage_applications \
  -H "Authorization: Bearer <api_key>" \
  -H "Content-Type: application/json" \
  -d '{
    "mortgage_application": {
      "annual_income": 80000,
      "monthly_expenses": 1500,
      "deposit": 50000,
      "property_value": 250000,
      "term_years": 25
    }
  }'
```

```bash
curl http://localhost:3000/api/v1/mortgage_applications/<id>/assessment \
  -H "Authorization: Bearer <api_key>"
```

---

## Design & Reflection

### 1. Key Design Decisions

**Separation of application and assessment resources**

A `MortgageApplication` represents the input i.e what the applicant submitted. An `Assessment` represents computed output ie. what the system decided. These are modelled as separate resources because they have different lifecycles, different consumers, and different rates of change.  An application is immutable once submitted; assessments can be recomputed as rules evolve or inputs are corrected.

This keeps the API contract clean:

- `GET /api/v1/mortgage_applications/:id` => applicant data only
- `GET /api/v1/mortgage_applications/:id/assessment` => latest decision
- `GET /api/v1/mortgage_applications/:id/assessments` => full history

Coupling assessment data to the application endpoint would make it harder to evolve either resource independently.

**Explicit status field rather than inferred state**

The `MortgageApplication` model carries an explicit `status` column (`processing`, `completed`, `failed`) rather than deriving state from the presence or absence of an assessment record. This makes application state directly queryable whih is useful for monitoring, dashboards, and operational tooling. It also means the API can return a meaningful status immediately after creation, before the background job completes, without requiring clients to inspect a separate resource.

Inferring state from related records works at small scale but becomes fragile as the system grows. Explicit state is easier to reason about, index, and filter.

**Failure as a first-class concern**

When the assessment job fails, the system creates a failed assessment record with the error reason and marks the application as `failed`.  Failures are visible through the same API surface as successful assessments. In a production mortgage platform, silent failures are unacceptable as a client or caseworker needs to know an application requires attention, not just that it has not yet completed.

The failure handling path uses the same transaction pattern as the success path where a failed assessment record and the status update to `failed` are committed atomically.

**Transactions to guarantee data consistency**

Assessment creation, audit event, and status update are wrapped in a single database transaction:

```ruby
ApplicationRecord.transaction do
  assessment = application.assessments.create!(...)
  assessment.assessment_events.create!(...)
  application.mark_completed!
end
```

So either all three writes succeed together, or none of them do. In a regulated environment, partial writes are a compliance risk .e.g a decision without an audit trail, or a status update without a corresponding decision, could create gaps that are difficult to explain to a regulator.

**Public IDs to decouple the API contract from persistence**

A `public_id` (UUID) is used instead of exposing internal database IDs.  This prevents sequential resource enumeration, decouples the API contract from the persistence layer, and future-proofs the system against migrations or sharding where internal IDs may change.

---

### 2. System Evolution

If this service needed to support a production mortgage platform, I would evolve it across three dimensions: system boundaries, load handling, and asynchronous processing.

**System boundaries**

The most important boundary to draw is between the origination domain and the assessment domain. Origination owns the application lifecycle (submission, validation, and state transitions) whereas Assessment owns the decision logic (given a set of financial inputs, what is the affordability outome) 

These change for different reasons. Origination changes when the application process changes. Assessment changes when underwriting rules or regulatory requirements change. Keeping them separate means a rule change does not require touching origination code, and an origination workflow change does not risk destabilising the assessment engine.

Critically, the assessment domain could receive inputs from multiple upstream systems, not just this origination service. If the provider integrates with a broker platform or acquires another mortgage product, a standalone assessment service can serve multiple consumers without duplication.

Rather than origination calling assessment directly, origination would publish an event ("application submitted") and assessment would consume it. The assessment events model already in this codebase is the seed of that architecture.

Authentication, rate limiting, and request logging are cross-cutting concerns that would eventually move to a shared API gateway layer rather than being implemented per-service.

**Handling increased load**

The web layer scales horizontally because the application is stateless, i.e. there is no in-process session or cache. Multiple web servers can sit behind a load balancer with zero coordination between instances. Under retry conditions, idempotency key support would prevent duplicate applications being created when a client retries a request after a network failure.

The job layer scales by increasing Solid Queue worker processes and threads, which are already configurable in `config/queue.yml`. Worker processes should run separately from the web layer so job processing does not contend with web traffic.

The database layer has different scaling profiles per domain. The assessments table is read-heavy — caseworkers querying decisions, compliance teams running reports. The applications table is write-heavy.  Read replicas relieve pressure on the primary write database for the read-heavy workload. Under high concurrency, PostgreSQL connection limits become a constraint and a connection pooler (e.g. PgBouncer) could sit between the application and the database, multiplexing connections efficiently.

The current database-backed rate limiter creates write pressure at scale and has no atomic counter guarantee across multiple processes. In production this would move to Redis with atomic increment operations.

---

### 3. Operational Considerations

**Failure handling**

Jobs retry up to three times on failure before creating a failed assessment record and marking the application status as `failed`. Every application will eventually reach a terminal state — either `completed` or `failed` and the reason for failure is persisted and queryable.  The system never silently stalls.

**Monitoring and observability**

Observability is built across three layers:

*Logs* — every request is logged with client identity, method, path, status, IP, user agent, and duration. The job logger uses a structured key=value format with application ID and public ID, enabling correlation across the web request and background job. In production, logs would ship to a log aggregation platform. A request correlation ID threading through the web request, job execution, and database operations would allow end-to-end tracing of a single application.

*Metrics* — in production, key signals to instrument include job queue depth, processing latency, error rate, and failed application count over time. These signals surface problems before customers notice them.

*Alerts* — threshold-based alerting on queue depth and failed application rate. If the queue depth exceeds a threshold and is not draining over a five-minute window, that indicates the worker process has died or is overwhelmed, which could trigger an on-call page.

The Rails health check endpoint at `/up` integrates with load balancer health checking to ensure traffic is only routed to healthy instances.

**Data integrity and auditability**

In a regulated mortgage platform, the ability to prove what the system did, when, and with what data is not optional. Three implementation decisions address this directly:

- Database transactions ensure atomic writes so that a decision record is never created without a corresponding status update and audit event
- Assessment events provide an immutable audit trail of every decision, queryable by event type and timestamp
- `dependent: :restrict_with_exception` on the assessments association prevents assessment records from being silently deleted, hence the audit trail cannot be broken accidentally

---

### 4. Change & Flexibility

Affordability rules change frequently in mortgage platforms. The variables LTV thresholds, income multipliers, and debt-to-income limits are adjusted in response to market conditions, regulatory guidance, and risk appetite.

The current implementation defines rules as constants in the service object:

```ruby
MAX_LTV = 0.9
MAX_DTI = 0.4
INCOME_MULTIPLIER = 4.0
```

This is intentionally simple for the exercise. The abstraction boundary is already in place via `AffordabilityAssessmentService`. This is the single place where rules are applied, which means the source of those rules can be changed without touching any other part of the system.

To support rule changes without redeployment, I would evolve this in stages:

**Stage 1 — database-driven configuration**

Move rule values into a database table with an admin interface.  Non-engineering teams can update values; changes take effect immediately with no deployment and without engineering being in the critical path of a business decision.

**Stage 2 — versioned rule sets with effective dates**

Store rule sets with `valid_from` timestamps, allowing the system to apply the correct rules for a given point in time. This is essential for auditability since if a decision is challenged, you need to know which rules were in effect when it was made, not what they are today. This also complements the versioned assessment records already in the system.

**Stage 3 — externally managed rules**

For complex rule logic, a rules engine managed by the risk or product team could be integrated behind the same service abstraction. The assessment service would fetch rules at runtime. This is premature until the team deeply understands the rule structure and the modernisation programme is more mature. A full rules engine requires significant research into how the rules actually work before it can be designed well.

---

### 5. Trade-offs & Prioritisation

**What I deliberately kept simple**

*In-process job queue* — the `:async` adapter runs jobs in-process using threads. Jobs are lost on process restart. This removes the operational overhead of running a separate queue worker, which is not justified for this exercise. Solid Queue with a dedicated worker process is the correct production choice.

*Database-backed rate limiting* — correct and simple, but not suitable for multi-process deployments at scale. In production this moves to Redis with atomic increment operations.

*Constant time authentication* — the current API key lookup does not use a constant time comparison, which could theoretically be vulnerable to timing attacks. `ActiveSupport::SecurityUtils.secure_compare` would address this. Noted as a deliberate omission given time constraints.

*Race condition on version calculation* — `next_assessment_version` reads the current maximum version and increments it. Two concurrent jobs for the same application could theoretically calculate the same version number. A pessimistic lock on the application record during this calculation would prevent it.

*GraphQL query layer* — a GraphQL endpoint would complement the REST API by giving diverse consumers — mobile clients, third-party integrators, internal tooling — the ability to request exactly the data they need.  REST was chosen because it more closely matches the way the system is modelled and makes authentication simpler to reason about. The GraphQL layer is a natural next step as the consumer base grows.

*End-to-end tests* — unit and request specs cover the core behaviour.  End-to-end tests covering the full application submission and assessment flow would provide additional confidence when evolving the system.

**What I would prioritise in the next 1-2 weeks**

1. **Solid Queue with database-backed processing** — jobs lost on restart is a production safety issue. This is the highest priority change.

2. **Database-driven affordability rules with effective dates** — unblocks the business from depending on engineering for rule changes, and closes the auditability gap on which rules applied at decision time.

3. **Constant time authentication** — a small change with a real security implication. Low effort, high value.

4. **GraphQL query layer** — future-proofs the API for multiple consumers without breaking the existing REST contract.

5. **End-to-end tests** — confidence when evolving the system, particularly important as the affordability rules become more complex.