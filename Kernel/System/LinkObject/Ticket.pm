# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::LinkObject::Ticket;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Config',
    'Log',
    'Ticket',
);

=head1 NAME

Kernel::System::LinkObject::Ticket

=head1 SYNOPSIS

Ticket backend for the ticket link object.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $LinkObjectTicketObject = $Kernel::OM->Get('LinkObject::Ticket');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item LinkListWithData()

fill up the link list with data

    $Success = $LinkObjectBackend->LinkListWithData(
        LinkList                     => $HashRef,
        IgnoreLinkedTicketStateTypes => 0|1,        # (optional) default 0
        UserID                       => 1,
    );

=cut

sub LinkListWithData {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(LinkList UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # check link list
    if ( ref $Param{LinkList} ne 'HASH' ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'LinkList must be a hash reference!',
        );
        return;
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Ticket');

    # get config, which ticket state types should not be included in linked tickets overview
    my @IgnoreLinkedTicketStateTypes = @{
        $Kernel::OM->Get('Config')->Get('LinkObject::IgnoreLinkedTicketStateTypes')
            // []
    };

    my %IgnoreLinkTicketStateTypesHash;
    map { $IgnoreLinkTicketStateTypesHash{$_}++ } @IgnoreLinkedTicketStateTypes;

    for my $LinkType ( sort keys %{ $Param{LinkList} } ) {

        for my $Direction ( sort keys %{ $Param{LinkList}->{$LinkType} } ) {

            TICKETID:
            for my $TicketID ( sort keys %{ $Param{LinkList}->{$LinkType}->{$Direction} } ) {

                # get ticket data
                my %TicketData = $TicketObject->TicketGet(
                    TicketID      => $TicketID,
                    UserID        => $Param{UserID},
                    DynamicFields => 0,
                );

                # remove id from hash if ticket can not get
                if ( !%TicketData ) {
                    delete $Param{LinkList}->{$LinkType}->{$Direction}->{$TicketID};
                    next TICKETID;
                }

                # if param is set, remove entries from hash with configured ticket state types
                if (
                    $Param{IgnoreLinkedTicketStateTypes}
                    && $IgnoreLinkTicketStateTypesHash{ $TicketData{StateType} }
                    )
                {
                    delete $Param{LinkList}->{$LinkType}->{$Direction}->{$TicketID};
                    next TICKETID;
                }

                # add ticket data
                $Param{LinkList}->{$LinkType}->{$Direction}->{$TicketID} = \%TicketData;
            }
        }
    }

    return 1;
}

=item ObjectDescriptionGet()

return a hash of object descriptions

Return
    %Description = (
        Normal => "Ticket# 1234455",
        Long   => "Ticket# 1234455: The Ticket Title",
    );

    %Description = $LinkObject->ObjectDescriptionGet(
        Key     => 123,
        Mode    => 'Temporary',  # (optional)
        UserID  => 1,
    );

=cut

sub ObjectDescriptionGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Object Key UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # create description
    my %Description = (
        Normal => 'Ticket',
        Long   => 'Ticket',
    );

    return %Description if $Param{Mode} && $Param{Mode} eq 'Temporary';

    # get ticket
    my %Ticket = $Kernel::OM->Get('Ticket')->TicketGet(
        TicketID      => $Param{Key},
        UserID        => $Param{UserID},
        DynamicFields => 0,
    );

    return if !%Ticket;

    my $ParamHook = $Kernel::OM->Get('Config')->Get('Ticket::Hook') || 'Ticket#';
    $ParamHook .= $Kernel::OM->Get('Config')->Get('Ticket::HookDivider');

    # create description
    %Description = (
        Normal => $ParamHook . "$Ticket{TicketNumber}",
        Long   => $ParamHook . "$Ticket{TicketNumber}: $Ticket{Title}",
    );

    return %Description;
}

=item ObjectSearch()

return a hash list of the search results

Return
    $SearchList = {
        NOTLINKED => {
            Source => {
                12  => $DataOfItem12,
                212 => $DataOfItem212,
                332 => $DataOfItem332,
            },
        },
    };

    $SearchList = $LinkObjectBackend->ObjectSearch(
        Search       => {
            AND => [
                {}
            ]
            OR  => [
                {}
            ]
        },                         # (optional)
        Sort         => [
            {}
        ],                         # (optional)
        UserType     => 1,
        UserID       => 1,
    );

=cut

