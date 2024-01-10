# --
# Modified version of the work: Copyright (C) 2006-2024 KIX Service Software GmbH, https://www.kixdesk.com
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ImportExport;

use strict;
use warnings;

use MIME::Base64;
use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'ClientRegistration',
    'Cache',
    'Config',
    'CheckItem',
    'DB',
    'Log',
    'Time',
    'Encode',
    'Daemon::SchedulerDB',
);

=head1 NAME

Kernel::System::ImportExport - import, export lib

=head1 SYNOPSIS

All import and export functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $ImportExportObject = $Kernel::OM->Get('ImportExport');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{CacheType} = 'ImportExportTemplate';
    $Self->{CacheTTL}  = 60 * 60 * 24 * 20;

    return $Self;
}

=item TemplateList()

return a list of templates as array reference

    my $TemplateList = $ImportExportObject->TemplateList(
        Object => 'Ticket',  # (optional)
        Format => 'CSV'      # (optional)
        UserID => 1,
    );

=cut

sub TemplateList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need UserID!',
        );
        return;
    }

    # create sql string
    my $SQL = 'SELECT id FROM imexport_template WHERE 1=1 ';
    my @BIND;

    if ( $Param{Object} ) {
        $SQL .= 'AND imexport_object = ? ';
        push @BIND, \$Param{Object};
    }
    if ( $Param{Format} ) {
        $SQL .= 'AND imexport_format = ? ';
        push @BIND, \$Param{Format};
    }

    # add order option
    $SQL .= 'ORDER BY id';

    # get DB object
    my $DBObject = $Kernel::OM->Get('DB');

    # ask database
    return if !$DBObject->Prepare(
        SQL  => $SQL,
        Bind => \@BIND,
    );

    # fetch the result
    my @TemplateList;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        push @TemplateList, $Row[0];
    }

    return \@TemplateList;
}

=item TemplateGet()

get a import export template

Return
    $TemplateData{TemplateID}
    $TemplateData{Number}
    $TemplateData{Object}
    $TemplateData{Format}
    $TemplateData{Name}
    $TemplateData{ValidID}
    $TemplateData{Comment}
    $TemplateData{CreateTime}
    $TemplateData{CreateBy}
    $TemplateData{ChangeTime}
    $TemplateData{ChangeBy}

    my $TemplateDataRef = $ImportExportObject->TemplateGet(
        TemplateID => 3,
        UserID     => 1,
    );

=cut

sub TemplateGet {
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

    my $CacheKey = 'TemplateGet::TemplateID::' . $Param{TemplateID};

    # read cache
    my $Cache = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return $Cache if $Cache;

    # get DB object
    my $DBObject = $Kernel::OM->Get('DB');

    # ask database
    return if !$DBObject->Prepare(
        SQL => 'SELECT id, imexport_object, imexport_format, name, valid_id, comments, '
            . 'create_time, create_by, change_time, change_by FROM imexport_template WHERE id = ?',
        Bind  => [ \$Param{TemplateID} ],
        Limit => 1,
    );

    # fetch the result
    my %TemplateData;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $TemplateData{TemplateID} = $Row[0];
        $TemplateData{Object}     = $Row[1];
        $TemplateData{Format}     = $Row[2];
        $TemplateData{Name}       = $Row[3];
        $TemplateData{ValidID}    = $Row[4];
        $TemplateData{Comment}    = $Row[5] || '';
        $TemplateData{CreateTime} = $Row[6];
        $TemplateData{CreateBy}   = $Row[7];
        $TemplateData{ChangeTime} = $Row[8];
        $TemplateData{ChangeBy}   = $Row[9];

        $TemplateData{Number} = sprintf "%06d", $TemplateData{TemplateID};
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        Key   => $CacheKey,
        Value => \%TemplateData,
        TTL   => $Self->{CacheTTL},
    );

    return \%TemplateData;
}

=item TemplateAdd()

add a new import/export template

    my $TemplateID = $ImportExportObject->TemplateAdd(
        Object  => 'Ticket',
        Format  => 'CSV',
        Name    => 'Template Name',
        ValidID => 1,
        Comment => 'Comment',       # (optional)
        UserID  => 1,
    );

=cut

sub TemplateAdd {
    my ( $Self, %Param ) = @_;

    # get log object
    my $LogObject = $Kernel::OM->Get('Log');

    # check needed stuff
    for my $Argument (qw(Object Format Name ValidID UserID)) {
        if ( !$Param{$Argument} ) {
            if ( !$Param{Silent} ) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "Need $Argument!",
                );
            }
            return;
        }
    }

    # set default values
    $Param{Comment} ||= '';

    # get CheckItem object
    my $CheckItemObject = $Kernel::OM->Get('CheckItem');

    # cleanup given params
    for my $Argument (qw(Object Format)) {
        $CheckItemObject->StringClean(
            StringRef         => \$Param{$Argument},
            RemoveAllNewlines => 1,
            RemoveAllTabs     => 1,
            RemoveAllSpaces   => 1,
        );
    }
    for my $Argument (qw(Name Comment)) {
        $CheckItemObject->StringClean(
            StringRef         => \$Param{$Argument},
            RemoveAllNewlines => 1,
            RemoveAllTabs     => 1,
        );
    }

    # get DB object
    my $DBObject = $Kernel::OM->Get('DB');

    # find exiting template with same name
    $DBObject->Prepare(
        SQL   => 'SELECT id FROM imexport_template WHERE imexport_object = ? AND name = ?',
        Bind  => [ \$Param{Object}, \$Param{Name} ],
        Limit => 1,
    );

    # fetch the result
    my $NoAdd;
    while ( $DBObject->FetchrowArray() ) {
        $NoAdd = 1;
    }

    # abort insert of new template, if template name already exists
    if ($NoAdd) {
        if ( !$Param{Silent} ) {
            $LogObject->Log(
                Priority => 'error',
                Message =>
                    "Can't add new template! Template with same name already exists in this object.",
            );
        }
        return;
    }

    # insert new template
    return if !$DBObject->Do(
        SQL => 'INSERT INTO imexport_template '
            . '(imexport_object, imexport_format, name, valid_id, comments, '
            . 'create_time, create_by, change_time, change_by) VALUES '
            . '(?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$Param{Object}, \$Param{Format}, \$Param{Name}, \$Param{ValidID},
            \$Param{Comment}, \$Param{UserID}, \$Param{UserID},
        ],
    );

    # find id of new template
    $DBObject->Prepare(
        SQL   => 'SELECT id FROM imexport_template WHERE imexport_object = ? AND name = ?',
        Bind  => [ \$Param{Object}, \$Param{Name} ],
        Limit => 1,
    );

    # fetch the result
    my $TemplateID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $TemplateID = $Row[0];
    }

    # cleanup cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType}
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'ImportExportTemplate',
        ObjectID  => $TemplateID,
    );

    return $TemplateID;
}

=item TemplateUpdate()

update a existing import/export template

    my $True = $ImportExportObject->TemplateUpdate(
        TemplateID => 123,
        Name       => 'Template Name',
        ValidID    => 1,
        Comment    => 'Comment',        # (optional)
        UserID     => 1,
    );

