# --
# Kernel/System/OpenTicketAIConnector/Rest.pm
# Copyright (C) Softoft, Tobias A. Bueck
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the GNU General Public License version 3 (GPL-3.0).
# --

package Kernel::System::OpenTicketAIConnector::Rest;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Auth',
    'Kernel::System::JSON',
    'Kernel::System::Log',
    'Kernel::System::Main',
    'Kernel::System::OpenTicketAIConnector::Catalog',
    'Kernel::System::OpenTicketAIConnector::Tickets',
    'Kernel::System::OpenTicketAIConnector::Token',
    'Kernel::System::User',
    'Kernel::System::YAML',
);

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $Method = uc( $ENV{REQUEST_METHOD} || 'GET' );
    my $Path   = $ENV{PATH_INFO} || '';
    if ( !$Path && ( $ENV{REQUEST_URI} || '' ) =~ m{otai-api\.pl/([^?]*)} ) {
        $Path = $1;
    }
    $Path =~ s{^/+}{};
    $Path =~ s{/+$}{};

    if ( $Path eq 'v1/docs' && $Method eq 'GET' ) {
        return $Self->_File( 'docs.html', 'text/html; charset=utf-8' );
    }
    if ( $Path eq 'v1/scalar.js' && $Method eq 'GET' ) {
        return $Self->_File( 'scalar.js', 'application/javascript; charset=utf-8' );
    }
    if ( $Path eq 'v1/scalar.config.json' && $Method eq 'GET' ) {
        return $Self->_File( 'scalar.config.json', 'application/json; charset=utf-8' );
    }
    if ( $Path eq 'v1/openapi.json' && $Method eq 'GET' ) {
        return $Self->_OpenAPI();
    }

    if ( !$Self->_ApiEnabled() ) {
        return $Self->_JSON( 403, { detail => 'API is off.' } );
    }

    my $Query = $Self->_Query();
    my $Body  = $Self->_Body();

    if ( $Method eq 'POST' && $Path eq 'v1/auth/agent' ) {
        return $Self->_Login($Body);
    }

    my $Principal = $Self->_Principal();
    if ( !$Principal ) {
        return $Self->_JSON( 401, { detail => 'Authentication failed.' } );
    }
    if ( ( $Principal->{Kind} || '' ) eq 'webhook' ) {
        return $Self->_JSON( 403, { detail => 'Webhook token cannot call the API.' } );
    }

    my $Catalog = $Kernel::OM->Get('Kernel::System::OpenTicketAIConnector::Catalog');
    my $Tickets = $Kernel::OM->Get('Kernel::System::OpenTicketAIConnector::Tickets');
    my $UserID  = $Principal->{UserID} || 1;

    if ( $Method eq 'GET' && $Path eq 'v1/tickets' ) {
        return $Self->_JSON( 200, $Tickets->Search( $Principal, %{$Query} ) );
    }
    if ( $Method eq 'POST' && $Path eq 'v1/tickets' ) {
        my $Created = $Tickets->Create( $Principal, $Body );
        return $Self->_JSON( 400, { detail => 'Ticket was not created.' } ) if !$Created;
        return $Self->_JSON( 201, $Created );
    }
    if ( $Path =~ m{\Av1/tickets/(\d+)\z} ) {
        my $ID = $1;
        if ( $Method eq 'GET' ) {
            my $Ticket = $Tickets->Get( $Principal, $ID );
            return $Self->_JSON( 404, { detail => 'Ticket not found.' } ) if !$Ticket;
            return $Self->_JSON( 200, $Ticket );
        }
        if ( $Method eq 'PATCH' ) {
            my $Ticket = $Tickets->Update( $Principal, $ID, $Body );
            return $Self->_JSON( 404, { detail => 'Ticket not found.' } ) if !$Ticket;
            return $Self->_JSON( 200, $Ticket );
        }
    }
    if ( $Method eq 'POST' && $Path =~ m{\Av1/tickets/(\d+)/articles\z} ) {
        my $Ticket = $Tickets->AddArticle( $Principal, $1, $Body );
        return $Self->_JSON( 404, { detail => 'Ticket not found.' } ) if !$Ticket;
        return $Self->_JSON( 201, $Ticket );
    }
    if ( $Method eq 'GET' && $Path eq 'v1/faqs' ) {
        return $Self->_JSON( 200, $Catalog->Faqs( %{$Query}, UserID => $UserID ) );
    }
    if ( $Path =~ m{\Av1/faqs/(\d+)\z} ) {
        my $ID = $1;
        if ( $Method eq 'GET' ) {
            return $Self->_JSON( 200, $Catalog->FaqGet( ID => $ID, UserID => $UserID ) );
        }
        if ( $Method eq 'PATCH' ) {
            return $Self->_JSON(
                200,
                $Catalog->FaqUpdate(
                    ID     => $ID,
                    UserID => $UserID,
                    Title  => $Body->{Title},
                    Field1 => $Body->{Field1},
                ),
            );
        }
    }
    if ( $Method eq 'GET' && $Path eq 'v1/queues' ) {
        return $Self->_JSON( 200, $Catalog->Queues() );
    }
    if ( $Method eq 'GET' && $Path eq 'v1/states' ) {
        return $Self->_JSON( 200, $Catalog->States() );
    }
    if ( $Method eq 'GET' && $Path eq 'v1/types' ) {
        return $Self->_JSON( 200, $Catalog->Types() );
    }
    if ( $Method eq 'GET' && $Path eq 'v1/services' ) {
        return $Self->_JSON( 200, $Catalog->Services( UserID => $UserID ) );
    }
    if ( $Method eq 'GET' && $Path eq 'v1/priorities' ) {
        return $Self->_JSON( 200, $Catalog->Priorities() );
    }
    if ( $Method eq 'GET' && $Path eq 'v1/dynamic-fields' ) {
        return $Self->_JSON( 200, $Catalog->DynamicFields() );
    }
    if ( $Method eq 'POST' && $Path eq 'v1/dynamic-fields' ) {
        my $Created = $Catalog->CreateDynamicField(
            %{$Body},
            UserID => $UserID,
        );
        return $Self->_JSON( 400, { detail => 'Dynamic field was not created.' } ) if !$Created;
        return $Self->_JSON( 201, $Created );
    }
    if ( $Method eq 'GET' && $Path =~ m{\Av1/dynamic-fields/([^/]+)/values\z} ) {
        return $Self->_JSON( 200, $Catalog->DynamicFieldValues( Name => $1 ) );
    }
    if ( $Method eq 'GET' && $Path eq 'v1/agents' ) {
        return $Self->_JSON( 200, $Catalog->Agents() );
    }
    if ( $Method eq 'GET' && $Path eq 'v1/customer-companies' ) {
        return $Self->_JSON( 200, $Catalog->CustomerCompanies() );
    }
    if ( $Method eq 'GET' && $Path eq 'v1/customer-users' ) {
        return $Self->_JSON( 200, $Catalog->CustomerUsers() );
    }
    if ( $Method eq 'GET' && $Path eq 'v1/config-items' ) {
        my $Items = $Catalog->ConfigItems( UserID => $UserID );
        return $Self->_JSON( 501, { detail => 'CMDB is not installed.' } ) if !$Items;
        return $Self->_JSON( 200, $Items );
    }

    return $Self->_JSON( 404, { detail => 'Not found.' } );
}

