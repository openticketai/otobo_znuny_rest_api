# --
# Kernel/System/OpenTicketAIConnector/Tickets.pm
# Copyright (C) Softoft, Tobias A. Bueck
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the GNU General Public License version 3 (GPL-3.0).
# --

package Kernel::System::OpenTicketAIConnector::Tickets;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::CustomerUser',
    'Kernel::System::Log',
    'Kernel::System::Ticket',
    'Kernel::System::User',
);

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub _Customer {
    my ( $Self, $Principal ) = @_;

    return ( $Principal->{Kind} || '' ) eq 'customer';
}

sub _MayRead {
    my ( $Self, $Principal, $TicketID ) = @_;

    return 0 if !$TicketID;
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    if ( $Self->_Customer($Principal) ) {
        my %Ticket = $TicketObject->TicketGet(
            TicketID => $TicketID,
            UserID   => 1,
        );
        return 0 if !%Ticket;
        my $Login = $Principal->{CustomerUserLogin} || '';
        return ( $Ticket{CustomerUserID} && $Ticket{CustomerUserID} eq $Login ) ? 1 : 0;
    }
    return $TicketObject->TicketPermission(
        Type     => 'ro',
        TicketID => $TicketID,
        UserID   => $Principal->{UserID},
    ) ? 1 : 0;
}

sub _Summary {
    my ( $Self, %Ticket ) = @_;

    my $QueueID = $Ticket{QueueID} || 0;
    my $StateID = $Ticket{StateID} || 0;
    my $PrioID  = $Ticket{PriorityID} || 0;
    return {
        TicketID     => ( $Ticket{TicketID} || '' ) . '',
        TicketNumber => $Ticket{TicketNumber} || '',
        Title        => $Ticket{Title} || '',
        State        => $Ticket{State} || '',
        Queue        => $Ticket{Queue} || '',
        Priority     => $Ticket{Priority} || '',
        Type         => $Ticket{Type} || '',
        Service      => $Ticket{Service} || '',
        CustomerUser => $Ticket{CustomerUserID} || '',
        Owner        => $Ticket{Owner} || '',
        Created      => $Ticket{Created} || '',
        Changed      => $Ticket{Changed} || '',
        id           => ( $Ticket{TicketID} || 0 ) + 0,
        title        => $Ticket{Title} || '',
        state        => { id => $StateID + 0, name => $Ticket{State} || '' },
        queue        => { id => $QueueID + 0, name => $Ticket{Queue} || '' },
        priority     => { id => $PrioID + 0, name => $Ticket{Priority} || '' },
    };
}

sub _ArticleVisible {
    my ( $Self, %Article ) = @_;

    if ( defined $Article{IsVisibleForCustomer} && !$Article{IsVisibleForCustomer} ) {
        return 0;
    }
    return 0 if ( $Article{ArticleType} || '' ) eq 'note-internal';
    return 1;
}

sub _Articles {
    my ( $Self, $TicketID, $Principal ) = @_;

    my @Out;
    my $ArticleObject = eval { $Kernel::OM->Get('Kernel::System::Ticket::Article') };
    my @Raw;
    if ( $ArticleObject && $ArticleObject->can('ArticleList') ) {
        my @List = $ArticleObject->ArticleList( TicketID => $TicketID );
        for my $Item (@List) {
            next if ref $Item ne 'HASH';
            my $Backend = $ArticleObject->BackendForArticle( %{$Item} );
            next if !$Backend;
            my %Article = $Backend->ArticleGet(
                %{$Item},
                DynamicFields => 0,
            );
            push @Raw, \%Article if %Article;
        }
    }
    else {
        @Raw = $Kernel::OM->Get('Kernel::System::Ticket')->ArticleGet(
            TicketID => $TicketID,
            UserID   => 1,
        );
    }

    for my $Article (@Raw) {
        next if ref $Article ne 'HASH';
        next if $Self->_Customer($Principal) && !$Self->_ArticleVisible( %{$Article} );
        my $ID = $Article->{ArticleID} || 0;
        push @Out, {
            ArticleID            => $ID . '',
            Subject              => $Article->{Subject} || '',
            Body                 => $Article->{Body} || '',
            From                 => $Article->{From} || '',
            SenderType           => $Article->{SenderType} || '',
            Created              => $Article->{CreateTime} || $Article->{Created} || '',
            IsVisibleForCustomer => $Self->_ArticleVisible( %{$Article} ) ? 1 : 0,
            article_id           => $ID + 0,
            subject              => $Article->{Subject} || '',
            body                 => $Article->{Body} || '',
        };
    }
    return \@Out;
}

