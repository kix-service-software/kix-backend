# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::ObjectIcon::Import;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

use MIME::Base64 qw(encode_base64);

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Config',
    'Encode',
    'Main',
    'SysConfig',
    'Time',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Update the object icon database from a CSV file.');

    $Self->AddOption(
        Name        => 'file',
        Description => "The CSV file to import.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'icon-directory',
        Description => "The directory where the iconn files are located.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'no-update',
        Description => "If an icon already exists, no update will be done.",
        Required    => 0,
        HasValue    => 0,
        ValueRegex  => qr/.*/smx,
    );

    my $Name = $Self->Name();

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $Home      = $Kernel::OM->Get('Config')->Get('Home');

    my $IconDir  = $Self->GetOption('icon-directory');
    my $CSVFile  = $Self->GetOption('file');
    my $NoUpdate = $Self->GetOption('no-update');

    if ( !-f $CSVFile ) {
        $Self->PrintError("File $CSVFile does not exist or is not readable!");
        return $Self->ExitCodeError();
    }

    $Self->Print("<yellow>Updating icon database...</yellow>\n");

    # read CSV file
    my $Content = $Kernel::OM->Get('Main')->FileRead(
        Location => $CSVFile,
    );
    if ( !$Content ) {
        $Self->PrintError('Could not read CSV file!');
        return $Self->ExitCodeError();
    }

    my $LinesRef = $Kernel::OM->Get('CSV')->CSV2Array(
        String => $$Content
    );

    # remove header line
    my @Lines = @{$LinesRef};
    shift @Lines;

    my $Count = 0;
    my $CountOK = 0;
    foreach my $Line ( @Lines ) {
        $Count++;

        my $Object      = $Line->[0];
        my $Parent      = $Line->[1];
        my $RawValue    = $Line->[2];
        my $File        = $Line->[3];
        my $ContentType = $Line->[4];

        # read icon file
        my $Content = $Kernel::OM->Get('Main')->FileRead(
            Directory => $IconDir,
            Filename  => $File,
        );
        if ( !$Content ) {
            $Self->PrintError("Could not read icon file $File!");
            next;
        }

        # lookup object
        my $Value = $Self->_LookupValue(
            Object   => $Object,
            Parent   => $Parent,
            RawValue => $RawValue
        );
        if ( !$Value ) {
            $Self->PrintError("Unable to lookup object value of line ".($Count + 1)."!");
            next;
        }

        my $ObjectIconList = $Kernel::OM->Get('ObjectIcon')->ObjectIconList(
            Object   => $Object,
            ObjectID => $Value,
        );

        my $Result;
        if ( IsArrayRefWithData($ObjectIconList) ) {
            if ( $NoUpdate ) { # ignore update
                $Result = 1;
            } else {
                $Result = $Kernel::OM->Get('ObjectIcon')->ObjectIconUpdate(
                    ID          => $ObjectIconList->[0],
                    Object      => $Object,
                    ObjectID    => $Value,
                    ContentType => $ContentType,
                    Content     => MIME::Base64::encode_base64($$Content),
                    UserID      => 1,
                );
            }
        } else {
            $Result = $Kernel::OM->Get('ObjectIcon')->ObjectIconAdd(
                Object      => $Object,
                ObjectID    => $Value,
                ContentType => $ContentType,
                Content     => MIME::Base64::encode_base64($$Content),
                UserID      => 1,
            );
        }

        if ( !$Result ) {
            $Self->PrintError("Could not import object icon for $Object/$RawValue!");
        }

        $CountOK++;
    }

    $Self->Print("\nImported $CountOK/$Count icons.\n");

    $Self->Print("\n<green>Done.</green>\n");

    return $Self->ExitCodeOk();
}

sub _LookupValue {
    my ($Self, %Param) = @_;

    my $Value = $Param{RawValue};

    if ( $Param{Object} eq 'GeneralCatalogItem' ) {
        my $ItemList = $Kernel::OM->Get('GeneralCatalog')->ItemList(
            Class => $Param{Parent},
        );
        my %ItemListReverse = reverse %{$ItemList || {}};
        $Value = $ItemListReverse{$Param{RawValue}};
    }
    elsif ( $Param{Object} eq 'FAQCategory' ) {
        $Value = $Kernel::OM->Get('FAQ')->CategoryLookup(
            Name => $Param{RawValue}
        );
    }
    elsif ( $Param{Object} eq 'Queue' ) {
        $Value = $Kernel::OM->Get('Queue')->QueueLookup(
            Queue => $Param{RawValue}
        );
    }
    elsif ( $Param{Object} eq 'TicketType' ) {
        $Value = $Kernel::OM->Get('Type')->TypeLookup(
            Type => $Param{RawValue}
        );
    }
    elsif ( $Param{Object} eq 'Priority' ) {
        $Value = $Kernel::OM->Get('Priority')->PriorityLookup(
            Priority => $Param{RawValue}
        );
    }
    elsif ( $Param{Object} eq 'TicketState' ) {
        $Value = $Kernel::OM->Get('State')->StateLookup(
            State => $Param{RawValue}
        );
    }
    elsif ( $Param{Object} eq 'TicketLockType' ) {
        $Value = $Kernel::OM->Get('Lock')->LockLookup(
            Lock => $Param{RawValue}
        );
    }
    elsif ( $Param{Object} eq 'ArticleSenderType' ) {
        my $Value = $Kernel::OM->Get('Ticket')->ArticleSenderTypeLookup(
            SenderType => $Param{RawValue},
        );
    }
    elsif ( $Param{Object} eq 'Channel' ) {
        $Value = $Kernel::OM->Get('Channel')->ChannelLookup(
            Name => $Param{RawValue}
        );
    }

    return $Value;
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
