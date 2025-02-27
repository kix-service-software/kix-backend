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

use Kernel::System::VariableCheck qw(:all);

# get helper object
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# begin transaction on database
$Helper->BeginWork();

my @Tests = (
    {
        Name       => 'Execution without rules',
        Parameters => {
            KeepRules   => [],
            DeleteRules => [],
        },
        Expected   => {
            Success                 => 1,
            ArticleAttachmentIndex1 => [
                {
                    'Filename'    => 'file-2',
                    'ContentType' => 'text/html; charset="utf-8"',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'smime.asc',
                    'ContentType' => 'application/x-pkcs7',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'attachment1.1',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment1.2',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment1.3',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'inline1.1',
                    'ContentType' => 'image/bmp',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline1.2',
                    'ContentType' => 'image/png',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline1.3',
                    'ContentType' => 'image/jpeg',
                    'Disposition' => 'inline',
                },
            ],
            ArticleAttachmentIndex2 => [
                {
                    'Filename'    => 'file-2',
                    'ContentType' => 'text/html; charset="utf-8"',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'smime.asc',
                    'ContentType' => 'application/pkcs7',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment2.1',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment2.2',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment2.3',
                    'ContentType' => 'application/zip',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'inline2.1',
                    'ContentType' => 'image/bmp',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline2.2',
                    'ContentType' => 'image/png',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline2.3',
                    'ContentType' => 'image/jpeg',
                    'Disposition' => 'inline',
                },
            ],
        }
    },
    {
        Name       => 'Execution with invalid keep rule',
        Parameters => {
            KeepRules   => ['Test'],
            DeleteRules => [],
        },
        Expected   => {
            Success                 => 1,
            ArticleAttachmentIndex1 => [
                {
                    'Filename'    => 'file-2',
                    'ContentType' => 'text/html; charset="utf-8"',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'smime.asc',
                    'ContentType' => 'application/x-pkcs7',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'attachment1.1',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment1.2',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment1.3',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'inline1.1',
                    'ContentType' => 'image/bmp',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline1.2',
                    'ContentType' => 'image/png',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline1.3',
                    'ContentType' => 'image/jpeg',
                    'Disposition' => 'inline',
                },
            ],
            ArticleAttachmentIndex2 => [
                {
                    'Filename'    => 'file-2',
                    'ContentType' => 'text/html; charset="utf-8"',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'smime.asc',
                    'ContentType' => 'application/pkcs7',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment2.1',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment2.2',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment2.3',
                    'ContentType' => 'application/zip',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'inline2.1',
                    'ContentType' => 'image/bmp',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline2.2',
                    'ContentType' => 'image/png',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline2.3',
                    'ContentType' => 'image/jpeg',
                    'Disposition' => 'inline',
                },
            ],
        }
    },
    {
        Name       => 'Execution with invalid delete rule',
        Parameters => {
            KeepRules   => [],
            DeleteRules => ['Test'],
        },
        Expected   => {
            Success                 => 1,
            ArticleAttachmentIndex1 => [
                {
                    'Filename'    => 'file-2',
                    'ContentType' => 'text/html; charset="utf-8"',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'smime.asc',
                    'ContentType' => 'application/x-pkcs7',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'attachment1.1',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment1.2',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment1.3',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'inline1.1',
                    'ContentType' => 'image/bmp',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline1.2',
                    'ContentType' => 'image/png',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline1.3',
                    'ContentType' => 'image/jpeg',
                    'Disposition' => 'inline',
                },
            ],
            ArticleAttachmentIndex2 => [
                {
                    'Filename'    => 'file-2',
                    'ContentType' => 'text/html; charset="utf-8"',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'smime.asc',
                    'ContentType' => 'application/pkcs7',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment2.1',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment2.2',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment2.3',
                    'ContentType' => 'application/zip',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'inline2.1',
                    'ContentType' => 'image/bmp',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline2.2',
                    'ContentType' => 'image/png',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline2.3',
                    'ContentType' => 'image/jpeg',
                    'Disposition' => 'inline',
                },
            ],
        }
    },
    {
        Name       => 'Execution with valid keep rule - no match',
        Parameters => {
            KeepRules   => [
                ['^$','.+','.+']
            ],
            DeleteRules => [],
        },
        Expected   => {
            Success                 => 1,
            ArticleAttachmentIndex1 => [
                {
                    'Filename'    => 'file-2',
                    'ContentType' => 'text/html; charset="utf-8"',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'smime.asc',
                    'ContentType' => 'application/x-pkcs7',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'attachment1.1',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment1.2',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment1.3',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'inline1.1',
                    'ContentType' => 'image/bmp',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline1.2',
                    'ContentType' => 'image/png',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline1.3',
                    'ContentType' => 'image/jpeg',
                    'Disposition' => 'inline',
                },
            ],
            ArticleAttachmentIndex2 => [
                {
                    'Filename'    => 'file-2',
                    'ContentType' => 'text/html; charset="utf-8"',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'smime.asc',
                    'ContentType' => 'application/pkcs7',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment2.1',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment2.2',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment2.3',
                    'ContentType' => 'application/zip',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'inline2.1',
                    'ContentType' => 'image/bmp',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline2.2',
                    'ContentType' => 'image/png',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline2.3',
                    'ContentType' => 'image/jpeg',
                    'Disposition' => 'inline',
                },
            ],
        }
    },
    {
        Name       => 'Execution with valid delete rule - no match',
        Parameters => {
            KeepRules   => [],
            DeleteRules => [
                ['^$','.+','.+']
            ],
        },
        Expected   => {
            Success                 => 1,
            ArticleAttachmentIndex1 => [
                {
                    'Filename'    => 'file-2',
                    'ContentType' => 'text/html; charset="utf-8"',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'smime.asc',
                    'ContentType' => 'application/x-pkcs7',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'attachment1.1',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment1.2',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment1.3',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'inline1.1',
                    'ContentType' => 'image/bmp',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline1.2',
                    'ContentType' => 'image/png',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline1.3',
                    'ContentType' => 'image/jpeg',
                    'Disposition' => 'inline',
                },
            ],
            ArticleAttachmentIndex2 => [
                {
                    'Filename'    => 'file-2',
                    'ContentType' => 'text/html; charset="utf-8"',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'smime.asc',
                    'ContentType' => 'application/pkcs7',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment2.1',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment2.2',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment2.3',
                    'ContentType' => 'application/zip',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'inline2.1',
                    'ContentType' => 'image/bmp',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline2.2',
                    'ContentType' => 'image/png',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline2.3',
                    'ContentType' => 'image/jpeg',
                    'Disposition' => 'inline',
                },
            ],
        }
    },
    {
        Name       => 'Execution with valid keep and delete rule - both match',
        Parameters => {
            KeepRules   => [
                ['.+','.+','.+']
            ],
            DeleteRules => [
                ['.+','.+','.+']
            ],
        },
        Expected   => {
            Success                 => 1,
            ArticleAttachmentIndex1 => [
                {
                    'Filename'    => 'file-2',
                    'ContentType' => 'text/html; charset="utf-8"',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'smime.asc',
                    'ContentType' => 'application/x-pkcs7',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'attachment1.1',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment1.2',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment1.3',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'inline1.1',
                    'ContentType' => 'image/bmp',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline1.2',
                    'ContentType' => 'image/png',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline1.3',
                    'ContentType' => 'image/jpeg',
                    'Disposition' => 'inline',
                },
            ],
            ArticleAttachmentIndex2 => [
                {
                    'Filename'    => 'file-2',
                    'ContentType' => 'text/html; charset="utf-8"',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'smime.asc',
                    'ContentType' => 'application/pkcs7',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment2.1',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment2.2',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment2.3',
                    'ContentType' => 'application/zip',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'inline2.1',
                    'ContentType' => 'image/bmp',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline2.2',
                    'ContentType' => 'image/png',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline2.3',
                    'ContentType' => 'image/jpeg',
                    'Disposition' => 'inline',
                },
            ],
        }
    },
    {
        Name       => 'Execution with valid keep and delete rules - both match second rule',
        Parameters => {
            KeepRules   => [
                ['^$','.+','.+'],
                ['.+','.+','.+']
            ],
            DeleteRules => [
                ['^$','.+','.+'],
                ['.+','.+','.+']
            ],
        },
        Expected   => {
            Success                 => 1,
            ArticleAttachmentIndex1 => [
                {
                    'Filename'    => 'file-2',
                    'ContentType' => 'text/html; charset="utf-8"',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'smime.asc',
                    'ContentType' => 'application/x-pkcs7',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'attachment1.1',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment1.2',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment1.3',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'inline1.1',
                    'ContentType' => 'image/bmp',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline1.2',
                    'ContentType' => 'image/png',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline1.3',
                    'ContentType' => 'image/jpeg',
                    'Disposition' => 'inline',
                },
            ],
            ArticleAttachmentIndex2 => [
                {
                    'Filename'    => 'file-2',
                    'ContentType' => 'text/html; charset="utf-8"',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'smime.asc',
                    'ContentType' => 'application/pkcs7',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment2.1',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment2.2',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment2.3',
                    'ContentType' => 'application/zip',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'inline2.1',
                    'ContentType' => 'image/bmp',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline2.2',
                    'ContentType' => 'image/png',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline2.3',
                    'ContentType' => 'image/jpeg',
                    'Disposition' => 'inline',
                },
            ],
        }
    },
    {
        Name       => 'Execution with valid keep and delete rules - delete an attachment of article 1 by Filename',
        Parameters => {
            KeepRules   => [
                ['^(?:file-1|file-2|file-1.html)$','^text/(?:plain|html)','^inline$'],
                ['smime','^application\/(?:x-pkcs7|pkcs7)','.+']
            ],
            DeleteRules => [
                ['^attachment1\.1$','.+','.+']
            ],
        },
        Expected   => {
            Success                 => 1,
            ArticleAttachmentIndex1 => [
                {
                    'Filename'    => 'file-2',
                    'ContentType' => 'text/html; charset="utf-8"',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'smime.asc',
                    'ContentType' => 'application/x-pkcs7',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'attachment1.2',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment1.3',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'inline1.1',
                    'ContentType' => 'image/bmp',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline1.2',
                    'ContentType' => 'image/png',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline1.3',
                    'ContentType' => 'image/jpeg',
                    'Disposition' => 'inline',
                },
            ],
            ArticleAttachmentIndex2 => [
                {
                    'Filename'    => 'file-2',
                    'ContentType' => 'text/html; charset="utf-8"',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'smime.asc',
                    'ContentType' => 'application/pkcs7',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment2.1',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment2.2',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment2.3',
                    'ContentType' => 'application/zip',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'inline2.1',
                    'ContentType' => 'image/bmp',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline2.2',
                    'ContentType' => 'image/png',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline2.3',
                    'ContentType' => 'image/jpeg',
                    'Disposition' => 'inline',
                },
            ],
        }
    },
    {
        Name       => 'Execution with valid keep and delete rules - delete an attachment of both articles by Filename',
        Parameters => {
            KeepRules   => [
                ['^(?:file-1|file-2|file-1.html)$','^text/(?:plain|html)','^inline$'],
                ['smime','^application\/(?:x-pkcs7|pkcs7)','.+']
            ],
            DeleteRules => [
                ['^attachment\d\.2$','.+','.+']
            ],
        },
        Expected   => {
            Success                 => 1,
            ArticleAttachmentIndex1 => [
                {
                    'Filename'    => 'file-2',
                    'ContentType' => 'text/html; charset="utf-8"',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'smime.asc',
                    'ContentType' => 'application/x-pkcs7',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'attachment1.3',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'inline1.1',
                    'ContentType' => 'image/bmp',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline1.2',
                    'ContentType' => 'image/png',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline1.3',
                    'ContentType' => 'image/jpeg',
                    'Disposition' => 'inline',
                },
            ],
            ArticleAttachmentIndex2 => [
                {
                    'Filename'    => 'file-2',
                    'ContentType' => 'text/html; charset="utf-8"',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'smime.asc',
                    'ContentType' => 'application/pkcs7',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment2.1',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment2.3',
                    'ContentType' => 'application/zip',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'inline2.1',
                    'ContentType' => 'image/bmp',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline2.2',
                    'ContentType' => 'image/png',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline2.3',
                    'ContentType' => 'image/jpeg',
                    'Disposition' => 'inline',
                },
            ],
        }
    },
    {
        Name       => 'Execution with valid keep and delete rules - delete an attachment of article 2 by ContentType',
        Parameters => {
            KeepRules   => [
                ['^(?:file-1|file-2|file-1.html)$','^text/(?:plain|html)','^inline$'],
                ['smime','^application\/(?:x-pkcs7|pkcs7)','.+']
            ],
            DeleteRules => [
                ['.+','^application\/zip','.+']
            ],
        },
        Expected   => {
            Success                 => 1,
            ArticleAttachmentIndex1 => [
                {
                    'Filename'    => 'file-2',
                    'ContentType' => 'text/html; charset="utf-8"',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'smime.asc',
                    'ContentType' => 'application/x-pkcs7',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'attachment1.3',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'inline1.1',
                    'ContentType' => 'image/bmp',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline1.2',
                    'ContentType' => 'image/png',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline1.3',
                    'ContentType' => 'image/jpeg',
                    'Disposition' => 'inline',
                },
            ],
            ArticleAttachmentIndex2 => [
                {
                    'Filename'    => 'file-2',
                    'ContentType' => 'text/html; charset="utf-8"',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'smime.asc',
                    'ContentType' => 'application/pkcs7',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'attachment2.1',
                    'ContentType' => 'text/plain; charset="utf-8"',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'inline2.1',
                    'ContentType' => 'image/bmp',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline2.2',
                    'ContentType' => 'image/png',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline2.3',
                    'ContentType' => 'image/jpeg',
                    'Disposition' => 'inline',
                },
            ],
        }
    },
    {
        Name       => 'Execution with valid keep and delete rules - delete all Disposition "attachment" attachments',
        Parameters => {
            KeepRules   => [
                ['^(?:file-1|file-2|file-1.html)$','^text/(?:plain|html)','^inline$'],
                ['smime','^application\/(?:x-pkcs7|pkcs7)','.+']
            ],
            DeleteRules => [
                ['.+','.+','^attachment$']
            ],
        },
        Expected   => {
            Success                 => 1,
            ArticleAttachmentIndex1 => [
                {
                    'Filename'    => 'file-2',
                    'ContentType' => 'text/html; charset="utf-8"',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'smime.asc',
                    'ContentType' => 'application/x-pkcs7',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline1.1',
                    'ContentType' => 'image/bmp',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline1.2',
                    'ContentType' => 'image/png',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline1.3',
                    'ContentType' => 'image/jpeg',
                    'Disposition' => 'inline',
                },
            ],
            ArticleAttachmentIndex2 => [
                {
                    'Filename'    => 'file-2',
                    'ContentType' => 'text/html; charset="utf-8"',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'smime.asc',
                    'ContentType' => 'application/pkcs7',
                    'Disposition' => 'attachment',
                },
                {
                    'Filename'    => 'inline2.1',
                    'ContentType' => 'image/bmp',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline2.2',
                    'ContentType' => 'image/png',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'inline2.3',
                    'ContentType' => 'image/jpeg',
                    'Disposition' => 'inline',
                },
            ],
        }
    },
    {
        Name       => 'Execution with valid keep and delete rules - delete all non internal attachments',
        Parameters => {
            KeepRules   => [
                ['^(?:file-1|file-2|file-1.html)$','^text/(?:plain|html)','^inline$'],
                ['smime','^application\/(?:x-pkcs7|pkcs7)','.+']
            ],
            DeleteRules => [
                ['.+','.+','.+']
            ],
        },
        Expected   => {
            Success                 => 1,
            ArticleAttachmentIndex1 => [
                {
                    'Filename'    => 'file-2',
                    'ContentType' => 'text/html; charset="utf-8"',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'smime.asc',
                    'ContentType' => 'application/x-pkcs7',
                    'Disposition' => 'inline',
                },
            ],
            ArticleAttachmentIndex2 => [
                {
                    'Filename'    => 'file-2',
                    'ContentType' => 'text/html; charset="utf-8"',
                    'Disposition' => 'inline',
                },
                {
                    'Filename'    => 'smime.asc',
                    'ContentType' => 'application/pkcs7',
                    'Disposition' => 'attachment',
                },
            ],
        }
    },
    {
        Name       => 'Execution with valid keep and delete rules - delete all attachments',
        Parameters => {
            KeepRules   => [],
            DeleteRules => [
                ['.+','.+','.+']
            ],
        },
        Expected   => {
            Success                 => 1,
            ArticleAttachmentIndex1 => [],
            ArticleAttachmentIndex2 => [],
        }
    }
);

