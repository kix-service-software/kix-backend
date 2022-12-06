# --
# Copyright (C) 2006-2022 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::HTMLToPDF::Ticket;

use strict;
use warnings;

use base qw(
    Kernel::System::HTMLToPDF::Common
);

our @ObjectDependencies = (
    "Config",
    "DB",
    "Log",
);

use Kernel::System::VariableCheck qw(:all);

sub GetParams {
    my ( $Self, %Param) = @_;

    return {
        IDKey     => 'TicketID',
        NumberKey => 'TicketNumber',
        Filters   => 'Article',
    };
}

sub GetPossibleExpands {
    my ( $Self, %Param) = @_;

    return [
        'DynamicField',
        'Article',
        'LinkObject'
    ];
}

sub CheckParams {
    my ( $Self, %Param) = @_;

    if (
        !$Param{TicketID}
        && !$Param{TicketNumber}
    ) {
        return {
            error => "No given TicketID or TicketNumber!"
        }
    }

    return 1;
}

sub DataGet {
    my ($Self, %Param) = @_;

    my $TicketObject = $Kernel::OM->Get('Ticket');
    my $LinkObject   = $Kernel::OM->Get('LinkObject');
    my $ConfigObject = $Kernel::OM->Get('Config');

    my %Ticket;
    my %Expands;
    my %Filters;

    if ( IsArrayRefWithData($Param{Expands}) ) {
        %Expands = map { $_ => 1 } @{$Param{Expands}};
    }
    elsif( $Param{Expands} ) {
        %Expands = map { $_ => 1 } split( /[,]/smx, $Param{Expands});
    }

    if (
        $Param{Filters}
        && $Param{Filters}->{Ticket}
        && IsHashRefWithData($Param{Filters}->{Ticket})
    ) {
        %Filters = %{$Param{Filters}->{Ticket}};
    }

    my $TicketID = $Param{TicketID};
    if ( !$Param{Data} ) {
        if ( $Param{TicketNumber} ) {
            $TicketID = $TicketObject->TicketIDLookup(
                TicketNumber => $Param{TicketNumber}
            );

            if ( !$TicketID ) {
                return {
                    error=> "Ticket '$Param{TicketNumber}' not found!"
                };
            }
        }

        %Ticket = $TicketObject->TicketGet(
            TicketID => $TicketID,
            Extended => 1,
            UserID   => $Param{UserID}
        );

        if ( !%Ticket ) {
            return {
                error=> "Ticket '$TicketID' not found!"
            };
        }
    }
    else {
        %Ticket = %{$Param{Data}};
    }

    my $DynamicFields;
    if (
        $Expands{DynamicField}
        && !IsHashRefWithData($Ticket{Expands}->{DynamicField})
    ) {
        $Self->_GetDynamicFields(
            IDKey    => 'TicketID',
            Type     => 'Ticket',
            TicketID => $Ticket{TicketID} || $TicketID,
            UserID   => $Param{UserID},
            Data     => \%Ticket
        );

        $DynamicFields = $Ticket{Expands}->{DynamicFied};
    }

    if ( %Filters ) {
        my $Match = $Self->_Filter(
            Data   => {
                %Ticket,
                %{$DynamicFields}
            },
            Filter => \%Filters
        );

        return if !$Match;
    }

    if (
        $Expands{Article}
        && !IsArrayRefWithData($Ticket{Expands}->{Article})
    ) {
        $Self->_GetArticleIDs(
            TicketID => $Ticket{TicketID} || $TicketID,
            UserID   => $Param{UserID},
            Ticket   => \%Ticket
        );
    }

    if (
        $Expands{LinkObject}
        && !IsHashRefWithData($Ticket{Expands}->{LinkObject})
    ) {
        $Self->_GetLinkedObjects(
            TicketID => $Ticket{TicketID} || $TicketID,
            UserID   => $Param{UserID},
            Ticket   => \%Ticket
        );
    }

    if (
        $Expands{Asset}
        && !IsHashRefWithData($Ticket{Expands}->{Asset})
    ) {
        $Self->_GetAssetIDs(
            TicketID => $Ticket{TicketID} || $TicketID,
            UserID   => $Param{UserID},
            Ticket   => \%Ticket
        );
    }

    return \%Ticket;
}

