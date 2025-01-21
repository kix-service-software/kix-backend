# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ITSMConfigItem::XML::Type::TeamReference;

use strict;
use warnings;

our @ObjectDependencies = (
    'Log',
    'Queue'
);

=head1 NAME

Kernel::System::ITSMConfigItem::XML::Type::TeamReference - xml backend module

=head1 SYNOPSIS

All xml functions of TeamReference objects

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $XMLTypeDummyBackendObject = $Kernel::OM->Get('ITSMConfigItem::XML::Type::TeamReference');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item ValueLookup()

get the xml data of a version

    my $Value = $BackendObject->ValueLookup(
        Value => 11, # (optional)
    );

=cut

sub ValueLookup {
    my ( $Self, %Param ) = @_;

    # return empty string, when false value (undef, 0, empty string) is given
    return q{} if ( !$Param{Value} );

    # return given value, if given value is not a number
    return $Param{Value} if ( $Param{Value} =~ /\D/ );

    # lookup queue name
    my $QueueName = $Kernel::OM->Get('Queue')->QueueLookup(
        QueueID => $Param{Value},
        Silent  => 1,
    );
    return $QueueName if ( $QueueName );

    return $Param{Value};
}

=item ExportSearchValuePrepare()

prepare search value for export

    my $ArrayRef = $BackendObject->ExportSearchValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ExportSearchValuePrepare {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Value};
    return $Param{Value};
}

=item ExportValuePrepare()

prepare value for export

    my $Value = $BackendObject->ExportValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ExportValuePrepare {
    my ( $Self, %Param ) = @_;

    # nothing given?
    return if !defined $Param{Value};

    # empty value?
    return '' if !$Param{Value};

    # lookup queue name
    my $QueueName = $Kernel::OM->Get('Queue')->QueueLookup(
        QueueID => $Param{Value},
        Silent  => 1,
    );
    return $QueueName if ( $QueueName );

    return '';
}

=item ImportSearchValuePrepare()

prepare search value for import

    my $ArrayRef = $BackendObject->ImportSearchValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ImportSearchValuePrepare {
    my ( $Self, %Param ) = @_;

    # nothing given?
    return if !defined $Param{Value};

    # empty value?
    return '' if !$Param{Value};

    # check if Queue name was given
    my $QueueID = $Kernel::OM->Get('Queue')->QueueLookup(
        Queue  => $Param{Value},
        Silent => 1,
    );
    return $QueueID if ( $QueueID );

    # check if given value is a valid Queue ID
    if ( $Param{Value} !~ /\D/ ) {
        my $QueueName = $Kernel::OM->Get('Queue')->QueueLookup(
            QueueID => $Param{Value},
            Silent  => 1,
        );
        return $Param{Value} if ( $QueueName );
    }

    return '';
}

=item ImportValuePrepare()

prepare value for import

    my $Value = $BackendObject->ImportValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ImportValuePrepare {
    my ( $Self, %Param ) = @_;

    # nothing given?
    return if !defined $Param{Value};

    # empty value?
    return '' if !$Param{Value};

    # check if Queue name was given
    my $QueueID = $Kernel::OM->Get('Queue')->QueueLookup(
        Queue  => $Param{Value},
        Silent => 1,
    );
    return $QueueID if ( $QueueID );

    # check if given value is a valid Queue ID
    if ( $Param{Value} !~ /\D/ ) {
        my $QueueName = $Kernel::OM->Get('Queue')->QueueLookup(
            QueueID => $Param{Value},
            Silent  => 1,
        );
        return $Param{Value} if ( $QueueName );
    }

    return '';
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