sub ObjectSearch {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed ( qw(UserID UserType) ) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    # search the tickets
    my @TicketIDs = $Kernel::OM->Get('ObjectSearch')->Search(
        %Param,
        Limit      => 50,
        Result     => 'ARRAY',
        ObjectType => 'Ticket',
        UserID     => $Param{UserID},
        UserType   => $Param{UserType}
    );

    my %SearchList;
    TICKETID:
    for my $TicketID (@TicketIDs) {

        # get ticket data
        my %TicketData = $Kernel::OM->Get('Ticket')->TicketGet(
            TicketID      => $TicketID,
            UserID        => $Param{UserID},
            DynamicFields => 0,
        );

        next TICKETID if !%TicketData;

        # add ticket data
        $SearchList{NOTLINKED}->{Source}->{$TicketID} = \%TicketData;
    }

    return \%SearchList;
}

=item LinkAddPre()

link add pre event module

    $True = $LinkObject->LinkAddPre(
        Key          => 123,
        SourceObject => 'Ticket',
        SourceKey    => 321,
        Type         => 'Normal',
        UserID       => 1,
    );

    or

    $True = $LinkObject->LinkAddPre(
        Key          => 123,
        TargetObject => 'Ticket',
        TargetKey    => 321,
        Type         => 'Normal',
        UserID       => 1,
    );

=cut

sub LinkAddPre {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Type UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    return 1;
}

=item LinkAddPost()

link add pre event module

    $True = $LinkObject->LinkAddPost(
        Key          => 123,
        SourceObject => 'Ticket',
        SourceKey    => 321,
        Type         => 'Normal',
        UserID       => 1,
    );

    or

    $True = $LinkObject->LinkAddPost(
        Key          => 123,
        TargetObject => 'Ticket',
        TargetKey    => 321,
        Type         => 'Normal',
        UserID       => 1,
    );

=cut

sub LinkAddPost {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Type UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Ticket');

    if ( $Param{SourceObject} && $Param{SourceObject} eq 'Ticket' && $Param{SourceKey} ) {

        # lookup ticket number
        my $TicketNumber = $TicketObject->TicketNumberLookup(
            TicketID => $Param{SourceKey},
            UserID   => $Param{UserID},
        );

        # add ticket history entry
        $TicketObject->HistoryAdd(
            TicketID     => $Param{Key},
            CreateUserID => $Param{UserID},
            HistoryType  => 'TicketLinkAdd',
            Name         => "\%\%$TicketNumber\%\%$Param{SourceKey}\%\%$Param{Key}",
        );

        # ticket event
        $TicketObject->EventHandler(
            Event => 'TicketSlaveLinkAdd' . $Param{Type},
            Data  => {
                TicketID => $Param{Key},
            },
            UserID => $Param{UserID},
        );

        return 1;
    }

    if ( $Param{TargetObject} && $Param{TargetObject} eq 'Ticket' && $Param{TargetKey} ) {

        # lookup ticket number
        my $TicketNumber = $TicketObject->TicketNumberLookup(
            TicketID => $Param{TargetKey},
            UserID   => $Param{UserID},
        );

        # add ticket history entry
        $TicketObject->HistoryAdd(
            TicketID     => $Param{Key},
            CreateUserID => $Param{UserID},
            HistoryType  => 'TicketLinkAdd',
            Name         => "\%\%$TicketNumber\%\%$Param{TargetKey}\%\%$Param{Key}",
        );

        # ticket event
        $TicketObject->EventHandler(
            Event  => 'TicketMasterLinkAdd' . $Param{Type},
            UserID => $Param{UserID},
            Data   => {
                TicketID => $Param{Key},
            },
        );

        return 1;
    }

    # KIX4OTRS-capeIT
    # do action for other link objects (document, change, CI)
    if ( $Param{TargetObject} ) {

        # add ticket history entry
        $TicketObject->HistoryAdd(
            TicketID     => $Param{Key},
            CreateUserID => $Param{UserID},
            HistoryType  => 'TicketLinkAdd',
            Name         => "\%\%$Param{TargetObject}\%\%$Param{TargetObject}\%\%$Param{Key}",
        );

        $TicketObject->EventHandler(
            Event  => 'TicketMasterLinkAdd' . $Param{Type},
            UserID => $Param{UserID},
            Data   => {
                TicketID => $Param{Key},
            },
        );
    }
    elsif ( $Param{SourceObject} ) {

        # add ticket history entry
        $TicketObject->HistoryAdd(
            TicketID     => $Param{Key},
            CreateUserID => $Param{UserID},
            HistoryType  => 'TicketLinkAdd',
            Name         => "\%\%$Param{SourceObject}\%\%$Param{SourceObject}\%\%$Param{Key}",
        );

        # ticket event
        $TicketObject->EventHandler(
            Event => 'TicketSlaveLinkAdd' . $Param{Type},
            Data  => {
                TicketID => $Param{Key},
            },
            UserID => $Param{UserID},
        );
    }

    # EO KIX4OTRS-capeIT

    return 1;
}

