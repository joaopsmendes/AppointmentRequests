# Nutritionist Appointment Requests

A web application where guests search for nutritionists and request appointments, and nutritionists accept or reject those requests. Guests are notified by email when their request is answered.

Built as a full-stack technical challenge with **Ruby on Rails** (API) and **React**.

> The interface follows the reference mockup provided with the challenge, including the Nutrium logo.

## Contents
- [Stack](#stack)
- [Project structure](#project-structure)
- [Setup](#setup)
- [Running the application](#running-the-application)
- [Running the tests](#running-the-tests)
- [Try it](#try-it)
- [API](#api)
- [Notes and decisions](#notes-and-decisions)
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
   - Carla and Diogo receive an email (see `tmp/mails/`);
   - the clock icon opens the history: every answered request, the most recent answer first.
4. **Taken slot:** request an appointment with Ana Lima at the time of **Gonçalo Teixeira**'s accepted appointment. The API answers 409 "This time slot is no longer available".
5. **One pending request per guest:** request a second appointment with the email of a guest who already has a pending request, e.g. `filipe.ramos@example.com`. The API answers 409.

## API

| Method | Path | Description |
|---|---|---|
| GET | `/api/nutritionists?q=&page=&per_page=` | Search nutritionists by name or service description |
| POST | `/api/appointment_requests` | Create a request: `{ appointment_request: { name, email, service_id, scheduled_at } }` |
| GET | `/api/nutritionists/:id/appointment_requests?status=&page=&per_page=` | A nutritionist's requests by one or more statuses, separated by commas (`pending` by default; `accepted,rejected` for the history). Pending requests are ordered by appointment date, answered ones by the most recent answer |
| PATCH | `/api/appointment_requests/:id` | Answer a request: `{ status: "accepted" \| "rejected" }`. Returns the request and the ids rejected automatically |

| Status | Meaning |
|---|---|
| 200 / 201 | Success |
| 400 | The body is missing its root key (`appointment_request` or `status`) |
| 404 | Nutritionist, service or request not found |
| 409 | Conflicts with the current state: the guest already has a pending request, the slot is taken, the request was already answered |
| 422 | Invalid data: a date in the past, an invalid email (it must look like `name@domain.tld`), an unknown status |

Errors are returned as `{ "errors": ["..."] }`. Lists are paginated with `{ data: [...], meta: { page, per_page, total_count, total_pages } }` (`per_page` is capped at 25).

## Notes and decisions

### Main decisions
- **The database enforces the rules.** Model validations give friendly error messages, but two simultaneous requests can both pass them. The rules that must always hold are PostgreSQL constraints:

  | Rule | Constraint |
  |---|---|
  | A guest has at most one pending request | Partial unique index on `guest_id WHERE status = 'pending'` |
  | A nutritionist never has two overlapping accepted appointments | Exclusion constraint: `nutritionist_id WITH =, tstzrange(scheduled_at, ends_at) WITH &&`, only for accepted requests |
  | A request's nutritionist is always its service's nutritionist | Composite foreign key `(service_id, nutritionist_id)` |
  | Guests are identified by email, case-insensitively | `citext` with a unique index |

- **A pending request does not reserve the slot.** Several guests may ask for the same time, and the nutritionist chooses. Only an accepted appointment takes the slot.
- **Accepting rejects every pending request that lost its slot:** the same guest at the same time (the challenge's rule) and also other guests' overlapping requests, which would otherwise wait for a slot that no longer exists. The response lists the ids rejected automatically.
- **Back-to-back appointments are allowed:** intervals are half-open (`[start, end)`), so 10:00–11:00 and 11:00–12:00 do not overlap. `ends_at` is computed from the service duration, never sent by the client.
- **Expired pending requests** (date passed with no answer) are rejected when the guest makes a new request. Otherwise the one-pending rule would block the guest forever. They are hidden from the pending list and cannot be accepted.
- **Emails are sent after the transaction commits** (`NotificationService` → `deliver_later`): a rollback cannot undo an email, so a failed accept never notifies anyone. Times are shown in Lisbon time; data is stored in UTC.

### Concurrency
The frontend disables buttons while a request is in flight, but the backend cannot rely on that: a double click, two open tabs or a direct API call can always race. These are the race conditions between the two write flows, **Create** (a guest requests an appointment) and **Update** (a nutritionist answers one), and how each is handled:

| Flows | Race condition | What could go wrong | How it is prevented |
|---|---|---|---|
| **Create vs Create** | The same guest sends two requests at once | Both pass the validation, and the guest ends up with two pending requests | Partial unique index on pending requests: the second insert fails → 409 |
| **Update vs Update** | Two overlapping requests of the same nutritionist are accepted at once | Double booking | Exclusion constraint on accepted intervals: the second accept fails → 409 |
| **Update vs Update** | The same request is answered twice (double click, two tabs) | Answered twice, two emails | Conditional `UPDATE ... WHERE status = 'pending'`: the second one updates 0 rows → 409 |
| **Create vs Update** | A request is created while an overlapping one is being accepted | Each side checks before the other commits: the new request passes the "slot taken" check, and the accept does not see it to reject it. It stays pending in a taken slot, and its guest is blocked. | Pessimistic lock on the nutritionist row (`SELECT ... FOR UPDATE`) at the start of both flows: the second one waits and then sees what the first one committed |

The first three are about rows the database can check when they are written, so a constraint is enough. **Create vs Update** depends on a row that does not exist yet (the new request), which no constraint can see. That is the only place that needed a lock. The lock only queues requests for the same nutritionist, and both flows lock in the same order (nutritionist, then requests), so they cannot deadlock each other; a retry on deadlock stays as a safety net.

Each case is covered by a test with real threads and committed transactions (`concurrency_test.rb`).

### Search
- Matches the nutritionist's name or a service description, ignoring case and accents ("joao" finds "João"). Nutritionists and services keep a normalized copy of that text (`name_search`, `description_search`), maintained by the models, and the query is normalized the same way.
- Tolerates typos ("ana lma" finds "Ana Lima") with pg_trgm's word similarity. Exact matches come first.
- Both use trigram GIN indexes. An external search engine would be one more service to run and keep in sync.

### Code
- **Backend:** use cases (`app/use_cases`) hold the business logic and return a `Result` with a symbolic status (`:ok`, `:created`, `:invalid`, `:conflict`, `:not_found`); controllers only map it to HTTP. Logs are added only for decisions taken silently (requests rejected automatically, refused overlaps, deadlock retries), with ids only.
- **Frontend:** there is no authentication (not required): the nutritionist picks their profile on `/professionals`. After an answer, the list is reloaded from the API, because accepting can reject other requests. The mockup's clock icon opens the history (every answered request, for auditing), and Pending / Accepted / Rejected tabs were added as well. The "Website" button is a placeholder, as the challenge allows.

## Known limitations and future work
- **Confirmation before accepting**, listing the requests that will be rejected automatically. Today the modal warns about it and a message reports how many were rejected.
- **Busy slots in the booking modal:** show the nutritionist's accepted appointments for the chosen day. Today a taken slot is refused when the request is submitted (409).
- **Location filter** (the mockup's "Location" field) and **caching** of the search.
- **Audit trail:** the history shows each request's final status and answer date, but not who decided. A `decisions` table with one record per answer would keep the full trail.
- **Reliable background jobs:** a persistent queue (or outbox) for emails, which today can be lost if the process dies right after the commit, and a scheduled job to reject pending requests as soon as their date passes.
- **Authentication and nutritionists' working hours**, with time zones per location.
- **Production readiness:** error tracking (e.g. Sentry) and structured logs, on top of the logs already written for the decisions taken silently.
- **i18n** and **frontend tests**.
