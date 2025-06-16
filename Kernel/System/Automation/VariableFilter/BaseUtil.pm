# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::VariableFilter::BaseUtil;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);
use base qw(
    Kernel::System::Automation::VariableFilter::Common
);

our @ObjectDependencies = qw(
    JSON
    Log
);

sub GetFilterHandler {
    my ( $Self, %Param ) = @_;

    my %Handler = (
        'JSON'              => \&_ToJSON,
        'ToJSON'            => \&_ToJSON,
        'FromJSON'          => \&_FromJSON,
        'JQ'                => \&_JQ,
        'Base64'            => \&_ToBase64,
        'ToBase64'          => \&_ToBase64,
        'FromBase64'        => \&_FromBase64,
        'AsConditionString' => \&_AsConditionString,
    );

    return %Handler;
}

sub _ToJSON {
    my ( $Self, %Param ) = @_;

    if ( defined( $Param{Value} ) ) {
        $Param{Value} = $Kernel::OM->Get('JSON')->Encode(
            Data => $Param{Value}
        );
        $Param{Value} =~ s/^"//;
        $Param{Value} =~ s/"$//;
    }
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "\"$Param{Filter}\" need defined data!"
        );
    }

    return $Param{Value};
}

sub _FromJSON {
    my ( $Self, %Param ) = @_;

    if ( IsStringWithData( $Param{Value} ) ) {
        $Param{Value} = $Kernel::OM->Get('JSON')->Decode(
            Data => $Param{Value}
        );
    }
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "\"$Param{Filter}\" need string with data!"
        );
    }

    return $Param{Value};
}

sub _JQ {
    my ( $Self, %Param ) = @_;

    if ( IsStringWithData( $Param{Parameter} ) ) {
        if ( IsStringWithData( $Param{Value} ) ) {
            $Param{Parameter} =~ s/\s+::\s+/|/g;
            $Param{Parameter} =~ s/&quot;/"/g;

            $Param{Value} = $Kernel::OM->Get('JSON')->Jq(
                Data   => $Param{Value},
                Filter => $Param{Parameter},
            );
        }
        else {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "\"$Param{Filter}\" need string with data!"
            );
        }
    }
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "\"$Param{Filter}\" has no jq expression!"
        );
    }

    return $Param{Value};
}

sub _ToBase64 {
    my ( $Self, %Param ) = @_;

    if ( defined( $Param{Value} ) ) {
        $Param{Value} = MIME::Base64::encode_base64( $Param{Value} );
        $Param{Value} =~ s/\n//g;
    }
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "\"$Param{Filter}\" need defined data!"
        );
    }

    return $Param{Value};
}

sub _FromBase64 {
    my ( $Self, %Param ) = @_;

    if ( IsStringWithData( $Param{Value} ) ) {
        $Param{Value} = MIME::Base64::decode_base64( $Param{Value} );
    }
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "\"$Param{Filter}\" need string with data!"
        );
    }

    return $Param{Value};
}

sub _AsConditionString {
    my ( $Self, %Param ) = @_;

    if ( IsString( $Param{Value} ) ) {
        $Param{Value} =~ s/([\\'])/\\$1/g;

        $Param{Value} = qq{'$Param{Value}'};
    }
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "\"$Param{Filter}\" need string!"
        );
    }

    return $Param{Value};
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
