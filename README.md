# Process-as-Code reference lab

[![CI](https://github.com/ProcessAsCode/reference-lab/actions/workflows/ci.yml/badge.svg)](https://github.com/ProcessAsCode/reference-lab/actions/workflows/ci.yml)

The whole [Process-as-Code](https://github.com/ProcessAsCode) stack as one deployable system: processes as versioned UAPF packages, executed by a process runtime and a governed AI agent, behind a single sign-in, with every step recorded. It runs on one machine with Docker Compose and any OpenAI-compatible LLM gateway.

```
                         browser
                            │
                ┌───────────▼────────────┐
                │ edge  (Apache, OIDC,   │──── auth.<domain> ──▶ Keycloak (realm "pac")
                │        OWASP CRS)      │
                └─┬────────┬──────┬────┬─┘
     processgit.<domain>  studio.  dms.  legal.<domain>
                  │        │      │      │
             ProcessGit  Studio  OpenDMS  OpenLegal
                  │                 │      │
                  │      UAPF-IP    ▼      ▼
                  └──────────▶  uapf-engine  ◀──────── process-agent ──▶ LLM gateway (external)
                                     │            (ai.*, task.*, event.*,
                                     │             data/document via MCP)
                                     └────────────▶ event-signer (DID/VC)
```

## Components

Each component is fetched at the commit pinned in [`components.lock`](components.lock).

| Service | Component | Licence | Started by |
|---|---|---|---|
| `edge` | Apache gateway with OpenID Connect and the OWASP Core Rule Set (this repository) | Apache-2.0 | core |
| `keycloak` | Identity and single sign-on, realm `pac` ([`keycloak/realm-pac.json`](keycloak/realm-pac.json)) | Apache-2.0 | core |
| `processgit` | [processgit](https://github.com/ProcessAsCode/processgit): UAPF package repository with MCP endpoint | AGPL-3.0-only | core |
| `uapf-engine` | [uapf-engine](https://github.com/UAPFormat/uapf-engine): UAPF-IP reference runtime | ISC | core |
| `process-agent` | [process-agent](https://github.com/ProcessAsCode/process-agent): governed agent, UAPF-IP host | Apache-2.0 | core |
| `event-signer` | [event-signer](https://github.com/ProcessAsCode/event-signer): DID/VC signing | Apache-2.0 | core |
| `dms-*` | [opendms](https://github.com/ProcessAsCode/opendms): document management | AGPL-3.0-only | profile `dms` |
| `legal-*` | [openlegal](https://github.com/ProcessAsCode/openlegal): contracts and governance obligations | AGPL-3.0-only | profile `legal` |
| `studio-*` | [studio](https://github.com/ProcessAsCode/studio): BPMN, DMN and CMMN modelling | AGPL-3.0-only | profile `studio` |

The LLM gateway is not part of the lab: point `LLM_GATEWAY_URL` at any OpenAI-compatible endpoint (an on-premises gateway, a local model server, or a hosted API).

## Quick start

Requirements: Docker with Compose v2, `git`, `zip`, `openssl`.

```bash
git clone https://github.com/ProcessAsCode/reference-lab.git
cd reference-lab
scripts/fetch-components.sh          # components at the pinned commits + example package
scripts/init-env.sh                  # .env with generated secrets
$EDITOR .env                         # set LLM_GATEWAY_URL, LLM_API_KEY, LLM_MODEL
docker compose up -d --build         # core
```

Add host systems with profiles:

```bash
docker compose --profile dms --profile legal --profile studio up -d --build
```

Open `http://lab.localhost` for the landing page.

| Address | Service |
|---|---|
| `http://lab.localhost` | landing page |
| `http://auth.lab.localhost/admin/` | Keycloak administration (`KC_ADMIN_USER` / `KC_ADMIN_PASSWORD` from `.env`) |
| `http://processgit.lab.localhost` | ProcessGit |
| `http://studio.lab.localhost` | Studio (profile `studio`) |
| `http://dms.lab.localhost` | OpenDMS (profile `dms`) |
| `http://legal.lab.localhost/app/` | OpenLegal (profile `legal`) |
| `http://127.0.0.1:4100` | process-agent API and MCP adapter (local only) |

`*.localhost` resolves to the local machine in current browsers. For another domain, set `LAB_DOMAIN` and point its DNS (`<domain>` and `*.<domain>`) at the host.

## First steps

1. **Create a user.** In Keycloak, realm `pac` → Users → Add user, set a password, and add the user to the group `example-organisation`. Self-registration is off.
2. **Sign in** at any service address; the session is shared across all subdomains. ProcessGit creates the account on first sign-in from the identity the gateway passes on.
3. **Run the example process.** `scripts/fetch-components.sh` builds `packages/document-intake.uapf` (from the UAPF-IP examples): classify an incoming document with AI, route it with a DMN decision table, emit an event.

   ```bash
   source .env
   curl -s -H "Authorization: Bearer $AGENT_API_TOKEN" http://127.0.0.1:4100/agent/processes
   curl -s -H "Authorization: Bearer $AGENT_API_TOKEN" -H "Content-Type: application/json" \
        http://127.0.0.1:4100/agent/runs -d '{
          "packageId": "dev.uapf.examples.opendms-document-intake",
          "processId": "document-intake",
          "input": { "text": "Invoice 2026-114 is overdue.", "categories": ["complaint","finance","legal","hr"] }
        }'
   curl -s -H "Authorization: Bearer $AGENT_API_TOKEN" http://127.0.0.1:4100/agent/audit/verify
   ```

4. **Add your own processes.** Put `.uapf` packages in `packages/` and restart `uapf-engine`, or publish them in ProcessGit.

## Configuration

| Setting | Where | Purpose |
|---|---|---|
| `LAB_DOMAIN`, `LAB_SCHEME` | `.env` | hostnames of all services |
| `LLM_GATEWAY_URL`, `LLM_API_KEY`, `LLM_MODEL` | `.env` | the model endpoint used by the agent, OpenDMS and OpenLegal |
| `LAB_WAF_MODE` | `.env` | `DetectionOnly` logs rule matches, `On` blocks them |
| system bindings | [`agent/agent.yaml`](agent/agent.yaml) | which MCP tools of your systems serve `data.*` and `document.*` |
| roles, groups, clients | [`keycloak/realm-pac.json`](keycloak/realm-pac.json) | imported on first start |
| routing | [`edge/conf/lab.conf`](edge/conf/lab.conf) | one line per protected service |

## Before exposing the lab beyond one machine

- Terminate TLS in front of the edge (or add certificates to it) and set `LAB_SCHEME=https`.
- Set `LAB_WAF_MODE=On` after checking the edge log for false positives.
- Keep `.env` out of version control; `scripts/init-env.sh` creates it with mode 600.
- The process-agent API is bound to `127.0.0.1` only; publish it through the edge if remote clients need it.

## What has been verified

- `docker compose config` validates the core and all three profiles; every build context exists at the pinned commits.
- The edge configuration passes `apachectl -t` and serves six virtual hosts.
- process-agent against uapf-engine with the example package runs end to end: AI classification with redaction, DMN routing, event emission and a verifiable audit chain.
- A full container build and start of every service has not been run in this repository's CI yet.

## License

Apache-2.0 — see [LICENSE](LICENSE) and [NOTICE](NOTICE). Each component keeps its own licence.
