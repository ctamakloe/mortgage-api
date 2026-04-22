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
docker-compose exec web rails console
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

Returns application details (no assessment data).

### Get Latest Assessment

```
GET /api/v1/mortgage_applications/:id/assessment
```

- 200 OK — assessment available
- 202 Accepted — still processing

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
