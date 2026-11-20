# REST-API

**Version 1.4.0** · GPL-3.0 · https://www.openticketai.com

Perl-Paket, damit der Python-Client [otai-ts-connector](https://github.com/openticketai/otai-ts-connector) gegen **OTOBO** und **Znuny** funktioniert. Ein Baum, zwei Package-Manager-Manifeste.

Es installiert:

1. Einen eingeschränkten API-Agenten (`otai-webservice`, Gruppe `ai-agent`). Das Passwort ist zufällig und wird nicht angezeigt. Das Konto ist nicht in der Gruppe `users` und kann sich nicht an der Agentenoberfläche anmelden.
2. Eine REST-API mit Bearer-Token (`otai-api.pl`) und die Admin-Ansicht **API**.
3. Die Admin-Ansicht **Webhooks**: das Paket auf OTAI zeigen. Es sendet Ticket- und FAQ-Ereignisse als JSON. Ein Web Service ist nicht nötig.
4. Die Admin-Ansicht **API-Referenz**: die OpenAPI-Seite dieses Systems.

Agenten-Oberfläche, Antwortentwürfe und Studio-SSO sind ein separates Paket und liegen nicht in diesem Baum.

## API-Referenz

[Scalar](https://scalar.com) zeigt das OpenAPI-3.2.1-Dokument im Ticketsystem. Es lädt `scalar.config.json` neben dieser Seite. Der Package Manager verlinkt dieses PDF. Dieselbe Seite wird in der öffentlichen Dokumentation eingebettet.

- **Admin → API-Referenz**
- OTOBO: [http://localhost/otobo/otai-api.pl/v1/docs](http://localhost/otobo/otai-api.pl/v1/docs)
- Znuny: [http://localhost/znuny/otai-api.pl/v1/docs](http://localhost/znuny/otai-api.pl/v1/docs)

`localhost` durch den Host des Ticketsystems ersetzen.

## Manifeste

| Datei                 | System                                | API-Agent         |
| --------------------- | ------------------------------------- | ----------------- |
| `REST-API-OTOBO.sopm` | OTOBO 11.0.x                          | `otai-webservice` |
| `REST-API-Znuny.sopm` | Znuny 7.3 / 7.2 / 7.1 / 7.0 / LTS 6.5 | `otai-webservice` |

Quelltext und Releases: https://github.com/openticketai/otobo_znuny_rest_api

## Installation

Ein eingehendes Passwort ist nicht nötig. Die Installation legt `otai-webservice` an, wenn dieser Login fehlt, setzt ihn in die Gruppe **`ai-agent`** und nimmt ihn aus **`users`**. FAQ-Kategorien dieser Gruppe freigeben, wenn der Benutzer FAQ lesen soll. Admin → API entfernt `users` erneut, falls jemand die Gruppe wieder gesetzt hat.

Optionale Prozessumgebung (SysConfig ist der Admin-Fallback):

| Variable                     | Standard          | Zweck                                                 |
| ---------------------------- | ----------------- | ----------------------------------------------------- |
| `OTAI_TICKETSYSTEM_USERNAME` | `otai-webservice` | Login des API-Benutzers                               |
| `OTAI_WEBHOOK_URL`           | _(leer)_          | Ziel der Ticket- und FAQ-Ereignisse                   |
| `OTAI_API_TOKEN`             | _(leer)_          | Sende-Token des Webhooks, falls vor dem Start gesetzt |

Ein Upgrade entfernt die alten Generic-Interface-Webservices `OpenTicketAI`, `OpenTicketAI-RuntimeEvents` und `OpenTicketAI-SearchEvents`, wenn sie noch installiert sind.

## Admin

| Ansicht                  | Wer   | Inhalt                                                                                                     |
| ------------------------ | ----- | ---------------------------------------------------------------------------------------------------------- |
| Admin → **API**          | Admin | Legt einen Systembenutzer mit einem Token an. Jede Zeile zeigt Gruppen und Rollen und hat je einen Button. |
| Admin → **API-Referenz** | Admin | Interaktive OpenAPI-Seite (Scalar) unter [otai-api.pl/v1/docs](http://localhost/otobo/otai-api.pl/v1/docs) |
| Admin → **Webhooks**     | Admin | Empfänger-URL, die vier Ereignisse, Sende-Token und ein Test-POST                                          |

Ein Token wird einmal angezeigt und als Hash gespeichert. Queues, Gruppen, Rollen und FAQ-Kategorien der gebundenen Person gelten. Das Webhook-Token kann keine Ticket-Routen aufrufen.

## REST-API

`<host>/<otobo|znuny>/otai-api.pl/v1/...`

`Authorization: Bearer <token>`. Nur JSON. Interaktive Doku: `otai-api.pl/v1/docs`.

Portal-Login sendet `login` und `password` und erhält ein Bearer-Token. Weitere Ticket-Aufrufe nutzen dieses Token. Ein falsches Passwort ist 401.

Der Python-Client schreibt das Bearer-Token in das Passwortfeld der Verbindung. Eine Basis-URL, die noch auf `nph-genericinterface.pl` endet, wird auf `otai-api.pl` umgesetzt.

## Webhooks

Admin → **Webhooks** zeigt das Paket auf OTAI. Das Paket sendet das Ereignis-JSON. Ein Web Service ist nicht nötig.

Die vier Ereignisse sind Ticket erstellt, Ticketfeld geändert (`ticket_attribute_changed`), Ticket gelöscht und FAQ geändert (`faq_changed`). Eine Feldänderung ist ein POST. Der Body enthält `attribute`. Ein neuer Artikel ist `notes`. Jeder POST ist JSON plus `Authorization: Bearer <webhook token>`. Dieses Token kann die API nicht aufrufen.

**Test-Ereignis senden** schickt ein Beispiel `ticket_attribute_changed` und zeigt den HTTP-Status.

OTOBO und Znuny nutzen dieselben Event-Module und `WebhookClient`.

Wenn die Webhook-URL leer ist, nutzt der Client `OpenTicketAIConnector::RuntimeEventsURL` für Tickets und `OpenTicketAIConnector::SearchEventsURL` für FAQ.

## Lizenz

GPL-3.0, weil dieser Code in OTOBO und Znuny läuft. Der Python-Client im selben Repository ist Apache-2.0.
