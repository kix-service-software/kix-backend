# --
# Modified version of the work: Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
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

use Kernel::System::EmailParser;

my $Home = $Kernel::OM->Get('Config')->Get('Home');

# test for bug#1970
my $FileContent = $Kernel::OM->Get('Main')->FileRead(
    Location => "$Home/scripts/test/system/sample/EmailParser/DuplicateFilenameSpecialCharacters.box",
    Result   => 'ARRAY',
);

# create local object
my $EmailParserObject = Kernel::System::EmailParser->new(
    Email => $FileContent,
);

my @Attachments = $EmailParserObject->GetAttachments();
$Self->Is(
    scalar @Attachments,
    3,
    "Found 3 files (plain and both attachments)",
);

$Self->Is(
    $Attachments[1]->{Filename} || '',
    '[Terminology_Guide].pdf',
    "First attachment",
);

$Self->Is(
    $Attachments[2]->{Filename} || '',
    '[Terminology_Guide].pdf',
    "First attachment",
);

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
