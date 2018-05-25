# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Ticket::TicketChecklistUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw( :all );

use base qw(
    Kernel::API::Operation::V1::Ticket::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Ticket::TicketChecklistUpdate - API TicketChecklistUpdate Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw( DebuggerObject WebserviceID )) {
        if ( !$Param{$Needed} ) {
            return {
                Success      => 0,
                ErrorMessage => "Got no $Needed!"
            };
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::ArticleUpdate');

    return $Self;
}

=item Run()

perform TicketChecklistUpdate Operation. This will return the updated ChecklistItemID

    my $Result = $OperationObject->Run(
        Data => {
            TicketID  => 123,                                                  # required
            ChecklistItemID  => 123',                                          # required            
            CheckListItem => {                                                 # required
                Value => '...'                                                 # required
            }
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            ChecklistItemID => 123,                 # ID of changed item
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # init webservice
    my $Result = $Self->Init(
        WebserviceID => $Self->{WebserviceID},
    );

    if ( !$Result->{Success} ) {
        $Self->_Error(
            Code    => 'Webservice.InvalidConfiguration',
            Message => $Result->{Message},
        );
    }

    # prepare data
    $Result = $Self->PrepareData(
        Data       => $Param{Data},
        Parameters => {
            'TicketID' => {
                Required => 1
            },
            'ArticleID' => {
                Required => 1
            },
            'FlagName' => {
                Required => 1
            },
            'ArticleFlag' => {
                Type     => 'HASH',
                Required => 1
            },
            'ArticleFlag::Value' => {
                Required => 1
            },
        }
    );

    # check result
    if ( !$Result->{Success} ) {
        return $Self->_Error(
            Code    => 'Operation.PrepareDataError',
            Message => $Result->{Message},
        );
    }

    if ( $Self->{Authorization}->{UserType} eq 'Customer' ) {
        # customers are not allowed to update articles
        return $Self->_Error(
            Code    => 'Forbidden',
            Message => 'No permission to update article flag!',
        );        
    }

    # check write permission
    my $Permission = $Self->CheckWritePermission(
        TicketID => $Param{Data}->{TicketID},
        UserID   => $Self->{Authorization}->{UserID},
        UserType => $Self->{Authorization}->{UserType},
    );

    if ( !$Permission ) {
        return $Self->_Error(
            Code    => 'Object.NoPermission',
            Message => "No permission to update article flag!",
        );
    }

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my %Article = $TicketObject->ArticleGet(
        ArticleID     => $Param{Data}->{ArticleID},
        DynamicFields => 0,
    );

    # check if article exists
    if ( !%Article ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Could not get data for article $Param{Data}->{ArticleID}",
        );
    }

    # check if article belongs to the given ticket
    if ( $Article{TicketID} != $Param{Data}->{TicketID} ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Article $Param{Data}->{ArticleID} not found in ticket $Param{Data}->{TicketID}",
        );
    }

    # check if flag exists
    my %ArticleFlags = $Kernel::OM->Get('Kernel::System::Ticket')->ArticleFlagGet(
        ArticleID => $Param{Data}->{ArticleID},
        UserID    => $Self->{Authorization}->{UserID},
    );

    if ( !exists($ArticleFlags{$Param{Data}->{FlagName}}) ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Cannot update article flag. No flag with name '$Param{Data}->{FlagName}' found for the given article.",
        );
    }

    my $Success = $Kernel::OM->Get('Kernel::System::Ticket')->ArticleFlagSet(
        ArticleID => $Param{Data}->{ArticleID},
        Key       => $Param{Data}->{FlagName},
        Value     => $Param{Data}->{ArticleFlag}->{Value},
        UserID    => $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code         => 'Object.UnableToUpdate',
            Message      => "Unable to update article flag '$Param{Data}->{FlagName}'",
        );
    }

    return $Self->_Success(
        FlagName => $Param{Data}->{FlagName},
    );
}

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
