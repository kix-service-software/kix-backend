# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Valid;

use strict;
use warnings;

our @ObjectDependencies = (
    'Cache',
    'DB',
    'Log',
);

=head1 NAME

Kernel::System::Valid - valid lib

=head1 SYNOPSIS

All valid functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $ValidObject = $Kernel::OM->Get('Valid');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{CacheType} = 'Valid';
    $Self->{CacheTTL}  = 60 * 60 * 24 * 20;

    return $Self;
}

=item ValidList()

return a valid list as hash

    my %List = $ValidObject->ValidList();

=cut

sub ValidList {
    my ( $Self, %Param ) = @_;

    # read cache
    my $CacheKey = 'ValidList';
    my $Cache    = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # get list from database
    return if !$DBObject->Prepare( SQL => 'SELECT id, name FROM valid' );

    # fetch the result
    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Data{ $Row[0] } = $Row[1];
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Data
    );

    return %Data;
}

=item ValidLookup()

returns the id or the name of a valid

    my $ValidID = $ValidObject->ValidLookup(
        Valid => 'valid',
    );

    my $Valid = $ValidObject->ValidLookup(
        ValidID => 1,
    );

=cut

sub ValidLookup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Valid} && !$Param{ValidID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need Valid or ValidID!',
        );
        return;
    }

    # get (already cached) valid list
    my %ValidList = $Self->ValidList();

    my $Key;
    my $Value;
    my $ReturnData;
    if ( $Param{ValidID} ) {
        $Key        = 'ValidID';
        $Value      = $Param{ValidID};
        $ReturnData = $ValidList{ $Param{ValidID} };
    }
    else {
        $Key   = 'Valid';
        $Value = $Param{Valid};
        my %ValidListReverse = reverse %ValidList;
        $ReturnData = $ValidListReverse{ $Param{Valid} };
    }

    # check if data exists
    if ( !defined $ReturnData ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "No $Key for $Value found!",
            );
        }
        return;
    }

    return $ReturnData;
}

=item ValidIDsGet()

return all valid ids as array

    my @List = $ValidObject->ValidIDsGet();

=cut

sub ValidIDsGet {
    my ( $Self, %Param ) = @_;

    my $ValidID = $Self->ValidLookup(
        Valid => 'valid',
    );

    return if !$ValidID;
    return ($ValidID);
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
