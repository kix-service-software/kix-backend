# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ImportExport::ObjectBackend::Contact;

use strict;
use warnings;

our @ObjectDependencies = (
    'ImportExport',
    'Contact',
    'Log',
    'Config'
);

=head1 NAME

Kernel::System::ImportExport::ObjectBackend::Contact - import/export backend for Contact

=head1 SYNOPSIS

All functions to import and export Contact entries

=over 4

=cut

=item new()

create an object

    use Kernel::Config;
    use Kernel::System::DB;
    use Kernel::System::Log;
    use Kernel::System::Main;
    use Kernel::System::ImportExport::ObjectBackend::Contact;

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
    my $BackendObject = Kernel::System::ImportExport::ObjectBackend::Contact->new(
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

    my %CSList    = $Kernel::OM->Get('Contact')->CustomerSourceList();
    my %Validlist = $Kernel::OM->Get('Valid')->ValidList();

    my $Attributes = [
        {
            Key   => 'CustomerBackend',
            Name  => 'Customer Backend',
            Input => {
                Type         => 'Selection',
                Data         => \%CSList,
                Required     => 1,
                Translation  => 0,
                PossibleNone => 0,
            },
        },
        {
            Key   => 'ForceImportInConfiguredCustomerBackend',
            Name  => 'Force import in configured customer backend',
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
            Key   => 'DefaultUserCustomerID',
            Name  => 'Default Customer ID',
            Input => {
                Type         => 'Text',
                Required     => 0,
                Size         => 50,
                MaxLength    => 250,
                ValueDefault => '',
            },
        },
        {
            Key   => 'EnableMailDomainCustomerIDMapping',
            Name  => 'Maildomain-CustomerID Mapping (see SysConfig)',
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
            Key   => 'DefaultUserEmail',
            Name  => 'Default Email',
            Input => {
                Type         => 'Text',
                Required     => 0,
                Size         => 50,
                MaxLength    => 250,
                ValueDefault => '',
            },
        },
        {
            Key   => 'ResetPassword',
            Name  => 'Reset password if updated',
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
            Key   => 'ResetPasswordSuffix',
            Name  => 'Password-Suffix (new password = login + suffix)',
            Input => {
                Type         => 'Text',
                Required     => 0,
                Size         => 50,
                MaxLength    => 50,
                ValueDefault => '',
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
    my @Map =
        @{ $Kernel::OM->Get('Config')->{ $ObjectData->{CustomerBackend} }->{'Map'} };

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

        # if UserPassword is available - add note to mapping..
        if ( $CurrAttributeMapping->[0] eq 'UserPassword' ) {
            $CurrAttribute = {
                Key => 'UserPassword',
                Value =>
                    'UserPassword (not filled in export, relevant only for import of new entries)',
            };
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
        # CustomerKey of Backend is used to search for existing enrties anyway!
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

    # search the customer users...
    my %ContactList = $Kernel::OM->Get('Contact')->ContactSearch(
        Search => '*',
        Valid  => 0,
    );

    my @ExportData;

    for my $ContactID (keys %ContactList) {

        my %ContactData = $Kernel::OM->Get('Contact')->ContactGet(
            ID => $ContactID,
        );

        # prepare validity...
        if ( $ContactData{ValidID} ) {
            $ContactData{Valid} = $Kernel::OM->Get('Valid')->ValidLookup(
                ValidID => $ContactData{ValidID},
            );
        }

        # prepare password...
        if ( $ContactData{UserPassword} ) {
            $ContactData{UserPassword} = '-';
        }

        if (
            $ContactData{Source}
            && ( $ContactData{Source} eq $ObjectData->{CustomerBackend} )
            )
        {
            my @CurrRow;
            for my $MappingObject (@MappingObjectList) {
                my $Key = $MappingObject->{Key};
                if ( !$Key ) {
                    push @CurrRow, '';
                }
                else {
                    push( @CurrRow, $ContactData{$Key} || '' );
                }
            }
            push @ExportData, \@CurrRow;
        }

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
    my $Counter             = 0;
    my %NewContactData = qw{};

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

        # It doesn't make sense to configure and set the identifier:
        # CustomerKey of Backend is used to search for existing enrties anyway!
        #
        #  See lines 638-639:
        #       if ( !$ContactKey || $ContactKey ne 'UserLogin' ) {
        #           $ContactKey = "UserLogin";
        #       }

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
        #            $ContactKey = $MappingObjectData->{Key};
        #        }

        if ( $MappingObjectData->{Key} ne "UserCountry" ) {
            $NewContactData{ $MappingObjectData->{Key} } =
            $Param{ImportDataRow}->[$Counter];
        }
        else {
            # Sanitize country if it isn't found in KIX to increase the chance it will
            # Note that standardizing against the ISO 3166-1 list might be a better approach...
            my $CountryList = $Kernel::OM->Get('ReferenceData')->CountryList();
            if ( exists $CountryList->{$Param{ImportDataRow}->[$Counter]} ) {
                $NewContactData{ $MappingObjectData->{Key} } = $Param{ImportDataRow}->[$Counter];
            }
            else {
                $NewContactData{ $MappingObjectData->{Key} } =
                    join ('', map { ucfirst lc } split /(\s+)/, $Param{ImportDataRow}->[$Counter]);
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'notice',
                    Message  => "Country '$Param{ImportDataRow}->[$Counter]' "
                        . "not found - save as '$NewContactData{ $MappingObjectData->{Key} }'.",
                );
            }
        }


        # WORKAROUND - for FEFF-character in _some_ texts (remove it)...
        if ( $NewContactData{ $MappingObjectData->{Key} } ) {
            $NewContactData{ $MappingObjectData->{Key} } =~ s/(\x{feff})//g;
        }
        #EO WORKAROUND

        $Counter++;

    }

    #--------------------------------------------------------------------------
    #DO THE IMPORT...

    # (0) search user
    my %ContactData = ();

    my $ContactKey;
    my $CustomerBackend = $Kernel::OM->Get('Config')->Get($ObjectData->{CustomerBackend} || $ObjectData->{ContactBackend});
    if ( $CustomerBackend && $CustomerBackend->{CustomerKey} && $CustomerBackend->{Map} ) {
        for my $Entry ( @{ $CustomerBackend->{Map} } ) {
            next if ( $Entry->{Label} ne $CustomerBackend->{CustomerKey} );

            $ContactKey = $Entry->{Attribute};
            last;
        }
        if ( !$ContactKey ) {
            $ContactKey = "ID";
        }
    }

    if ( $NewContactData{$ContactKey} ) {
        %ContactData = $Kernel::OM->Get('Contact')->ContactGet(
            ID => $NewContactData{$ContactKey}
        );
    }

    my $NewUser = 1;
    if (%ContactData) {
        $NewUser = 0;
    }

    #---------------------------------------------------------------------------
    # (1) Preprocess data...
    my $DefaultCustomerID = $Kernel::OM->Get('Config')->Get(
        'ContactImport::DefaultCustomerID'
    ) || 'DefaultCustomerID';
    my $DefaultEmailAddress = $Kernel::OM->Get('Config')->Get(
        'ContactImport::DefaultEmailAddress'
    ) || 'dummy@localhost';
    my $EmailDomainCustomerIDMapping = $Kernel::OM->Get('Config')->Get(
        'ContactImport::EMailDomainCustomerIDMapping'
    );

    # lookup Valid-ID...
    if ( !$NewContactData{ValidID} && $NewContactData{Valid} ) {
        $NewContactData{ValidID} = $Kernel::OM->Get('Valid')->ValidLookup(
            Valid => $NewContactData{Valid}
        );
    }
    if ( !$NewContactData{ValidID} ) {
        $NewContactData{ValidID} = $ObjectData->{DefaultValid} || 1;
    }

    #UserEmail-Domain 2 CustomerID Mapping...
    if ( $ObjectData->{EnableMailDomainCustomerIDMapping} ) {

        # get company mapping from email address
        if ( $NewContactData{UserEmail} ) {

            for my $Key ( keys( %{$EmailDomainCustomerIDMapping} ) ) {
                $EmailDomainCustomerIDMapping->{ lc($Key) } = $EmailDomainCustomerIDMapping->{$Key};
            }

            my ( $LocalPart, $DomainPart ) = split( '@', $NewContactData{UserEmail} );
            $DomainPart = lc($DomainPart);

            if ( $EmailDomainCustomerIDMapping->{$DomainPart} ) {
                $NewContactData{UserCustomerID} =
                    $EmailDomainCustomerIDMapping->{$DomainPart};
            }
            elsif (
                $EmailDomainCustomerIDMapping->{$DomainPart}
                && $EmailDomainCustomerIDMapping->{ANYTHINGELSE}
                )
            {
                $NewContactData{UserCustomerID} =
                    $EmailDomainCustomerIDMapping->{ANYTHINGELSE};
            }
        }
    }

    # default UserCustomerID...
    if ( !$NewContactData{UserCustomerID} ) {
        $NewContactData{UserCustomerID} = $ContactData{UserCustomerID}
            || $ObjectData->{DefaultUserCustomerID}
            || $DefaultCustomerID;
    }

    # default UserEmail...
    if ( !$NewContactData{UserEmail} ) {
        $NewContactData{UserEmail} = $ContactData{UserEmail}
            || $ObjectData->{DefaultUserEmail}
            || $DefaultEmailAddress;
    }

    # reset UserPassword...
    if (
        ( $NewUser || $ObjectData->{ResetPassword} )
        && (
            ( $NewContactData{UserPassword} && $NewContactData{UserPassword} eq '-' )
            || ( !$NewContactData{UserPassword} )
        )
        )
    {
        $NewContactData{UserPassword} = $NewContactData{$ContactKey}
            . ( $ObjectData->{ResetPasswordSuffix} || '' );
    }
    elsif ( !$NewUser && !$ObjectData->{ResetPassword} ) {
        delete $NewContactData{UserPassword};
        delete $ContactData{UserPassword};
    }

    #---------------------------------------------------------------------------
    # (2) overwrite existing values with new values...
    for my $Key ( keys(%NewContactData) ) {
        $ContactData{$Key} = $NewContactData{$Key};
    }

    #---------------------------------------------------------------------------
    # (3) if user DOES NOT exists => create in specified backend
    # update user
    my $Result     = 0;
    my $ReturnCode = "";    # Created | Changed | Failed
    if ($NewUser) {

        # set defaults
        delete $ContactData{ID};
        $Result = $Kernel::OM->Get('Contact')->ContactAdd(
            %ContactData,
            Source => $ObjectData->{CustomerBackend} || $ObjectData->{ContactBackend},
            UserID => $Param{UserID},
        );

        if ( !$Result ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "ImportDataSave: adding Contact ("
                    . "CustomerEmail "
                    . $ContactData{UserEmail}
                    . ") failed (line $Param{Counter}).",
            );
        }
        else {
            $ReturnCode = "Created";
        }

    }

    #---------------------------------------------------------------------------
    #(3) if user DOES exists => check backend and update...
    else {
        $ContactData{ID} = $NewContactData{$ContactKey};

        if (
            $ContactData{Source}
            && $ContactData{Source} eq $ObjectData->{CustomerBackend}
            )
        {
            $Result = $Kernel::OM->Get('Contact')->ContactUpdate(
                Source => $ObjectData->{CustomerBackend},
                %ContactData,
                UserID => $Param{UserID},
            );

            if ( !$Result ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "ImportDataSave: updating Contact ("
                        . "CustomerEmail "
                        . $ContactData{UserEmail}
                        . ") failed (line $Param{Counter}).",
                );
            }
            else {
                $ReturnCode = "Changed";
            }
        }
        elsif ( $ObjectData->{ForceImportInConfiguredCustomerBackend} ) {

            # NOTE: this is a somewhat dirty hack to force the import of the
            # customer user data in the backend which is assigned in the current
            # mapping. Actually a customer data set can not be added under the
            # same key (UserLogin).

            my %BackendRef = ();
            my $ResultNote = "";

            # find backend and backup customer user data backend refs...
            while (
                $ContactData{Source}
                && $ContactData{Source} ne $ObjectData->{CustomerBackend}
                )
            {
                $BackendRef{ $ContactData{Source} } =
                    $Kernel::OM->Get('Contact')->{ $ContactData{Source} };
                delete( $Kernel::OM->Get('Contact')->{ $ContactData{Source} } );

                %ContactData = $Kernel::OM->Get('Contact')->ContactGet(
                    ID => $NewContactData{$ContactKey}
                );
            }

            # overwrite existing values with new values...
            for my $Key ( keys(%NewContactData) ) {
                $ContactData{$Key} = $NewContactData{$Key};
            }

            # update existing entry...
            if (
                $ContactData{Source}
                && $ContactData{Source} eq $ObjectData->{CustomerBackend}
                )
            {
                $ContactData{ID} = $NewContactData{$ContactKey};
                $Result = $Kernel::OM->Get('Contact')->ContactUpdate(
                    %ContactData,
                    Source => $ObjectData->{CustomerBackend},
                    UserID => $Param{UserID},
                );
                $ResultNote = "update";
                $ReturnCode = "Changed";
            }

            # create new entry...
            else {
                $Result = $Kernel::OM->Get('Contact')->ContactAdd(
                    %ContactData,
                    Source => $ObjectData->{CustomerBackend},
                    UserID => $Param{UserID},
                );
                $ResultNote = "add";
                $ReturnCode = "Created";
            }

            # check for errors...
            if ( !$Result ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "ImportDataSave: forcing Contact ("
                        . "CustomerEmail "
                        . $ContactData{UserEmail}
                        . ") in "
                        . $ObjectData->{CustomerBackend}
                        . " ($ResultNote) "
                        . " failed (line $Param{Counter}).",
                );
                $ReturnCode = "";
            }

            # restore customer user data backend refs...
            for my $CurrKey ( keys(%BackendRef) ) {
                $Kernel::OM->Get('Contact')->{$CurrKey} = $BackendRef{$CurrKey};
            }

        }
        else {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'notice',
                Message  => "ImportDataSave: updating Contact ("
                    . "CustomerEmail "
                    . $ContactData{UserEmail}
                    . ") failed - Contact exists in other backend.",

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
