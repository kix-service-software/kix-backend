# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Certificate;

use strict;
use warnings;

our @ObjectDependencies = qw(
    Config
    Cache
);

=head1 NAME

Kernel::System::Certificate - Certificate backend lib

=head1 SYNOPSIS

This is a sub module of Kernel::System::Certificate contains all Certificate functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{Debug} = $Param{Debug} || 0;

    return $Self;
}


=item CertificateCreate()

create a local certificate

    my $Success = $CryptObject->CertificateCreate(
        ## TODO: filling with parameters
    );

    return boolean?

=cut

sub CertificateCreate {
    my ( $Self, %Param ) = @_;

   return 1;
}

=item CertificateGet()

get a local certificate

    my $Certificate = $CryptObject->CertificateGet(

    );

=cut

sub CertificateGet {
    my ( $Self, %Param ) = @_;

    return {};
}

=item CertificateDelete()

remove a local certificate

    $CryptObject->CertificateDelete(

    );

=cut

sub CertificateDelete {
    my ( $Self, %Param ) = @_;

    return 1;
}

=item CertificateSearch()

get list of local certificates filenames

    my @CertList = $CryptObject->CertificateSearch();

=cut

sub CertificateSearch {
    my ( $Self, %Param ) = @_;

    my @CertList;

    return @CertList;
}

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
