# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::SysConfig::SysConfigOptionDefinitionSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::SysConfig::SysConfigOptionGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::SysConfig::SysConfigOptionDefinitionSearch - API SysConfig Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform SysConfigOptionDefinitionSearch Operation. This will return a SysConfig definition list with data.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            SysConfigOptionDefinition => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform SysConfig search
    my %AllOptions = $Kernel::OM->Get('SysConfig')->OptionGetAll();

    # prepare search if given
    if ( IsHashRefWithData( $Self->{Search}->{SysConfigOptionDefinition} ) ) {
        my @Definitions = values %AllOptions;
        my $Data = {
            SysConfigOptionDefinition => \@Definitions,
        };

        # use the in-API filter to do that, because the AllOptions hash already contains everything we need
        my $Result = $Self->_ApplyFilter(
            Filter => $Self->{Search},
            Data   => $Data
        );
        %AllOptions = map { $_->{Name} => 1 } @{$Data->{SysConfigOptionDefinition}};
    }

	# get already prepared SysConfig data from SysConfigDefinitionGet operation
    if ( IsHashRefWithData(\%AllOptions) ) {
        my $SysConfigGetResult = $Self->ExecOperation(
            OperationType            => 'V1::SysConfig::SysConfigOptionDefinitionGet',
            SuppressPermissionErrors => 1,
            Data      => {
                Option  => join(',', sort keys %AllOptions),
                include => $Param{Data}->{include},
            }
        );

        if ( !IsHashRefWithData($SysConfigGetResult) || !$SysConfigGetResult->{Success} ) {
            return $SysConfigGetResult;
        }

        my @SysConfigDataList;
        if ( defined $SysConfigGetResult->{Data}->{SysConfigOptionDefinition} ) {
            @SysConfigDataList = IsArrayRef($SysConfigGetResult->{Data}->{SysConfigOptionDefinition}) ? @{$SysConfigGetResult->{Data}->{SysConfigOptionDefinition}} : ( $SysConfigGetResult->{Data}->{SysConfigOptionDefinition} );
        }

        if ( IsArrayRefWithData(\@SysConfigDataList) ) {
            return $Self->_Success(
                SysConfigOptionDefinition => \@SysConfigDataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        SysConfigOptionDefinition => [],
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
