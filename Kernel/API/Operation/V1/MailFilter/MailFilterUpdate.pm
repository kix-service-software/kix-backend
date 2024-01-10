# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::MailFilter::MailFilterUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::API::Operation::V1::MailFilter::Common);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::MailFilter::MailFilterUpdate - API MailFilter Update Operation backend

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
        'MailFilterID' => {
            Required => 1
        },
        'MailFilter' => {
            Type     => 'HASH',
            Required => 1
        },
        'MailFilter::Name' => {
            RequiresValueIfUsed => 1
        },
        'MailFilter::StopAfterMatch' => {
            RequiresValueIfUsed => 1,
            OneOf => [ 0, 1 ]
        },
        'MailFilter::Match' => {
            RequiresValueIfUsed => 1,
            Type => 'ARRAY'
        },
        'MailFilter::Set' => {
            RequiresValueIfUsed => 1,
            Type => 'ARRAY'
        },
    };
}

=item Run()

perform MailFilterUpdate Operation. This will return the updated TypeID.

    my $Result = $OperationObject->Run(
        Data => {
            MailFilterID => 123,
            MailFilter  => {
                Name           => 'some name',          # optional
                StopAfterMatch => 1 | 0,                # optional, default 0
                Comment        => 'some comment',       # optional
                ValidID        => 1,                    # optional
                Match          => [                     # optional
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
                Set            => [                     # optional
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
            MailFilterID  => 123,                     # ID of the updated MailFilter
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim MailFilter parameter
    my $MailFilter = $Self->_Trim( Data => $Param{Data}->{MailFilter} );

    # check if another filter with name already exists
    if (exists $MailFilter->{Name}) {
        my $Exists = $Kernel::OM->Get('PostMaster::Filter')->NameExistsCheck(
            Name => $MailFilter->{Name},
            ID   => $Param{Data}->{MailFilterID}
        );
        if ($Exists) {
            return $Self->_Error(
                Code    => 'Object.AlreadyExists',
                Message => "Another MailFilter with the same name already exists."
            );
        }
    }

    # validate MailFilter
    my $Check = $Self->_CheckMailFilter(
        MailFilter => $MailFilter
    );
    if ( !$Check->{Success} ) {
        return $Check;
    }

    # get "old" data of MailFilter
    my %MailFilterData = $Kernel::OM->Get('PostMaster::Filter')->FilterGet(
        ID     => $Param{Data}->{MailFilterID},
        UserID => $Self->{Authorization}->{UserID},
    );
    if ( !%MailFilterData ) {
        return $Self->_Error( Code => 'Object.NotFound', );
    }

    $Self->_PrepareFilter( Filter => $MailFilter );

    # update MailFilter
    my $Success = $Kernel::OM->Get('PostMaster::Filter')->FilterUpdate(
        ID             => $Param{Data}->{MailFilterID},
        Name           => $MailFilter->{Name} || $MailFilterData{Name},
        ValidID        => $MailFilter->{ValidID} || $MailFilterData{ValidID},
        StopAfterMatch => defined $MailFilter->{StopAfterMatch} ? $MailFilter->{StopAfterMatch} : $MailFilterData{StopAfterMatch},
        Comment        => exists $MailFilter->{Comment} ? $MailFilter->{Comment} : $MailFilterData{Comment},
        Match          => $MailFilter->{Match} || $MailFilterData{Match},
        Set            => $MailFilter->{Set}   || $MailFilterData{Set},
        Not            => $MailFilter->{Not}   || $MailFilterData{Not},
        UserID         => $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        return $Self->_Error( Code => 'Object.UnableToUpdate', );
    }

    # return result
    return $Self->_Success( MailFilterID => $MailFilterData{ID} );
}

sub _PrepareFilter {
    my ( $Self, %Param ) = @_;

    if ( IsArrayRefWithData( $Param{Filter}->{Match} ) ) {
        my %NotData   = ();
        my %MatchData = ();
        for my $Match ( @{ $Param{Filter}->{Match} } ) {
            $MatchData{ $Match->{Key} } = $Match->{Value};
            $NotData{ $Match->{Key} }   = $Match->{Not} ? 1 : 0;
        }
        $Param{Filter}->{Match} = \%MatchData;
        $Param{Filter}->{Not}   = \%NotData;
    }

    if ( IsArrayRefWithData( $Param{Filter}->{Set} ) ) {
        my %SetData = ();
        for my $Set ( @{ $Param{Filter}->{Set} } ) {
            $SetData{ $Set->{Key} } = $Set->{Value};
        }
        $Param{Filter}->{Set} = \%SetData;
    }
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
