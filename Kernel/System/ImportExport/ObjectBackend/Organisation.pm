# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ImportExport::ObjectBackend::Organisation;

use strict;
use warnings;
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Config',
    'Organisation',
    'ImportExport',
    'Log',
);

=head1 NAME

Kernel::System::ImportExport::ObjectBackend::Organisation - import/export backend for Organisation

=head1 SYNOPSIS

All functions to import and export Organisation entries

=over 4

=cut

=item new()

create an object

    use Kernel::Config;
    use Kernel::System::DB;
    use Kernel::System::Log;
    use Kernel::System::Main;
    use Kernel::System::ImportExport::ObjectBackend::Organisation;

    my $ConfigObject = Kernel::Config->new();
    my $LogObject = Kernel::System::Log->new(
        ConfigObject => $ConfigObject,
    );
    my $MainObject = Kernel::System::Main->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
    );
    my $DBObject = Kernel::System::DB->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
        MainObject   => $MainObject,
    );
    my $BackendObject = Kernel::System::ImportExport::ObjectBackend::Organisation->new(
        ConfigObject       => $ConfigObject,
        LogObject          => $LogObject,
        DBObject           => $DBObject,
        MainObject         => $MainObject,
        ImportExportObject => $ImportExportObject,
    );

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item ObjectAttributesGet()

get the object attributes of an object as array/hash reference

    my $Attributes = $ObjectBackend->ObjectAttributesGet(
        UserID => 1,
    );

=cut

sub ObjectAttributesGet {
    my ( $Self, %Param ) = @_;

    # check needed object
    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Log')
            ->Log( Priority => 'error', Message => 'Need UserID!' );
        return;
    }

    my %Validlist = $Kernel::OM->Get('Valid')->ValidList();

    my $Attributes = [
        {
            Key   => 'ForceImportInConfiguredOrganisationBackend',
            Name  => 'Force import in configured organisation backend',
            Input => {
                Type => 'Selection',
                Data => {
                    '0' => 'No',
                    '1' => 'Yes',
                },
                Required     => 0,
                Translation  => 1,
                PossibleNone => 0,
                ValueDefault => 0,
            },
        },
        {
            Key   => 'DefaultValid',
            Name  => 'Default Validity',
            Input => {
                Type         => 'Selection',
                Data         => \%Validlist,
                Required     => 1,
                Translation  => 1,
                PossibleNone => 0,
                ValueDefault => 1,
            },
        },
        {
            Key   => 'EmptyFieldsLeaveTheOldValues',
            Name  => 'Empty fields indicate that the current values are kept',
            Input => {
                Type => 'Checkbox',
            },
        },
    ];

    return $Attributes;
}

=item MappingObjectAttributesGet()

get the mapping attributes of an object as array/hash reference

    my $Attributes = $ObjectBackend->MappingObjectAttributesGet(
        TemplateID => 123,
        UserID     => 1,
    );

=cut

sub MappingObjectAttributesGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(TemplateID UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get object data
    my $ObjectData = $Kernel::OM->Get('ImportExport')->ObjectDataGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    my @ElementList = qw{};
    my @Map = @{ $Kernel::OM->Get('Config')->{ $ObjectData->{OrganisationBackend} }->{'Map'} };

    for my $CurrAttributeMapping (@Map) {
        my $CurrAttribute = {
            Key   => $CurrAttributeMapping->[0],
            Value => $CurrAttributeMapping->[0],
        };

        # if ValidID is available - offer Valid instead..
        if ( $CurrAttributeMapping->[0] eq 'ValidID' ) {
            $CurrAttribute = {
                Key   => 'ValidID',
                Value => 'ValidID (not used in import anymore, use Validity instead)',
            };
            push( @ElementList, $CurrAttribute );

            $CurrAttribute = { Key => 'Valid', Value => 'Validity', };
        }

        push( @ElementList, $CurrAttribute );

    }

    my $Attributes = [
        {
            Key   => 'Key',
            Name  => 'Key',
            Input => {
                Type         => 'Selection',
                Data         => \@ElementList,
                Required     => 1,
                Translation  => 0,
                PossibleNone => 1,
            },
        },

        # It doesn't make sense to configure and set the identifier:
        # CustomerID is used to search for existing enrties anyway!
        # (See sub ImportDataSave)
        #        {
        #            Key   => 'Identifier',
        #            Name  => 'Identifier',
        #            Input => { Type => 'Checkbox', },
        #        },
    ];

    return $Attributes;
}

