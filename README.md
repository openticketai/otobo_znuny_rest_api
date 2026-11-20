# REST-API

GPL-3.0 package for Znuny and OTOBO. After install, Admin has **API**, **API reference**, and **Webhooks**. The Python client is [otai-ts-connector](https://github.com/openticketai/otai-ts-connector). Source: https://github.com/openticketai/otobo_znuny_rest_api

Install docs (also shown in Package Manager): [doc/en/OpenTicketAIConnector.pdf](doc/en/OpenTicketAIConnector.pdf) · [doc/de/OpenTicketAIConnector.pdf](doc/de/OpenTicketAIConnector.pdf). Source: [doc/en/OpenTicketAIConnector.md](doc/en/OpenTicketAIConnector.md) · [doc/de/OpenTicketAIConnector.md](doc/de/OpenTicketAIConnector.md).

The package provides:

- Bearer-token REST API at `otai-api.pl/v1` (tickets, FAQ, catalogues, agents, customer companies, customer users, configuration items, agent login)
- API user `otai-webservice` (not in the `users` group, cannot sign in) and per-agent tokens. Rights are the bound person's queues, groups, roles, and FAQ categories
- Admin **Webhooks** screen: point the package at OTAI. It sends ticket and FAQ event JSON. A Web Service is not required
- Scalar OpenAPI 3.2.1 reference at `otai-api.pl/v1/docs` (`scalar.config.json`), also under Admin → **API reference**

Event listeners on both systems call `WebhookClient` and POST JSON with `Authorization: Bearer`.

Manifests: `REST-API-OTOBO.sopm`, `REST-API-Znuny.sopm`.

Agent UI, reply drafts, and Studio SSO stay in the separate `OpenTicketAI` package (`ticket-ai/znuny-otobo`), which requires this one.

## Tests

Live HTTP checks for this API ship with the Python client [otai-ts-connector](https://github.com/openticketai/otai-ts-connector).
