# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::TextModule;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);
use vars qw(@ISA);

our @ObjectDependencies = qw(
    ClientRegistration
    Config
    Cache
    CSV
    Log
    Main
    Queue
    State
    Type
    XML
);

=head1 NAME

Kernel::System::TextModule

=head1 SYNOPSIS

TextModule backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create a TextModule object. Do not     'it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $TextModuleObject = $Kernel::OM->Get('TextModuleField');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get needed objects
    $Self->{DBObject}     = $Kernel::OM->Get('DB');
    $Self->{ConfigObject} = $Kernel::OM->Get('Config');
    $Self->{CacheObject}  = $Kernel::OM->Get('Cache');
    $Self->{CSVObject}    = $Kernel::OM->Get('CSV');
    $Self->{LogObject}    = $Kernel::OM->Get('Log');
    $Self->{MainObject}   = $Kernel::OM->Get('Main');
    $Self->{QueueObject}  = $Kernel::OM->Get('Queue');
    $Self->{StateObject}  = $Kernel::OM->Get('State');
    $Self->{TypeObject}   = $Kernel::OM->Get('Type');
    $Self->{XMLObject}    = $Kernel::OM->Get('XML');

    # extension modules
    if ( $Self->{ConfigObject}->Get('TextModule::CustomModules') ) {
        my @CustomModules = @{ $Self->{ConfigObject}->Get('TextModule::CustomModules') };
        for my $CustMod (@CustomModules) {
            if ( !$Self->{MainObject}->Require($CustMod) ) {
                $Self->{LogObject}->Log(
                    Priority => 'error',
                    Message  => "Can't load TextModule custom module "
                        . $CustMod . " ($@)!",
                );
                next;
            }

            unshift( @ISA, $CustMod );
        }
    }

    $Self->{CacheType} = 'TextModule';

    return $Self;
}

=item TextModuleAdd()

Adds a new TextModule

    my $HashRef = $TextModuleObject->TextModuleAdd(
        Name       => 'some short name',
        Text       => 'some blabla...',
        Category   => ''                  #optional
        Language   => 'de',               #optional
        Keywords   => 'key1, key2, key3', #optional
        Comment    => '',                 #optional
        Subject    => '',                 #optional
        UserID     => 1,
        ValidID    => 1,
    );

=cut

sub TextModuleAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Name Text UserID ValidID)) {
        if ( !defined( $Param{$_} ) ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # default language...
    if ( !$Param{Language} ) {
        $Param{Language} = $Self->{ConfigObject}->Get('DefaultLanguage') || 'en';
    }

    # build sql...
    my $SQL = "INSERT INTO text_module "
        . "(name, valid_id, keywords, category, comment, text, subject, language, "
        . "create_time, create_by, change_time, change_by ) "
        . "VALUES "
        . "(?, ?, ?, ?, ?, ?, ?, ?, "
        . "current_timestamp, ?, current_timestamp, ?) ";

    # do the db insert...
    my $DBInsert = $Self->{DBObject}->Do(
        SQL  => $SQL,
        Bind => [
            \$Param{Name}, \$Param{ValidID}, \$Param{Keywords}, \$Param{Category},
            \$Param{Comment}, \$Param{Text}, \$Param{Subject}, \$Param{Language},
            \$Param{UserID}, \$Param{UserID},
        ],
    );

    #handle the insert result...
    if ($DBInsert) {

        # delete cache
        $Self->{CacheObject}->CleanUp(
            Type => $Self->{CacheType}
        );

        return 0 if !$Self->{DBObject}->Prepare(
            SQL => 'SELECT max(id) FROM text_module '
                . " WHERE name = ? AND language = ? AND create_by = ? ",
            Bind => [ \$Param{Name}, \$Param{Language}, \$Param{UserID} ],
        );

        my $ID;
        while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
            $ID = $Row[0];
        }

        # push client callback event
        $Kernel::OM->Get('ClientNotification')->NotifyClients(
            Event     => 'CREATE',
            Namespace => 'TextModule',
            ObjectID  => $ID,
        );

        return $ID;
    }
    else {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "TextModules::DB insert failed!",
        );
    }

    return 0;
}

=item TextModuleGet()

Returns an existing TextModule.

    my %Data = $TextModuleObject->TextModuleGet(
        ID => 123,
    );

=cut