my ($TicketID, $ArticleID1, $ArticleID2) = _PrepareTicket();

if ( $TicketID ) {
    my ($MacroID, %MacroAction) = _PrepareMacro();

    if (
        $MacroID
        && %MacroAction
    ) {
        TEST:
        for my $Test ( @Tests ) {
            my $Success = $Kernel::OM->Get('Automation')->MacroActionUpdate(
                %MacroAction,
                Parameters => $Test->{Parameters},
                UserID     => 1,
            );
            $Self->True(
                $Success,
                $Test->{Name} . ': MacroActionUpdate',
            );
            next TEST if ( !$Success );

            $Success = $Kernel::OM->Get('Automation')->MacroExecute(
                ID       => $MacroID,
                ObjectID => $TicketID,
                UserID   => 1,
            );
            $Self->Is(
                $Success,
                $Test->{Expected}->{Success},
                $Test->{Name} . ': MacroExecute',
            );
            next TEST if ( !$Success );

            my %ArticleAttachmentIndex1 = $Kernel::OM->Get('Ticket')->ArticleAttachmentIndexRaw(
                ArticleID => $ArticleID1,
                UserID    => 1,
            );
            my @ArticleAttachmentIndex1 = values( %ArticleAttachmentIndex1 );
            for my $Attachment ( @ArticleAttachmentIndex1 ) {
                delete( $Attachment->{ID} );
                delete( $Attachment->{Filesize} );
                delete( $Attachment->{FilesizeRaw} );
                delete( $Attachment->{ContentID} );
                delete( $Attachment->{ContentAlternative} );
            }
            $Self->IsDeeply(
                \@ArticleAttachmentIndex1,
                $Test->{Expected}->{ArticleAttachmentIndex1},
                $Test->{Name} . ': ArticleAttachmentIndex1',
                1
            );

            my %ArticleAttachmentIndex2 = $Kernel::OM->Get('Ticket')->ArticleAttachmentIndexRaw(
                ArticleID => $ArticleID2,
                UserID    => 1,
            );
            my @ArticleAttachmentIndex2 = values( %ArticleAttachmentIndex2 );
            for my $Attachment ( @ArticleAttachmentIndex2 ) {
                delete( $Attachment->{ID} );
                delete( $Attachment->{Filesize} );
                delete( $Attachment->{FilesizeRaw} );
                delete( $Attachment->{ContentID} );
                delete( $Attachment->{ContentAlternative} );
            }
            $Self->IsDeeply(
                \@ArticleAttachmentIndex2,
                $Test->{Expected}->{ArticleAttachmentIndex2},
                $Test->{Name} . ': ArticleAttachmentIndex2',
                1
            );
        }
    }
}