=item SearchAttributesGet()

get the search object attributes of an object as array/hash reference

    my $AttributeList = $ObjectBackend->SearchAttributesGet(
        TemplateID => 123,
        UserID     => 1,
    );

=cut

sub SearchAttributesGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(TemplateID UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get object data
    my $ObjectData = $Kernel::OM->Get('ImportExport')->ObjectDataGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    return;
}

=item ExportDataGet()

get export data as 2D-array-hash reference

    my $ExportData = $ObjectBackend->ExportDataGet(
        TemplateID => 123,
        UserID     => 1,
    );

=cut

sub ExportDataGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(TemplateID UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get object data
    my $ObjectData = $Kernel::OM->Get('ImportExport')->ObjectDataGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    # check object data
    if ( !$ObjectData || ref $ObjectData ne 'HASH' ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No object data found for the template id $Param{TemplateID}",
        );
        return;
    }

    # get the mapping list
    my $MappingList = $Kernel::OM->Get('ImportExport')->MappingList(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    # check the mapping list
    if ( !$MappingList || ref $MappingList ne 'ARRAY' || !@{$MappingList} ) {

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No valid mapping list found for the template id $Param{TemplateID}",
        );
        return;
    }

    # create the mapping object list
    my @MappingObjectList;
    for my $MappingID ( @{$MappingList} ) {

        # get mapping object data
        my $MappingObjectData =
            $Kernel::OM->Get('ImportExport')->MappingObjectDataGet(
            MappingID => $MappingID,
            UserID    => $Param{UserID},
            );

        # check mapping object data
        if ( !$MappingObjectData || ref $MappingObjectData ne 'HASH' ) {

            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "No valid mapping list found for the template id $Param{TemplateID}",
            );
            return;
        }

        push( @MappingObjectList, $MappingObjectData );
    }

    # list organisations...
    my %OrganisationSearch = $Kernel::OM->Get('Organisation')->OrganisationSearch(
        Valid => 0,
    );
    my @ExportData;

    for my $OrgID (keys %OrganisationSearch) {

        my %OrganisationData = $Kernel::OM->Get('Organisation')->OrganisationGet(
            ID => $OrgID
        );

        my @CurrRow;

        # prepare validity...
        if ( $OrganisationData{ValidID} ) {
            $OrganisationData{Valid} = $Kernel::OM->Get('Valid')->ValidLookup(
                ValidID => $OrganisationData{ValidID},
            );
        }

        for my $MappingObject (@MappingObjectList) {
            my $Key = $MappingObject->{Key};
            if ( !$Key ) {
                push @CurrRow, '';
            }
            else {
                push( @CurrRow, $OrganisationData{$Key} || '' );
            }
        }
        push @ExportData, \@CurrRow;
    }

    return \@ExportData;
}

=item ImportDataSave()

import one row of the import data

    my $ConfigItemID = $ObjectBackend->ImportDataSave(
        TemplateID    => 123,
        ImportDataRow => $ArrayRef,
        UserID        => 1,
    );

=cut