=item LinkDeletePre()

link delete pre event module

    $True = $LinkObject->LinkDeletePre(
        Key          => 123,
        SourceObject => 'Ticket',
        SourceKey    => 321,
        Type         => 'Normal',
        UserID       => 1,
    );

    or

    $True = $LinkObject->LinkDeletePre(
        Key          => 123,
        TargetObject => 'Ticket',
        TargetKey    => 321,
        Type         => 'Normal',
        UserID       => 1,
    );

=cut

sub LinkDeletePre {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Type UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    return 1;
}

=item LinkDeletePost()

link delete post event module

    $True = $LinkObject->LinkDeletePost(
        Key          => 123,
        SourceObject => 'Ticket',
        SourceKey    => 321,
        Type         => 'Normal',
        UserID       => 1,
    );

    or

    $True = $LinkObject->LinkDeletePost(
        Key          => 123,
        TargetObject => 'Ticket',
        TargetKey    => 321,
        Type         => 'Normal',
        UserID       => 1,
    );

=cut

sub LinkDeletePost {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Type UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Ticket');

    if ( $Param{SourceObject} && $Param{SourceObject} eq 'Ticket' && $Param{SourceKey} ) {

        # lookup ticket number
        my $TicketNumber = $TicketObject->TicketNumberLookup(
            TicketID => $Param{SourceKey},
            UserID   => $Param{UserID},
        );

        # add ticket history entry
        $TicketObject->HistoryAdd(
            TicketID     => $Param{Key},
            CreateUserID => $Param{UserID},
            HistoryType  => 'TicketLinkDelete',
            Name         => "\%\%$TicketNumber\%\%$Param{SourceKey}\%\%$Param{Key}",
        );

        # ticket event
        $TicketObject->EventHandler(
            Event => 'TicketSlaveLinkDelete' . $Param{Type},
            Data  => {
                TicketID => $Param{Key},
            },
            UserID => $Param{UserID},
        );

        return 1;
    }

    if ( $Param{TargetObject} && $Param{TargetObject} eq 'Ticket' && $Param{TargetKey} ) {

        # lookup ticket number
        my $TicketNumber = $TicketObject->TicketNumberLookup(
            TicketID => $Param{TargetKey},
            UserID   => $Param{UserID},
        );

        # add ticket history entry
        $TicketObject->HistoryAdd(
            TicketID     => $Param{Key},
            CreateUserID => $Param{UserID},
            HistoryType  => 'TicketLinkDelete',
            Name         => "\%\%$TicketNumber\%\%$Param{TargetKey}\%\%$Param{Key}",
        );

        # ticket event
        $TicketObject->EventHandler(
            Event => 'TicketMasterLinkDelete' . $Param{Type},
            Data  => {
                TicketID => $Param{Key},
            },
            UserID => $Param{UserID},
        );

        return 1;
    }

    # KIX4OTRS-capeIT
    # do action for other link objects (document, change, CI)
    if ( $Param{TargetObject} ) {

        # add ticket history entry
        $TicketObject->HistoryAdd(
            TicketID     => $Param{Key},
            CreateUserID => $Param{UserID},
            HistoryType  => 'TicketLinkDelete',
            Name         => "\%\%$Param{TargetObject}\%\%$Param{TargetObject}\%\%$Param{Key}",
        );

        # ticket event
        $TicketObject->EventHandler(
            Event  => 'TicketMasterLinkDelete' . $Param{Type},
            UserID => $Param{UserID},
            Data   => {
                TicketID => $Param{Key},
            },
        );
    }
    elsif ( $Param{SourceObject} ) {

        # add ticket history entry
        $TicketObject->HistoryAdd(
            TicketID     => $Param{Key},
            CreateUserID => $Param{UserID},
            HistoryType  => 'TicketLinkDelete',
            Name         => "\%\%$Param{SourceObject}\%\%$Param{SourceObject}\%\%$Param{Key}",
        );

        # ticket event
        $TicketObject->EventHandler(
            Event  => 'TicketSlaveLinkDelete' . $Param{Type},
            UserID => $Param{UserID},
            Data   => {
                TicketID => $Param{Key},
            },
        );
    }

    # EO KIX4OTRS-capeIT

    return 1;
}

1;





=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
