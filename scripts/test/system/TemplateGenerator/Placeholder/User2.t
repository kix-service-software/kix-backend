# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get needed objects
my $ConfigObject  = $Kernel::OM->Get('Config');
my $UserObject    = $Kernel::OM->Get('User');
my $ContactObject = $Kernel::OM->Get('Contact');
my $DynamicFieldObject        = $Kernel::OM->Get('DynamicField');
my $DynamicFieldBackendObject = $Kernel::OM->Get('DynamicField::Backend');
my $TemplateGeneratorObject   = $Kernel::OM->Get('TemplateGenerator');

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

$Helper->BeginWork();

my %User = (
    UserLogin    => 'SomeLogin',
    UserPw       => 'somepass',
    ValidID      => 1,
    ChangeUserID => 1,
);
my $TestUserID = $UserObject->UserAdd(%User);
$Self->True(
    $TestUserID,
    'Create test user',
);

if ($TestUserID) {
    my %Contact = (
        Firstname             => 'firstname-test',
        Lastname              => 'lastname-test',
        Email                 => 'firstname.lastname@test.com',
        AssignedUserID        => $TestUserID,
        ValidID               => 1,
        UserID                => 1,
    );
    my $TestContactID = $ContactObject->ContactAdd(%Contact);
    $Self->True(
        $TestContactID,
        'Create test contact',
    );

    if ($TestContactID) {
        my $DynamicFieldName = 'TextDFTest' . $Helper->GetRandomNumber();
        my $DFSeparator = ' # ';
        my $DFID = $DynamicFieldObject->DynamicFieldAdd(
            Name            => $DynamicFieldName,
            Label           => $DynamicFieldName,
            InternalField   => 1,
            FieldType       => 'Text',
            ObjectType      => 'Contact',
            Config          => {
                CountDefault  => 1,
                CountMax      => 2,
                CountMin      => 0,
                ItemSeparator => ' # '
            },
            CustomerVisible => 0,
            ValidID         => 1,
            UserID          => 1,
            Comment         => 'testing purpose'
        );
        $Self->True(
            $DFID,
            'Create dynamic field',
        );

        if ($DFID) {
            my $DynamicField = $DynamicFieldObject->DynamicFieldGet(
                ID => $DFID
            );
            my $DFValue = ['Value1', 'Value2'];
            my $Success = $DynamicFieldBackendObject->ValueSet(
                DynamicFieldConfig => $DynamicField,
                ObjectID           => $TestContactID,
                Value              => $DFValue,
                UserID             => 1,
            );
            $Self->True(
                $Success,
                'Set dynamic field value',
            );

            # TODO: add tests for ONWER and RESPONSIBLE
            my @Tests = (
                {
                    Name => 'Current Login',
                    Text   => 'Current Login: <KIX_CURRENT_UserLogin>',
                    Result => 'Current Login: ' . $User{UserLogin},
                },
                {
                    Name => 'Current Firstname',
                    Text   => 'Current Firstname: <KIX_CURRENT_Firstname>',
                    Result => 'Current Firstname: ' . $Contact{Firstname},
                },
                {
                    Name => 'Current TextDF',
                    Text   => 'Current TextDF: <KIX_CURRENT_DynamicField_'.$DynamicFieldName.'>',
                    Result => 'Current TextDF: ' . join( $DFSeparator, @{$DFValue} ),
                },
            );

            for my $Test (@Tests) {
                my $Result = $TemplateGeneratorObject->_Replace(
                    Text        => $Test->{Text},
                    Data        => {},
                    UserID      => $TestUserID,
                    Translate   => 0
                );
                $Self->Is(
                    $Result,
                    $Test->{Result},
                    "$Test->{Name} - _Replace()",
                );
            }
        }
    }
}

# rollback transaction on database
$Helper->Rollback();

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