sub _Load {
    my ( $Self, $TicketID, $Principal ) = @_;

    return if !$Self->_MayRead( $Principal, $TicketID );
    my %Ticket = $Kernel::OM->Get('Kernel::System::Ticket')->TicketGet(
        TicketID      => $TicketID,
        UserID        => 1,
        DynamicFields => 0,
    );
    return if !%Ticket;
    my $Summary = $Self->_Summary(%Ticket);
    $Summary->{Article}  = $Self->_Articles( $TicketID, $Principal );
    $Summary->{articles} = $Summary->{Article};
    return $Summary;
}

sub Search {
    my ( $Self, $Principal, %Param ) = @_;

    my $Limit = $Param{limit} || $Param{Limit} || 50;
    $Limit = 50 if $Limit !~ m{\A\d+\z} || $Limit < 1 || $Limit > 200;

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my %Search       = (
        Result => 'ARRAY',
        Limit  => $Limit,
    );
    if ( $Self->_Customer($Principal) ) {
        my $Login = $Principal->{CustomerUserLogin} || '';
        %Search = (
            %Search,
            CustomerUserLogin => $Login,
            CustomerUserID    => $Login,
            UserID            => 1,
            Permission        => 'ro',
        );
    }
    else {
        %Search = (
            %Search,
            UserID     => $Principal->{UserID},
            Permission => 'ro',
        );
        $Search{Queues}     = [ $Param{queue} ]     if $Param{queue};
        $Search{States}     = [ $Param{state} ]     if $Param{state};
        $Search{Priorities} = [ $Param{priority} ]  if $Param{priority};
        $Search{Types}      = [ $Param{type} ]      if $Param{type};
    }

    my @IDs = $TicketObject->TicketSearch(%Search);
    my @Tickets;
    for my $TicketID (@IDs) {
        my $Row = $Self->_Load( $TicketID, $Principal );
        push @Tickets, $Row if $Row;
    }
    return { Ticket => \@Tickets };
}

sub Get {
    my ( $Self, $Principal, $TicketID ) = @_;

    return $Self->_Load( $TicketID, $Principal );
}

sub _AddArticle {
    my ( $Self, %Param ) = @_;

    my $SenderType = $Param{SenderType} || 'agent';
    my %Common     = (
        TicketID             => $Param{TicketID},
        SenderType           => $SenderType,
        From                 => $Param{From} || $SenderType,
        Subject              => $Param{Subject} || 'API',
        Body                 => $Param{Body} || '',
        ContentType          => $Param{ContentType} || 'text/plain; charset=utf-8',
        HistoryType          => 'AddNote',
        HistoryComment       => 'OTAI API',
        UserID               => $Param{UserID} || 1,
        IsVisibleForCustomer => 1,
        Charset              => 'utf-8',
        MimeType             => 'text/plain',
    );
    my $ArticleObject = eval { $Kernel::OM->Get('Kernel::System::Ticket::Article') };
    if ( $ArticleObject && $ArticleObject->can('BackendForChannel') ) {
        my $Channel = $SenderType eq 'customer' ? 'Email' : 'Internal';
        my $Backend = $ArticleObject->BackendForChannel( ChannelName => $Channel );
        return $Backend->ArticleCreate(%Common) if $Backend;
    }
    return $Kernel::OM->Get('Kernel::System::Ticket')->ArticleCreate(
        %Common,
        ArticleType => $SenderType eq 'customer' ? 'webrequest' : 'note-external',
    );
}

