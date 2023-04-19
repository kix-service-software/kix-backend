# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::MailFilter::MailFilterCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::API::Operation::V1::MailFilter::Common);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::MailFilter::MailFilterCreate - API MailFilter Create Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

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
        'MailFilter' => {
            Type     => 'HASH',
            Required => 1
        },
        'MailFilter::Name' => {
            Required => 1
        },
        'MailFilter::StopAfterMatch' => {
            RequiresValueIfUsed => 1,
            OneOf => [ 0, 1 ]
        },
        'MailFilter::Match' => {
            Required => 1,
            Type     => 'ARRAY'
        },
        'MailFilter::Set' => {
            Required => 1,
            Type     => 'ARRAY'
        },
    };
}

=item Run()

perform MailFilterCreate Operation. This will return the created MailFilterID.

    my $Result = $OperationObject->Run(
        Data => {
            MailFilter  => {
                Name           => 'some name',
                StopAfterMatch => 1 | 0,                # optional, default 0
                Comment        => 'some comment',       # optional
                ValidID        => 1,
                Match          => [
                    {
                        Key    => 'From',
                        Value  => 'email@example.com',
                        Not    => 0                     # optional
                    },
                    {
                        Key    => 'Subject',
                        Value  => 'Test',
                        Not    => 1                     # optional
                    }
                ],
                Set            => [
                    {
                        Key    => 'X-KIX-Queue',
                        Value  => 'Some::Queue'
                    }
                ]
            }
        }
    );

    $Result = {
        Success           => 1,                       # 0 or 1
        Code              => '',                      # in case of error
        Message           => '',                      # in case of error
        Data              => {                        # result data payload after Operation
            MailFilterID  => '',                      # ID of the created MailFilter
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim MailFilter parameter
    my $MailFilter = $Self->_Trim( Data => $Param{Data}->{MailFilter} );

    # check if filter exists
    my $Exists = $Kernel::OM->Get('PostMaster::Filter')->NameExistsCheck( Name => $MailFilter->{Name} );
    if ($Exists) {
        return $Self->_Error( Code => 'Object.AlreadyExists' );
    }

    # validate MailFilter
    my $Check = $Self->_CheckMailFilter(
        MailFilter => $MailFilter
    );
    if ( !$Check->{Success} )  {
        return $Check;
    }

    $Self->_PrepareFilter( Filter => $MailFilter );

    # create MailFilter
    my $MailFilterID = $Kernel::OM->Get('PostMaster::Filter')->FilterAdd(
        Name           => $MailFilter->{Name},
        StopAfterMatch => $MailFilter->{StopAfterMatch} || 0,
        ValidID        => $MailFilter->{ValidID} || 1,
        Comment        => $MailFilter->{Comment} || '',
        Match          => $MailFilter->{Match},
        Set            => $MailFilter->{Set},
        Not            => $MailFilter->{Not},
        UserID         => $Self->{Authorization}->{UserID},
    );

    if ( !$MailFilterID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create MailFilter, please contact the system administrator',
        );
    }

    # return result
    return $Self->_Success(
        Code         => 'Object.Created',
        MailFilterID => $MailFilterID,
    );
}

sub _PrepareFilter {
    my ( $Self, %Param ) = @_;

    my %NotData   = ();
    my %MatchData = ();
    for my $Match ( @{ $Param{Filter}->{Match} } ) {
        $MatchData{ $Match->{Key} } = $Match->{Value};
        $NotData{ $Match->{Key} }   = $Match->{Not} ? 1 : 0;
    }
    $Param{Filter}->{Match} = \%MatchData;
    $Param{Filter}->{Not}   = \%NotData;

    my %SetData = ();
    for my $Set ( @{ $Param{Filter}->{Set} } ) {
        $SetData{ $Set->{Key} } = $Set->{Value};
    }
    $Param{Filter}->{Set} = \%SetData;
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
