# --
# OpenTicketAIConnector - German language file.
# --
package Kernel::Language::de_OpenTicketAIConnector;

use strict;
use warnings;
use utf8;

sub Data {
    my $Self = shift;

    my %Lang = (
        'API reference' => 'API-Referenz',
        'API user' => 'API-Benutzer',
        'The API user could not be created.' => 'Der API-Benutzer konnte nicht angelegt werden.',
        'This account is not in the users group. It cannot sign in to the agent interface. A token uses the groups and roles below.' =>
            'Dieses Konto ist nicht in der Gruppe users. Es kann sich nicht an der Agentenoberfläche anmelden. Ein Token nutzt die Gruppen und Rollen unten.',
        'This account is an API user and cannot sign in to the agent interface.' =>
            'Dieses Konto ist ein API-Benutzer und kann sich nicht an der Agentenoberfläche anmelden.',
        'Login' => 'Anmeldung',
        'Name' => 'Name',
        'Email' => 'E-Mail',
        'Groups' => 'Gruppen',
        'Group' => 'Gruppe',
        'Rights' => 'Rechte',
        'No groups yet.' => 'Noch keine Gruppen.',
        'Change groups' => 'Gruppen ändern',
        'Roles' => 'Rollen',
        'Role' => 'Rolle',
        'No roles.' => 'Keine Rollen.',
        'No roles' => 'Keine Rollen',
        'New system user' => 'Neuer Systembenutzer',
        'System users' => 'Systembenutzer',
        'Create system user' => 'Systembenutzer anlegen',
        'No system users yet.' => 'Noch keine Systembenutzer.',
        'No token' => 'Kein Token',
        'The system user could not be created.' => 'Der Systembenutzer konnte nicht angelegt werden.',
        'The system user was created, but the token was not.' => 'Der Systembenutzer wurde angelegt, aber das Token nicht.',
        'A new token creates a system user. That account is not in the users group and cannot sign in. Each system user has one token or none.' =>
            'Ein neues Token legt einen Systembenutzer an. Dieses Konto ist nicht in der Gruppe users und kann sich nicht anmelden. Jeder Systembenutzer hat ein Token oder keines.',
        'No groups' => 'Keine Gruppen',
        'Change roles' => 'Rollen ändern',
        'Tokens' => 'Token',
        'Copy this token now. It is not shown again.' => 'Kopieren Sie dieses Token jetzt. Es wird nicht wieder angezeigt.',
        'On' => 'An',
        'Save' => 'Speichern',
        'Label' => 'Bezeichnung',
        'Hours' => 'Stunden',
        'Valid for' => 'Gültig für',
        '7 days' => '7 Tage',
        '30 days' => '30 Tage',
        '90 days' => '90 Tage',
        '1 year' => '1 Jahr',
        'API on' => 'API an',
        'API off' => 'API aus',
        'Choose how long the token is valid.' => 'Wählen Sie, wie lange das Token gültig ist.',
        'Generate token' => 'Token erzeugen',
        'No tokens yet.' => 'Noch keine Token.',
        'User' => 'Benutzer',
        'Expires' => 'Läuft ab',
        'Last used' => 'Zuletzt benutzt',
        'Never' => 'Nie',
        'Revoke' => 'Widerrufen',
        'Revoked' => 'Widerrufen',
        'Interactive OpenAPI reference for this system.' =>
            'Interaktive OpenAPI-Referenz für dieses System.',
        'Admin screen for the Open Ticket AI OpenAPI reference.' =>
            'Admin-Ansicht für die OpenAPI-Referenz von Open Ticket AI.',
        'Admin overview entry for the OpenAPI reference.' =>
            'Eintrag in der Admin-Übersicht für die OpenAPI-Referenz.',
        'This package sends ticket and FAQ events as JSON. A Web Service is not required for OTAI.' =>
            'Dieses Paket sendet Ticket- und FAQ-Ereignisse als JSON. Für OTAI ist kein Web Service nötig.',
        'Generate webhook token' => 'Webhook-Token erzeugen',
        'Send test event' => 'Test-Ereignis senden',
        'Receiver' => 'Empfänger',
        'Receiver URL' => 'Empfänger-URL',
        'If this URL is empty, ticket events use the Runtime URL and FAQ events use the Search URL.' =>
            'Wenn diese URL leer ist, nutzen Ticket-Ereignisse die Runtime-URL und FAQ-Ereignisse die Search-URL.',
        'Runtime URL' => 'Runtime-URL',
        'Search URL' => 'Search-URL',
        'Ticket created' => 'Ticket erstellt',
        'Ticket field changed' => 'Ticketfeld geändert',
        'Ticket deleted' => 'Ticket gelöscht',
        'FAQ changed' => 'FAQ geändert',
        'One POST per field. The body contains attribute. A new article is notes.' =>
            'Ein POST pro Feld. Der Body enthält attribute. Ein neuer Artikel ist notes.',
        'Example event' => 'Beispiel-Ereignis',
        'Each POST sends Authorization: Bearer and the send token. That token cannot call the API.' =>
            'Jeder POST sendet Authorization: Bearer und das Sende-Token. Dieses Token kann die API nicht aufrufen.',
        'Send token' => 'Sende-Token',
        'A send token is set.' => 'Ein Sende-Token ist gesetzt.',
        'No send token is set. Events are not sent.' =>
            'Kein Sende-Token gesetzt. Ereignisse werden nicht gesendet.',
        'Test POST returned %s.' => 'Test-POST hat %s geliefert.',
        'The test POST failed.' => 'Der Test-POST ist fehlgeschlagen.',
        'No receiver URL' => 'Keine Empfänger-URL',
        'Webhook secret not configured' => 'Webhook-Token ist nicht konfiguriert',
    );

    for my $Key ( keys %Lang ) {
        $Self->{Translation}->{$Key} = $Lang{$Key};
    }
    return 1;
}

1;
