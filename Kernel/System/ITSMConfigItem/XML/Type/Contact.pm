# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ITSMConfigItem::XML::Type::Contact;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Contact',
    'Log',
);

=head1 NAME

Kernel::System::ITSMConfigItem::XML::Type::Contact - xml backend module

=head1 SYNOPSIS

All xml functions of customer objects

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $XMLTypeCustomerBackendObject = $Kernel::OM->Get('ITSMConfigItem::XML::Type::Contact');

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

    return '' if !$Param{Value};

    my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
        ID => $Param{Value}
    );

    if ( IsHashRefWithData( \%Contact ) ) {
        return $Contact{Fullname}
    }
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

    return if !defined $Param{Value};
    return $Param{Value};
}

=item ImportSearchValuePrepare()

prepare search value for import

    my $ArrayRef = $BackendObject->ImportSearchValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ImportSearchValuePrepare {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Value};
    return $Param{Value};
}

=item ImportValuePrepare()

prepare value for import

    my $Value = $BackendObject->ImportValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ImportValuePrepare {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Value};
    return $Param{Value};
}

=item ValidateValue()

validate given value for this particular attribute type

    my $Value = $BackendObject->ValidateValue(
        Value => ..., # (optional)
    );

=cut

sub ValidateValue {
    my ( $Self, %Param ) = @_;

    my $Value = $Param{Value};

    return if !$Value;

    my %ContactData = $Kernel::OM->Get('Contact')->ContactGet(
        ID => $Param{Value},
    );

    # if customer is not registered in the database
    if ( !IsHashRefWithData( \%ContactData ) ) {
        return 'contact not found';
    }

    # if ValidID is present, check if it is valid!
    if ( defined $ContactData{ValidID} ) {

        # return false if customer is not valid
        if ( $Kernel::OM->Get('Valid')->ValidLookup( ValidID => $ContactData{ValidID} ) ne 'valid' ) {
            return 'invalid contact';
        }
    }

    return 1;
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
