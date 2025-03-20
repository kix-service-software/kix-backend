#!/usr/bin/perl
# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/ 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;

use File::Basename;
use FindBin qw($Bin);
use lib dirname($Bin);
use lib dirname($Bin) . '/Kernel/cpan-lib';

use Kernel::System::ObjectManager;
use Kernel::System::VariableCheck qw(:all);

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Log' => {
        LogPrefix => 'framework_update-to-build-1437',
    },
);

use vars qw(%INC);

# update initial report
_UpdateReports();
_FixAutoIncrementIDs();

sub _UpdateReports {
    my ( $Self, %Param ) = @_;

    my $LogObject  = $Kernel::OM->Get('Log');
    my $ReportingObject = $Kernel::OM->Get('Reporting');

    my @UpdateReports = (
        {
            Name   => 'Tickets Created In Date Range',
            OldSQL => 'base64(U0VMRUNUIHR0Lm5hbWUgQVMgIlR5cGUiLCAKICAgICAgIHQudG4gQVMgIlROUiIsIAogICAgICAgdC50aXRsZSBBUyAiVGl0bGUiLCAKICAgICAgIHRzLm5hbWUgQVMgIlN0YXRlIiwKICAgICAgIG8ubmFtZSBBUyAiT3JnYW5pc2F0aW9uIiwgCiAgICAgICBjLmVtYWlsIEFTICJDb250YWN0IiwgCiAgICAgICB0LmFjY291bnRlZF90aW1lIEFTICJBY2NvdW50ZWQgVGltZSIKJHtGdW5jdGlvbnMuaWZfcGx1Z2luX2F2YWlsYWJsZSgnS0lYUHJvJywnLAogICAgIGRmdi52YWx1ZV90ZXh0IEFTICJDbG9zZSBDb2RlIiwKICAgICBzbGFfcmVzcG9uc2UubmFtZSBBUyAiU0xBIFJlc3BvbnNlIE5hbWUiLAogICAgIHRzY19yZXNwb25zZS50YXJnZXRfdGltZSBBUyAiU0xBIFJlc3BvbnNlIFRhcmdldCBUaW1lIiwgCiAgICAgdHNjX3Jlc3BvbnNlLmZ1bGZpbGxtZW50X3RpbWUgQVMgIlNMQSBSZXNwb25zZSBGdWxmaWxsbWVudCBUaW1lIiwgCiAgICAgdHNjX3Jlc3BvbnNlLnRpbWVfZGV2aWF0aW9uX2J1c2luZXNzIEFTICJTTEEgUmVzcG9uc2UgQnVzaW5lc3MgVGltZSBEZXZpYXRpb24iLAogICAgIHNsYV9zb2x1dGlvbi5uYW1lIEFTICJTTEEgU29sdXRpb24gTmFtZSIsCiAgICAgdHNjX3NvbHV0aW9uLnRhcmdldF90aW1lIEFTICJTTEEgU29sdXRpb24gVGFyZ2V0IFRpbWUiLCAKICAgICB0c2Nfc29sdXRpb24uZnVsZmlsbG1lbnRfdGltZSBBUyAiU0xBIFNvbHV0aW9uIEZ1bGZpbGxtZW50IFRpbWUiLCAKICAgICB0c2Nfc29sdXRpb24udGltZV9kZXZpYXRpb25fYnVzaW5lc3MgQVMgIlNMQSBTb2x1dGlvbiBCdXNpbmVzcyBUaW1lIERldmlhdGlvbiIKJyl9CiAgRlJPTSBvcmdhbmlzYXRpb24gbywgCiAgICAgICBjb250YWN0IGMsIAogICAgICAgdGlja2V0X3N0YXRlIHRzLAogICAgICAgdGlja2V0X3R5cGUgdHQsIAogICAgICAgdGlja2V0IHQKJHtGdW5jdGlvbnMuaWZfcGx1Z2luX2F2YWlsYWJsZSgnS0lYUHJvJywnCiAgTEVGVCBPVVRFUiBKT0lOIGR5bmFtaWNfZmllbGQgZGYgT04gKGRmLm5hbWUgPSAnQ2xvc2VDb2RlJykKICBMRUZUIE9VVEVSIEpPSU4gZHluYW1pY19maWVsZF92YWx1ZSBkZnYgT04gKGRmdi5vYmplY3RfaWQgPSB0LmlkIEFORCBkZnYuZmllbGRfaWQgPSBkZi5pZCkKICBMRUZUIE9VVEVSIEpPSU4gdGlja2V0X3NsYV9jcml0ZXJpb24gdHNjX3Jlc3BvbnNlIE9OICh0c2NfcmVzcG9uc2UudGlja2V0X2lkID0gdC5pZCBBTkQgdHNjX3Jlc3BvbnNlLm5hbWUgPSAnUmVzcG9uc2UnKQogIExFRlQgT1VURVIgSk9JTiBzbGEgQVMgc2xhX3Jlc3BvbnNlIE9OICh0c2NfcmVzcG9uc2Uuc2xhX2lkID0gc2xhX3Jlc3BvbnNlLmlkKQogIExFRlQgT1VURVIgSk9JTiB0aWNrZXRfc2xhX2NyaXRlcmlvbiB0c2Nfc29sdXRpb24gT04gKHRzY19zb2x1dGlvbi50aWNrZXRfaWQgPSB0LmlkIEFORCB0c2Nfc29sdXRpb24ubmFtZSA9ICdTb2x1dGlvbicpCiAgTEVGVCBPVVRFUiBKT0lOIHNsYSBBUyBzbGFfc29sdXRpb24gT04gKHRzY19zb2x1dGlvbi5zbGFfaWQgPSBzbGFfc29sdXRpb24uaWQpCicpfQogV0hFUkUgdC50eXBlX2lkID0gdHQuaWQKICAgQU5EIHQudGlja2V0X3N0YXRlX2lkID0gdHMuaWQKICAgQU5EIHQub3JnYW5pc2F0aW9uX2lkID0gby5pZAogICBBTkQgdC5jb250YWN0X2lkID0gYy5pZAogICBBTkQgby5pZCBJTiAoJHtQYXJhbWV0ZXJzLk9yZ2FuaXNhdGlvbklETGlzdH0pCiAgIEFORCB0LmNyZWF0ZV90aW1lIEJFVFdFRU4gJyR7UGFyYW1ldGVycy5TdGFydERhdGV9IDAwOjAwOjAwJyBBTkQgJyR7UGFyYW1ldGVycy5FbmREYXRlfSAyMzo1OTo1OScKIE9SREVSIEJZIHR0Lm5hbWUsIHQudG4=)',
            NewSQL => 'base64(U0VMRUNUIHR0Lm5hbWUgQVMgIlR5cGUiLCAKICAgICAgIHQudG4gQVMgIlROUiIsIAogICAgICAgdC50aXRsZSBBUyAiVGl0bGUiLCAKICAgICAgIHRzLm5hbWUgQVMgIlN0YXRlIiwKICAgICAgIG8ubmFtZSBBUyAiT3JnYW5pc2F0aW9uIiwgCiAgICAgICBjLmVtYWlsIEFTICJDb250YWN0IiwgCiAgICAgICB0LmFjY291bnRlZF90aW1lIEFTICJBY2NvdW50ZWQgVGltZSIKJHtGdW5jdGlvbnMuaWZfcGx1Z2luX2F2YWlsYWJsZSgnS0lYUHJvJywnLAogICAgIGRmdi52YWx1ZV90ZXh0IEFTICJDbG9zZSBDb2RlIiwKICAgICBzbGFfcmVzcG9uc2UubmFtZSBBUyAiU0xBIFJlc3BvbnNlIE5hbWUiLAogICAgIHRzY19yZXNwb25zZS50YXJnZXRfdGltZSBBUyAiU0xBIFJlc3BvbnNlIFRhcmdldCBUaW1lIiwgCiAgICAgdHNjX3Jlc3BvbnNlLmZ1bGZpbGxtZW50X3RpbWUgQVMgIlNMQSBSZXNwb25zZSBGdWxmaWxsbWVudCBUaW1lIiwgCiAgICAgdHNjX3Jlc3BvbnNlLnRpbWVfZGV2aWF0aW9uX2J1c2luZXNzIEFTICJTTEEgUmVzcG9uc2UgQnVzaW5lc3MgVGltZSBEZXZpYXRpb24iLAogICAgIHNsYV9zb2x1dGlvbi5uYW1lIEFTICJTTEEgU29sdXRpb24gTmFtZSIsCiAgICAgdHNjX3NvbHV0aW9uLnRhcmdldF90aW1lIEFTICJTTEEgU29sdXRpb24gVGFyZ2V0IFRpbWUiLCAKICAgICB0c2Nfc29sdXRpb24uZnVsZmlsbG1lbnRfdGltZSBBUyAiU0xBIFNvbHV0aW9uIEZ1bGZpbGxtZW50IFRpbWUiLCAKICAgICB0c2Nfc29sdXRpb24udGltZV9kZXZpYXRpb25fYnVzaW5lc3MgQVMgIlNMQSBTb2x1dGlvbiBCdXNpbmVzcyBUaW1lIERldmlhdGlvbiIKJyl9CiAgRlJPTSBvcmdhbmlzYXRpb24gbywgCiAgICAgICBjb250YWN0IGMsIAogICAgICAgdGlja2V0X3N0YXRlIHRzLAogICAgICAgdGlja2V0X3R5cGUgdHQsIAogICAgICAgdGlja2V0IHQKJHtGdW5jdGlvbnMuaWZfcGx1Z2luX2F2YWlsYWJsZSgnS0lYUHJvJywnCiAgTEVGVCBPVVRFUiBKT0lOIGR5bmFtaWNfZmllbGQgZGYgT04gKGRmLm5hbWUgPSAnQ2xvc2VDb2RlJykKICBMRUZUIE9VVEVSIEpPSU4gZHluYW1pY19maWVsZF92YWx1ZSBkZnYgT04gKGRmdi5vYmplY3RfaWQgPSB0LmlkIEFORCBkZnYuZmllbGRfaWQgPSBkZi5pZCkKICBMRUZUIE9VVEVSIEpPSU4gdGlja2V0X3NsYV9jcml0ZXJpb24gdHNjX3Jlc3BvbnNlIE9OICh0c2NfcmVzcG9uc2UudGlja2V0X2lkID0gdC5pZCBBTkQgdHNjX3Jlc3BvbnNlLm5hbWUgPSAnRmlyc3RSZXNwb25zZScpCiAgTEVGVCBPVVRFUiBKT0lOIHNsYSBBUyBzbGFfcmVzcG9uc2UgT04gKHRzY19yZXNwb25zZS5zbGFfaWQgPSBzbGFfcmVzcG9uc2UuaWQpCiAgTEVGVCBPVVRFUiBKT0lOIHRpY2tldF9zbGFfY3JpdGVyaW9uIHRzY19zb2x1dGlvbiBPTiAodHNjX3NvbHV0aW9uLnRpY2tldF9pZCA9IHQuaWQgQU5EIHRzY19zb2x1dGlvbi5uYW1lID0gJ1NvbHV0aW9uJykKICBMRUZUIE9VVEVSIEpPSU4gc2xhIEFTIHNsYV9zb2x1dGlvbiBPTiAodHNjX3NvbHV0aW9uLnNsYV9pZCA9IHNsYV9zb2x1dGlvbi5pZCkKJyl9CiBXSEVSRSB0LnR5cGVfaWQgPSB0dC5pZAogICBBTkQgdC50aWNrZXRfc3RhdGVfaWQgPSB0cy5pZAogICBBTkQgdC5vcmdhbmlzYXRpb25faWQgPSBvLmlkCiAgIEFORCB0LmNvbnRhY3RfaWQgPSBjLmlkCiAgIEFORCBvLmlkIElOICgke1BhcmFtZXRlcnMuT3JnYW5pc2F0aW9uSURMaXN0fSkKICAgQU5EIHQuY3JlYXRlX3RpbWUgQkVUV0VFTiAnJHtQYXJhbWV0ZXJzLlN0YXJ0RGF0ZX0gMDA6MDA6MDAnIEFORCAnJHtQYXJhbWV0ZXJzLkVuZERhdGV9IDIzOjU5OjU5JwogT1JERVIgQlkgdHQubmFtZSwgdC50bg==)'
        },
        {
            Name   => 'Tickets Closed In Date Range',
            OldSQL => 'base64(U0VMRUNUIHR0Lm5hbWUgQVMgIlR5cGUiLCAKICAgICAgIHQudG4gQVMgIlROUiIsIAogICAgICAgdC50aXRsZSBBUyAiVGl0bGUiLCAKICAgICAgIHRzLm5hbWUgQVMgIlN0YXRlIiwKICAgICAgIG8ubmFtZSBBUyAiT3JnYW5pc2F0aW9uIiwgCiAgICAgICBjLmVtYWlsIEFTICJDb250YWN0IiwgCiAgICAgICB0LmFjY291bnRlZF90aW1lIEFTICJBY2NvdW50ZWQgVGltZSIKJHtGdW5jdGlvbnMuaWZfcGx1Z2luX2F2YWlsYWJsZSgnS0lYUHJvJywnLAogICAgIGRmdi52YWx1ZV90ZXh0IEFTICJDbG9zZSBDb2RlIiwKICAgICBzbGFfcmVzcG9uc2UubmFtZSBBUyAiU0xBIFJlc3BvbnNlIE5hbWUiLAogICAgIHRzY19yZXNwb25zZS50YXJnZXRfdGltZSBBUyAiU0xBIFJlc3BvbnNlIFRhcmdldCBUaW1lIiwgCiAgICAgdHNjX3Jlc3BvbnNlLmZ1bGZpbGxtZW50X3RpbWUgQVMgIlNMQSBSZXNwb25zZSBGdWxmaWxsbWVudCBUaW1lIiwgCiAgICAgdHNjX3Jlc3BvbnNlLnRpbWVfZGV2aWF0aW9uX2J1c2luZXNzIEFTICJTTEEgUmVzcG9uc2UgQnVzaW5lc3MgVGltZSBEZXZpYXRpb24iLAogICAgIHNsYV9zb2x1dGlvbi5uYW1lIEFTICJTTEEgU29sdXRpb24gTmFtZSIsCiAgICAgdHNjX3NvbHV0aW9uLnRhcmdldF90aW1lIEFTICJTTEEgU29sdXRpb24gVGFyZ2V0IFRpbWUiICwgCiAgICAgdHNjX3NvbHV0aW9uLmZ1bGZpbGxtZW50X3RpbWUgQVMgIlNMQSBTb2x1dGlvbiBGdWxmaWxsbWVudCBUaW1lIiwgCiAgICAgdHNjX3NvbHV0aW9uLnRpbWVfZGV2aWF0aW9uX2J1c2luZXNzIEFTICJTTEEgU29sdXRpb24gQnVzaW5lc3MgVGltZSBEZXZpYXRpb24iCicpfQogIEZST00gb3JnYW5pc2F0aW9uIG8sIAogICAgICAgY29udGFjdCBjLCAKICAgICAgIHRpY2tldF90eXBlIHR0LAogICAgICAgdGlja2V0X3N0YXRlIHRzLAogICAgICAgdGlja2V0IHQKJHtGdW5jdGlvbnMuaWZfcGx1Z2luX2F2YWlsYWJsZSgnS0lYUHJvJywnCiAgTEVGVCBPVVRFUiBKT0lOIGR5bmFtaWNfZmllbGQgZGYgT04gKGRmLm5hbWUgPSAnQ2xvc2VDb2RlJykKICBMRUZUIE9VVEVSIEpPSU4gZHluYW1pY19maWVsZF92YWx1ZSBkZnYgT04gKGRmdi5vYmplY3RfaWQgPSB0LmlkIEFORCBkZnYuZmllbGRfaWQgPSBkZi5pZCkKICBMRUZUIE9VVEVSIEpPSU4gdGlja2V0X3NsYV9jcml0ZXJpb24gdHNjX3Jlc3BvbnNlIE9OICh0c2NfcmVzcG9uc2UudGlja2V0X2lkID0gdC5pZCBBTkQgdHNjX3Jlc3BvbnNlLm5hbWUgPSAnUmVzcG9uc2UnKQogIExFRlQgT1VURVIgSk9JTiBzbGEgQVMgc2xhX3Jlc3BvbnNlIE9OICh0c2NfcmVzcG9uc2Uuc2xhX2lkID0gc2xhX3Jlc3BvbnNlLmlkKQogIExFRlQgT1VURVIgSk9JTiB0aWNrZXRfc2xhX2NyaXRlcmlvbiB0c2Nfc29sdXRpb24gT04gKHRzY19zb2x1dGlvbi50aWNrZXRfaWQgPSB0LmlkIEFORCB0c2Nfc29sdXRpb24ubmFtZSA9ICdTb2x1dGlvbicpCiAgTEVGVCBPVVRFUiBKT0lOIHNsYSBBUyBzbGFfc29sdXRpb24gT04gKHRzY19zb2x1dGlvbi5zbGFfaWQgPSBzbGFfc29sdXRpb24uaWQpCicpfQogV0hFUkUgdC50eXBlX2lkID0gdHQuaWQKICAgQU5EIHQudGlja2V0X3N0YXRlX2lkID0gdHMuaWQKICAgQU5EIHQub3JnYW5pc2F0aW9uX2lkID0gby5pZAogICBBTkQgdC5jb250YWN0X2lkID0gYy5pZAogICBBTkQgby5pZCBJTiAoJHtQYXJhbWV0ZXJzLk9yZ2FuaXNhdGlvbklETGlzdH0pCiAgIEFORCBFWElTVFMgKAogICAgIFNFTEVDVCB0aC5pZCAKICAgICAgIEZST00gdGlja2V0X3N0YXRlIHRzLAogICAgICAgICAgICB0aWNrZXRfaGlzdG9yeSB0aCwKICAgICAgICAgICAgdGlja2V0X2hpc3RvcnlfdHlwZSB0aHQsCiAgICAgICAgICAgIHRpY2tldF9zdGF0ZV90eXBlIHRzdAogICAgICBXSEVSRSB0aC50aWNrZXRfaWQgPSB0LmlkCiAgICAgICAgQU5EIHRoLmhpc3RvcnlfdHlwZV9pZCA9IHRodC5pZAogICAgICAgIEFORCB0aHQubmFtZSA9ICdTdGF0ZVVwZGF0ZScKICAgICAgICBBTkQgdGguc3RhdGVfaWQgPSB0cy5pZAogICAgICAgIEFORCB0cy50eXBlX2lkID0gdHN0LmlkCiAgICAgICAgQU5EIHRzdC5uYW1lID0gJ2Nsb3NlZCcKICAgICAgICBBTkQgdGguY3JlYXRlX3RpbWUgQkVUV0VFTiAnJHtQYXJhbWV0ZXJzLlN0YXJ0RGF0ZX0gMDA6MDA6MDAnIEFORCAnJHtQYXJhbWV0ZXJzLkVuZERhdGV9IDIzOjU5OjU5JwogICApCiBPUkRFUiBCWSB0dC5uYW1lLCB0LnRu)',
            NewSQL => 'base64(U0VMRUNUIHR0Lm5hbWUgQVMgIlR5cGUiLCAKICAgICAgIHQudG4gQVMgIlROUiIsIAogICAgICAgdC50aXRsZSBBUyAiVGl0bGUiLCAKICAgICAgIHRzLm5hbWUgQVMgIlN0YXRlIiwKICAgICAgIG8ubmFtZSBBUyAiT3JnYW5pc2F0aW9uIiwgCiAgICAgICBjLmVtYWlsIEFTICJDb250YWN0IiwgCiAgICAgICB0LmFjY291bnRlZF90aW1lIEFTICJBY2NvdW50ZWQgVGltZSIKJHtGdW5jdGlvbnMuaWZfcGx1Z2luX2F2YWlsYWJsZSgnS0lYUHJvJywnLAogICAgIGRmdi52YWx1ZV90ZXh0IEFTICJDbG9zZSBDb2RlIiwKICAgICBzbGFfcmVzcG9uc2UubmFtZSBBUyAiU0xBIFJlc3BvbnNlIE5hbWUiLAogICAgIHRzY19yZXNwb25zZS50YXJnZXRfdGltZSBBUyAiU0xBIFJlc3BvbnNlIFRhcmdldCBUaW1lIiwgCiAgICAgdHNjX3Jlc3BvbnNlLmZ1bGZpbGxtZW50X3RpbWUgQVMgIlNMQSBSZXNwb25zZSBGdWxmaWxsbWVudCBUaW1lIiwgCiAgICAgdHNjX3Jlc3BvbnNlLnRpbWVfZGV2aWF0aW9uX2J1c2luZXNzIEFTICJTTEEgUmVzcG9uc2UgQnVzaW5lc3MgVGltZSBEZXZpYXRpb24iLAogICAgIHNsYV9zb2x1dGlvbi5uYW1lIEFTICJTTEEgU29sdXRpb24gTmFtZSIsCiAgICAgdHNjX3NvbHV0aW9uLnRhcmdldF90aW1lIEFTICJTTEEgU29sdXRpb24gVGFyZ2V0IFRpbWUiICwgCiAgICAgdHNjX3NvbHV0aW9uLmZ1bGZpbGxtZW50X3RpbWUgQVMgIlNMQSBTb2x1dGlvbiBGdWxmaWxsbWVudCBUaW1lIiwgCiAgICAgdHNjX3NvbHV0aW9uLnRpbWVfZGV2aWF0aW9uX2J1c2luZXNzIEFTICJTTEEgU29sdXRpb24gQnVzaW5lc3MgVGltZSBEZXZpYXRpb24iCicpfQogIEZST00gb3JnYW5pc2F0aW9uIG8sIAogICAgICAgY29udGFjdCBjLCAKICAgICAgIHRpY2tldF90eXBlIHR0LAogICAgICAgdGlja2V0X3N0YXRlIHRzLAogICAgICAgdGlja2V0IHQKJHtGdW5jdGlvbnMuaWZfcGx1Z2luX2F2YWlsYWJsZSgnS0lYUHJvJywnCiAgTEVGVCBPVVRFUiBKT0lOIGR5bmFtaWNfZmllbGQgZGYgT04gKGRmLm5hbWUgPSAnQ2xvc2VDb2RlJykKICBMRUZUIE9VVEVSIEpPSU4gZHluYW1pY19maWVsZF92YWx1ZSBkZnYgT04gKGRmdi5vYmplY3RfaWQgPSB0LmlkIEFORCBkZnYuZmllbGRfaWQgPSBkZi5pZCkKICBMRUZUIE9VVEVSIEpPSU4gdGlja2V0X3NsYV9jcml0ZXJpb24gdHNjX3Jlc3BvbnNlIE9OICh0c2NfcmVzcG9uc2UudGlja2V0X2lkID0gdC5pZCBBTkQgdHNjX3Jlc3BvbnNlLm5hbWUgPSAnRmlyc3RSZXNwb25zZScpCiAgTEVGVCBPVVRFUiBKT0lOIHNsYSBBUyBzbGFfcmVzcG9uc2UgT04gKHRzY19yZXNwb25zZS5zbGFfaWQgPSBzbGFfcmVzcG9uc2UuaWQpCiAgTEVGVCBPVVRFUiBKT0lOIHRpY2tldF9zbGFfY3JpdGVyaW9uIHRzY19zb2x1dGlvbiBPTiAodHNjX3NvbHV0aW9uLnRpY2tldF9pZCA9IHQuaWQgQU5EIHRzY19zb2x1dGlvbi5uYW1lID0gJ1NvbHV0aW9uJykKICBMRUZUIE9VVEVSIEpPSU4gc2xhIEFTIHNsYV9zb2x1dGlvbiBPTiAodHNjX3NvbHV0aW9uLnNsYV9pZCA9IHNsYV9zb2x1dGlvbi5pZCkKJyl9CiBXSEVSRSB0LnR5cGVfaWQgPSB0dC5pZAogICBBTkQgdC50aWNrZXRfc3RhdGVfaWQgPSB0cy5pZAogICBBTkQgdC5vcmdhbmlzYXRpb25faWQgPSBvLmlkCiAgIEFORCB0LmNvbnRhY3RfaWQgPSBjLmlkCiAgIEFORCBvLmlkIElOICgke1BhcmFtZXRlcnMuT3JnYW5pc2F0aW9uSURMaXN0fSkKICAgQU5EIEVYSVNUUyAoCiAgICAgU0VMRUNUIHRoLmlkIAogICAgICAgRlJPTSB0aWNrZXRfc3RhdGUgdHMsCiAgICAgICAgICAgIHRpY2tldF9oaXN0b3J5IHRoLAogICAgICAgICAgICB0aWNrZXRfaGlzdG9yeV90eXBlIHRodCwKICAgICAgICAgICAgdGlja2V0X3N0YXRlX3R5cGUgdHN0CiAgICAgIFdIRVJFIHRoLnRpY2tldF9pZCA9IHQuaWQKICAgICAgICBBTkQgdGguaGlzdG9yeV90eXBlX2lkID0gdGh0LmlkCiAgICAgICAgQU5EICh0aHQubmFtZSA9ICdTdGF0ZVVwZGF0ZScgT1IgdGh0Lm5hbWUgPSAnTmV3VGlja2V0JykKICAgICAgICBBTkQgdGguc3RhdGVfaWQgPSB0cy5pZAogICAgICAgIEFORCB0cy50eXBlX2lkID0gdHN0LmlkCiAgICAgICAgQU5EIHRzdC5uYW1lID0gJ2Nsb3NlZCcKICAgICAgICBBTkQgdGguY3JlYXRlX3RpbWUgQkVUV0VFTiAnJHtQYXJhbWV0ZXJzLlN0YXJ0RGF0ZX0gMDA6MDA6MDAnIEFORCAnJHtQYXJhbWV0ZXJzLkVuZERhdGV9IDIzOjU5OjU5JwogICApCiBPUkRFUiBCWSB0dC5uYW1lLCB0LnRu)'
        }
    );

    for my $UpdateReport (@UpdateReports) {

        my $ReportDefinitionID = $ReportingObject->ReportDefinitionLookup(
            Name => $UpdateReport->{Name},
        );

        if ($ReportDefinitionID) {
            my %ReportDefinitionData = $ReportingObject->ReportDefinitionGet(
                ID => $ReportDefinitionID,
            );

            # only update if sql is not changed yet (sql from update script 91)
            if (
                IsHashRefWithData($ReportDefinitionData{Config}) &&
                IsHashRefWithData($ReportDefinitionData{Config}->{DataSource}) &&
                IsHashRefWithData($ReportDefinitionData{Config}->{DataSource}->{SQL}) &&
                $ReportDefinitionData{Config}->{DataSource}->{SQL}->{any} &&
                $ReportDefinitionData{Config}->{DataSource}->{SQL}->{any} eq $UpdateReport->{OldSQL}
            ) {
                $ReportDefinitionData{Config}->{DataSource}->{SQL}->{any} = $UpdateReport->{NewSQL};
                my $Success = $ReportingObject->ReportDefinitionUpdate(
                    %ReportDefinitionData,
                    ID     => $ReportDefinitionID,
                    UserID => 1
                );

                if ( !$Success ) {
                    $LogObject->Log(
                        Priority => 'error',
                        Message  => "Could not update sql of report definition of '$UpdateReport->{Name}'."
                    );
                }
                else {
                    $LogObject->Log(
                        Priority => 'info',
                        Message  => "Updated successfully sql of report definition '$UpdateReport->{Name}'."
                    );
                }
            } else {
                $LogObject->Log(
                    Priority => 'notice',
                    Message  => "Did not update report definition '$UpdateReport->{Name}'."
                );
            }
        }
    }

    return 1;
}

sub _FixAutoIncrementIDs {
    my ( $Self, %Param ) = @_;

    my $DBObject = $Kernel::OM->Get('DB');

    # only needed with mysql based DBMS
    return 1 if $DBObject->{'DB::Type'} ne 'mysql';

    my @Tables = (
        'article_flag',
        'ticket_flag',
        'virtual_fs_preferences',
    );

    foreach my $Table ( @Tables ) {
        my $Success = $DBObject->Do(
            SQL => "ALTER TABLE $Table MODIFY COLUMN id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY"
        );
        if ( !$Success ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Could not update 'id' column of table '$Table'!"
            );
        }
        else {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'info',
                Message  => "Updated 'id' column of table '$Table'."
            );
        }
    }

    return 1;
}

exit 0;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
