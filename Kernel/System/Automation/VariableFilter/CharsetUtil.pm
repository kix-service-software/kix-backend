# --
# Modified version of the work: Copyright (C) 2006-2026 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::VariableFilter::CharsetUtil;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);
use base qw(
    Kernel::System::Automation::VariableFilter::Common
);

our @ObjectDependencies = ();

sub GetFilterHandler {
    my ( $Self, %Param ) = @_;

    my %Handler = (
        'CharsetUtil.ConvertFrom' => \&_ConvertFrom,
        'CharsetUtil.ConvertTo' => \&_ConvertTo,
        'CharsetUtil.EncodeInput' => \&_EncodeInput,
        'CharsetUtil.EncodeOutput' => \&_EncodeOutput,
    );

    return %Handler;
}

sub _ConvertFrom {
    my ( $Self, %Param ) = @_;

    if ( !IsString( $Param{Value} ) ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "\"CharsetUtil.ConvertFrom\" need string with data!"
            );
        }
        return $Param{Value};
    }

    if ( !IsStringWithData( $Param{Parameter} ) ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "\"CharsetUtil.ConvertFrom\" need charset as parameter!"
            );
        }
        return $Param{Value};
    }

    return $Kernel::OM->Get('Encode')->Convert(
        Text => $Param{Value},
        From => $Param{Parameter},
        To   => 'utf-8',
    );
}

sub _ConvertTo {
    my ( $Self, %Param ) = @_;

    if ( !IsString( $Param{Value} ) ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "\"CharsetUtil.ConvertTo\" need string with data!"
            );
        }
        return $Param{Value};
    }

    if ( !IsStringWithData( $Param{Parameter} ) ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "\"CharsetUtil.ConvertTo\" need charset as parameter!"
            );
        }
        return $Param{Value};
    }

    return $Kernel::OM->Get('Encode')->Convert(
        Text => $Param{Value},
        From => 'utf-8',
        To   => $Param{Parameter},
    );
}

sub _EncodeInput {
    my ( $Self, %Param ) = @_;

    if ( !IsString( $Param{Value} ) ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "\"CharsetUtil.EncodeInput\" need string with data!"
            );
        }
        return $Param{Value};
    }

    return $Kernel::OM->Get('Encode')->EncodeInput( $Param{Value} );
}

sub _EncodeOutput {
    my ( $Self, %Param ) = @_;

    if ( !IsString( $Param{Value} ) ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "\"CharsetUtil.EncodeOutput\" need string with data!"
            );
        }
        return $Param{Value};
    }

    return $Kernel::OM->Get('Encode')->EncodeOutput( $Param{Value} );
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