sub _PrepareTicket {
    my $ContactID = $Kernel::OM->Get('Contact')->ContactAdd(
        Firstname             => 'Unit',
        Lastname              => 'Test',
        Email                 => 'unit.test@kixdesk.com',
        ValidID               => 1,
        UserID                => 1
    );
    $Self->True(
        $ContactID,
        '_PrepareTicket - create Contact',
    );
    return if ( !$ContactID );

    my $TicketID = $Kernel::OM->Get('Ticket')->TicketCreate(
        Title     => 'UnitTest',
        OwnerID   => 1,
        Queue     => 'Junk',
        Lock      => 'unlock',
        Priority  => '3 normal',
        State     => 'closed',
        UserID    => 1,
        ContactID => $ContactID
    );
    $Self->True(
        $TicketID,
        '_PrepareTicket - create Ticket'
    );
    return if ( !$TicketID );

    my $ArticleID1 = $Kernel::OM->Get('Ticket')->ArticleCreate(
        TicketID         => $TicketID,
        ChannelID        => 1,
        CustomerVisible  => 0,
        SenderType       => 'agent',
        Subject          => 'UnitTest',
        Body             => '<p>UnitTest<p>',
        Charset          => 'utf-8',
        MimeType         => 'text/html; charset="utf-8"',
        HistoryType      => 'AddNote',
        HistoryComment   => 'unit test article!',
        UserID           => 1
    );
    $Self->True(
        $ArticleID1,
        '_PrepareTicket - create first Article'
    );
    return if ( !$ArticleID1 );

    my $AttachmentID = $Kernel::OM->Get('Ticket')->ArticleWriteAttachment(
        ArticleID   => $ArticleID1,
        Filename    => 'smime.asc',
        ContentType => 'application/x-pkcs7',
        Content     => 'Test',
        Disposition => 'inline',
        UserID      => 1
    );
    $Self->True(
        $AttachmentID,
        '_PrepareTicket - create Attachment smime.asc'
    );
    return if ( !$AttachmentID );

    $AttachmentID = $Kernel::OM->Get('Ticket')->ArticleWriteAttachment(
        ArticleID   => $ArticleID1,
        Filename    => 'attachment1.1',
        ContentType => 'text/plain; charset="utf-8"',
        Content     => 'Test',
        Disposition => 'attachment',
        UserID      => 1
    );
    $Self->True(
        $AttachmentID,
        '_PrepareTicket - create Attachment attachment1.1'
    );
    return if ( !$AttachmentID );

    $AttachmentID = $Kernel::OM->Get('Ticket')->ArticleWriteAttachment(
        ArticleID   => $ArticleID1,
        Filename    => 'attachment1.2',
        ContentType => 'text/plain; charset="utf-8"',
        Content     => 'Test',
        Disposition => 'attachment',
        UserID      => 1
    );
    $Self->True(
        $AttachmentID,
        '_PrepareTicket - create Attachment attachment1.2'
    );
    return if ( !$AttachmentID );

    $AttachmentID = $Kernel::OM->Get('Ticket')->ArticleWriteAttachment(
        ArticleID   => $ArticleID1,
        Filename    => 'attachment1.3',
        ContentType => 'text/plain; charset="utf-8"',
        Content     => 'Test',
        Disposition => 'attachment',
        UserID      => 1
    );
    $Self->True(
        $AttachmentID,
        '_PrepareTicket - create Attachment attachment1.3'
    );
    return if ( !$AttachmentID );

    $AttachmentID = $Kernel::OM->Get('Ticket')->ArticleWriteAttachment(
        ArticleID   => $ArticleID1,
        Filename    => 'inline1.1',
        ContentType => 'image/bmp',
        Content     => 'Test',
        Disposition => 'inline',
        UserID      => 1
    );
    $Self->True(
        $AttachmentID,
        '_PrepareTicket - create Attachment inline1.1'
    );
    return if ( !$AttachmentID );

    $AttachmentID = $Kernel::OM->Get('Ticket')->ArticleWriteAttachment(
        ArticleID   => $ArticleID1,
        Filename    => 'inline1.2',
        ContentType => 'image/png',
        Content     => 'Test',
        Disposition => 'inline',
        UserID      => 1
    );
    $Self->True(
        $AttachmentID,
        '_PrepareTicket - create Attachment inline1.2'
    );
    return if ( !$AttachmentID );

    $AttachmentID = $Kernel::OM->Get('Ticket')->ArticleWriteAttachment(
        ArticleID   => $ArticleID1,
        Filename    => 'inline1.3',
        ContentType => 'image/jpeg',
        Content     => 'Test',
        Disposition => 'inline',
        UserID      => 1
    );
    $Self->True(
        $AttachmentID,
        '_PrepareTicket - create Attachment inline1.3'
    );
    return if ( !$AttachmentID );

    my $ArticleID2 = $Kernel::OM->Get('Ticket')->ArticleCreate(
        TicketID         => $TicketID,
        ChannelID        => 1,
        CustomerVisible  => 0,
        SenderType       => 'agent',
        Subject          => 'UnitTest',
        Body             => '<p>UnitTest<p>',
        Charset          => 'utf-8',
        MimeType         => 'text/html; charset="utf-8"',
        HistoryType      => 'AddNote',
        HistoryComment   => 'unit test article!',
        UserID           => 1
    );
    $Self->True(
        $ArticleID2,
        '_PrepareTicket - create second Article'
    );
    return if ( !$ArticleID2 );

    $AttachmentID = $Kernel::OM->Get('Ticket')->ArticleWriteAttachment(
        ArticleID   => $ArticleID2,
        Filename    => 'smime.asc',
        ContentType => 'application/pkcs7',
        Content     => 'Test',
        Disposition => 'attachment',
        UserID      => 1
    );
    $Self->True(
        $AttachmentID,
        '_PrepareTicket - create Attachment smime.asc'
    );
    return if ( !$AttachmentID );

    $AttachmentID = $Kernel::OM->Get('Ticket')->ArticleWriteAttachment(
        ArticleID   => $ArticleID2,
        Filename    => 'attachment2.1',
        ContentType => 'text/plain; charset="utf-8"',
        Content     => 'Test',
        Disposition => 'attachment',
        UserID      => 1
    );
    $Self->True(
        $AttachmentID,
        '_PrepareTicket - create Attachment attachment2.1'
    );
    return if ( !$AttachmentID );

    $AttachmentID = $Kernel::OM->Get('Ticket')->ArticleWriteAttachment(
        ArticleID   => $ArticleID2,
        Filename    => 'attachment2.2',
        ContentType => 'text/plain; charset="utf-8"',
        Content     => 'Test',
        Disposition => 'attachment',
        UserID      => 1
    );
    $Self->True(
        $AttachmentID,
        '_PrepareTicket - create Attachment attachment2.2'
    );
    return if ( !$AttachmentID );

    $AttachmentID = $Kernel::OM->Get('Ticket')->ArticleWriteAttachment(
        ArticleID   => $ArticleID2,
        Filename    => 'attachment2.3',
        ContentType => 'application/zip',
        Content     => 'Test',
        Disposition => 'attachment',
        UserID      => 1
    );
    $Self->True(
        $AttachmentID,
        '_PrepareTicket - create Attachment attachment2.3'
    );
    return if ( !$AttachmentID );

    $AttachmentID = $Kernel::OM->Get('Ticket')->ArticleWriteAttachment(
        ArticleID   => $ArticleID2,
        Filename    => 'inline2.1',
        ContentType => 'image/bmp',
        Content     => 'Test',
        Disposition => 'inline',
        UserID      => 1
    );
    $Self->True(
        $AttachmentID,
        '_PrepareTicket - create Attachment inline2.1'
    );
    return if ( !$AttachmentID );

    $AttachmentID = $Kernel::OM->Get('Ticket')->ArticleWriteAttachment(
        ArticleID   => $ArticleID2,
        Filename    => 'inline2.2',
        ContentType => 'image/png',
        Content     => 'Test',
        Disposition => 'inline',
        UserID      => 1
    );
    $Self->True(
        $AttachmentID,
        '_PrepareTicket - create Attachment inline2.2'
    );
    return if ( !$AttachmentID );

    $AttachmentID = $Kernel::OM->Get('Ticket')->ArticleWriteAttachment(
        ArticleID   => $ArticleID2,
        Filename    => 'inline2.3',
        ContentType => 'image/jpeg',
        Content     => 'Test',
        Disposition => 'inline',
        UserID      => 1
    );
    $Self->True(
        $AttachmentID,
        '_PrepareTicket - create Attachment inline2.3'
    );
    return if ( !$AttachmentID );

    return ($TicketID, $ArticleID1, $ArticleID2);
}

