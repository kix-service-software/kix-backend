# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

# get needed objects
my $DBObject   = $Kernel::OM->Get('DB');
my $MainObject = $Kernel::OM->Get('Main');

# create database for tests
my $XML = '
<Table Name="test_md5_conversion">
    <Column Name="message_id" Required="true" Size="3800" Type="VARCHAR"/>
    <Column Name="message_id_md5" Required="false" Size="32" Type="VARCHAR"/>
</Table>
';
my @XMLARRAY = $Kernel::OM->Get('XML')->XMLParse( String => $XML );
my @SQL = $DBObject->SQLProcessor( Database => \@XMLARRAY );
$Self->True(
    $SQL[0],
    'SQLProcessor() CREATE TABLE',
);

for my $SQL (@SQL) {
    $Self->True(
        $DBObject->Do( SQL => $SQL ) || 0,
        "Do() CREATE TABLE ($SQL)",
    );
}

# create data
my %MessageIDs;
my $Success;

INSERT:
for ( 1 .. 10_000 ) {

    my $RandomString = $MainObject->GenerateRandomString( Length => 50 );
    $MessageIDs{$RandomString} = $MainObject->MD5sum( String => $RandomString );
    $Success = $DBObject->Do(
        SQL => 'INSERT INTO test_md5_conversion ( message_id )'
            . ' VALUES ( ? )',
        Bind => [ \$RandomString ],
    );
    last INSERT if !$Success;
}
$Self->True(
    $Success,
    'INSERT ok',
);

# conversion to MD5
if (
    $DBObject->GetDatabaseFunction('Type') eq 'mysql'
    || $DBObject->GetDatabaseFunction('Type') eq 'postgresql'
    )
{
    $Self->True(
        $DBObject->Do(
            SQL => 'UPDATE test_md5_conversion SET message_id_md5 = MD5(message_id)'
            )
            || 0,
        "UPDATE statement",
    );
}
else {

    my %MD5sum;
    $DBObject->Prepare(
        SQL => 'SELECT message_id, message_id_md5
                    FROM test_md5_conversion
                ',
    );
    MESSAGEID:
    while ( my @Row = $DBObject->FetchrowArray() ) {
        next MESSAGEID if !$Row[0];
        $MD5sum{ $Row[0] } = $MainObject->MD5sum( String => $Row[0] );
    }

    for my $MessageID ( sort keys %MD5sum ) {
        $DBObject->Do(
            SQL => "UPDATE test_md5_conversion
                     SET message_id_md5 = ?
                     WHERE message_id = ?",
            Bind => [ \$MD5sum{$MessageID}, \$MessageID ],
        );
    }

}

# test conversion
return if !$DBObject->Prepare(
    SQL => 'SELECT message_id, message_id_md5 FROM test_md5_conversion',
);

my $Result = 1;

RESULT:
while ( my @Row = $DBObject->FetchrowArray() ) {
    next RESULT if $Row[1] eq $MessageIDs{ $Row[0] };
    $Result = 0;
}

$Self->True(
    $Result,
    'Conversion result',
);

# cleanup
$Self->True(
    $DBObject->Do( SQL => 'DROP TABLE test_md5_conversion' ) || 0,
    "Do() DROP TABLE",
);

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