sub TextModuleGet {
    my ( $Self, %Param ) = @_;

    # check required params...
    if ( !$Param{ID} ) {
        $Self->{LogObject}->Log( Priority => 'error', Message => "Need ID!" );
        return;
    }

    # read cache
    my $CacheKey = 'TextModule::' . $Param{ID};
    my $Cache    = $Self->{CacheObject}->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey
    );
    return %{$Cache} if $Cache;

    # db quote
    for (qw(ID)) {
        $Param{$_} = $Self->{DBObject}->Quote( $Param{$_}, 'Integer' );
    }

    # sql
    my $SQL
        = 'SELECT name, valid_id, keywords, category, comment, text, '
        . 'language, subject, create_time, create_by, change_time, change_by '
        . 'FROM text_module '
        . 'WHERE id = ?';

    return if !$Self->{DBObject}->Prepare(
        SQL  => $SQL,
        Bind => [ \$Param{ID} ]
    );

    if ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        my %Data = (
            ID                  => $Param{ID},
            Name                => $Data[0],
            ValidID             => $Data[1],
            Keywords            => $Data[2],
            Category            => $Data[3],
            Comment             => $Data[4],
            Text                => $Data[5],
            Language            => $Data[6],
            Subject             => $Data[7],
            CreateTime          => $Data[8],
            CreateBy            => $Data[9],
            ChangeTime          => $Data[10],
            ChangeBy            => $Data[11],
        );

        # set cache
        $Self->{CacheObject}->Set(
            Type  => $Self->{CacheType},
            Key   => $CacheKey,
            Value => \%Data
        );

        return %Data;
    }

    return;
}

=item TextModuleUpdate()

Updates an existing TextModule

    my $HashRef = $TextModuleObject->TextModuleUpdate(
        ID         => 1234,               #required
        Name       => 'some short name',  #required
        ValidID    => 1,                  #required
        Text       => 'some blabla...',   #required
        UserID     => 1,                  #required
        Subject    => '',                 #optional
        Category   => '',                 #optional
        Language   => 'de',               #optional
        Keywords   => 'key1, key2, key3', #optional
        Comment    => '',                 #optional
    );

=cut

sub TextModuleUpdate {
    my ( $Self, %Param ) = @_;

    # check required params...
    for (qw(ID Name Text UserID ValidID)) {
        if ( !defined( $Param{$_} ) ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # default language...
    if ( !$Param{Language} ) {
        $Param{Language} = $Self->{ConfigObject}->Get('DefaultLanguage') || 'en';
    }

    # build sql...
    my $SQL = "UPDATE text_module SET "
        . " name = ?, text = ?, subject = ?, keywords = ?, language = ?, "
        . " category = ?, comment = ?, valid_id = ?, "
        . " change_time = current_timestamp, change_by = ? "
        . "WHERE id = ?";

    # do the db insert...
    my $DBUpdate = $Self->{DBObject}->Do(
        SQL  => $SQL,
        Bind => [
            \$Param{Name}, \$Param{Text}, \$Param{Subject},
            \$Param{Keywords}, \$Param{Language},
            \$Param{Category}, \$Param{Comment}, \$Param{ValidID},
            \$Param{UserID},   \$Param{ID}
        ],
    );

    # handle update result...
    if ($DBUpdate) {

        # delete cache
        $Self->{CacheObject}->CleanUp(
            Type => $Self->{CacheType}
        );

        # push client callback event
        $Kernel::OM->Get('ClientNotification')->NotifyClients(
            Event     => 'UPDATE',
            Namespace => 'TextModule',
            ObjectID  => $Param{ID},
        );

        return $Param{ID};
    }
    else {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "TextModules::DB update of $Param{ID} failed!",
        );
        return;
    }

}

=item TextModuleDelete()

Deletes a text module.

    my $HashRef = $TextModuleObject->TextModuleDelete(
        ID      => 1234,  #required
    );

=cut

sub TextModuleDelete {
    my ( $Self, %Param ) = @_;

    # check required params...
    if ( !$Param{ID} ) {
        $Self->{LogObject}->Log( Priority => 'error', Message => 'TextModuleDelete: Need ID!' );
        return;
    }

    # delete cache
    $Self->{CacheObject}->CleanUp(
        Type => $Self->{CacheType}
    );

    my $Result = $Self->{DBObject}->Do(
        SQL  => 'DELETE FROM text_module WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'TextModule',
        ObjectID  => $Param{ID},
    );

    return $Result;
}

=item TextModuleList()

Returns all TextModuleIDs depending on given parameters.

    my $TextModuleIDs = $TextModuleObject->TextModuleList(
        Name          => '...'   #optional
        Category      => '...',  #optional
        Language      => 'de',   #optional
        ValidID        => 1,     #optional: 1 is assumed as default
    );

=cut

sub TextModuleList {
    my ( $Self, %Param ) = @_;

    my @Result;
    my @SQLWhere;
    my @BindVars;

    # read cache
    my $CacheKey = 'TextModuleList::';
    my @Params;
    foreach my $ParamKey (
        qw{Category Name Language ValidID}
        )
    {
        if ( $Param{$ParamKey} ) {
            push( @Params, $Param{$ParamKey} );
        }
        else {
            push( @Params, '' );
        }
    }
    $CacheKey .= join( '::', @Params );
    my $Cache = $Self->{CacheObject}->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return $Cache if $Cache;

    # set valid
    if ( exists( $Param{ValidID} ) ) {
        push(@SQLWhere, 'valid_id = ?');
        push(@BindVars, \$Param{ValidID});
    }

    if ( $Param{Name} ) {
        push(@SQLWhere, 'name = ?');
        push(@BindVars, \$Param{Name});
    }

    if ( $Param{Language} ) {
        push(@SQLWhere, 'language = ?');
        push(@BindVars, \$Param{Language});
    }

    # create SQL-String
    my $SQL = "SELECT id FROM text_module";

    if ( @SQLWhere ) {
        $SQL .= ' WHERE '.join(' AND ', @SQLWhere);
    }

    # do query
    return if !$Self->{DBObject}->Prepare(
        SQL  => $SQL,
        Bind => \@BindVars
    );

    while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        push( @Result, $Data[0] );
    }

    # set cache
    $Self->{CacheObject}->Set(
        Type  => $Self->{CacheType},
        Key   => $CacheKey,
        Value => \@Result
    );

    # return result
    return \@Result;
}

