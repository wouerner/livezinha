# livezinha

Monorepo with two independent apps: Laravel API + Vue 3 SPA.

## Structure

- `backend/` — Laravel 13.x API (PHP 8.3+)
- `frontend/` — Standalone Vue 3 SPA (Vite), **not** built by Laravel Vite

## Backend commands (run from `backend/`)

| Command | What it does |
|---|---|
| `composer dev` | Starts all services: `artisan serve`, `queue:listen`, `pail` (logs), `npm run dev` (Vite for Laravel) concurrently |
| `composer test` | `artisan config:clear` then `artisan test` (PHPUnit wrapper) |
| `php artisan test --filter=Name` | Single test |
| `vendor/bin/phpunit tests/Feature/ExampleTest.php` | Single file via phpunit directly |
| `./vendor/bin/pint` | Laravel Pint (PSR-12 linter, no config file) |
| `composer setup` | Full project setup |

## Frontend commands (run from `frontend/`)

| Command | What it does |
|---|---|
| `npm run dev` | Vite dev server (default port 5173) |
| `npm run build` | Production build |
| `npm run preview` | Preview production build |

No lint, test, or typecheck commands configured for frontend.

## API

- All API routes in `routes/api.php` are auto-prefixed with `/api` by Laravel
- JSON-only responses (middleware in `bootstrap/app.php` targets `api/*`)
- Frontend hardcodes `apiBaseUrl = 'http://localhost/api'`
- No authentication on public endpoints (`/lives/active`, `/lives/active/question`, question creation)
- Sanctum auth on admin CRUD endpoints (`/lives/*`, `/questions/*` excluding POST `/questions`)

## Database

- `.env` uses **MySQL** pointing to `mysql` host (Docker Sail service)
- Tests use **SQLite in-memory** (`phpunit.xml` sets `DB_CONNECTION=sqlite`, `DB_DATABASE=testing`)
- Session, cache, and queue all backed by the database
- Run migrations: `php artisan migrate`
- Seed database: `php artisan db:seed`
- Reset everything (migrate fresh + seed): `php artisan migrate:fresh --seed`
- Default admin user after seeding: `admin@livezinha.com` / `admin123`

## Models & Migrations

- `LiveStream` — `hasMany(Question)`, fields: `title`, `streamer_name`, `live_url`, `scheduled_at`, `status`
- `Question` — `belongsTo(LiveStream)`, fields: `live_stream_id`, `name`, `tiktok_handle`, `question_text`, `passcode`, `status`, `is_tagged`
- `Note` — standalone, fields: `title`, `content`
- Passcode generation: Portuguese noun-adjective string (`gato-azul`), unique across all questions

## Frontend architecture

- Single `App.vue` with hash-based routing (`#/public`, `#/admin`, `#/obs`)
- No Vue Router, no Pinia, no Axios — vanilla `fetch()` calls
- OBS overlay view polls `/lives/active/question` every 2 seconds
- Connection health check polls `/ping` every 10 seconds

## Testing quirks

- Unit tests extend `PHPUnit\Framework\TestCase` (no Laravel app)
- Feature tests extend `Tests\TestCase` (Laravel app, no `RefreshDatabase` trait by default)
- Example test in Feature dir calls `$this->get('/')` which returns the Blade welcome view

## Dev environment

- Laravel Sail (`./vendor/bin/sail up`) runs Docker with PHP 8.5 + MySQL 8.4
- Run artisan commands via `docker exec -w /var/www/html backend-laravel.test-1 php artisan <cmd>` (or `./vendor/bin/sail artisan <cmd>` if Sail is configured)
- `compose.yaml` vendor-published (do not edit directly)
- Recommended VS Code extension for frontend: `Vue.volar`
