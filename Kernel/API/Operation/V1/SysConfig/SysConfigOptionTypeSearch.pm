# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::SysConfig::SysConfigOptionTypeSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::SysConfig::SysConfigOptionTypeSearch - API SysConfigOptionTypeSearch Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Run()

perform SysConfigOptionTypeSearch Operation. This will return a SysConfigOptionType list.

    my $Result = $OperationObject->Run(
        Data => {
            SysConfigID => 123
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            SysConfigOptionType => [
                'String',
                'Array'
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform search
    my @OptionTypeList = $Kernel::OM->Get('SysConfig')->OptionTypeList();

	# get prepare
    if ( IsArrayRefWithData(\@OptionTypeList) ) {

        return $Self->_Success(
            SysConfigOptionType => \@OptionTypeList,
        )
    }

    # return result
    return $Self->_Success(
        SysConfigOptionType => [],
    );
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