sub Create {
    my ( $Self, $Principal, $Data ) = @_;

    $Data ||= {};
    my $Ticket = $Data->{Ticket} || $Data;
    my $Article = $Data->{Article} || $Ticket->{article} || {};
    my $Title = $Ticket->{Title} || $Ticket->{title} || '';
    return if $Title eq '';

    my $UserID = $Principal->{UserID} || 1;
    my $CustomerUser = $Ticket->{CustomerUser} || $Ticket->{customer_user} || '';
    if ( $Self->_Customer($Principal) ) {
        $CustomerUser = $Principal->{CustomerUserLogin} || $CustomerUser;
        $UserID       = 1;
    }

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $TicketID     = $TicketObject->TicketCreate(
        Title        => $Title,
        Queue        => $Ticket->{Queue} || $Ticket->{queue} || 'Raw',
        Lock         => 'unlock',
        Priority     => $Ticket->{Priority} || $Ticket->{priority} || '3 normal',
        State        => $Ticket->{State} || $Ticket->{state} || 'new',
        CustomerUser => $CustomerUser,
        OwnerID      => 1,
        UserID       => $UserID,
    );
    return if !$TicketID;

    my $Body = $Article->{Body} || $Article->{body} || '';
    if ( $Body ne '' ) {
        $Self->_AddArticle(
            TicketID   => $TicketID,
            Subject    => $Article->{Subject} || $Article->{subject} || $Title,
            Body       => $Body,
            SenderType => $Self->_Customer($Principal) ? 'customer' : ( $Article->{sender_type} || 'agent' ),
            UserID     => $UserID,
            ContentType => $Article->{content_type} || 'text/plain; charset=utf-8',
        );
    }
    return $Self->_Load( $TicketID, $Principal );
}

sub Update {
    my ( $Self, $Principal, $TicketID, $Data ) = @_;

    return if !$Self->_MayRead( $Principal, $TicketID );
    $Data ||= {};
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $UserID = $Self->_Customer($Principal) ? 1 : ( $Principal->{UserID} || 1 );

    my $State = $Data->{state} || $Data->{State} || '';
    if ( $State ne '' ) {
        $TicketObject->TicketStateSet(
            State    => $State,
            TicketID => $TicketID,
            UserID   => $UserID,
        );
    }
    my $Queue = $Data->{queue} || $Data->{Queue} || '';
    if ( $Queue ne '' && !$Self->_Customer($Principal) ) {
        $TicketObject->TicketQueueSet(
            Queue    => $Queue,
            TicketID => $TicketID,
            UserID   => $UserID,
        );
    }
    my $Title = $Data->{title} || $Data->{Title} || '';
    if ( $Title ne '' && !$Self->_Customer($Principal) ) {
        $TicketObject->TicketTitleUpdate(
            Title    => $Title,
            TicketID => $TicketID,
            UserID   => $UserID,
        );
    }
    my $Priority = $Data->{priority} || $Data->{Priority} || '';
    if ( $Priority ne '' && !$Self->_Customer($Principal) ) {
        $TicketObject->TicketPrioritySet(
            Priority => $Priority,
            TicketID => $TicketID,
            UserID   => $UserID,
        );
    }
    return $Self->_Load( $TicketID, $Principal );
}

sub AddArticle {
    my ( $Self, $Principal, $TicketID, $Data ) = @_;

    return if !$Self->_MayRead( $Principal, $TicketID );
    $Data ||= {};
    my $UserID = $Self->_Customer($Principal) ? 1 : ( $Principal->{UserID} || 1 );
    $Self->_AddArticle(
        TicketID    => $TicketID,
        Subject     => $Data->{subject} || $Data->{Subject} || 'API',
        Body        => $Data->{body} || $Data->{Body} || '',
        SenderType  => $Self->_Customer($Principal) ? 'customer' : 'agent',
        UserID      => $UserID,
        ContentType => $Data->{content_type} || 'text/plain; charset=utf-8',
    );
    return $Self->_Load( $TicketID, $Principal );
}

1;