=cut

sub TemplateUpdate {
    my ( $Self, %Param ) = @_;

    # get log object
    my $LogObject = $Kernel::OM->Get('Log');

    # check needed stuff
    for my $Argument (qw(TemplateID Name ValidID UserID)) {
        if ( !$Param{$Argument} ) {
            if ( !$Param{Silent} ) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "Need $Argument!",
                );
            }
            return;
        }
    }

    # set default values
    $Param{Comment} ||= '';

    # cleanup given params
    for my $Argument (qw(Name Comment)) {
        $Kernel::OM->Get('CheckItem')->StringClean(
            StringRef         => \$Param{$Argument},
            RemoveAllNewlines => 1,
            RemoveAllTabs     => 1,
        );
    }

    # get DB object
    my $DBObject = $Kernel::OM->Get('DB');

    # get the object of this template id
    $DBObject->Prepare(
        SQL   => 'SELECT imexport_object FROM imexport_template WHERE id = ?',
        Bind  => [ \$Param{TemplateID} ],
        Limit => 1,
    );

    # fetch the result
    my $Object;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Object = $Row[0];
    }

    if ( !$Object ) {
        if ( !$Param{Silent} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Can't update template because it hasn't been found!",
            );
        }
        return;
    }

    # find exiting template with same name
    $DBObject->Prepare(
        SQL   => 'SELECT id FROM imexport_template WHERE imexport_object = ? AND name = ?',
        Bind  => [ \$Object, \$Param{Name} ],
        Limit => 1,
    );

    # fetch the result
    my $Update = 1;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        if ( $Param{TemplateID} ne $Row[0] ) {
            $Update = 0;
        }
    }

    if ( !$Update ) {
        if ( !$Param{Silent} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Can't update template! Template with same name already exists in this object.",
            );
        }
        return;
    }

    # update template
    my $Success = $DBObject->Do(
        SQL => 'UPDATE imexport_template SET name = ?,'
            . 'valid_id = ?, comments = ?, '
            . 'change_time = current_timestamp, change_by = ? '
            . 'WHERE id = ?',
        Bind => [
            \$Param{Name}, \$Param{ValidID}, \$Param{Comment},
            \$Param{UserID}, \$Param{TemplateID},
        ],
    );

    # cleanup cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType}
    );

    # push client callback event
    if ($Success) {
        $Kernel::OM->Get('ClientNotification')->NotifyClients(
            Event     => 'UPDATE',
            Namespace => 'ImportExportTemplate',
            ObjectID  => $Param{TemplateID},
        );
    }

    return $Success;
}

=item TemplateDelete()

delete existing import/export templates

    my $True = $ImportExportObject->TemplateDelete(
        TemplateID => 123,
        UserID     => 1,
    );

    or

    my $True = $ImportExportObject->TemplateDelete(
        TemplateID => [1,44,166,5],
        UserID     => 1,
    );

=cut

sub TemplateDelete {
    my ( $Self, %Param ) = @_;

    # get log object
    my $LogObject = $Kernel::OM->Get('Log');

    # check needed stuff
    for my $Argument (qw(TemplateID UserID)) {
        if ( !$Param{$Argument} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    if ( !ref $Param{TemplateID} ) {
        $Param{TemplateID} = [ $Param{TemplateID} ];
    }
    elsif ( ref $Param{TemplateID} ne 'ARRAY' ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'TemplateID must be an array reference or a string!',
        );
        return;
    }

    # delete existing search data
    $Self->SearchDataDelete(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    # delete all mapping data
    for my $TemplateID ( @{ $Param{TemplateID} } ) {
        $Self->MappingDelete(
            TemplateID => $TemplateID,
            UserID     => $Param{UserID},
        );
    }

    # delete existing format data
    $Self->FormatDataDelete(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    # delete existing object data
    $Self->ObjectDataDelete(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    # delete existing run data
    $Self->_TemplateRunDelete(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID}
    );

    # create the template id string
    my $TemplateIDString = join q{, }, map {'?'} @{ $Param{TemplateID} };

    # create and add bind parameters
    my @BIND = map { \$_ } @{ $Param{TemplateID} };

    # cleanup cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType}
    );

    # delete templates
    my $Success = $Kernel::OM->Get('DB')->Do(
        SQL  => "DELETE FROM imexport_template WHERE id IN ( $TemplateIDString )",
        Bind => \@BIND,
    );

    # push client callback event
    if ($Success) {
        for my $TemplateID ( @{$Param{TemplateID}} ) {
            $Kernel::OM->Get('ClientNotification')->NotifyClients(
                Event     => 'DELETE',
                Namespace => 'ImportExportTemplate',
                ObjectID  => $TemplateID
            );
        }
    }

    return $Success;
}

=item ObjectList()

return a list of available objects as hash reference

    my $ObjectList = $ImportExportObject->ObjectList();

=cut

sub ObjectList {
    my ( $Self, %Param ) = @_;

    # get config
    my $ModuleList = $Kernel::OM->Get('Config')->Get('ImportExport::ObjectBackendRegistration');

    return if !$ModuleList;
    return if ref $ModuleList ne 'HASH';

    # create the object list
    my $ObjectList = {};
    for my $Module ( sort keys %{$ModuleList} ) {
        $ObjectList->{$Module} = $ModuleList->{$Module}->{Name};
    }

    return $ObjectList;
}

=item ObjectDataGet()

get the object data from a template

    my $ObjectDataRef = $ImportExportObject->ObjectDataGet(
        TemplateID => 3,
        UserID     => 1,
    );

=cut

sub ObjectDataGet {
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

    # get DB object
    my $DBObject = $Kernel::OM->Get('DB');

    # ask database
    $DBObject->Prepare(
        SQL  => 'SELECT data_key, data_value FROM imexport_object WHERE template_id = ?',
        Bind => [ \$Param{TemplateID} ],
    );

    # fetch the result
    my %ObjectData;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ObjectData{ $Row[0] } = $Row[1];
    }

    return \%ObjectData;
}

=item ObjectDataSave()

save the object data of a template

    my $True = $ImportExportObject->ObjectDataSave(
        TemplateID => 123,
        ObjectData => $HashRef,
        UserID     => 1,
    );

=cut

sub ObjectDataSave {
    my ( $Self, %Param ) = @_;

    # get log object
    my $LogObject = $Kernel::OM->Get('Log');

    # check needed stuff
    for my $Argument (qw(TemplateID ObjectData UserID)) {
        if ( !$Param{$Argument} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    if ( ref $Param{ObjectData} ne 'HASH' ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'ObjectData must be a hash reference!',
        );
        return;
    }

    # delete existing object data
    $Self->ObjectDataDelete(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    DATAKEY:
    for my $DataKey ( sort keys %{ $Param{ObjectData} } ) {

        my $DataValue = $Param{ObjectData}->{$DataKey};

        next DATAKEY if !defined $DataKey;
        next DATAKEY if !defined $DataValue;

        # insert one row
        $Kernel::OM->Get('DB')->Do(
            SQL => 'INSERT INTO imexport_object '
                . '(template_id, data_key, data_value) VALUES '
                . '(?, ?, ?)',
            Bind => [ \$Param{TemplateID}, \$DataKey, \$DataValue ],
        );
    }

    return 1;
}

=item ObjectDataDelete()

delete the existing object data of a template

    my $True = $ImportExportObject->ObjectDataDelete(
        TemplateID => 123,
        UserID     => 1,
    );

    or

    my $True = $ImportExportObject->ObjectDataDelete(
        TemplateID => [1,44,166,5],
        UserID     => 1,
    );

=cut

sub ObjectDataDelete {
    my ( $Self, %Param ) = @_;

    # get log object
    my $LogObject = $Kernel::OM->Get('Log');

    # check needed stuff
    for my $Argument (qw(TemplateID UserID)) {
        if ( !$Param{$Argument} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    if ( !ref $Param{TemplateID} ) {
        $Param{TemplateID} = [ $Param{TemplateID} ];
    }
    elsif ( ref $Param{TemplateID} ne 'ARRAY' ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'TemplateID must be an array reference or a string!',
        );
        return;
    }

    # create the template id string
    my $TemplateIDString = join q{, }, map {'?'} @{ $Param{TemplateID} };

    # create and add bind parameters
    my @BIND = map { \$_ } @{ $Param{TemplateID} };

    # delete templates
    return $Kernel::OM->Get('DB')->Do(
        SQL  => "DELETE FROM imexport_object WHERE template_id IN ( $TemplateIDString )",
        Bind => \@BIND,
    );
}

=item FormatList()

return a list of available formats as hash reference

    my $FormatList = $ImportExportObject->FormatList();

=cut

sub FormatList {
    my ( $Self, %Param ) = @_;

    # get config
    my $ModuleList = $Kernel::OM->Get('Config')->Get('ImportExport::FormatBackendRegistration');

    return if !$ModuleList;
    return if ref $ModuleList ne 'HASH';

    # create the format list
    my $FormatList = {};
    for my $Module ( sort keys %{$ModuleList} ) {
        $FormatList->{$Module} = $ModuleList->{$Module}->{Name};
    }

    return $FormatList;
}

=item FormatAttributesGet()

get the attributes of a format backend as array/hash reference

    my $Attributes = $ImportExportObject->FormatAttributesGet(
        TemplateID => 123,
        UserID     => 1,
    );

=cut

sub FormatAttributesGet {
    my ( $Self, %Param ) = @_;

    # get log object
    my $LogObject = $Kernel::OM->Get('Log');

    # check needed stuff
    for my $Argument (qw(TemplateID UserID)) {
        if ( !$Param{$Argument} ) {
            if ( !$Param{Silent} ) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "Need $Argument!",
                );
            }
            return;
        }
    }

    # get template data
    my $TemplateData = $Self->TemplateGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    # check template data
    if ( !$TemplateData || !$TemplateData->{Format} ) {
        if ( !$Param{Silent} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Template with ID $Param{TemplateID} is incomplete!",
            );
        }
        return;
    }

    my $ModuleList = $Kernel::OM->Get('Config')->Get('ImportExport::FormatBackendRegistration');

    # load backend
    my $Backend = $Kernel::OM->Get(
        $ModuleList->{$TemplateData->{Format}}->{Module}
    );

    return if !$Backend;

    # get an attribute list of the format
    my $Attributes = $Backend->FormatAttributesGet(
        UserID => $Param{UserID},
    );

    return $Attributes;
}

=item FormatDataGet()

get the format data from a template

    my $FormatDataRef = $ImportExportObject->FormatDataGet(
        TemplateID => 3,
        UserID     => 1,
    );

=cut

sub FormatDataGet {
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

    # get DB object
    my $DBObject = $Kernel::OM->Get('DB');

    # ask database
    return if !$DBObject->Prepare(
        SQL  => 'SELECT data_key, data_value FROM imexport_format WHERE template_id = ?',
        Bind => [ \$Param{TemplateID} ],
    );

    # fetch the result
    my %FormatData;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $FormatData{ $Row[0] } = $Row[1];
    }

    return \%FormatData;
}

