# Nutritionist Appointment Requests

A web application where guests search for nutritionists and request appointments, and nutritionists accept or reject those requests. Guests are notified by email when their request is answered.

Built as a full-stack technical challenge with **Ruby on Rails** (API) and **React**.

> The interface follows the challenge's reference mockup. This project is not affiliated with or endorsed by Nutrium.

## Contents
- [Stack](#stack)
- [Project structure](#project-structure)
- [Setup](#setup)
- [Running the application](#running-the-application)
- [Running the tests](#running-the-tests)
- [Try it](#try-it)
- [API](#api)
- [Design decisions](#design-decisions)
- [Known limitations and future work](#known-limitations-and-future-work)

## Stack

| | |
|---|---|
| Backend | Ruby 3.0.2, Rails 7.1 (API mode), PostgreSQL 14, Kaminari (pagination) |
| Frontend | React 19, Vite, React Router, Tailwind CSS 4 |
| Tests | Minitest (models, use cases, request, concurrency, mailer) |

## Project structure

```
nutritionist-api/       Rails API
  app/use_cases/          business logic (Search, Create, List, Answer), one class per use case
  app/models/             validations, scopes, the conditional UPDATE used to answer a request
  app/serializers/        JSON responses
  app/controllers/api/    thin controllers: params -> use case -> HTTP status
  db/                     migrations (constraints live here), schema.rb, seeds.rb
  test/                   models, use cases, controllers (request), mailers
nutritionist-client/    React app
  src/api/                fetch wrapper and one function per endpoint
  src/pages/              one component per route
  src/components/         cards, modals, pagination
```

## Setup

### Requirements
- Ruby 3.0.2 and Bundler
- PostgreSQL 14+ with the `contrib` extensions (`citext`, `btree_gist`, `pg_trgm`; on Ubuntu they come with `postgresql-contrib`)
- Node.js 20.19+ or 22.12+ (required by Vite) and npm

### Backend
```bash
cd nutritionist-api
bundle install
bin/rails db:setup        # creates the databases, loads the schema and runs the seeds
```
The database connection uses your local PostgreSQL user by default. If you need other credentials, set the standard `PGUSER`, `PGPASSWORD` and `PGHOST` environment variables. The user must be allowed to create databases.

To reset the demo data at any time: `bin/rails db:seed` (it deletes and recreates all data).

### Frontend
```bash
cd nutritionist-client
npm install
```

## Running the application

In two terminals:
```bash
cd nutritionist-api && bin/rails server        # API on http://localhost:3000
cd nutritionist-client && npm run dev          # app on http://localhost:5173
```
Open **http://localhost:5173**. In development, Vite forwards `/api` requests to the Rails server, so the browser only talks to one origin.

| Page | URL |
|---|---|
| Nutritionist search (guest) | `/` |
| Choose a nutritionist profile | `/professionals` (the header link "Are you a nutrition professional?") |
| Appointment requests (nutritionist) | `/nutritionists/:id/requests` |

**Emails:** in development they are written to files in `nutritionist-api/tmp/mails/`, one file per recipient.

## Running the tests

```bash
cd nutritionist-api
bin/rails test
cd ../nutritionist-client
npm run lint
```

| Layer | Folder | What it covers |
|---|---|---|
| Models | `test/models/` | Validations and normalization that no use case reaches |
| Use cases | `test/use_cases/` | The business rules, against the real database (no mocks), because many rules are database constraints |
| Concurrency | `test/use_cases/appointment_requests/concurrency_test.rb` | Simultaneous requests with real threads and committed transactions |
| Request | `test/controllers/api/` | Routes, status codes, JSON shape, strong parameters |
| Mailer | `test/mailers/` | Email content and Lisbon time in emails |

## Try it

The seeds create 10 nutritionists with services at different prices and locations. Nutritionist **Ana Lima** (license 3176N) has a ready-made scenario. Its id is printed at the end of `bin/rails db:seed`.

1. **Search** on `/` for `sports`, `follow-up`, `joao` (no accent) or `ana lma` (typo).
2. **Request an appointment:** click "Schedule appointment" on any card, then fill in the name, email, date and time.
3. **Answer requests:** open `/professionals`, choose Ana Lima, and accept **Carla Nunes** (10:00–11:00):
   - **Diogo Pires** (10:30, overlapping) is rejected automatically;
   - **Eva Moreira** (11:00, right after) stays pending: back-to-back appointments do not overlap;
   - Carla and Diogo receive an email (see `tmp/mails/`).
4. **Taken slot:** request an appointment with Ana Lima at the time of **Gonçalo Teixeira**'s accepted appointment. The API answers 409 "This time slot is no longer available".
5. **One pending request per guest:** request a second appointment with the email of a guest who already has a pending request, e.g. `filipe.ramos@example.com`. The API answers 409.

## API

| Method | Path | Description |
|---|---|---|
| GET | `/api/nutritionists?q=&page=&per_page=` | Search nutritionists by name or service description |
| POST | `/api/appointment_requests` | Create a request: `{ appointment_request: { name, email, service_id, scheduled_at } }` |
| GET | `/api/nutritionists/:id/appointment_requests?status=&page=&per_page=` | A nutritionist's requests by status (`pending` by default, or `accepted` / `rejected`) |
| PATCH | `/api/appointment_requests/:id` | Answer a request: `{ status: "accepted" \| "rejected" }`. Returns the request and the ids rejected automatically |

| Status | Meaning |
|---|---|
| 200 / 201 | Success |
| 400 | The body is missing its root key (`appointment_request` or `status`) |
| 404 | Nutritionist, service or request not found |
| 409 | Conflicts with the current state: the guest already has a pending request, the slot is taken, the request was already answered |
| 422 | Invalid data: a date in the past, an invalid email, an unknown status |

Errors are returned as `{ "errors": ["..."] }`. Lists are paginated with `{ data: [...], meta: { page, per_page, total_count, total_pages } }` (`per_page` is capped at 25).

## Design decisions

### The database guarantees the rules
Model validations give friendly error messages, but two simultaneous requests can both pass them. The rules that must always hold are PostgreSQL constraints:

| Rule | Constraint |
|---|---|
| A guest has at most one pending request | Partial unique index on `guest_id WHERE status = 'pending'` |
| A nutritionist never has two overlapping accepted appointments | Exclusion constraint on `(nutritionist_id WITH =, tstzrange(scheduled_at, ends_at) WITH &&) WHERE status = 'accepted'` |
| A request's nutritionist is always the service's nutritionist | Composite foreign key `(service_id, nutritionist_id) -> services (id, nutritionist_id)` |
| Valid intervals, statuses, prices and durations | Check constraints |
| Guests are identified by email, case-insensitively | `citext` column with a unique index |

`ends_at` is computed from the service duration when the request is created (never sent by the client) and stored, because the exclusion constraint can only use columns of its own table.

### Business rules
- **A pending request does not reserve the slot.** Several guests may request the same time; only an accepted appointment takes it.
- **Accepting a request** (in one transaction) rejects every other pending request that lost its slot: the same guest at the same time (the challenge's rule) and also **other guests' overlapping requests**, which would otherwise wait for a slot that no longer exists.
- **Back-to-back appointments are allowed:** intervals are half-open (`[start, end)`), so 10:00–11:00 and 11:00–12:00 do not overlap.
- **Answering is a conditional UPDATE** (`WHERE status = 'pending'`), so a double click or two open tabs cannot answer the same request twice (409).
- **Pending requests whose date has passed** are rejected when the guest makes a new request (otherwise the one-pending rule would block the guest forever). They are hidden from the pending list and cannot be accepted (422).

### Concurrency
| Case | Guarantee |
|---|---|
| The same guest sends two requests at once | Partial unique index -> 409 |
| Two overlapping requests are accepted at once | Exclusion constraint -> 409 |
| A request is created while an overlapping one is being accepted | Pessimistic lock on the nutritionist row (`SELECT ... FOR UPDATE`) in both use cases: the second one waits and sees what the first one committed |

The lock only queues requests for the **same** nutritionist. Each case has a test with real threads (`concurrency_test.rb`). Alternatives considered: `SERIALIZABLE` isolation with retries, and optimistic locking. Both need retry logic in both use cases.

### Emails
Emails are sent **after the transaction commits**, through a `NotificationService` (`GuestMailer.answered(...).deliver_later`). An email cannot be undone by a rollback, so a failed accept never notifies anyone. Guests rejected automatically are notified too. Times in emails are shown in Lisbon time (`config.time_zone = "Lisbon"`; data is stored in UTC).

### Search
- Matches the nutritionist's name **or** a service description, case-insensitively.
- **Accent-insensitive** ("joao" finds "João"): nutritionists and services keep a normalized copy of the searchable text (`name_search`, `description_search`, without accents and in lowercase), maintained by the models. The query is normalized with the same function. This avoids a custom SQL function, so the schema stays in `schema.rb`.
- **Typo-tolerant** ("ana lma" finds "Ana Lima"): pg_trgm's word similarity operator (`<%`). Exact matches are listed first.
- Both use the **trigram GIN indexes** on the normalized columns. An external search engine (Elasticsearch, Meilisearch) would be one more service to run and keep in sync, which this scale does not need.

### Code structure
- **Use cases** (`app/use_cases`) hold the business logic and return a `Result` with a symbolic status (`:ok`, `:created`, `:invalid`, `:conflict`, `:not_found`). Controllers only map that status to HTTP, and serializers build the JSON.
- **Logs** are added only for the decisions the code takes silently (requests rejected automatically, refused overlaps, deadlock retries), as `[UseCase] event key=value` with ids only.

### Frontend
- There is **no authentication** (not required by the challenge). The nutritionist picks their profile on `/professionals`.
- After answering a request, the list is **reloaded from the API** instead of updated locally: accepting can reject other requests and change the pagination, and the server is the source of truth.
- The requests page has **Pending / Accepted / Rejected tabs** in place of the mockup's history icon, and the card's **"Website"** button is a non-functional placeholder, as the challenge allows.
- Responses that arrive out of order (e.g. clicking quickly through pages) are ignored with an effect cleanup.

## Known limitations and future work
- **Confirmation before accepting**, listing the requests that will be rejected automatically. Today the modal warns about it and a message reports how many were rejected.
- **Busy slots in the booking modal:** show the nutritionist's accepted appointments for the chosen day. Today a taken slot is refused when the request is submitted (409).
- **Location filter** (the mockup's "Location" field) and **caching** of the search.
- **Scheduled job** to reject pending requests as soon as their date passes, with an email to the guest.
- **Persistent job queue / outbox for emails:** `deliver_later` uses the in-memory adapter, so an email can be lost if the process dies right after the commit.
- **Authentication, nutritionists' working hours, i18n**, and frontend tests.
- Ruby 3.0.2 is past its end of life; upgrading to a supported version would be the first maintenance task.
