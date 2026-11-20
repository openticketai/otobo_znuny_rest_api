# --
# Kernel/System/OpenTicketAIConnector/Token.pm
# Copyright (C) Softoft, Tobias A. Bueck
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the GNU General Public License version 3 (GPL-3.0).
# --

package Kernel::System::OpenTicketAIConnector::Token;

use strict;
use warnings;

use Digest::SHA qw(sha256_hex);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::Main',
);

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Issue {
    my ( $Self, %Param ) = @_;

    my $Kind = $Param{Kind} || '';
    return if $Kind !~ m{\A(?:api|agent|customer|webhook)\z};

    my $Label = $Param{Label} || '';
    $Label =~ s{^\s+|\s+$}{}g;
    return if $Label eq '';

    my $ExpiresAt = $Param{ExpiresAt};
    if ( $Kind ne 'webhook' ) {
        return if !defined $ExpiresAt || $ExpiresAt !~ m{\A\d+\z};
    }

    my $Raw = $Kernel::OM->Get('Kernel::System::Main')->GenerateRandomString(
        Length => 48,
    );
    return if !$Raw;

    my $Hash     = sha256_hex($Raw);
    my $Now      = time();
    my $LastUsed = 0;
    my $Revoked  = 0;
    my $UserID = $Param{UserID} || 0;
    if ( $Kind eq 'api' ) {
        return if !$UserID;
        my $Existing = $Self->List(
            Kind   => 'api',
            UserID => $UserID,
        );
        for my $Row ( @{ $Existing || [] } ) {
            return if !$Row->{Revoked};
        }
    }
    my $Login    = $Param{CustomerUserLogin} || '';
    my $Expiry   = $ExpiresAt || 0;
    my $OK       = $Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => 'INSERT INTO otai_api_token '
            . '(user_id, customer_user_login, label, kind, token_hash, expires_at, created_at, last_used_at, revoked) '
            . 'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        Bind => [
            \$UserID, \$Login, \$Label, \$Kind, \$Hash,
            \$Expiry, \$Now, \$LastUsed, \$Revoked,
        ],
    );
    return if !$OK;

    return {
        Token     => $Raw,
        ExpiresAt => $ExpiresAt,
        Kind      => $Kind,
        Label     => $Label,
    };
}

sub Verify {
    my ( $Self, %Param ) = @_;

    my $Raw = $Param{Token} || '';
    return if $Raw eq '';

    my $Hash = sha256_hex($Raw);
    my $DB   = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DB->Prepare(
        SQL => 'SELECT id, user_id, customer_user_login, kind, expires_at, revoked '
            . 'FROM otai_api_token WHERE token_hash = ?',
        Bind  => [ \$Hash ],
        Limit => 1,
    );

    my @Row = $DB->FetchrowArray();
    return if !@Row;
    return if $Row[5];

    my $ExpiresAt = $Row[4] || 0;
    if ( $ExpiresAt > 0 && $ExpiresAt < time() ) {
        return;
    }

    my $ID  = $Row[0];
    my $Now = time();
    $DB->Do(
        SQL  => 'UPDATE otai_api_token SET last_used_at = ? WHERE id = ?',
        Bind => [ \$Now, \$ID ],
    );

    return {
        ID                 => $ID,
        UserID             => $Row[1],
        CustomerUserLogin  => $Row[2] || '',
        Kind               => $Row[3] || '',
    };
}

sub List {
    my ( $Self, %Param ) = @_;

    my $SQL  = 'SELECT id, user_id, customer_user_login, label, kind, expires_at, created_at, last_used_at, revoked '
        . 'FROM otai_api_token WHERE 1=1';
    my @Bind;
    if ( $Param{Kind} ) {
        $SQL .= ' AND kind = ?';
        push @Bind, \$Param{Kind};
    }
    if ( $Param{UserID} ) {
        $SQL .= ' AND user_id = ?';
        push @Bind, \$Param{UserID};
    }
    $SQL .= ' ORDER BY id DESC';

    my $DB = $Kernel::OM->Get('Kernel::System::DB');
    return [] if !$DB->Prepare(
        SQL  => $SQL,
        Bind => \@Bind,
    );

    my @Rows;
    while ( my @Row = $DB->FetchrowArray() ) {
        push @Rows, {
            ID                => $Row[0],
            UserID            => $Row[1],
            CustomerUserLogin => $Row[2] || '',
            Label             => $Row[3] || '',
            Kind              => $Row[4] || '',
            ExpiresAt         => $Row[5],
            CreatedAt         => $Row[6],
            LastUsedAt        => $Row[7],
            Revoked           => $Row[8] ? 1 : 0,
        };
    }
    return \@Rows;
}

sub Revoke {
    my ( $Self, %Param ) = @_;

    my $ID = $Param{ID} || return;
    my $SQL = 'UPDATE otai_api_token SET revoked = 1 WHERE id = ?';
    my @Bind = ( \$ID );
    if ( $Param{UserID} ) {
        $SQL .= ' AND user_id = ?';
        push @Bind, \$Param{UserID};
    }
    return $Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL  => $SQL,
        Bind => \@Bind,
    );
}

sub TTLHours {
    my ( $Self, %Param ) = @_;

    my $Hours = $Kernel::OM->Get('Kernel::Config')->Get('OpenTicketAIConnector::TokenTTLHours');
    return if !defined $Hours || $Hours !~ m{\A\d+\z} || $Hours < 1;
    return $Hours;
}

sub ExpiresFromHours {
    my ( $Self, $Hours ) = @_;

    return if !defined $Hours || $Hours !~ m{\A\d+\z} || $Hours < 1;
    return time() + ( $Hours * 3600 );
}

sub ExpiresFromChoice {
    my ( $Self, $Choice ) = @_;

    return 0 if defined $Choice && $Choice eq 'never';

    my %Hours = (
        '7d'  => 24 * 7,
        '30d' => 24 * 30,
        '90d' => 24 * 90,
        '1y'  => 24 * 365,
    );
    return if !defined $Choice || !exists $Hours{$Choice};
    return $Self->ExpiresFromHours( $Hours{$Choice} );
}

1;