=item FormatDataSave()

save the format data of a template

    my $True = $ImportExportObject->FormatDataSave(
        TemplateID => 123,
        FormatData => $HashRef,
        UserID     => 1,
    );

=cut

sub FormatDataSave {
    my ( $Self, %Param ) = @_;

    # get log object
    my $LogObject = $Kernel::OM->Get('Log');

    # check needed stuff
    for my $Argument (qw(TemplateID FormatData UserID)) {
        if ( !$Param{$Argument} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    if ( ref $Param{FormatData} ne 'HASH' ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'FormatData must be a hash reference!',
        );
        return;
    }

    # delete existing format data
    $Self->FormatDataDelete(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    DATAKEY:
    for my $DataKey ( sort keys %{ $Param{FormatData} } ) {

        my $DataValue = $Param{FormatData}->{$DataKey};

        next DATAKEY if !defined $DataKey;
        next DATAKEY if !defined $DataValue;

        # insert one row
        return if !$Kernel::OM->Get('DB')->Do(
            SQL => 'INSERT INTO imexport_format '
                . '(template_id, data_key, data_value) VALUES (?, ?, ?)',
            Bind => [ \$Param{TemplateID}, \$DataKey, \$DataValue ],
        );
    }

    return 1;
}

=item FormatDataDelete()

delete the existing format data of a template

    my $True = $ImportExportObject->FormatDataDelete(
        TemplateID => 123,
        UserID     => 1,
    );

    or

    my $True = $ImportExportObject->FormatDataDelete(
        TemplateID => [1,44,166,5],
        UserID     => 1,
    );

=cut

sub FormatDataDelete {
    my ( $Self, %Param ) = @_;

    # get log object
    my $LogObject = $Kernel::OM->Get('Log');

    # check needed stuff
    for my $Argument (qw(TemplateID UserID)) {
        if ( !$Param{$Argument} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    if ( !ref $Param{TemplateID} ) {
        $Param{TemplateID} = [ $Param{TemplateID} ];
    }
    elsif ( ref $Param{TemplateID} ne 'ARRAY' ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'TemplateID must be an array reference or a string!',
        );
        return;
    }

    # create the template id string
    my $TemplateIDString = join q{, }, map {'?'} @{ $Param{TemplateID} };

    # create and add bind parameters
    my @BIND = map { \$_ } @{ $Param{TemplateID} };

    # delete templates
    return $Kernel::OM->Get('DB')->Do(
        SQL  => "DELETE FROM imexport_format WHERE template_id IN ( $TemplateIDString )",
        Bind => \@BIND,
    );
}

=item MappingList()

return a list of mapping data ids sorted by position as array reference

    my $MappingList = $ImportExportObject->MappingList(
        TemplateID => 123,
        UserID     => 1,
    );

=cut

sub MappingList {
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

    # get DB object
    my $DBObject = $Kernel::OM->Get('DB');

    # ask database
    $DBObject->Prepare(
        SQL  => 'SELECT id FROM imexport_mapping WHERE template_id = ? ORDER BY position',
        Bind => [ \$Param{TemplateID} ],
    );

    # fetch the result
    my @MappingList;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        push @MappingList, $Row[0];
    }

    return \@MappingList;
}

=item MappingAdd()

add a new mapping data row

    my $MappingID = $ImportExportObject->MappingAdd(
        TemplateID => 123,
        UserID     => 1,
    );

=cut

sub MappingAdd {
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

    # get DB object
    my $DBObject = $Kernel::OM->Get('DB');

    # find maximum position
    return if !$DBObject->Prepare(
        SQL   => 'SELECT max(position) FROM imexport_mapping WHERE template_id = ?',
        Bind  => [ \$Param{TemplateID} ],
        Limit => 1,
    );

    # fetch the result
    my $NewPosition = 0;
    while ( my @Row = $DBObject->FetchrowArray() ) {

        if ( defined $Row[0] ) {
            $NewPosition = $Row[0];
            $NewPosition++;
        }
    }

    # insert a new mapping data row
    return if !$DBObject->Do(
        SQL  => 'INSERT INTO imexport_mapping (template_id, position) VALUES (?, ?)',
        Bind => [ \$Param{TemplateID}, \$NewPosition ],
    );

    # find id of new mapping data row
    $DBObject->Prepare(
        SQL   => 'SELECT id FROM imexport_mapping WHERE template_id = ? AND position = ?',
        Bind  => [ \$Param{TemplateID}, \$NewPosition ],
        Limit => 1,
    );

    # fetch the result
    my $MappingID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $MappingID = $Row[0];
    }

    return $MappingID;
}

=item MappingDelete()

delete existing mapping data rows

    my $True = $ImportExportObject->MappingDelete(
        MappingID  => 123,
        TemplateID => 321,
        UserID     => 1,
    );

    or

    my $True = $ImportExportObject->MappingDelete(
        TemplateID => 321,
        UserID     => 1,
    );

=cut

sub MappingDelete {
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

    # get DB object
    my $DBObject = $Kernel::OM->Get('DB');

    if ( defined $Param{MappingID} ) {

        # delete existing object mapping data
        $Self->MappingObjectDataDelete(
            MappingID => $Param{MappingID},
            UserID    => $Param{UserID},
        );

        # delete existing format mapping data
        $Self->MappingFormatDataDelete(
            MappingID => $Param{MappingID},
            UserID    => $Param{UserID},
        );

        # delete one mapping row
        return if !$DBObject->Do(
            SQL  => 'DELETE FROM imexport_mapping WHERE id = ?',
            Bind => [ \$Param{MappingID} ],
        );

        # rebuild mapping positions
        $Self->MappingPositionRebuild(
            TemplateID => $Param{TemplateID},
            UserID     => $Param{UserID},
        );

        return 1;
    }
    else {

        # get mapping list
        my $MappingList = $Self->MappingList(
            TemplateID => $Param{TemplateID},
            UserID     => $Param{UserID},
        );

        for my $MappingID ( @{$MappingList} ) {

            # delete existing object mapping data
            $Self->MappingObjectDataDelete(
                MappingID => $MappingID,
                UserID    => $Param{UserID},
            );

            # delete existing format mapping data
            $Self->MappingFormatDataDelete(
                MappingID => $MappingID,
                UserID    => $Param{UserID},
            );
        }

        # delete all mapping rows of this template
        return $DBObject->Do(
            SQL  => 'DELETE FROM imexport_mapping WHERE template_id = ?',
            Bind => [ \$Param{TemplateID} ],
        );
    }
}

=item MappingUp()

move an mapping data row up

    my $True = $ImportExportObject->MappingUp(
        MappingID  => 123,
        TemplateID => 321,
        UserID     => 1,
    );

=cut

sub MappingUp {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(MappingID TemplateID UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get mapping data list
    my $MappingList = $Self->MappingList(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    return 1 if $Param{MappingID} == $MappingList->[0];

    # get DB object
    my $DBObject = $Kernel::OM->Get('DB');

    # ask database
    return if !$DBObject->Prepare(
        SQL  => 'SELECT position FROM imexport_mapping WHERE id = ?',
        Bind => [ \$Param{MappingID} ],
    );

    # fetch the result
    my $Position;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Position = $Row[0];
    }

    return 1 if !$Position;

    my $PositionUpper = $Position - 1;

    # update positions
    $DBObject->Do(
        SQL  => 'UPDATE imexport_mapping SET position = ? WHERE template_id = ? AND position = ?',
        Bind => [ \$Position, \$Param{TemplateID}, \$PositionUpper ],
    );
    $DBObject->Do(
        SQL  => 'UPDATE imexport_mapping SET position = ? WHERE id = ?',
        Bind => [ \$PositionUpper, \$Param{MappingID} ],
    );

    return 1;
}

=item MappingDown()

move an mapping data row down

    my $True = $ImportExportObject->MappingDown(
        MappingID  => 123,
        TemplateID => 321,
        UserID     => 1,
    );

=cut

sub MappingDown {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(MappingID TemplateID UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get mapping data list
    my $MappingList = $Self->MappingList(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    return 1 if $Param{MappingID} == $MappingList->[-1];

    # get DB object
    my $DBObject = $Kernel::OM->Get('DB');

    # ask database
    $DBObject->Prepare(
        SQL  => 'SELECT position FROM imexport_mapping WHERE id = ?',
        Bind => [ \$Param{MappingID} ],
    );

    # fetch the result
    my $Position;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Position = $Row[0];
    }

    my $PositionDown = $Position + 1;

    # update positions
    $DBObject->Do(
        SQL  => 'UPDATE imexport_mapping SET position = ? WHERE template_id = ? AND position = ?',
        Bind => [ \$Position, \$Param{TemplateID}, \$PositionDown ],
    );
    $DBObject->Do(
        SQL  => 'UPDATE imexport_mapping SET position = ? WHERE id = ?',
        Bind => [ \$PositionDown, \$Param{MappingID} ],
    );

    return 1;
}

=item MappingPositionRebuild()

rebuild the positions of a mapping list

    my $True = $ImportExportObject->MappingPositionRebuild(
        TemplateID => 123,
        UserID     => 1,
    );

=cut

sub MappingPositionRebuild {
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

    # get mapping data list
    my $MappingList = $Self->MappingList(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    # update position
    my $Counter = 0;
    for my $MappingID ( @{$MappingList} ) {
        $Kernel::OM->Get('DB')->Do(
            SQL  => 'UPDATE imexport_mapping SET position = ? WHERE id = ?',
            Bind => [ \$Counter, \$MappingID ],
        );
        $Counter++;
    }

    return 1;
}

=item MappingObjectAttributesGet()

get the attributes of an object backend as array/hash reference

    my $Attributes = $ImportExportObject->MappingObjectAttributesGet(
        TemplateID => 123,
        UserID     => 1,
    );

=cut

sub MappingObjectAttributesGet {
    my ( $Self, %Param ) = @_;

    # get log object
    my $LogObject = $Kernel::OM->Get('Log');

    # check needed stuff
    for my $Argument (qw(TemplateID UserID)) {
        if ( !$Param{$Argument} ) {
            return if $Param{Silent};

            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get template data
    my $TemplateData = $Self->TemplateGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
        Silent     => $Param{Silent}
    );

    # check template data
    if ( !$TemplateData || !$TemplateData->{Object} ) {
        return if $Param{Silent};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Template with ID $Param{TemplateID} is incomplete!",
        );
        return;
    }

    my $ModuleList = $Kernel::OM->Get('Config')->Get('ImportExport::ObjectBackendRegistration');

    # load backend
    my $Backend = $Kernel::OM->Get(
        $ModuleList->{$TemplateData->{Object}}->{Module}
    );

    return if !$Backend;

    # get an attribute list of the object
    my $Attributes = $Backend->MappingObjectAttributesGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
        Silent     => $Param{Silent}
    );

    return $Attributes;
}

=item MappingObjectDataDelete()

delete the existing object data of a mapping

    my $True = $ImportExportObject->MappingObjectDataDelete(
        MappingID => 123,
        UserID    => 1,
    );

    or

    my $True = $ImportExportObject->MappingObjectDataDelete(
        MappingID => [1,44,166,5],
        UserID    => 1,
    );

=cut

sub MappingObjectDataDelete {
    my ( $Self, %Param ) = @_;

    # get log object
    my $LogObject = $Kernel::OM->Get('Log');

    # check needed stuff
    for my $Argument (qw(MappingID UserID)) {
        if ( !$Param{$Argument} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    if ( !ref $Param{MappingID} ) {
        $Param{MappingID} = [ $Param{MappingID} ];
    }
    elsif ( ref $Param{MappingID} ne 'ARRAY' ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'MappingID must be an array reference or a string!',
        );
        return;
    }

    # create the template id string
    my $MappingIDString = join q{, }, map {'?'} @{ $Param{MappingID} };

    # create and add bind parameters
    my @BIND = map { \$_ } @{ $Param{MappingID} };

    # delete mapping object data
    return $Kernel::OM->Get('DB')->Do(
        SQL  => "DELETE FROM imexport_mapping_object WHERE mapping_id IN ( $MappingIDString )",
        Bind => \@BIND,
    );
}

=item MappingObjectDataSave()

save the object data of a mapping

    my $True = $ImportExportObject->MappingObjectDataSave(
        MappingID         => 123,
        MappingObjectData => $HashRef,
        UserID            => 1,
    );

=cut

sub MappingObjectDataSave {
    my ( $Self, %Param ) = @_;

    # get log object
    my $LogObject = $Kernel::OM->Get('Log');

    # check needed stuff
    for my $Argument (qw(MappingID MappingObjectData UserID)) {
        if ( !$Param{$Argument} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    if ( ref $Param{MappingObjectData} ne 'HASH' ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'MappingObjectData must be a hash reference!',
        );
        return;
    }

    # delete existing object mapping data
    $Self->MappingObjectDataDelete(
        MappingID => $Param{MappingID},
        UserID    => $Param{UserID},
    );

    DATAKEY:
    for my $DataKey ( sort keys %{ $Param{MappingObjectData} } ) {

        my $DataValue = $Param{MappingObjectData}->{$DataKey};

        next DATAKEY if !defined $DataKey;
        next DATAKEY if !defined $DataValue;

        # insert one mapping object row
        $Kernel::OM->Get('DB')->Do(
            SQL => 'INSERT INTO imexport_mapping_object '
                . '(mapping_id, data_key, data_value) VALUES (?, ?, ?)',
            Bind => [ \$Param{MappingID}, \$DataKey, \$DataValue ],
        );
    }

    return 1;
}

=item MappingObjectDataGet()

get the object data of a mapping

    my $ObjectDataRef = $ImportExportObject->MappingObjectDataGet(
        MappingID => 123,
        UserID    => 1,
    );

=cut

sub MappingObjectDataGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(MappingID UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get DB object
    my $DBObject = $Kernel::OM->Get('DB');

    # ask database
    $DBObject->Prepare(
        SQL  => 'SELECT data_key, data_value FROM imexport_mapping_object WHERE mapping_id = ?',
        Bind => [ \$Param{MappingID} ],
    );

    # fetch the result
    my %MappingObjectData;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $MappingObjectData{ $Row[0] } = $Row[1];
    }

    return \%MappingObjectData;
}

=item MappingFormatAttributesGet()

get the attributes of an format backend as array/hash reference

    my $Attributes = $ImportExportObject->MappingFormatAttributesGet(
        TemplateID => 123,
        UserID     => 1,
    );

=cut

sub MappingFormatAttributesGet {
    my ( $Self, %Param ) = @_;

    # get log object
    my $LogObject = $Kernel::OM->Get('Log');

    # check needed stuff
    for my $Argument (qw(TemplateID UserID)) {
        if ( !$Param{$Argument} ) {
            if ( !$Param{Silent} ) {
                $LogObject->Log(
                    Priority => 'error',
                    Message  => "Need $Argument!",
                );
            }
            return;
        }
    }

    # get template data
    my $TemplateData = $Self->TemplateGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    # check template data
    if ( !$TemplateData || !$TemplateData->{Format} ) {
        if ( !$Param{Silent} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Template with ID $Param{TemplateID} is incomplete!",
            );
        }
        return;
    }

    my $ModuleList = $Kernel::OM->Get('Config')->Get('ImportExport::FormatBackendRegistration');

    # load backend
    my $Backend = $Kernel::OM->Get(
        $ModuleList->{$TemplateData->{Format}}->{Module}
    );

    return if !$Backend;

    # get an attribute list of the format
    my $Attributes = $Backend->MappingFormatAttributesGet(
        UserID => $Param{UserID},
    );

    return $Attributes;
}

=item MappingFormatDataDelete()

delete the existing format data of a mapping

    my $True = $ImportExportObject->MappingFormatDataDelete(
        MappingID => 123,
        UserID    => 1,
    );

    or

    my $True = $ImportExportObject->MappingFormatDataDelete(
        MappingID => [1,44,166,5],
        UserID    => 1,
    );

=cut

sub MappingFormatDataDelete {
    my ( $Self, %Param ) = @_;

    # get log object
    my $LogObject = $Kernel::OM->Get('Log');

    # check needed stuff
    for my $Argument (qw(MappingID UserID)) {
        if ( !$Param{$Argument} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    if ( !ref $Param{MappingID} ) {
        $Param{MappingID} = [ $Param{MappingID} ];
    }
    elsif ( ref $Param{MappingID} ne 'ARRAY' ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'MappingID must be an array reference or a string!',
        );
        return;
    }

    # create the template id string
    my $MappingIDString = join q{, }, map {'?'} @{ $Param{MappingID} };

    # create and add bind parameters
    my @BIND = map { \$_ } @{ $Param{MappingID} };

    # delete mapping format data
    return $Kernel::OM->Get('DB')->Do(
        SQL  => "DELETE FROM imexport_mapping_format WHERE mapping_id IN ( $MappingIDString )",
        Bind => \@BIND,
    );
}

=item MappingFormatDataSave()

save the format data of a mapping

    my $True = $ImportExportObject->MappingFormatDataSave(
        MappingID         => 123,
        MappingFormatData => $HashRef,
        UserID            => 1,
    );

=cut

sub MappingFormatDataSave {
    my ( $Self, %Param ) = @_;

    # get log object
    my $LogObject = $Kernel::OM->Get('Log');

    # check needed stuff
    for my $Argument (qw(MappingID MappingFormatData UserID)) {
        if ( !$Param{$Argument} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    if ( ref $Param{MappingFormatData} ne 'HASH' ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'MappingFormatData must be a hash reference!',
        );
        return;
    }

    # delete existing format mapping data
    $Self->MappingFormatDataDelete(
        MappingID => $Param{MappingID},
        UserID    => $Param{UserID},
    );

    DATAKEY:
    for my $DataKey ( sort keys %{ $Param{MappingFormatData} } ) {

        my $DataValue = $Param{MappingFormatData}->{$DataKey};

        next DATAKEY if !defined $DataKey;
        next DATAKEY if !defined $DataValue;

        # insert one mapping format row
        $Kernel::OM->Get('DB')->Do(
            SQL => 'INSERT INTO imexport_mapping_format '
                . '(mapping_id, data_key, data_value) VALUES (?, ?, ?)',
            Bind => [ \$Param{MappingID}, \$DataKey, \$DataValue ],
        );
    }

    return 1;
}

=item MappingFormatDataGet()

get the format data of a mapping

    my $ObjectDataRef = $ImportExportObject->MappingFormatDataGet(
        MappingID => 123,
        UserID    => 1,
    );

=cut

sub MappingFormatDataGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(MappingID UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get DB object
    my $DBObject = $Kernel::OM->Get('DB');

    # ask database
    $DBObject->Prepare(
        SQL  => 'SELECT data_key, data_value FROM imexport_mapping_format WHERE mapping_id = ?',
        Bind => [ \$Param{MappingID} ],
    );

    # fetch the result
    my %MappingFormatData;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $MappingFormatData{ $Row[0] } = $Row[1];
    }

    return \%MappingFormatData;
}

=item SearchAttributesGet()

get the search attributes of a object backend as array/hash reference

    my $Attributes = $ImportExportObject->SearchAttributesGet(
        TemplateID => 123,
        UserID     => 1,
    );

=cut

sub SearchAttributesGet {
    my ( $Self, %Param ) = @_;

    # get log object
    my $LogObject = $Kernel::OM->Get('Log');

    # check needed stuff
    for my $Argument (qw(TemplateID UserID)) {
        if ( !$Param{$Argument} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get template data
    my $TemplateData = $Self->TemplateGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    # check template data
    if ( !$TemplateData || !$TemplateData->{Object} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Template with ID $Param{TemplateID} is incomplete!",
        );
        return;
    }

    my $ModuleList = $Kernel::OM->Get('Config')->Get('ImportExport::ObjectBackendRegistration');

    # load backend
    my $Backend = $Kernel::OM->Get(
        $ModuleList->{$TemplateData->{Object}}->{Module}
    );

    return if !$Backend;

    # get an search attribute list of an object
    my $Attributes = $Backend->SearchAttributesGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    return $Attributes;
}

=item SearchDataGet()

get the search data from a template

    my $SearchDataRef = $ImportExportObject->SearchDataGet(
        TemplateID => 3,
        UserID     => 1,
    );

=cut

sub SearchDataGet {
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

    # get DB object
    my $DBObject = $Kernel::OM->Get('DB');

    # ask database
    $DBObject->Prepare(
        SQL  => 'SELECT data_key, data_value FROM imexport_search WHERE template_id = ?',
        Bind => [ \$Param{TemplateID} ],
    );

    # fetch the result
    my %SearchData;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $SearchData{ $Row[0] } = $Row[1];
    }

    return \%SearchData;
}

=item SearchDataSave()

save the search data of a template

    my $True = $ImportExportObject->SearchDataSave(
        TemplateID => 123,
        SearchData => $HashRef,
        UserID     => 1,
    );

=cut

sub SearchDataSave {
    my ( $Self, %Param ) = @_;

    # get log object
    my $LogObject = $Kernel::OM->Get('Log');

    # check needed stuff
    for my $Argument (qw(TemplateID SearchData UserID)) {
        if ( !$Param{$Argument} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    if ( ref $Param{SearchData} ne 'HASH' ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'SearchData must be a hash reference!',
        );
        return;
    }

    # delete existing search data
    $Self->SearchDataDelete(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    DATAKEY:
    for my $DataKey ( sort keys %{ $Param{SearchData} } ) {

        # quote
        my $DataValue = $Param{SearchData}->{$DataKey};

        next DATAKEY if !$DataKey;
        next DATAKEY if !$DataValue;

        # insert one row
        $Kernel::OM->Get('DB')->Do(
            SQL => 'INSERT INTO imexport_search '
                . '(template_id, data_key, data_value) VALUES (?, ?, ?)',
            Bind => [ \$Param{TemplateID}, \$DataKey, \$DataValue ],
        );
    }

    return 1;
}

=item SearchDataDelete()

delete the existing search data of a template

    my $True = $ImportExportObject->SearchDataDelete(
        TemplateID => 123,
        UserID     => 1,
    );

    or

    my $True = $ImportExportObject->SearchDataDelete(
        TemplateID => [1,44,166,5],
        UserID     => 1,
    );

=cut

sub SearchDataDelete {
    my ( $Self, %Param ) = @_;

    # get log object
    my $LogObject = $Kernel::OM->Get('Log');

    # check needed stuff
    for my $Argument (qw(TemplateID UserID)) {
        if ( !$Param{$Argument} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    if ( !ref $Param{TemplateID} ) {
        $Param{TemplateID} = [ $Param{TemplateID} ];
    }
    elsif ( ref $Param{TemplateID} ne 'ARRAY' ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => 'TemplateID must be an array reference or a string!',
        );
        return;
    }

    # create the template id string
    my $TemplateIDString = join q{, }, map {'?'} @{ $Param{TemplateID} };

    # create and add bind parameters
    my @BIND = map { \$_ } @{ $Param{TemplateID} };

    # delete templates
    return $Kernel::OM->Get('DB')->Do(
        SQL  => "DELETE FROM imexport_search WHERE template_id IN ( $TemplateIDString )",
        Bind => \@BIND,
    );
}

=item Export()

export function

    my $ResultRef = $ImportExportObject->Export(
        TemplateID => 123,
        UserID     => 1,
    );

returns something like

    $ResultRef = {
        Success   => 2,
        Failed    => 0,
        DestinationContent => [
            [ 'Attr_1a', 'Attr_1b', 'Attr_1c', ],
            [ 'Attr_2a', 'Attr_2b', 'Attr_3c', ],
        ],
    };

=cut

sub Export {
    my ( $Self, %Param ) = @_;

    # get log object
    my $LogObject = $Kernel::OM->Get('Log');

    # check needed stuff
    for my $Argument (qw(TemplateID UserID)) {
        if ( !$Param{$Argument} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get template data
    my $TemplateData = $Self->TemplateGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    # check template data
    if ( !$TemplateData || !$TemplateData->{Object} || !$TemplateData->{Format} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Template with ID $Param{TemplateID} is incomplete!",
        );
        return;
    }

    my $ModuleList = $Kernel::OM->Get('Config')->Get('ImportExport::ObjectBackendRegistration');

    # load backend
    my $ObjectBackend = $Kernel::OM->Get(
        $ModuleList->{$TemplateData->{Object}}->{Module}
    );

    return if !$ObjectBackend;

    $ModuleList = $Kernel::OM->Get('Config')->Get('ImportExport::FormatBackendRegistration');

    # load backend
    my $FormatBackend = $Kernel::OM->Get(
        $ModuleList->{$TemplateData->{Format}}->{Module}
    );

    return if !$FormatBackend;

    # create template run
    my $RunID = $Self->_TemplateRunAdd(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
        Export     => 1
    );

    # get export data
    my $ExportData = $ObjectBackend->ExportDataGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    # get format data
    my $FormatData = $Self->FormatDataGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    # if column headers should be included in the export
    if ( $FormatData->{IncludeColumnHeaders} ) {

        # get object attributes (the name of the columns)
        my $MappingObjectAttributes = $Self->MappingObjectAttributesGet(
            TemplateID => $Param{TemplateID},
            UserID     => $Param{UserID},
        );

        # create a lookup hash for the object attribute names
        my %AttributeLookup = map { $_->{Key} => $_->{Value} } @{ $MappingObjectAttributes->[0]->{Input}->{Data} };

        # get mapping data list
        my $MappingList = $Self->MappingList(
            TemplateID => $Param{TemplateID},
            UserID     => $Param{UserID},
        );

        # get the column names
        my @ColumnNames;
        for my $MappingID ( @{$MappingList} ) {

            # get mapping object data
            my $MappingObjectData = $Self->MappingObjectDataGet(
                MappingID => $MappingID,
                UserID    => $Param{UserID},
            );

            # get the column name
            my $ColumnName = $AttributeLookup{ $MappingObjectData->{Key} };

            push @ColumnNames, $ColumnName;
        }

        # add column headers as first row
        unshift @{$ExportData}, \@ColumnNames;
    }

    my %Result = (
        Success            => 0,
        Failed             => 0,
        DestinationContent => [],
    );

    EXPORTDATAROW:
    for my $ExportDataRow ( @{$ExportData} ) {

        # export one row
        my $DestinationContentRow = $FormatBackend->ExportDataSave(
            TemplateID    => $Param{TemplateID},
            ExportDataRow => $ExportDataRow,
            UserID        => $Param{UserID},
        );

        if ( !defined $DestinationContentRow ) {
            $Result{Failed}++;
            next EXPORTDATAROW;
        }

        # add row to destination content
        push @{ $Result{DestinationContent} }, $DestinationContentRow;
        $Result{Success}++;
    }

    # update run entry
    $Self->_TemplateRunUpdate(
        RunID      => $RunID,
        TemplateID => $Param{TemplateID},
        Success    => $Result{Success},
        Failed     => $Result{Failed}
    );

    # log result
    $LogObject->Log(
        Priority => 'notice',
        Message  => "Export of $Result{Failed} records ($TemplateData->{Object}): failed!",
    );
    $LogObject->Log(
        Priority => 'notice',
        Message  => "Export of $Result{Success} records ($TemplateData->{Object}): successful!",
    );

    return \%Result;
}

=item Import()

import function

    my $ResultRef = $ImportExportObject->Import(
        TemplateID    => 123,
        SourceContent => $StringRef,  # (optional)
        UserID        => 1,
    );

=cut

sub Import {
    my ( $Self, %Param ) = @_;

    # get log object
    my $LogObject = $Kernel::OM->Get('Log');

    # check needed stuff
    for my $Argument (qw(TemplateID UserID)) {
        if ( !$Param{$Argument} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get template data
    my $TemplateData = $Self->TemplateGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    # check template data
    if ( !$TemplateData || !$TemplateData->{Object} || !$TemplateData->{Format} ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Template with ID $Param{TemplateID} is incomplete!",
        );
        return;
    }

    my $ModuleList = $Kernel::OM->Get('Config')->Get('ImportExport::ObjectBackendRegistration');

    # load backend
    my $ObjectBackend = $Kernel::OM->Get(
        $ModuleList->{$TemplateData->{Object}}->{Module}
    );

    return if !$ObjectBackend;

    $ModuleList = $Kernel::OM->Get('Config')->Get('ImportExport::FormatBackendRegistration');

    # load backend
    my $FormatBackend = $Kernel::OM->Get(
        $ModuleList->{$TemplateData->{Format}}->{Module}
    );

    return if !$FormatBackend;

    if (IsStringWithData($Param{SourceContent})) {
        $Param{SourceContent} = \$Param{SourceContent};
    }

    # get import data
    my $ImportData = $FormatBackend->ImportDataGet(
        TemplateID    => $Param{TemplateID},
        SourceContent => $Param{SourceContent},
        UserID        => $Param{UserID},
    );

    return if !$ImportData;

    # get format data
    my $FormatData = $Self->FormatDataGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    # if column headers are activated, the first row must be removed
    if ( $FormatData->{IncludeColumnHeaders} ) {
        shift @{$ImportData};
    }

    # Number of successfully and not successfully imported rows
    my %Result = (
        Object  => $TemplateData->{Object},
        Success => 0,
        Failed  => 0,
        RetCode => {},
        Counter => 0,
    );

    # create template run
    my $RunID = $Self->_TemplateRunAdd(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID}
    );

    IMPORTDATAROW:
    for my $ImportDataRow ( @{$ImportData} ) {

        $Result{Counter}++;

        # import a single row
        my ( $ID, $RetCode ) = $ObjectBackend->ImportDataSave(
            TemplateID    => $Param{TemplateID},
            ImportDataRow => $ImportDataRow,
            Counter       => $Result{Counter},
            UserID        => $Param{UserID},
        );

        if ( !$ID ) {

            # count DuplicateName entries as errors
            if ( $RetCode && $RetCode =~ m{ \A DuplicateName }xms ) {
                $Result{RetCode}->{$RetCode}++;
            }
            $Result{Failed}++;
        }
        else {
            $Result{RetCode}->{$RetCode}++;
            $Result{Success}++;
        }
    }

    # update run entry
    $Self->_TemplateRunUpdate(
        RunID      => $RunID,
        TemplateID => $Param{TemplateID},
        Success    => $Result{Success},
        Failed     => $Result{Failed}
    );

    # log result
    $LogObject->Log(
        Priority => 'notice',
        Message =>
            "Import of $Result{Counter} $Result{Object} records: "
            . "$Result{Failed} failed, $Result{Success} succeeded",
    );
    for my $RetCode ( sort keys %{ $Result{RetCode} } ) {
        my $Count = $Result{RetCode}->{$RetCode} || 0;
        $LogObject->Log(
            Priority => 'notice',
            Message =>
                "Import of $Result{Counter} $Result{Object} records: $Count $RetCode",
        );
    }
    if ( $Result{Failed} ) {
        $LogObject->Log(
            Priority => 'notice',
            Message  => "Last processed line number of import file: $Result{Counter}",
        );
    }

    return \%Result;
}

=item ImportTaskCreate()

adds future task for import

    my $TaskID = $ImportExportObject->ImportTaskCreate(
        TemplateID    => 123,
        SourceContent => 'import content'
        UserID        => 1,
    );

    returns ID of scheduler future task

=cut

sub ImportTaskCreate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(TemplateID SourceContent UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # check if Template exists
    my $TemplateDataRef = $Self->TemplateGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    if ( !IsHashRefWithData( $TemplateDataRef ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No Template with ID $Param{TemplateID} found.",
        );
        return;
    }

    $Kernel::OM->Get('Encode')->EncodeOutput( \$Param{SourceContent} );
    my $FileContent = decode_base64( $Param{SourceContent} );

    # Get current time.
    my $ExecutionTime = $Kernel::OM->Get('Time')->CurrentTimestamp();

    # Create a new future task for import.
    my $TaskID = $Kernel::OM->Get('Daemon::SchedulerDB')->FutureTaskAdd(
        ExecutionTime => $ExecutionTime,
        Type          => 'AsynchronousExecutor',
        Name          => 'Import for template "'.$TemplateDataRef->{Name}.'" ('.$Param{TemplateID}.')',
        Attempts      => 1,
        Data          => {
            Object   => 'ImportExport',
            Function => 'Import',
            Params   => {
                TemplateID    => $Param{TemplateID},
                SourceContent => \$FileContent,
                UserID        => $Param{UserID}
            },
        }
    );

    if ( !$TaskID) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Could not create import execution task.",
        );
        return;
    }

    return $TaskID;
}

=item TemplateRunList()

returns an array of all imports/exports of a template

    my %Runs = $ImportExportObject->TemplateRunList(
        TemplateID    => 123,
        Type          => 'import',    # optional - import | export, both if omitted
        UserID        => 1
    );

the result looks like

    @Runs = (
        {
            ID           => 1,
            TemplateID   => 1,
            StateID      => 1,
            State        => 'running',
            SuccessCount => 10,           # number of successfully imported/exported objects
            FailCount    => 2,            # number of failed imported/exported objects,
            Type         => 'import',
            CreateBy     => 1,
            StartTime    => '2019-12-04 10:00:00',
            EndTime      => '2019-12-04 12:00:00'
        },
        { ... },
        ...
    );

=cut

sub TemplateRunList {
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

    if ( $Param{Type} && $Param{Type} !~ m/(export|import)/i) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Unknown Type!",
        );
        return;
    }

    my $SQL = 'SELECT id, template_id, state_id, success_count, fail_count, create_by, start_time, end_time, type FROM imexport_template_run WHERE template_id = ?';
    my $Bind = [ \$Param{TemplateID} ];

    if ($Param{Type}) {
        $SQL .= ' AND type = ?';
        push(@{$Bind}, \$Param{Type});
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # get runs
    return if !$DBObject->Prepare(
        SQL  => $SQL,
        Bind => $Bind
    );

    # fetch the result
    my @TemplateRuns;
    while ( my @Row = $DBObject->FetchrowArray() ) {

        push(@TemplateRuns, {
            ID           => $Row[0],
            TemplateID   => $Row[1],
            StateID      => $Row[2],
            SuccessCount => $Row[3] ? 0 + $Row[3] : 0,
            FailCount    => $Row[4] ? 0 + $Row[4] : 0,
            CreateBy     => $Row[5],
            StartTime    => $Row[6],
            EndTime      => $Row[7],
            Type         => $Row[8]
        });
    }

    # get states names
    if (@TemplateRuns) {
        my %RunStates;
        if ( IsHashRefWithData($Self->{Cache}->{RunStates}) ) {
            %RunStates = %{$Self->{Cache}->{RunStates}};
        } elsif (
            $DBObject->Prepare(
                SQL => 'SELECT id, name FROM imexport_template_run_state'
            )
        ) {
            while ( my @Row = $DBObject->FetchrowArray() ) {
                $RunStates{$Row[0]} = $Row[1];
            }
            $Self->{Cache}->{RunStates} = \%RunStates;
        }

        for my $Run (@TemplateRuns) {
            if ($Run->{StateID}) {
                $Run->{State} = $RunStates{$Run->{StateID}} || '';
                # keep StateID as number
                $Run->{StateID} = 0 + $Run->{StateID};
            }
        }
    }

    return @TemplateRuns;
}

sub _TemplateRunAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(TemplateID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get template data
    my $TemplateData = $Self->TemplateGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    # check template data
    if ( !$TemplateData ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No Template with ID $Param{TemplateID}!",
        );
        return;
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    my $Type = $Param{Export} ? 'export' : 'import';
    return if !$DBObject->Do(
        SQL => 'INSERT INTO imexport_template_run (template_id, state_id, start_time, create_by, type) '
             . 'VALUES (?, 1, current_timestamp, ?, ?)',
        Bind => [
            \$Param{TemplateID}, \$Param{UserID}, \$Type
        ],
    );

    # get new id
    return if !$DBObject->Prepare(
        SQL  => 'SELECT id FROM imexport_template_run WHERE template_id = ? AND type = ? ORDER by id DESC',
        Bind => [
            \$Param{TemplateID}, \$Type
        ],
        Limit => 1,
    );

    # fetch the result
    my $ID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ID = $Row[0];
    }

    $Self->_ClearCacheAndNotify(
        RunID      => $ID,
        TemplateID => $Param{TemplateID}
    );

    return $ID;
}

sub _TemplateRunUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(RunID TemplateID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    my $StateID = 2;
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'UPDATE imexport_template_run SET end_time = current_timestamp, state_id = ?, success_count = ?, fail_count = ? WHERE id = ?',
        Bind => [ \$StateID, \$Param{Success}, \$Param{Failed}, \$Param{RunID} ],
    );

    $Self->_ClearCacheAndNotify(
        RunID      => $Param{RunID},
        TemplateID => $Param{TemplateID},
        UPDATE     => 1
    );

    return 1;
}

sub _TemplateRunDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(TemplateID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    if ( !ref $Param{TemplateID} ) {
        $Param{TemplateID} = [ $Param{TemplateID} ];
    } elsif ( ref $Param{TemplateID} ne 'ARRAY' ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'TemplateID must be an array reference or a string!',
        );
        return;
    }

    # create the template id string
    my $TemplateIDString = join q{, }, map {'?'} @{ $Param{TemplateID} };

    # create and add bind parameters
    my @Bind = map { \$_ } @{ $Param{TemplateID} };

    return if !$Kernel::OM->Get('DB')->Do(
        SQL  => "DELETE FROM imexport_template_run WHERE template_id IN ( $TemplateIDString )",
        Bind => \@Bind,
    );

    return 1;
}

sub _ClearCacheAndNotify {
    my ( $Self, %Param ) = @_;

    # delete cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType}
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => $Param{UPDATE} ? 'UPDATE' : 'CREATE',
        Namespace => 'ImportExportTemplate.ImportExportTemplateRun',
        ObjectID  => $Param{TemplateID}.'::'.$Param{RunID},
    );
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