=item TextModuleCategoryList()

Returns all TextModuleCategories

    my $CategoryList = $TextModuleObject->TextModuleCategoryList();

=cut

sub TextModuleCategoryList {
    my ( $Self, %Param ) = @_;

    my $SQL = "SELECT DISTINCT(category) FROM text_module WHERE category <> ''";

    return if !$Self->{DBObject}->Prepare(
        SQL => $SQL,
    );

    my @Result;
    while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        push(@Result, $Data[0]);
    }

    return \@Result;
}

#-------------------------------------------------------------------------------
# BEGIN OBJECT LINK-RELATED FUNCTIONS

=item TextModuleObjectLinkGet()

Returns all object links for a text module.

    my $ArrayRef = $TextModuleObject->TextModuleObjectLinkGet(
        ObjectType => '...'     #required
        TextModuleID => 123,    #required
    );

Return all text module-links for a object.

    my $ArrayRef = $TextModuleObject->TextModuleObjectLinkGet(
        ObjectType => '...'    #required
        ObjectID   => 123,     #required if TextModuleID not given
        TextModuleID => 123    #required if ObjectID not given
    );


=cut

sub TextModuleObjectLinkGet {
    my ( $Self, %Param ) = @_;
    my @Result;

    # check required params...
    if ( !$Param{TextModuleID} && !$Param{ObjectType} && !$Param{ObjectID} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'TextModuleObjectLinkDelete: Need ObjectType and TextModuleID or ObjectID!'
        );
        return;
    }

    # read cache
    for my $Key (qw(TextModuleID ObjectType ObjectID)) {
        if ( !defined $Param{$Key} ) {
            $Param{$Key} = '';
        }
    }
    my $CacheKey =
        'TextModuleObjectLink::'
        . $Param{TextModuleID} . '::'
        . $Param{ObjectType} . '::'
        . $Param{ObjectID};
    my $Cache = $Self->{CacheObject}->Get(
        Type => 'TextModule',
        Key  => $CacheKey
    );
    return $Cache if $Cache;

    # select object_link<->text module relation
    if ( $Param{TextModuleID} ) {
        return if !$Self->{DBObject}->Prepare(
            SQL =>
                'SELECT object_id FROM text_module_object_link WHERE object_type = ? AND text_module_id = ? ',
            Bind => [ \$Param{ObjectType}, \$Param{TextModuleID} ],
        );
    }
    else {
        return if !$Self->{DBObject}->Prepare(
            SQL =>
                'SELECT text_module_id FROM text_module_object_link WHERE object_type = ? AND object_id = ? ',
            Bind => [ \$Param{ObjectType}, \$Param{ObjectID} ],
        );
    }

    while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        push( @Result, $Data[0] );
    }

    # set cache
    $Self->{CacheObject}->Set(
        Type  => 'TextModule',
        Key   => $CacheKey,
        Value => \@Result
    );

    return \@Result;
}

=item TextModuleObjectLinkDelete()

Deletes all object links for a text module.

    my $HashRef = $TextModuleObject->TextModuleObjectLinkDelete(
        TextModuleID => 123,    #required
        ObjectType   => '...'   #optional
    );