sub _GetArticleIDs {
    my ($Self, %Param) = @_;

    my $TicketObject = $Kernel::OM->Get('Ticket');

    my @ArticleIDs = $TicketObject->ArticleIndex(
        TicketID => $Param{TicketID},
        UserID   => $Param{UserID}
    );

    if ( scalar(@ArticleIDs) ) {
        my $Count = 1;
        $Param{Ticket}->{Expands}->{Article} = \@ArticleIDs;
    }

    return 1;
}

sub _GetLinkedObjects {
    my ( $Self, %Param ) = @_;

    my $LinkObject   = $Kernel::OM->Get('LinkObject');
    my $ConfigObject = $Kernel::OM->Get('Config');

    my $FAQHook           = $ConfigObject->Get('FAQ::FAQHook');
    my $TicketHook        = $ConfigObject->Get('Ticket::Hook');
    my $TicketHookDivider = $ConfigObject->Get('Ticket::HookDivider');
    my %TypeList = $LinkObject->TypeList(
        UserID => $Param{UserID},
    );
    my $LinkList = $LinkObject->LinkListWithData(
        Object           => 'Ticket',
        Key              => $Param{TicketID},
        State            => 'Valid',
        UserID           => $Param{UserID},
        ObjectParameters => {
            Ticket => {
                IgnoreLinkedTicketStateTypes => 1,
            },
        },
    );

    for my $LinkType ( sort keys %{ $LinkList } ) {

        # extract link type List
        my $LinkTypeList = $LinkList->{$LinkType};
        for my $DirectionType ( sort keys %{$LinkTypeList} ) {

            # extract direction type list
            my $DirectionTypeList = $LinkList->{$LinkType}->{$DirectionType};

            for my $Direction ( sort keys %{$DirectionTypeList} ) {

                # extract direction list
                my $DirectionList = $LinkList->{$LinkType}->{$DirectionType}->{$Direction};

                for my $ID ( sort { $a <=> $b } keys %{$DirectionList} ) {

                    # extract data
                    my $Data = $DirectionList->{$ID};

                    if ( $LinkType eq 'Ticket' ) {
                        push(
                            @{$Param{Ticket}->{Expands}->{LinkObject}->{$TypeList{$DirectionType}->{$Direction . 'Name'}}},
                            "$TicketHook$TicketHookDivider$Data->{TicketNumber}: $Data->{Title}"
                        );
                    }

                    if ( $LinkType eq 'Person' ) {
                        my $Type = ( $Data->{Type} =~ /Agent/smx ) ? 'Agent' : 'Customer';
                        push(
                            @{$Param{Ticket}->{Expands}->{LinkObject}->{$TypeList{$DirectionType}->{$Direction . 'Name'}}},
                            "$Data->{UserFirstnam} $Data->{UserLastname}"
                        );
                    }

                    if ( $LinkType eq 'FAQArticle' ) {
                        push(
                            @{$Param{Ticket}->{Expands}->{LinkObject}->{$TypeList{$DirectionType}->{$Direction . 'Name'}}},
                            "$FAQHook$Data->{Number}: $Data->{Title}"
                        );
                    }

                    if ( $LinkType eq 'ConfigItem' ) {
                        push(
                            @{$Param{Ticket}->{Expands}->{LinkObject}->{$TypeList{$DirectionType}->{$Direction . 'Name'}}},
                            "Asset#$Data->{Number} ($Data->{Class}): $Data->{Name}"
                        );
                    }
                }
            }
        }
    }

    return 1;
}

sub _GetAssetIDs {
    my ( $Self, %Param ) = @_;

    my $LinkObject = $Kernel::OM->Get('LinkObject');

    my %LinkKeyList = $LinkObject->LinkKeyList(
        Object1   => 'Ticket',
        Key1      => $Param{TicketID},
        Object2   => 'ITSMConfigItem',
        State     => 'Valid',
        UserID    => $Param{UserID},
    );

    if ( %LinkKeyList ) {
        $Param{Ticket}->{Expands}->{Asset} = keys %LinkKeyList;
    }

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