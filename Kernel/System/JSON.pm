# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::JSON;

use strict;
use warnings;

use JSON::MaybeXS qw(is_bool);

our @ObjectDependencies = (
    'Log',
);

=head1 NAME

Kernel::System::JSON - the JSON wrapper lib

=head1 SYNOPSIS

Functions for encoding perl data structures to JSON.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create a JSON object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $JSONObject = $Kernel::OM->Get('JSON');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item Encode()

Encode a perl data structure to a JSON string.

    my $JSONString = $JSONObject->Encode(
        Data     => $Data,
        SortKeys => 1,          # (optional) (0|1) default 0, to sort the keys of the json data
        Pretty   => 1,          # (optional) (0|1) default 0, to pretty print the json data
    );

=cut

sub Encode {
    my ( $Self, %Param ) = @_;

    # create json object
    my $JSONObject = JSON::MaybeXS->new();

    $JSONObject->allow_nonref(1);

    # sort the keys of the JSON data
    if ( $Param{SortKeys} ) {
        $JSONObject->canonical( [1] );
    }

    # pretty print the JSON data
    if ( $Param{Pretty} ) {
        $JSONObject->pretty( [1,1,1] );
    }

    # get JSON-encoded presentation of perl structure
    my $JSONEncoded = $JSONObject->encode( $Param{Data} ) || '""';

    # Special handling for unicode line terminators (\u2028 and \u2029),
    # they are allowed in JSON but not in JavaScript
    # see: http://timelessrepo.com/json-isnt-a-javascript-subset
    #
    # Should be fixed in JSON module, but bug report is still open
    # see: https://rt.cpan.org/Public/Bug/Display.html?id=75755
    #
    # Therefore must be encoded manually
    $JSONEncoded =~ s/\x{2028}/\\u2028/xmsg;
    $JSONEncoded =~ s/\x{2029}/\\u2029/xmsg;

    # Special handling for unicode ampersand (\u0026),
    $JSONEncoded =~ s/\x{0026}/\\u0026/xmsg;

    return $JSONEncoded;
}

=item Decode()

Decode a JSON string to a perl data structure.

    my $PerlStructureScalar = $JSONObject->Decode(
        Data => $JSONString,
    );

=cut

sub Decode {
    my ( $Self, %Param ) = @_;

    # check for needed data
    return if !defined $Param{Data};

    # create json object
    my $JSONObject = JSON::MaybeXS->new();

    $JSONObject->allow_nonref(1);

    # decode JSON encoded to perl structure
    my $Scalar;

    # use eval here, as JSON::XS->decode() dies when providing a malformed JSON string
    if ( !eval { $Scalar = $JSONObject->decode( $Param{Data} ) } ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'Decoding the JSON string failed: ' . $@,
            );
        }
        return;
    }

    # sanitize leftover boolean objects
    $Scalar = $Self->_BooleansProcess(
        JSON => $Scalar,
    );

    return $Scalar;
}

=item True()

returns a constant that can be mapped to a boolean true value
in JSON rather than a string with "true".

    my $TrueConstant = $JSONObject->True();

    my $TrueJS = $JSONObject->Encode(
        Data => $TrueConstant,
    );

This will return the string 'true'.
If you pass the perl string 'true' to JSON, it will return '"true"'
as a JavaScript string instead.

=cut

sub True {

    # Use constant instead of JSON::false() as this can cause nasty problems with JSON::XS on some platforms.
    # (encountered object '1', but neither allow_blessed, convert_blessed nor allow_tags settings are enabled)
    return \1;
}

=item False()

like C<True()>, but for a false boolean value.

=cut

sub False {

    # Use constant instead of JSON::false() as this can cause nasty problems with JSON::XS on some platforms.
    # (encountered object '0', but neither allow_blessed, convert_blessed nor allow_tags settings are enabled)
    return \0;
}

=item Jq()

Execute jq

    my $JSON = $JSONObject->Jq(
        Data   => $JSONString,
        Filter => $JqFilter,
    );

=cut

sub Jq {
    my ( $Self, %Param ) = @_;

    # check for needed data
    return if !defined $Param{Data} || !$Param{Filter};

    # store files
    my ($DataFH, $DataFilename) = $Kernel::OM->Get('FileTemp')->TempFile(
        Suffix => '.json'
    );
    my ($FilterFH, $FilterFilename) = $Kernel::OM->Get('FileTemp')->TempFile(
        Suffix => '.filter'
    );

    binmode($DataFH, ':encoding(UTF-8)');
    print {$DataFH} $Param{Data};
    close $DataFH;

    binmode($FilterFH, ':encoding(UTF-8)');
    print {$FilterFH} $Param{Filter};
    close $FilterFH;

    my $Value = `jq -rf $FilterFilename $DataFilename`;
    chomp($Value);

    # special characters must be re-encoded because the result is decoded twice after the system call
    $Kernel::OM->Get('Encode')->EncodeInput( \$Value );

    return $Value;
}

=begin Internal:

=cut

=item _BooleansProcess()

decode boolean values leftover from JSON decoder to simple scalar values

    my $ProcessedJSON = $JSONObject->_BooleansProcess(
        JSON => $JSONData,
    );

=cut

sub _BooleansProcess {
    my ( $Self, %Param ) = @_;

    # convert scalars if needed
    if ( JSON::MaybeXS::is_bool( $Param{JSON} ) ) {
        $Param{JSON} = ( $Param{JSON} ? 1 : 0 );
    }

    # recurse into arrays
    elsif ( ref $Param{JSON} eq 'ARRAY' ) {

        for my $Value ( @{ $Param{JSON} } ) {
            $Value = $Self->_BooleansProcess(
                JSON => $Value,
            );
        }
    }

    # recurse into hashes
    elsif ( ref $Param{JSON} eq 'HASH' ) {

        for my $Value ( values %{ $Param{JSON} } ) {
            $Value = $Self->_BooleansProcess(
                JSON => $Value,
            );
        }
    }

    return $Param{JSON};
}

1;

=end Internal:





=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