Deletes all text module-links for a object.

    my $HashRef = $TextModuleObject->TextModuleObjectLinkDelete(
        ObjectType => '...'    #required
        ObjectID   => 123,     #required
    );

=cut

sub TextModuleObjectLinkDelete {
    my ( $Self, %Param ) = @_;

    # check required params...
    if ( !$Param{TextModuleID} && !$Param{ObjectType} && !$Param{ObjectID} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => 'TextModuleObjectLinkDelete: Need TextModuleID or ObjectType and ObjectID!'
        );
        return;
    }

    # delete cache
    $Self->{CacheObject}->CleanUp(Type => 'TextModule');

    # delete object_link<->text module relation
    if ( $Param{TextModuleID} ) {
        if ( $Param{ObjectType} ) {
            return $Self->{DBObject}->Do(
                SQL =>
                    'DELETE FROM text_module_object_link WHERE object_type = ? AND text_module_id = ?',
                Bind => [ \$Param{ObjectType}, \$Param{TextModuleID} ],
            );
        }
        else {
            return $Self->{DBObject}->Do(
                SQL  => 'DELETE FROM text_module_object_link WHERE text_module_id = ?',
                Bind => [ \$Param{TextModuleID} ],
            );
        }
    }
    else {
        return $Self->{DBObject}->Do(
            SQL =>
                'DELETE FROM text_module_object_link WHERE object_type = ? AND object_id = ?',
            Bind => [ \$Param{ObjectType}, \$Param{ObjectID} ],
        );
    }
}

=item TextModuleObjectLinkCreate()

Creates a link between a text module and a object, thus making the text module
available for this object.

    my $Result = $TextModuleObject->TextModuleObjectLinkCreate(
        TextModuleID => 5678,  #required
        ObjectType   => '..',  #required
        ObjectID     => 1234,  #required
        UserID       => 1,     #required
    );

=cut

sub TextModuleObjectLinkCreate {
    my ( $Self, %Param ) = @_;

    # check required params...
    for (qw(TextModuleID ObjectType ObjectID UserID)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    my $SQL = "INSERT INTO text_module_object_link "
        . " (text_module_id, object_type, object_id, create_time, create_by, change_time, change_by)"
        . " VALUES  (?, ?, ?, current_timestamp, ?, current_timestamp, ?)";

    return $Self->{DBObject}->Do(
        SQL  => $SQL,
        Bind => [
            \$Param{TextModuleID}, \$Param{ObjectType}, \$Param{ObjectID},
            \$Param{UserID}, \$Param{UserID}
        ],
    );
}

# END OBJECT LINK-RELATED FUNCTIONS
#-------------------------------------------------------------------------------

=item TextModuleCount()


    my $HashOrArrayRef = $TextModuleObject->TextModuleCount(
        Type = 'ALL'|'UNASSIGNED::<ObjectType>',      # optional, default 'ALL'
    );

=cut

sub TextModuleCount {
    my ( $Self, %Param ) = @_;
    my $SQL = "SELECT count(*) FROM text_module t";

    if ( defined $Param{Type} && $Param{Type} =~ /^UNASSIGNED::(.*?)$/g ) {
        $SQL
            .= " WHERE NOT EXISTS (SELECT object_id FROM text_module_object_link ol WHERE object_type = '"
            . $1
            . "' AND ol.text_module_id = t.id)";
    }

    return if !$Self->{DBObject}->Prepare( SQL => $SQL );

    my $Count = 0;
    while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        $Count = $Data[0];
        last;
    }

    return $Count;
}

=item TextModuleGetList()

Returns all textmodules which matched the search params.

    my $HashRef = $TextModuleObject->TextModuleGetList(
        Language => 'en',         #optional
        Name     => '%somename*', #optional
        ValidID  => 1,            #optional
        Agent    => 1,            #optional
        Customer => 1,            #optional
        Public   => 1,            #optional
    );

=cut

=item TextModulesExport()

Export all Textmodules into XML document.

    my $String = $TextModuleObject->TextModulesExport(
        Format => 'CSV'|'XML'
        CSVSeparator => ';'
    );

=cut

sub TextModulesExport {
    my ( $Self, %Param ) = @_;
    my $Result = "";

    if ( !$Param{Format} || $Param{Format} eq 'XML' ) {
        $Result = $Self->_CreateTextModuleExportXML(
            %Param,
        );
    }
    elsif ( $Param{Format} eq 'CSV' ) {
        $Result = $Self->_CreateTextModuleExportCSV(
            %Param,
        );
    }

    return $Result;
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
