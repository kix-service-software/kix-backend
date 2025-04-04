# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::OAuth2::ProfileSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::OAuth2::ProfileGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::OAuth2::ProfileSearch - API OAuth2 Profile Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform OAuth2 ProfileSearch Operation. This will return a Profile list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            Profile => [
                {
                    ...
                },
                {
                    ...
                }
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # get Profile list
    my %ProfileList = $Kernel::OM->Get('OAuth2')->ProfileList();

    # get already prepared Profile data from ProfileGet operation
    if ( IsHashRefWithData( \%ProfileList ) ) {
        my $GetResult = $Self->ExecOperation(
            OperationType            => 'V1::OAuth2::ProfileGet',
            SuppressPermissionErrors => 1,
            Data          => {
                ProfileID => join( ',', sort( keys( %ProfileList ) ) ),
            }
        );
        if ( !IsHashRefWithData($GetResult) || !$GetResult->{Success} ) {
            return $GetResult;
        }

        my @ResultList;
        if ( defined $GetResult->{Data}->{Profile} ) {
            @ResultList = IsArrayRef($GetResult->{Data}->{Profile}) ? @{$GetResult->{Data}->{Profile}} : ( $GetResult->{Data}->{Profile} );
        }

        if ( IsArrayRefWithData( \@ResultList ) ) {
            return $Self->_Success(
                Profile => \@ResultList,
            );
        }
    }

    # return result
    return $Self->_Success(
        Profile => [],
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
