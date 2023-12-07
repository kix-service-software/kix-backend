# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Contact::ContactSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Contact::ContactSearch - API Contact Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

sub Init {
    my ( $Self, %Param ) = @_;

    my $Result = $Self->SUPER::Init(%Param);

    $Self->{HandleSortInCORE} = 1;

    return $Result;
}

=item Run()

perform ContactSearch Operation. This will return a Contact ID list.

    my $Result = $OperationObject->Run(
        Data => { }
    );

    $Result = {
        Success     => 1,                                # 0 or 1
        Message     => '',                               # In case of an error
        Data        => {
            Contact => [
                { },
                { }
            ],
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;
    my @ContactList;

    $Self->SetDefaultSort(
        Contact => [
            { Field => 'Lastname' },
            { Field => 'Firstname' },
        ]
    );

    @ContactList = $Kernel::OM->Get('ObjectSearch')->Search(
        ObjectType => 'Contact',
        Result     => 'ARRAY',
        Search     => $Self->{Search}->{Contact}      || {},
        Limit      => $Self->{SearchLimit}->{Contact} || $Self->{SearchLimit}->{'__COMMON'},
        Sort       => $Self->{Sort}->{Contact}        || $Self->{DefaultSort}->{Contact},
        UserType   => $Self->{Authorization}->{UserType},
        UserID     => $Self->{Authorization}->{UserID},
        Debug      => $Param{Data}->{debug} || 0
    );

    if ( IsArrayRefWithData( \@ContactList ) ) {

        # get already prepared Contact data from ContactGet operation
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::Contact::ContactGet',
            SuppressPermissionErrors => 1,
            Data          => {
                ContactID                   => join( q{,}, @ContactList ),
                NoDynamicFieldDisplayValues => $Param{Data}->{NoDynamicFieldDisplayValues},
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{Contact} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{Contact}) ? @{$GetResult->{Data}->{Contact}} : ( $GetResult->{Data}->{Contact} );
        }

        if ( IsArrayRefWithData( \@ResultList ) ) {
            return $Self->_Success(
                Contact => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        Contact => [],
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