sub _ApiEnabled {
    my ( $Self, %Param ) = @_;

    my $Value = $Kernel::OM->Get('Kernel::Config')->Get('OpenTicketAIConnector::ApiEnabled');
    return 1 if !defined $Value || $Value eq '';
    return 0 if $Value eq '0';
    return 1;
}

sub _Principal {
    my ( $Self, %Param ) = @_;

    my $Header = $ENV{HTTP_AUTHORIZATION} || '';
    my ($Token) = $Header =~ m{\ABearer\s+(\S+)}i;
    return if !$Token;
    return $Kernel::OM->Get('Kernel::System::OpenTicketAIConnector::Token')->Verify(
        Token => $Token,
    );
}

sub _Login {
    my ( $Self, $Body ) = @_;

    $Body ||= {};
    my $Login = $Body->{login} || $Body->{PersonLogin} || '';
    my $Password = $Body->{password} || $Body->{PersonPassword} || '';
    $Login =~ s{^\s+|\s+$}{}g;
    return $Self->_JSON( 401, { detail => 'Authentication failed.' } ) if $Login eq '' || $Password eq '';

    my $TokenObject = $Kernel::OM->Get('Kernel::System::OpenTicketAIConnector::Token');
    my $Hours       = $TokenObject->TTLHours();
    return $Self->_JSON( 500, { detail => 'Token TTL is not configured.' } ) if !$Hours;

    my $User = $Kernel::OM->Get('Kernel::System::Auth')->Auth(
        User => $Login,
        Pw   => $Password,
    );
    return $Self->_JSON( 401, { detail => 'Authentication failed.' } ) if !$User;
    my $UserID = $Kernel::OM->Get('Kernel::System::User')->UserLookup( UserLogin => $User );
    return $Self->_JSON( 401, { detail => 'Authentication failed.' } ) if !$UserID;
    my $Issued = $TokenObject->Issue(
        Kind      => 'agent',
        Label     => $User,
        UserID    => $UserID,
        ExpiresAt => $TokenObject->ExpiresFromHours($Hours),
    );
    return $Self->_JSON( 500, { detail => 'Token was not created.' } ) if !$Issued;
    return $Self->_JSON(
        200,
        {
            token      => $Issued->{Token},
            SessionID  => $Issued->{Token},
            UserID     => $UserID . '',
            UserLogin  => $User,
            CustomerID => '',
            Role       => 'agent',
            expires_at => $Issued->{ExpiresAt},
        },
    );
}

