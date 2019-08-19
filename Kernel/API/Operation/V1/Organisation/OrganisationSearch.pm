# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Organisation::OrganisationSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw( :all );

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Organisation::OrganisationSearch - API Organisation Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(DebuggerObject WebserviceID)) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "Got no $Needed!"
            );
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    return $Self;
}

=item Run()

perform OrganisationSearch Operation. This will return a Organisation list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Message => '',                               # In case of an error
        Data         => {
            Organisation => [
                {
                },
                {                    
                }
            ],
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform Organisation search
    my %OrganisationSearch = $Kernel::OM->Get('Kernel::System::Organisation')->OrganisationSearch(
        Valid  => 0,
    );

    if (IsHashRefWithData(\%OrganisationSearch)) {
        
        # get already prepared Organisation data from OrganisationGet operation
        my $OrganisationGetResult = $Self->ExecOperation(
            OperationType => 'V1::Organisation::OrganisationGet',
            Data          => {
                OrganisationID => join(',', sort keys %OrganisationSearch),
            }
        );
        if ( !IsHashRefWithData($OrganisationGetResult) || !$OrganisationGetResult->{Success} ) {
            return $OrganisationGetResult;
        }

        my @ResultList = IsArrayRefWithData($OrganisationGetResult->{Data}->{Organisation}) ? @{$OrganisationGetResult->{Data}->{Organisation}} : ( $OrganisationGetResult->{Data}->{Organisation} );
        
        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                Organisation => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        Organisation => [],
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