sub _PrepareMacro {
    my $MacroID = $Kernel::OM->Get('Automation')->MacroAdd(
        Name    => 'UnitTest',
        Type    => 'Ticket',
        ValidID => 1,
        UserID  => 1,
    );
    $Self->True(
        $MacroID,
        '_PrepareMacro - create Macro',
    );
    return if ( !$MacroID );

    my $MacroActionID = $Kernel::OM->Get('Automation')->MacroActionAdd(
        MacroID    => $MacroID,
        Type       => 'ArticleAttachmentsDelete',
        Parameters => {
            KeepRules   => [],
            DeleteRules => [],
        },
        ValidID    => 1,
        UserID     => 1,
    );
    $Self->True(
        $MacroActionID,
        '_PrepareMacro - create MacroAction',
    );
    return if ( !$MacroActionID );

    my $Success = $Kernel::OM->Get('Automation')->MacroUpdate(
        ID        => $MacroID,
        ExecOrder => [ $MacroActionID ],
        UserID    => 1,
    );
    $Self->True(
        $Success,
        '_PrepareMacro - update ExecOrder',
    );
    return if ( !$Success );

    my %MacroAction = $Kernel::OM->Get('Automation')->MacroActionGet(
        ID => $MacroActionID,
    );

    return ($MacroID, %MacroAction);
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
