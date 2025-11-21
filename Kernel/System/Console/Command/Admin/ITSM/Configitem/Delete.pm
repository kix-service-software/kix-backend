# --
# Modified version of the work: Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com/
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::ITSM::Configitem::Delete;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'GeneralCatalog',
    'ITSMConfigItem',
    'ObjectSearch',
    'Time',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Delete assets (by number, by class and deployment state, or all), or their versions.');
    $Self->AddOption(
        Name        => 'all',
        Description => "Delete all assets",
        Required    => 0,
        HasValue    => 0,
    );
    $Self->AddArgument(
        Name        => 'accept',
        Description => "Accept deletion of assets. (--asset-number always accepts deletion) ",
        Required    => 0,
        ValueRegex  => qr/(y|n)/smx,
    );
    $Self->AddOption(
        Name        => 'class',
        Description => "Delete all assets of this class.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'deployment-state',
        Description => "Delete all assets with this deployment state (ONLY TOGETHER with the --class parameter)",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'asset-number',
        Description => "Delete given asset(s)",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d+/smx,
        Multiple    => 1,
    );
    $Self->AddOption(
        Name        => 'all-old-versions',
        Description => "Delete all asset versions except the newest version",
        Required    => 0,
        HasValue    => 0,
    );
    $Self->AddOption(
        Name        => 'all-but-keep-last-versions',
        Description => "Delete all asset versions but keep the last XX versions",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d+/smx,
    );
    $Self->AddOption(
        Name        => 'all-older-than-days-versions',
        Description => "Delete all asset versions older than XX days (24h)",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/\d+/smx,
    );

    return;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    my $All               = $Self->GetOption('all');
    my $Class             = $Self->GetOption('class')            // q{};
    my @ConfigItemNumbers = @{ $Self->GetOption('asset-number')  // [] };
    my $DeploymentState   = $Self->GetOption('deployment-state') // q{};

    if (
        !$All
        && !$Class
        && !IsArrayRefWithData( \@ConfigItemNumbers )
    ) {
        die
            "Please provide option --all, --class, or --asset-number.\n"
            . "For more details use --help\n";
    }

    if ( $DeploymentState && !$Class ) {
        die
            "Restriction of relevant deployment state is possible ONLY TOGETHER with the --class parameter.\n"
            . "For more details use --help\n";
    }

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $All               = $Self->GetOption('all');
    my $Class             = $Self->GetOption('class')                        // q{};
    my @ConfigItemNumbers = @{ $Self->GetOption('asset-number')              // [] };
    my $DeploymentState   = $Self->GetOption('deployment-state')             // q{};
    my $AllOldVersions    = $Self->GetOption('all-old-versions')             // q{};
    my $AllButKeepLast    = $Self->GetOption('all-but-keep-last-versions')   // q{};
    my $AllOlderThanDays  = $Self->GetOption('all-older-than-days-versions') // q{};

    # init variable
    my @ConfigItemIDs;

    # get relevant assets
    if ( @ConfigItemNumbers ) {
        for my $ConfigItemNumber ( @ConfigItemNumbers ) {
            # checks the validity of the asset number
            my $ID = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemLookup(
                ConfigItemNumber => $ConfigItemNumber,
            );
            if ( $ID ) {
                push( @ConfigItemIDs, $ID );
            }
            else {
                $Self->Print("<yellow>Unable to find asset $ConfigItemNumber.</yellow>\n");
            }
        }
    }
    elsif ( $Class ) {
        # get class list and inverted list for lookup
        my $ClassList = $Kernel::OM->Get('GeneralCatalog')->ItemList(
            Class => 'ITSM::ConfigItem::Class',
            Valid => 0,
        );
        my %ClassName2ID = reverse( %{ $ClassList } );

        if ( $ClassName2ID{ $Class } ) {
            # define the search param for the class search
            my @SearchParam = (
                {
                    Field    => 'ClassID',
                    Operator => 'IN',
                    Type     => 'NUMERIC',
                    Value    => [ $ClassName2ID{ $Class } ]
                }
            );

            # handle given depl state
            if ( $DeploymentState ) {
                # get deployment state list and inverted list for lookup
                my $DeplStateList = $Kernel::OM->Get('GeneralCatalog')->ItemList(
                    Class => 'ITSM::ConfigItem::DeploymentState',
                    Valid => 0,
                );
                my %DeplState2ID = reverse( %{ $DeplStateList } );

                if ( $DeplState2ID{ $DeploymentState } ) {
                    # add search parameter
                    push(
                        @SearchParam,
                        {
                            Field    => 'DeplStateID',
                            Operator => 'IN',
                            Type     => 'NUMERIC',
                            Value    => [ $DeplState2ID{ $DeploymentState } ]
                        }
                    );
                }
                else {
                    $Self->PrintError("Unable to find deployment state $DeploymentState.");
                    return $Self->ExitCodeError();
                }
            }

            # get ids of this class (and maybe deployment state) assetss
            @ConfigItemIDs = $Kernel::OM->Get('ObjectSearch')->Search(
                ObjectType => 'ConfigItem',
                Result     => 'ARRAY',
                Search     => {
                    AND => \@SearchParam
                },
                UserID     => 1,
                UserType   => 'Agent'
            );
        }
        else {
            $Self->PrintError("Unable to find class name $Class.");
            return $Self->ExitCodeError();
        }
    }
    else {
        @ConfigItemIDs = $Kernel::OM->Get('ObjectSearch')->Search(
            ObjectType => 'ConfigItem',
            Result     => 'ARRAY',
            UserID     => 1,
            UserType   => 'Agent'
        );
    }

    if ( !@ConfigItemIDs ) {
        $Self->Print("<yellow>No assets to handle.</yellow>\n");
        return $Self->ExitCodeOk();
    }
    else {
        $Self->Print("<yellow>" . scalar( @ConfigItemIDs ) . " asset(s) to handle.</yellow>\n");
    }

    # handle version deletions
    if (
        $AllOlderThanDays
        || $AllOldVersions
        || $AllButKeepLast
    ) {
        # get version list
        my $VersionList = $Kernel::OM->Get('ITSMConfigItem')->VersionListAll(
            ConfigItemIDs => \@ConfigItemIDs
        );
        if ( IsHashRefWithData( $VersionList ) ) {
            # prepare versions to delete
            my @VersionsToDelete;
            if ($AllOlderThanDays) {
                # get versions before given days
                my $OlderSystemTime = $Kernel::OM->Get('Time')->TimeStamp2SystemTime(
                    String => '-' . $AllOlderThanDays . 'd',
                );
                my $OlderDate = $Kernel::OM->Get('Time')->SystemTime2TimeStamp(
                    SystemTime => $OlderSystemTime,
                );
                my $VersionsOlderDate = $Kernel::OM->Get('ITSMConfigItem')->VersionListAll(
                    ConfigItemIDs => \@ConfigItemIDs,
                    OlderDate     => $OlderDate,
                );

                CONFIGITEMID:
                for my $ConfigItemID ( sort( keys( %{ $VersionsOlderDate } ) ) ) {
                    # number of found older versions of this CI
                    my $NumberOfOlderVersions = scalar( keys( %{ $VersionsOlderDate->{ $ConfigItemID } } ) );
                    next CONFIGITEMID if !$NumberOfOlderVersions;

                    # number of all versions of this CI
                    my $NumberOfAllVersions = scalar( keys( %{ $VersionList->{ $ConfigItemID } } ) );
                    next CONFIGITEMID if ( $NumberOfAllVersions <= 1 );

                    # if the amount of Versions we have to delete
                    # is exactly the same as the amount of AllVersions
                    # we have to keep the last one
                    # in order to keep the system working
                    #
                    # -> so let's start counting at "1" instead of "0"
                    # in order to stop deleting before we reach the newest version
                    my $Count = 0;
                    if ( $NumberOfOlderVersions == $NumberOfAllVersions ) {
                        $Count = 1;
                    }

                    # make sure that the versions are numerically sorted
                    for my $Version ( sort { $a <=> $b }( keys( %{ $VersionsOlderDate->{ $ConfigItemID } } ) ) ) {
                        if ( $Count < $NumberOfOlderVersions ) {
                            push @VersionsToDelete, $Version;
                        }
                        $Count++;
                    }
                }
            }
            else {
                my $KeepLastCount = 1;
                if ( $AllButKeepLast ) {
                    $KeepLastCount = $AllButKeepLast;
                }
                CONFIGITEMID:
                for my $ConfigItemID ( sort( keys( %{ $VersionList } ) ) ) {
                    next CONFIGITEMID if ( !IsHashRefWithData( $VersionList->{ $ConfigItemID } ) );

                    # make sure that the versions are numerically reverse sorted
                    my @ReducedVersions = reverse( sort { $a <=> $b }( keys( %{ $VersionList->{ $ConfigItemID } } ) ) );

                    my $Count = 0;
                    @ReducedVersions = grep { $Count++; $Count > $KeepLastCount } @ReducedVersions;
                    push( @VersionsToDelete, @ReducedVersions );
                }
            }

            if ( @VersionsToDelete ) {
                $Self->_DeleteConfigItemVersions(
                    VersionIDs => \@VersionsToDelete,
                );
            }
            else {
                $Self->Print("<yellow>No versions to handle.</yellow>\n");
                return $Self->ExitCodeOk();
            }
        }
        else {
            $Self->Print("<yellow>No versions to handle.</yellow>\n");
            return $Self->ExitCodeOk();
        }
    }
    # handle asset deletion
    else {
        my $Confirmation;
        if ( @ConfigItemNumbers ) {
            $Confirmation = 'y';
        }
        else {
            $Confirmation = $Self->GetArgument('accept');

            if ( !defined( $Confirmation ) ) {
                $Self->Print("<yellow>Are you sure that you want to delete ALL " . scalar( @ConfigItemIDs ) . " config items?</yellow>\n");
                $Self->Print("<yellow>This is irrevocable. [y/n] </yellow>\n");
                chomp( $Confirmation = lc <STDIN> );
            }
        }


        # if the user confirms the deletion
        if ( $Confirmation eq 'y' ) {
            $Self->_DeleteConfigItems( ConfigItemIDs => \@ConfigItemIDs );
        }
        else {
            $Self->Print("<yellow>Command delete was canceled</yellow>\n");
            return $Self->ExitCodeOk();
        }
    }

    # show successfull output
    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

sub _DeleteConfigItems {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if ( !IsArrayRefWithData( $Param{ConfigItemIDs} ) );

    $Self->Print("<yellow>Deleting " . scalar( @{ $Param{ConfigItemIDs} } ) . " asset(s).</yellow>\n");

    my $DeletedCI;

    # delete given assets
    for my $ConfigItemID ( @{ $Param{ConfigItemIDs} } ) {
        my $Success = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemDelete(
            ConfigItemID => $ConfigItemID,
            UserID       => 1,
        );
        if ( !$Success ) {
            $Self->PrintError("Unable to delete asset with id $ConfigItemID.");
        }
        else {
            $DeletedCI++;
        }
    }

    $Self->Print("<green>Deleted $DeletedCI asset(s).</green>\n\n");

    return 1;
}

sub _DeleteConfigItemVersions {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return if ( !IsArrayRefWithData( $Param{VersionIDs} ) );

    $Self->Print("<yellow>Deleting " . scalar( @{ $Param{VersionIDs} } ) . " asset version(s).</yellow>\n");

    $Kernel::OM->Get('ITSMConfigItem')->VersionDelete(
        VersionIDs => $Param{VersionIDs},
        UserID     => 1,
    );

    return 1;
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