sub _Query {
    my ( $Self, %Param ) = @_;

    my %Query;
    for my $Pair ( split /&/, $ENV{QUERY_STRING} || '' ) {
        my ( $Key, $Value ) = split /=/, $Pair, 2;
        next if !defined $Key || $Key eq '';
        $Value //= '';
        for ( $Key, $Value ) {
            tr/+/ /;
            s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
        }
        $Query{$Key} = $Value;
    }
    return \%Query;
}

sub _Body {
    my ( $Self, %Param ) = @_;

    my $Length = $ENV{CONTENT_LENGTH} || 0;
    return {} if !$Length;
    my $Raw = '';
    read STDIN, $Raw, $Length;
    return {} if $Raw eq '';
    my $Data = eval {
        $Kernel::OM->Get('Kernel::System::JSON')->Decode( Data => $Raw );
    };
    return {} if !$Data || ref $Data ne 'HASH';
    return $Data;
}

sub _JSON {
    my ( $Self, $Status, $Data ) = @_;

    my $JSON = $Kernel::OM->Get('Kernel::System::JSON')->Encode( Data => $Data );
    print "Status: $Status\r\n";
    print "Content-Type: application/json; charset=utf-8\r\n";
    print "\r\n";
    print $JSON;
    return 1;
}

sub _Home {
    my ( $Self, %Param ) = @_;

    return $Kernel::OM->Get('Kernel::Config')->Get('Home');
}

sub _File {
    my ( $Self, $Name, $Type ) = @_;

    my $Path = $Self->_Home() . '/var/httpd/htdocs/otai-api/' . $Name;
    my $Content = $Kernel::OM->Get('Kernel::System::Main')->FileRead(
        Location => $Path,
        Mode     => 'utf8',
    );
    if ( !$Content ) {
        return $Self->_JSON( 404, { detail => 'File not found.' } );
    }
    print "Status: 200\r\n";
    print "Content-Type: $Type\r\n";
    print "\r\n";
    print ${$Content};
    return 1;
}

sub _OpenAPI {
    my ( $Self, %Param ) = @_;

    my $Path = $Self->_Home() . '/var/httpd/htdocs/otai-api/openapi.yaml';
    my $Content = $Kernel::OM->Get('Kernel::System::Main')->FileRead(
        Location => $Path,
        Mode     => 'utf8',
    );
    if ( !$Content ) {
        return $Self->_JSON( 404, { detail => 'OpenAPI document not found.' } );
    }
    my $Data = $Kernel::OM->Get('Kernel::System::YAML')->Load( Data => ${$Content} );
    return $Self->_JSON( 200, $Data || {} );
}

1;
