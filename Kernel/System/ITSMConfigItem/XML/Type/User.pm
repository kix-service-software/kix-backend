# --
# Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ITSMConfigItem::XML::Type::User;

use strict;
use warnings;

our @ObjectDependencies = (
    'Log',
    'User'
);

=head1 NAME

Kernel::System::ITSMConfigItem::XML::Type::User - xml backend module

=head1 SYNOPSIS

All xml functions of User objects

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $XMLTypeDummyBackendObject = $Kernel::OM->Get('ITSMConfigItem::XML::Type::User');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{LogObject}  = $Kernel::OM->Get('Log');
    $Self->{UserObject} = $Kernel::OM->Get('User');
    $Self->{ContactObject} = $Kernel::OM->Get('Contact');

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

    # get User data
    my %ContactInfo = $Self->{ContactObject}->ContactGet(
        UserID => $Param{Value},
    );
    my $UserName = '';
    if (%ContactInfo) {
        $UserName = '"'
            . $ContactInfo{Firstname} . ' '
            . $ContactInfo{Lastname} . '" <'
            . $ContactInfo{Email} . '>';
    }

    return $UserName || '';

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

    my %UserData = $Self->{UserObject}->GetUserData(
        UserID => $Param{Value},
    );

    $Self->{LogObject}->Log(
        Priority => 'error',
        Message  => "No user found for ID <$Param{Value}>!"
    );

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

    my %UserData = $Self->{UserObject}->GetUserData(
        UserID => $Param{Value},
    );

    $Self->{LogObject}->Log(
        Priority => 'error',
        Message  => "No user found for ID <$Param{Value}>!"
    );

    return $UserData{UserLogin} || '';
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

    my %UserData = $Self->{UserObject}->GetUserData(
        User => $Param{Value},
    );

    if ( !$UserData{UserID} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "No user found for login <$Param{Value}>!"
        );
        return;
    }

    return $UserData{UserID};
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

    my %UserData = $Self->{UserObject}->GetUserData(
        User => $Param{Value},
    );

    if ( !$UserData{UserID} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "No user found for login <$Param{Value}>!"
        );
        return;
    }

    return $UserData{UserID};
}

1;


=head1 VERSION

$Revision$ $Date$

=cut




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
