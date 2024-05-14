# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::VariableFilter::XMLUtil;

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
        'XMLUtil.FromXML' => \&_FromXML,
    );

    return %Handler;
}

sub _FromXML {
    my ( $Self, %Param ) = @_;

    if ( !IsStringWithData( $Param{Value} ) ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "\"XMLUtil.FromXML\" need string with data!"
            );
        }
        return $Param{Value};
    }

    # init return data
    my $ReturnData;

    # catch parsing errors
    eval {
        # require XML::Simple for parsing
        $Kernel::OM->Get('Main')->Require('XML::Simple');

        # get parser object
        my $XMLSimple = XML::Simple->new();

        # convert xml string to perl data structure
        $ReturnData = $XMLSimple->XMLin(
            $Param{Value},
            SuppressEmpty => '',
            ForceArray    => 0,
            ContentKey    => '-content',
            NoAttr        => 0,
            KeyAttr       => [],
        );
        if ( ref( $ReturnData ) eq 'HASH' ) {
            $ReturnData = _ProcessReturnDataHash(
                Data => $ReturnData,
            );

        }
    };
    if ( !defined( $ReturnData ) ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Could not convert data from XML to Perl: '$Param{Value}'!",
            );
        }

        return '';
    }

    return $ReturnData;
}

sub _ProcessReturnDataHash {
    my ( %Param ) = @_;

    # init return hashref
    my $Return = {};

    # process given hash
    for my $Key ( keys( %{ $Param{Data} } ) ) {
        # get current key
        my $ReturnKey = $Key;

        # convert colon to underscore
        $ReturnKey =~ s/:/_/g;

        # check for hash ref in value
        if ( ref( $Param{Data}->{ $Key } ) eq 'HASH' ) {
            $Return->{ $ReturnKey } = _ProcessReturnDataHash(
                Data => $Param{Data}->{ $Key },
            );
        }
        # check for array ref in value
        elsif ( ref( $Param{Data}->{ $Key } ) eq 'ARRAY' ) {
            $Return->{ $ReturnKey } = _ProcessReturnDataArray(
                Data => $Param{Data}->{ $Key },
            );
        }
        # use value with return key
        else {
            $Return->{ $ReturnKey } = $Param{Data}->{ $Key };
        }
    }

    # return clean up data hash
    return $Return;
}

sub _ProcessReturnDataArray {
    my ( %Param ) = @_;

    # init return array
    my @Return = ();

    # process given array
    for my $Entry ( @{ $Param{Data} } ) {

        # check for hash ref in entry
        if ( ref( $Entry ) eq 'HASH' ) {
            push( @Return, _ProcessReturnDataHash(
                Data => $Entry,
            ));
        }
        # check for array ref in entry
        elsif ( ref( $Entry ) eq 'ARRAY' ) {
            push( @Return, _ProcessReturnDataArray(
                Data => $Entry,
            ));
        }
        # push entry to result
        else {
            push( @Return, $Entry );
        }
    }

    # return data array
    return \@Return;
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


