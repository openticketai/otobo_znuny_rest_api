# REST-API

**Version 1.4.0** · GPL-3.0 · https://www.openticketai.com

Perl package that makes the [otai-ts-connector](https://github.com/openticketai/otai-ts-connector) Python client work against **OTOBO** and **Znuny**. One tree, two Package Manager manifests.

It installs:

1. A restricted API agent (`otai-webservice`, group `ai-agent`). The password is random and is never shown. The account is not in the `users` group, so it cannot sign in to the agent interface.
2. A bearer-token REST API (`otai-api.pl`) and the Admin **API** screen.
3. Admin **Webhooks**: point the package at OTAI. It sends ticket and FAQ event JSON. A Web Service is not required.
4. Admin **API reference**: the OpenAPI page for this system.

Agent UI, reply drafts, and Studio SSO are a separate package and are not in this tree.

## API reference

[Scalar](https://scalar.com) shows the OpenAPI 3.2.1 document inside the ticket system. It loads `scalar.config.json` beside this page. Package Manager links this PDF. The same page is the one to embed in the public documentation.

- **Admin → API reference**
- OTOBO: [http://localhost/otobo/otai-api.pl/v1/docs](http://localhost/otobo/otai-api.pl/v1/docs)
- Znuny: [http://localhost/znuny/otai-api.pl/v1/docs](http://localhost/znuny/otai-api.pl/v1/docs)

Replace `localhost` with the host of the ticket system.

## Manifests

| File                  | System                                | API user          |
| --------------------- | ------------------------------------- | ----------------- |
| `REST-API-OTOBO.sopm` | OTOBO 11.0.x                          | `otai-webservice` |
| `REST-API-Znuny.sopm` | Znuny 7.3 / 7.2 / 7.1 / 7.0 / LTS 6.5 | `otai-webservice` |

Source and releases: https://github.com/openticketai/otobo_znuny_rest_api

## Install

No inbound password is required. Install creates `otai-webservice` when that login is missing, puts it in the **`ai-agent`** group, and removes it from **`users`**. Grant FAQ categories to **`ai-agent`** when that user should read FAQ. Opening Admin → API again removes `users` if someone added it back.

Optional process environment (SysConfig is the admin fallback):

| Variable                     | Default           | Purpose                                      |
| ---------------------------- | ----------------- | -------------------------------------------- |
| `OTAI_TICKETSYSTEM_USERNAME` | `otai-webservice` | API user login                               |
| `OTAI_WEBHOOK_URL`           | _(empty)_         | Where ticket and FAQ events are POSTed       |
| `OTAI_API_TOKEN`             | _(empty)_         | Send-only webhook bearer, if set before boot |

From this directory (OTOBO example; Znuny uses `znuny.Console.pl` and `REST-API-Znuny.sopm`):

```bash
docker cp . otobo-web-1:/tmp/otai-opm
docker exec otobo-web-1 /opt/otobo/bin/otobo.Console.pl \
  Dev::Package::Build --module-directory /tmp/otai-opm \
  /tmp/otai-opm/REST-API-OTOBO.sopm /tmp/otai-out
docker exec otobo-web-1 /opt/otobo/bin/otobo.Console.pl \
  Admin::Package::Install /tmp/otai-out/REST-API-1.4.0.opm
```

Upgrade removes the old Generic Interface webservices `OpenTicketAI`, `OpenTicketAI-RuntimeEvents`, and `OpenTicketAI-SearchEvents` when they are still installed.

### Admin screens

| Screen                    | Who   | What                                                                                                   |
| ------------------------- | ----- | ------------------------------------------------------------------------------------------------------ |
| Admin → **API**           | admin | Create a system user with one token. Each row has its groups, roles, and a button for each.            |
| Admin → **API reference** | admin | Interactive OpenAPI page (Scalar) at [otai-api.pl/v1/docs](http://localhost/otobo/otai-api.pl/v1/docs) |
| Admin → **Webhooks**      | admin | Receiver URL, the four events, send token, and a test POST                                             |

A token is shown once. It is stored as a hash. Queues, groups, roles, and FAQ categories of the bound person decide what a call may do. The webhook token cannot call ticket routes.

SysConfig:

| Setting                                 | Purpose                                     |
| --------------------------------------- | ------------------------------------------- |
| `OpenTicketAIConnector::AgentUserLogin` | API user login                              |
| `OpenTicketAIConnector::AgentEmail`     | API user email                              |
| `OpenTicketAIConnector::ApiEnabled`     | API on/off                                  |
| `OpenTicketAIConnector::TokenTTLHours`  | Lifetime of API, agent, and customer tokens |

### Customer footer

OTOBO customer and public screens show an Open Ticket AI footer by default. Set `OpenTicketAIConnector::CustomerFooter::Enabled` to **No** to hide it.

## REST API

Call the ticket system on an internal URL.

`<host>/<otobo|znuny>/otai-api.pl/v1/...`

`Authorization: Bearer <token>`. JSON only. Interactive docs: `otai-api.pl/v1/docs`. The contract shipped with this package is `var/httpd/htdocs/otai-api/openapi.yaml`.

| Call                                        | Route                               | Method |
| ------------------------------------------- | ----------------------------------- | ------ |
| Ticket list / search                        | `/v1/tickets`                       | GET    |
| One ticket                                  | `/v1/tickets/{id}`                  | GET    |
| Create ticket                               | `/v1/tickets`                       | POST   |
| Update ticket                               | `/v1/tickets/{id}`                  | PATCH  |
| Add article                                 | `/v1/tickets/{id}/articles`         | POST   |
| FAQ list                                    | `/v1/faqs`                          | GET    |
| One FAQ                                     | `/v1/faqs/{id}`                     | GET    |
| Update FAQ                                  | `/v1/faqs/{id}`                     | PATCH  |
| Queues, states, types, services, priorities | `/v1/queues` and the matching names | GET    |
| Dynamic fields                              | `/v1/dynamic-fields`                | GET    |
| Dynamic field values                        | `/v1/dynamic-fields/{name}/values`  | GET    |
| Create dynamic field                        | `/v1/dynamic-fields`                | POST   |
| Agents                                      | `/v1/agents`                        | GET    |
| Customer companies                          | `/v1/customer-companies`            | GET    |
| Customer users                              | `/v1/customer-users`                | GET    |
| Configuration items                         | `/v1/config-items`                  | GET    |
| Agent login                                 | `/v1/auth/agent`                    | POST   |

Agent login sends `login` and `password` (or `PersonLogin` and `PersonPassword`) and receives a bearer token. Later ticket calls use that token. A wrong password is 401.

The Python client accepts a base URL that still ends in `nph-genericinterface.pl` and calls `otai-api.pl` instead. Put the bearer token in the connection password field.

## Webhooks

Admin → **Webhooks** is where you point this package at OTAI. The package sends the event JSON. A Web Service is not required.

The four events are ticket created, ticket field changed (`ticket_attribute_changed`), ticket deleted, and FAQ changed (`faq_changed`). A field change is one POST. The body contains `attribute`. A new article is `notes`. Each POST is JSON plus `Authorization: Bearer <webhook token>`. That token cannot call the API.

**Send test event** posts one sample `ticket_attribute_changed` and shows the HTTP status.

Both OTOBO and Znuny use the event modules below and `Kernel::System::OpenTicketAIConnector::WebhookClient`.

| Module                                             | Events                                                        |
| -------------------------------------------------- | ------------------------------------------------------------- |
| `Kernel::System::Ticket::Event::OTAITicketChanged` | Ticket create, update, delete, and article create/update/send |
| `Kernel::System::FAQ::Event::OTAIFAQChanged`       | FAQ create, update, delete                                    |

If the webhook URL is empty, the client falls back to `OpenTicketAIConnector::RuntimeEventsURL` for tickets and `OpenTicketAIConnector::SearchEventsURL` for FAQ.

## License

GPL-3.0, because this code runs inside OTOBO and Znuny. The Python client in the same GitHub repository is Apache-2.0.
