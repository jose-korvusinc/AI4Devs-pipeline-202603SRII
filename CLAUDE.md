# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

LTI is a full-stack Applicant Tracking System: a Create React App frontend (`frontend/`) and an Express + TypeScript backend (`backend/`) using Prisma over PostgreSQL. The two are independent npm projects; there is no root install. Backend serves on `http://localhost:3010`, frontend on `http://localhost:3000`. CORS in `backend/src/index.ts` is hardcoded to allow only `localhost:3000`, and the frontend hardcodes the `localhost:3010` API base in its service files — changing ports means editing both sides.

## Commands

Run these from within `backend/` or `frontend/` — there is no root-level build/test.

Backend (`cd backend`):
- `npm run dev` — run with hot reload (ts-node-dev); use this for local development
- `npm run build` — compile TypeScript to `dist/`
- `npm start` — run compiled `dist/index.js` (requires a prior build)
- `npm test` — run all Jest tests
- `npx jest path/to/file.test.ts` — run a single test file
- `npx jest -t "test name"` — run tests matching a name

Frontend (`cd frontend`):
- `npm start` — dev server
- `npm run build` — production build to `build/`
- `npm test` — Jest (config in `frontend/jest.config.js`)
- `npm run cypress:open` / `npm run cypress:run` — Cypress e2e (specs in `frontend/cypress/integration/`)

Database (from `backend/`, requires the Docker Postgres running):
- `docker-compose up -d` — start Postgres (run from repo root; reads DB vars from root `.env`)
- `npx prisma generate` — regenerate the Prisma client after schema changes
- `npx prisma migrate dev` — create/apply migrations
- `npx ts-node prisma/seed.ts` — seed example data

## Backend architecture

The backend follows a layered (DDD-flavored) structure under `backend/src/`. A request flows:

`routes/` → `presentation/controllers/` → `application/services/` → `domain/models/` → Prisma → Postgres

- **`routes/`** — Express routers mapping HTTP verbs to controllers (`candidateRoutes.ts`, `positionRoutes.ts`), registered in `index.ts` under `/candidates` and `/positions`. Note: some routers wrap controllers in inline try/catch (see `candidateRoutes.ts`), so error handling is split between route and controller.
- **`presentation/controllers/`** — parse/validate request params, call services, shape HTTP responses and status codes.
- **`application/services/`** — business logic and Prisma queries. Each service instantiates its own `new PrismaClient()` at module scope.
- **`domain/models/`** — TypeScript classes that mirror the Prisma schema and act as **active records**: they carry data and have their own `async save()` methods that call Prisma directly (e.g. `Candidate.save()` builds nested `create` payloads for educations/workExperiences/resumes). They are not plain DTOs.
- **`application/validator.ts`** — regex-based field validation (name, email, Spanish phone format `^(6|7|9)\d{8}$`, dates) throwing `Error` on invalid input; called before persistence.
- **`application/services/fileUploadService.ts`** — Multer-based CV upload, wired directly as `POST /upload` in `index.ts`.

`index.ts` also attaches a shared `PrismaClient` to `req.prisma` via middleware (separate from the per-service clients), and a global error handler returns 500 "Something broke!".

Tests are co-located as `*.test.ts` next to the code they cover (controllers and services), using `ts-jest` (`backend/jest.config.js`).

## Data model

The Prisma schema (`backend/prisma/schema.prisma`) is the source of truth. Core entities: `Candidate` (with `Education`, `WorkExperience`, `Resume`) and the hiring pipeline — `Company` → `Position` → `Application` → `Interview`, structured by `InterviewFlow` / `InterviewStep` / `InterviewType` and conducted by `Employee`. See `backend/ModeloDatos.md` for the diagram and `backend/api-spec.yaml` for endpoint specs.

Note: `schema.prisma` hardcodes the `datasource db.url` connection string rather than reading `DATABASE_URL` from `.env`. Keep the schema URL and the `.env` `DATABASE_URL` in sync, or migrations will hit the wrong database.

## Frontend architecture

CRA + React Router (`frontend/src/App.js`) with four routes: `/` (RecruiterDashboard), `/add-candidate`, `/positions`, `/positions/:id`. Uses `react-beautiful-dnd` / `react-dnd` for the kanban-style stage columns. API calls live in `frontend/src/services/` (axios, hardcoded `localhost:3010` base URLs). Most components are `.js`; a few are `.tsx`.

## Conventions

- See `backend/ManifestoBuenasPracticas.md` for the project's coding guidelines.
- Backend formatting/linting is Prettier-driven ESLint (`backend/.eslintrc.js` extends `plugin:prettier/recommended`).
- Code comments and some messages are in Spanish; both English and Spanish docs exist in `README.md`.

## CI/CD

`.github/workflows/ci.yml` exists but is currently **empty** — this repo is a teaching exercise (session 12: GitHub Actions) where the CI/CD pipeline is meant to be built. The README describes the intended target: build + test on PR, then deploy to an EC2 instance via PM2, using repo secrets `AWS_ACCESS_ID`, `AWS_ACCESS_KEY`, and `EC2_INSTANCE`.
