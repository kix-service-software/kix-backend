# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::SysConfig::SysConfigOptionSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::SysConfig::SysConfigOptionGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::SysConfig::SysConfigOptionSearch - API SysConfig Search Operation backend

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

perform SysConfigOptionSearch Operation. This will return a SysConfig item list with data.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            SysConfigOption => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform SysConfig search
    my %AllOptions = $Kernel::OM->Get('Kernel::System::SysConfig')->ValueGetAll();

	# get already prepared SysConfig data from SysConfigGet operation
    if ( IsHashRefWithData(\%AllOptions) ) {  	
        my $SysConfigGetResult = $Self->ExecOperation(
            OperationType => 'V1::SysConfig::SysConfigOptionGet',
            Data      => {
                Option  => join(',', sort keys %AllOptions),
                include => $Param{Data}->{include},
            }
        );    

        if ( !IsHashRefWithData($SysConfigGetResult) || !$SysConfigGetResult->{Success} ) {
            return $SysConfigGetResult;
        }

        my @SysConfigDataList = IsArrayRefWithData($SysConfigGetResult->{Data}->{SysConfigOption}) ? @{$SysConfigGetResult->{Data}->{SysConfigOption}} : ( $SysConfigGetResult->{Data}->{SysConfigOption} );

        if ( IsArrayRefWithData(\@SysConfigDataList) ) {
            return $Self->_Success(
                SysConfigOption => \@SysConfigDataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        SysConfigOption => [],
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