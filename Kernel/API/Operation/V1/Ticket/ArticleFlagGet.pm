# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Ticket::ArticleFlagGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Ticket::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Ticket::ArticleFlagGet - API Ticket Get Operation backend

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
    for my $Needed (qw(DebuggerObject WebserviceID)) {
        if ( !$Param{$Needed} ) {
            return {
                Success      => 0,
                ErrorMessage => "Got no $Needed!",
            };
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    return $Self;
}

=item ParameterDefinition()

define parameter preparation and check for this operation

    my $Result = $OperationObject->ParameterDefinition(
        Data => {
            ...
        },
    );

    $Result = {
        ...
    };

=cut

sub ParameterDefinition {
    my ( $Self, %Param ) = @_;

    return {
        'TicketID' => {
            Required => 1
        },
        'ArticleID' => {
            Required => 1
        },
        'FlagName' => {
            Type     => 'ARRAY',
            Required => 1
        },
    }
}

=item Run()

perform ArticleFlagGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            TicketID     => 1'                                             # required 
            ArticleID    => 32,                                            # required
            FlagName     => 'seen',                                        # required, could be coma separated IDs or an Array
        },
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Code         => '',                               # In case of an error
        Message      => '',                               # In case of an error
        Data         => {
            ArticleFlag => [
                {
                    ArticleID  => 32,
                    Name       => 'seen',
                    Value      => '...',
                },
                {
                    #. . .
                },
            ],
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my %Article = $TicketObject->ArticleGet(
        ArticleID     => $Param{Data}->{ArticleID},
        DynamicFields => 0,
    );

    # check if article exists
    if ( !%Article ) {
        return $Self->_Error(
            Code => 'ParentObject.NotFound',
        );
    }

    # check if article belongs to the given ticket
    if ( $Article{TicketID} != $Param{Data}->{TicketID} ) {
        return $Self->_Error(
            Code => 'ParentObject.NotFound',
        );
    }

    my @FlagList;

    my %ArticleFlags = $TicketObject->ArticleFlagGet(
        ArticleID => $Param{Data}->{ArticleID},
        UserID    => $Self->{Authorization}->{UserID},
    );

    # start loop
    foreach my $ArticleFlag ( sort @{$Param{Data}->{FlagName}} ) {
        my %Flag = (
            ArticleID => $Param{Data}->{ArticleID},
            Name      => $ArticleFlag,
            Value     => $ArticleFlags{$ArticleFlag},
        );

        # add
        push(@FlagList, \%Flag);
    }

    if ( scalar(@FlagList) == 1 ) {
        return $Self->_Success(
            ArticleFlag => $FlagList[0],
        );    
    }

    return $Self->_Success(
        ArticleFlag => \@FlagList,
    );
}

1;





=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