sub ImportDataSave {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(TemplateID ImportDataRow UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return ( undef, 'Failed' );
        }
    }

    # check import data row
    if ( ref $Param{ImportDataRow} ne 'ARRAY' ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'ImportDataRow must be an array reference',
        );
        return ( undef, 'Failed' );
    }

    # get object data
    my $ObjectData = $Kernel::OM->Get('ImportExport')->ObjectDataGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    # check object data
    if ( !$ObjectData || ref $ObjectData ne 'HASH' ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No object data found for the template id $Param{TemplateID}",
        );
        return ( undef, 'Failed' );
    }

    # get the mapping list
    my $MappingList = $Kernel::OM->Get('ImportExport')->MappingList(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    # check the mapping list
    if ( !$MappingList || ref $MappingList ne 'ARRAY' || !@{$MappingList} ) {

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No valid mapping list found for the template id $Param{TemplateID}",
        );
        return ( undef, 'Failed' );
    }

    # create the mapping object list
    #    my @MappingObjectList;
    #    my %Identifier;
    my $Counter                = 0;
    my %NewOrganisationData = qw{};

    #--------------------------------------------------------------------------
    #BUILD MAPPING TABLE...
    my $IsHeadline = 1;
    for my $MappingID ( @{$MappingList} ) {

        # get mapping object data
        my $MappingObjectData =
            $Kernel::OM->Get('ImportExport')->MappingObjectDataGet(
            MappingID => $MappingID,
            UserID    => $Param{UserID},
            );

        # check mapping object data
        if ( !$MappingObjectData || ref $MappingObjectData ne 'HASH' ) {

            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "No valid mapping list found for template id $Param{TemplateID}",
            );
            return ( undef, 'Failed' );
        }

        #        push( @MappingObjectList, $MappingObjectData );

        # TO DO: It doesn't make sense to configure and set the identifier:
        # CustomerID is used to search for existing enrties anyway!
        #
        #  See lines 529-530:
        #  my %OrganisationData = $Self->{OrganisationObject}
        #        ->OrganisationGet( CustomerID => $NewOrganisationData{CustomerID} );

        #        if (
        #            $MappingObjectData->{Identifier}
        #            && $Identifier{ $MappingObjectData->{Key} }
        #            )
        #        {
        #            $Self->{LogObject}->Log(
        #                Priority => 'error',
        #                Message  => "Can't import this entity. "
        #                    . "'$MappingObjectData->{Key}' has been used multiple "
        #                    . "times as identifier (line $Param{Counter}).!",
        #            );
        #        }
        #        elsif ( $MappingObjectData->{Identifier} ) {
        #            $Identifier{ $MappingObjectData->{Key} } =
        #                $Param{ImportDataRow}->[$Counter];
        #            $OrganisationKey = $MappingObjectData->{Key};
        #        }

        if ( $MappingObjectData->{Key} ne "OrganisationCountry" ) {
            $NewOrganisationData{ $MappingObjectData->{Key} } =
                $Param{ImportDataRow}->[$Counter];
        }
        else {
            # Sanitize country if it isn't found in KIX to increase the chance it will
            # Note that standardizing against the ISO 3166-1 list might be a better approach...
            my $CountryList = $Kernel::OM->Get('ReferenceData')->CountryList();
            if ( exists $CountryList->{ $Param{ImportDataRow}->[$Counter] } ) {
                $NewOrganisationData{ $MappingObjectData->{Key} } = $Param{ImportDataRow}->[$Counter];
            }
            else {
                $NewOrganisationData{ $MappingObjectData->{Key} } =
                    join( '', map { ucfirst lc } split /(\s+)/, $Param{ImportDataRow}->[$Counter] );
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'notice',
                    Message  => "Country '$Param{ImportDataRow}->[$Counter]' "
                        . "not found - save as '$NewOrganisationData{ $MappingObjectData->{Key} }'.",
                );
            }
        }


        # WORKAROUND - for FEFF-character in _some_ texts (remove it)...
        if ( $NewOrganisationData{ $MappingObjectData->{Key} } ) {
            $NewOrganisationData{ $MappingObjectData->{Key} } =~ s/(\x{feff})//g;
        }
        #EO WORKAROUND

        $Counter++;

    }

    #--------------------------------------------------------------------------
    #DO THE IMPORT...

    #(0) lookup company entry
    my %OrganisationData = ();

    my $OrganisationKey;
    my $OrganisationBackend = $Kernel::OM->Get('Config')->Get($ObjectData->{OrganisationBackend});
    if ( $OrganisationBackend && $OrganisationBackend->{OrganisationKey} && $OrganisationBackend->{Map} ) {
        for my $Entry ( @{ $OrganisationBackend->{Map} } ) {
            next if ( $Entry->{Label} ne $OrganisationBackend->{OrganisationKey} );

            $OrganisationKey = $Entry->{Attribute}};
            last;
        }
        if ( !$OrganisationKey ) {
            $OrganisationKey = "ID";
        }
    }

    if ( $NewOrganisationData{$OrganisationKey} ) {
        %OrganisationData = $Kernel::OM->Get('Organisation')->OrganisationGet(
            ID => $NewOrganisationData{$OrganisationKey}
        );
    }

    my $NewOrg = 1;
    if (%OrganisationData) {
        $NewOrg = 0;
    }

    #(1) Preprocess data...

    # lookup Valid-ID...
    if ( !$NewOrganisationData{ValidID} && $NewOrganisationData{Valid} ) {
        $NewOrganisationData{ValidID} = $Kernel::OM->Get('Valid')->ValidLookup(
            Valid => $NewOrganisationData{Valid}
        );
    }
    if ( !$NewOrganisationData{ValidID} ) {
        $NewOrganisationData{ValidID} = $ObjectData->{DefaultValid} || 1;
    }

    #---------------------------------------------------------------------------
    # (2) overwrite existing values with new values...
    for my $Key ( keys(%NewOrganisationData) ) {
        if( $ObjectData->{EmptyFieldsLeaveTheOldValues}
            && $NewOrganisationData{$Key}
        ) {
            $OrganisationData{$Key} = $NewOrganisationData{$Key};

        } elsif ( !$ObjectData->{EmptyFieldsLeaveTheOldValues} ) {
            $OrganisationData{$Key} = $NewOrganisationData{$Key};
        }
    }

    #(3) if company DOES NOT exist => create in specified backend
    my $Result     = 0;
    my $ReturnCode = "";    # Created | Changed | Failed

    if ($NewOrg) {
        $Result = $Kernel::OM->Get('Organisation')->OrganisationAdd(
            %OrganisationData,
            UserID => $Param{UserID},
        );

        if ( !$Result ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "ImportDataSave: adding Organisation ("
                    . "Organisation "
                    . $OrganisationData{$OrganisationKey}
                    . ") failed (line $Param{Counter}).",
            );
        }
        else {
            $ReturnCode = "Created";
        }
    }

    #(4) if company DOES exist => check backend and update...
    else {
        $OrganisationData{ID} = $NewOrganisationData{$OrganisationKey};

        if (
            $OrganisationData{Source}
            && $OrganisationData{Source} eq $ObjectData->{OrganisationBackend}
            )
        {
            $Result = $Kernel::OM->Get('Organisation')->OrganisationUpdate(
                %OrganisationData,
                Source => $ObjectData->{OrganisationBackend},
                UserID => $Param{UserID},
            );

            if ( !$Result ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "ImportDataSave: updating Organisation "
                        . $OrganisationData{ID}
                        . " failed (line $Param{Counter}).",
                );
            }
            else {
                $ReturnCode = "Changed";
            }
        }
        elsif ( $ObjectData->{ForceImportInConfiguredOrganisationBackend} ) {

            # NOTE: this is a somewhat dirty hack to force the import of the
            # organisation data in the backend which is assigned in the current
            # mapping. Actually a organisation data set can not be added under the
            # same key (CustomerID).

            my %BackendRef = ();
            my $ResultNote = "";

            # find backend and backup organisation data backend refs...
            while (
                $OrganisationData{Source}
                && $OrganisationData{Source} ne $ObjectData->{OrganisationBackend}
                )
            {
                $BackendRef{ $OrganisationData{Source} } =
                    $Kernel::OM->Get('Organisation')->{ $OrganisationData{Source} };
                delete( $Kernel::OM->Get('Organisation')->{ $OrganisationData{Source} } );

                %OrganisationData = $Kernel::OM->Get('Organisation')->OrganisationGet(
                    ID => $NewOrganisationData{$OrganisationKey}
                );
            }

            # overwrite existing values with new values...
            for my $Key ( keys(%NewOrganisationData) ) {
                $OrganisationData{$Key} = $NewOrganisationData{$Key};
            }

            # update existing entry...
            if (
                $OrganisationData{Source}
                && $OrganisationData{Source} eq $ObjectData->{OrganisationBackend}
                )
            {
                $OrganisationData{ID} = $NewOrganisationData{$OrganisationKey};
                $Result = $Kernel::OM->Get('Organisation')->OrganisationUpdate(
                    %OrganisationData,
                    UserID => $Param{UserID},
                );
                $ResultNote = "update";
                $ReturnCode = "Changed";
            }

            # create new entry...
            else {
                $Result = $Kernel::OM->Get('Organisation')->OrganisationAdd(
                    %OrganisationData,
                    UserID => $Param{UserID},
                );
                $ResultNote = "add";
                $ReturnCode = "Created";
            }

            # check for errors...
            if ( !$Result ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "ImportDataSave: forcing Organisation "
                        . $OrganisationData{ID}
                        . " in "
                        . $ObjectData->{OrganisationBackend}
                        . " ($ResultNote) "
                        . " failed (line $Param{Counter}).",
                );
                $ReturnCode = "";
            }

            # restore organisation data backend refs...
            for my $CurrKey ( keys(%BackendRef) ) {
                $Kernel::OM->Get('Organisation')->{$CurrKey} = $BackendRef{$CurrKey};
            }

        }
        else {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'notice',
                Message  => "ImportDataSave: updating Organisation "
                    . $OrganisationData{ID}
                    . " failed - Organisation exists in other backend.",

            );
        }
    }

    #
    #--------------------------------------------------------------------------

    return ( $Result, $ReturnCode );
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
