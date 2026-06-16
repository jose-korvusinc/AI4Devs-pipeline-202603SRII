======================================================================================================
CLAUDE CODE MODELO OPUS 4.8
======================================================================================================
1. /init

------------------------------------------------------------------------------------------------------

2. META PROMPT

Create prompt to configure deploy backend with Github Actions on AWS ECS Instance Ubuntu
by SSH with file key .pem connection

------------------------------------------------------------------------------------------------------

3. PROMPT OBTAINED

Create a GitHub Actions workflow at `.github/workflows/ci.yml` that builds, tests, and deploys the
`backend/` service to an AWS EC2 Ubuntu instance over SSH using a .pem private key. Requirements:

CONTEXT
- Monorepo: the backend lives in `backend/` (Express + TypeScript + Prisma over PostgreSQL).
- The EC2 instance is Ubuntu, already provisioned, reachable by SSH on port 22, with Node.js, npm,
  PM2, and a running PostgreSQL available to the app.
- Deployment auth is an SSH .pem private key (no AWS CLI / SSM); connect as the `ubuntu` user.

TRIGGER
- Run on push to `main` and on pull requests targeting `main`.
- Use a `defaults.run.working-directory: backend` so steps run inside the backend folder.

JOBS
1) build-and-test (runs on every push and PR):
   - Checkout, setup Node 18 with npm cache.
   - `npm ci`, `npx prisma generate`, `npm run build`, `npm test`.
2) deploy (runs only on push to `main`, and only if build-and-test succeeds — use `needs:`):
   - Connect to EC2 over SSH using the .pem key stored in a GitHub Secret.
   - On the server: `cd` to the app directory, `git pull`, `npm ci`, `npx prisma generate`,
     `npx prisma migrate deploy`, `npm run build`, then restart the app with
     `pm2 restart <app> || pm2 start dist/index.js --name <app>` and `pm2 save`.

SECRETS (read from GitHub repository Secrets, never hardcode)
- `EC2_SSH_KEY`   -> the full contents of the .pem private key.
- `EC2_HOST`      -> the public IP or DNS of the instance.
- `EC2_USER`      -> the SSH user (e.g. `ubuntu`).
- `DATABASE_URL`  -> if migrations/build need it at deploy time.

IMPLEMENTATION NOTES
- Prefer a maintained SSH action (e.g. `appleboy/ssh-action`) OR write the key to a file with
  `chmod 600` and run a raw `ssh -i key.pem -o StrictHostKeyChecking=no ...` heredoc — pick one and
  explain the choice.
- Fail the deploy if any remote command fails (`set -e` in the remote script).
- Do not echo secrets into logs. Add brief comments explaining each step.

After creating the workflow, list exactly which GitHub Secrets I must add and where, and any
security-group / EC2 prerequisite I need to verify before the first run.
----------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------

4. META PROMPT

Create prompt to create script to install all applications used by backend on AWS EC2
Ubuntu 26 Server

------------------------------------------------------------------------------------------------------

5. PROMPT OBTAINED

Create a Bash provisioning script at `scripts/provision-ec2.sh` that installs every dependency the
`backend/` service needs to build and run on a fresh AWS EC2 Ubuntu Server 26.04 LTS instance.
Requirements:

CONTEXT
- The backend is Express + TypeScript + Prisma, served with PM2, persisting to PostgreSQL.
- Target host: a clean EC2 Ubuntu 26.04 LTS instance, connected as the `ubuntu` user with sudo.
- The script is run once to prepare the box before the GitHub Actions deploy job runs.

THE SCRIPT MUST
- Start with `#!/usr/bin/env bash` and `set -euo pipefail`; be idempotent (safe to re-run).
- Update apt and install base tooling: `git`, `curl`, `build-essential`, `ufw`.
- Install Node.js 18 LTS via the NodeSource apt repo (so `node` and `npm` are available system-wide).
- Install PM2 globally (`npm install -g pm2`) and enable it to start on boot (`pm2 startup`).
- Install and start PostgreSQL (server + client), enable the service, and create the app database,
  user, and password to match the backend's `DATABASE_URL` (take DB name/user/password as variables
  at the top of the script with sensible defaults).
- Optionally install Nginx as a reverse proxy in front of the backend (behind a flag).
- Configure the firewall (ufw) to allow OpenSSH plus the app/HTTP ports, then enable it.
- Print a final summary of installed versions (`node -v`, `npm -v`, `pm2 -v`, `psql --version`).

IMPLEMENTATION NOTES
- Use `apt-get install -y` and guard each install so re-running does not fail on already-installed
  packages (idempotent).
- Do not hardcode secrets; read DB credentials from environment variables or clearly marked
  variables at the top, and warn the user to change defaults.
- Add comments grouping each section (system, Node, PM2, PostgreSQL, Nginx, firewall).
- Use `sudo` only where required, and verify each major step succeeded before continuing.

After writing the script, list the exact commands to copy it to the instance and run it
(e.g. via `scp` with the .pem key and `ssh`), and note anything I must edit before running.
----------------------------------------------------------------------------------------------------

6. FIX ERROR GITHUB ACTIONS WITH CLAUDE

Fix this error in Github Actions:
FAIL dist/application/services/positionService.test.js
  ● Console

    console.error
      Error retrieving candidates by position: PrismaClientInitializationError:
      Invalid `prisma.application.findMany()` invocation in
      /home/runner/work/AI4Devs-pipeline-202603SRII/AI4Devs-pipeline-202603SRII/backend/dist/application/services/positionService.js:54:57

        51 switch (_a.label) {
        52     case 0:
        53         _a.trys.push([0, 2, , 3]);
      → 54         return [4 /*yield*/, prisma.application.findMany(
      Can't reach database server at `localhost:5432`

      Please make sure your database server is running at `localhost:5432`.
          at In.handleRequestError (/home/runner/work/AI4Devs-pipeline-202603SRII/AI4Devs-pipeline-202603SRII/backend/node_modules/@prisma/client/runtime/library.js:122:7177)
          at In.handleAndLogRequestError (/home/runner/work/AI4Devs-pipeline-202603SRII/AI4Devs-pipeline-202603SRII/backend/node_modules/@prisma/client/runtime/library.js:122:6211)
          at In.request (/home/runner/work/AI4Devs-pipeline-202603SRII/AI4Devs-pipeline-202603SRII/backend/node_modules/@prisma/client/runtime/library.js:122:5919)
          at l (/home/runner/work/AI4Devs-pipeline-202603SRII/AI4Devs-pipeline-202603SRII/backend/node_modules/@prisma/client/runtime/library.js:127:11167) {
        clientVersion: '5.14.0',
        errorCode: undefined
      }

      71 |             case 2:
      72 |                 error_1 = _a.sent();
    > 73 |                 console.error('Error retrieving candidates by position:', error_1);
         |                         ^
      74 |                 throw new Error('Error retrieving candidates by position');
      75 |             case 3: return [2 /*return*/];
      76 |         }

      at dist/application/services/positionService.js:73:25
      at step (dist/application/services/positionService.js:33:23)
      at Object.throw (dist/application/services/positionService.js:14:53)
      at rejected (dist/application/services/positionService.js:6:65)
