# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::TextModule;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);
use vars qw(@ISA);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::CacheInternal',
    'Kernel::System::CSV',
    'Kernel::System::Log',
    'Kernel::System::Main',
    'Kernel::System::Queue',
    'Kernel::System::State',
    'Kernel::System::Type',
    'Kernel::System::XML',
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
    my $TextModuleObject = $Kernel::OM->Get('Kernel::System::TextModuleField');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get needed objects
    $Self->{DBObject}     = $Kernel::OM->Get('Kernel::System::DB');
    $Self->{ConfigObject} = $Kernel::OM->Get('Kernel::Config');
    $Self->{CacheObject}  = $Kernel::OM->Get('Kernel::System::Cache');
    $Self->{CSVObject}    = $Kernel::OM->Get('Kernel::System::CSV');
    $Self->{LogObject}    = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{MainObject}   = $Kernel::OM->Get('Kernel::System::Main');
    $Self->{QueueObject}  = $Kernel::OM->Get('Kernel::System::Queue');
    $Self->{StateObject}  = $Kernel::OM->Get('Kernel::System::State');
    $Self->{TypeObject}   = $Kernel::OM->Get('Kernel::System::Type');
    $Self->{XMLObject}    = $Kernel::OM->Get('Kernel::System::XML');

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
        AgentFrontend    => 1,            #optional
        CustomerFrontend => 1,            #optional
        PublicFrontend   => 1,            #optional
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

    # set frontend display flags...
    for my $CurrKey (qw(AgentFrontend CustomerFrontend PublicFrontend)) {
        if ( $Param{$CurrKey} ) {
            $Param{$CurrKey} = 1;
        }
        else {
            $Param{$CurrKey} = 0;
        }
    }

    # build sql...
    my $SQL = "INSERT INTO kix_text_module "
        . "(name, valid_id, keywords, category, comment, text, subject, language, "
        . "f_agent, f_customer, f_public, "
        . "create_time, create_by, change_time, change_by ) "
        . "VALUES "
        . "(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, "
        . "current_timestamp, ?, current_timestamp, ?) ";

    # do the db insert...
    my $DBInsert = $Self->{DBObject}->Do(
        SQL  => $SQL,
        Bind => [
            \$Param{Name}, \$Param{ValidID}, \$Param{Keywords}, \$Param{Category}, 
            \$Param{Comment}, \$Param{Text}, \$Param{Subject}, \$Param{Language},
            \$Param{AgentFrontend}, \$Param{CustomerFrontend}, \$Param{PublicFrontend},
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
            SQL => 'SELECT max(id) FROM kix_text_module '
                . " WHERE name = ? AND language = ? AND create_by = ? ",
            Bind => [ \$Param{Name}, \$Param{Language}, \$Param{UserID} ],
        );

        while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
            return $Row[0];
        }
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
        . 'language, subject, f_agent, f_customer, f_public '
        . 'FROM kix_text_module '
        . 'WHERE id = ?';

    return if !$Self->{DBObject}->Prepare( 
        SQL  => $SQL,
        Bind => [ \$Param{ID} ] 
    );

    if ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        my %Data = (
            ID         => $Param{ID},
            Name       => $Data[0],
            ValidID    => $Data[1],
            Keywords   => $Data[2],
            Category   => $Data[3],
            Comment    => $Data[4],
            Text       => $Data[5],
            Language   => $Data[6],
            Subject    => $Data[7],
            AgentFrontend      => $Data[8],
            CustomerFrontend   => $Data[9],
            PublicFrontend     => $Data[10],
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
        Category   => '',                 #optional
        Language   => 'de',               #optional
        Keywords   => 'key1, key2, key3', #optional
        Comment    => '',                 #optional
        AgentFrontend      => 1,          #optional
        CustomerFrontend   => 1,          #optional
        PublicFrontend     => 1,          #optional
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

    # set frontend display flags...
    for my $CurrKey (qw(AgentFrontend CustomerFrontend PublicFrontend )) {
        if ( $Param{$CurrKey} ) {
            $Param{$CurrKey} = 1;
        }
        else {
            $Param{$CurrKey} = 0;
        }
    }

    # build sql...
    my $SQL = "UPDATE kix_text_module SET "
        . " name = ?, text = ?, subject = ?, keywords = ?, language = ?, "
        . " category = ?, comment = ?, valid_id = ?, "
        . " f_agent = ?, f_customer = ?, f_public = ?, "
        . " change_time = current_timestamp, change_by = ? "
        . "WHERE id = ?";

    # do the db insert...
    my $DBUpdate = $Self->{DBObject}->Do(
        SQL  => $SQL,
        Bind => [
            \$Param{Name}, \$Param{Text}, \$Param{Subject},
            \$Param{Keywords}, \$Param{Language},
            \$Param{Category}, \$Param{Comment}, \$Param{ValidID},
            \$Param{AgentFrontend}, \$Param{CustomerFrontend}, \$Param{PublicFrontend},
            \$Param{UserID},   \$Param{ID}
        ],
    );

    # handle update result...
    if ($DBUpdate) {

        # delete cache
        $Self->{CacheObject}->CleanUp(
            Type => $Self->{CacheType}
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

    return $Self->{DBObject}->Do(
        SQL  => 'DELETE FROM kix_text_module WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );
}

=item TextModuleList()

Returns all TextModuleIDs depending on given parameters.

    my $TextModuleIDs = $TextModuleObject->TextModuleList(
        Name          => '...'   #optional
        Category      => '...',  #optional
        Language      => 'de',   #optional
        AgentFrontend => 1,      #optional
        CustomerFrontend => 1    #optional
        PublicFrontend => 1,     #optional
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
        qw{Category Name AgentFrontend CustomerFrontend PublicFrontend Language ValidID}
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

    # set frontend display flags...
    if ( $Param{AgentFrontend} ) {
        push(@SQLWhere, 'f_agent = 1');
    }
    elsif ( $Param{CustomerFrontend} ) {
        push(@SQLWhere, 'f_customer = 1');
    }
    elsif ( $Param{PublicFrontend} ) {
        push(@SQLWhere, 'f_public = 1');
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
    my $SQL = "SELECT id FROM kix_text_module";

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




#-------------------------------------------------------------------------------
# BEGIN CATEGORY-RELATED FUNCTIONS

=item TextModuleCategoryAdd()

Adds a new TextModuleCategory

    my $HashRef = $TextModuleObject->TextModuleCategoryAdd(
        Name       => 'some short name',    # required
        UserID     => 1,                    # required
    );

=cut

sub TextModuleCategoryAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Name UserID)) {
        if ( !defined( $Param{$_} ) ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # build sql...
    my $SQL = "INSERT INTO kix_text_module_category "
        . "(name, create_time, create_by, change_time, change_by ) "
        . "VALUES "
        . "(?, current_timestamp, ?, current_timestamp, ?) ";

    # do the db insert...
    my $DBInsert = $Self->{DBObject}->Do(
        SQL  => $SQL,
        Bind => [
            \$Param{Name}, \$Param{UserID}, \$Param{UserID},
        ],
    );

    #handle the insert result...
    if ($DBInsert) {
        return 0 if !$Self->{DBObject}->Prepare(
            SQL => 'SELECT max(id) FROM kix_text_module_category '
                . " WHERE name = ? ",
            Bind => [ \$Param{Name} ],
        );

        while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
            return $Row[0];
        }
    }
    else {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "TextModuleCategory::DB insert failed!",
        );
    }

    return 0;
}

=item TextModuleCategoryUpdate()

Updates an existing TextModuleCategory

    my $HashRef = $TextModuleObject->TextModuleCategoryUpdate(
        ID         => 1234,               #required
        Name       => 'some short name',  #required
    );

=cut

sub TextModuleCategoryUpdate {
    my ( $Self, %Param ) = @_;

    # check required params...
    for (qw(ID Name)) {
        if ( !defined( $Param{$_} ) ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    my %OldCategory = $Self->TextModuleCategoryGet(
        ID => $Param{ID},
    );

    # check if queue with same name already exists
    my $SQL = "SELECT count(*) FROM kix_text_module_category WHERE name = ? AND id <> ?";
    return if !$Self->{DBObject}->Prepare(
        SQL => $SQL,
        Bind => [ \$Param{Name}, \$Param{ID} ],
    );

    my $Count = 0;
    if ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        $Count = $Data[0];
    }
    if ($Count) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message =>
                "TextModuleCategory: category '$Param{Name}' exists! Can't update category '$OldCategory{Name}'.",
        );
        return;
    }

    # build sql...
    $SQL = "UPDATE kix_text_module_category SET "
        . " name = ?, change_time = current_timestamp, change_by = ? "
        . "WHERE id = ?";

    # do the db insert...
    my $DBUpdate = $Self->{DBObject}->Do(
        SQL  => $SQL,
        Bind => [
            \$Param{Name}, \$Param{UserID}, \$Param{ID}
        ],
    );

    #handle update result...
    if ($DBUpdate) {

        # update all sub category names
        my %AllCategories = $Self->TextModuleCategoryList();
        my @ParentCategory = split( /::/, $OldCategory{Name} );
        for my $CategoryID ( keys %AllCategories ) {
            my @SubCategory = split( /::/, $AllCategories{$CategoryID} );
            if ( $#SubCategory > $#ParentCategory ) {
                if ( $AllCategories{$CategoryID} =~ /^\Q$OldCategory{Name}::\E/i ) {
                    my $NewCategoryName = $AllCategories{$CategoryID};
                    $NewCategoryName =~ s/\Q$OldCategory{Name}\E/$Param{Name}/;
                    return if !$Self->{DBObject}->Do(
                        SQL =>
                            'UPDATE kix_text_module_category SET name = ?, change_time = current_timestamp, '
                            . ' change_by = ? WHERE id = ?',
                        Bind => [ \$NewCategoryName, \$Param{UserID}, \$CategoryID ],
                    );
                }
            }
        }
        return $Param{ID};
    }
    else {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "TextModuleCategory::DB update of $Param{ID} failed!",
        );
        return;
    }

}

=item TextModuleCategoryLookup()

Returns ID or Name of an existing TextModuleCategory.

    my $Result = $TextModuleObject->TextModuleCategoryLookup(
        ID   => 123,        # required if no Name given
        Name => '...'       # required if no ID given
    );

=cut

sub TextModuleCategoryLookup {
    my ( $Self, %Param ) = @_;
    my $BindObj;

    # check required params...
    if ( !$Param{ID} && !$Param{Name} ) {
        $Self->{LogObject}->Log( Priority => 'error', Message => "Need ID or Name!" );
        return;
    }

    my $SQL;
    if ( $Param{ID} ) {
        $SQL     = 'SELECT name FROM kix_text_module_category WHERE id = ?';
        $BindObj = $Param{ID};
    }
    elsif ( $Param{Name} ) {
        $SQL     = 'SELECT id FROM kix_text_module_category WHERE name = ?';
        $BindObj = $Param{Name};
    }

    return if !$Self->{DBObject}->Prepare(
        SQL  => $SQL,
        Bind => [ \$BindObj ],
    );

    my $Result;
    if ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        $Result = $Data[0];
    }

    return $Result;
}

=item TextModuleCategoryGet()

Returns an existing TextModuleCategory.

    my %Data = $TextModuleObject->TextModuleCategoryGet(
        ID => 123,
    );

=cut

sub TextModuleCategoryGet {
    my ( $Self, %Param ) = @_;

    # check required params...
    if ( !$Param{ID} ) {
        $Self->{LogObject}->Log( Priority => 'error', Message => "Need ID!" );
        return;
    }

    # db quote
    for (qw(ID)) {
        $Param{$_} = $Self->{DBObject}->Quote( $Param{$_}, 'Integer' );
    }

    # sql
    my $SQL
        = 'SELECT name FROM kix_text_module_category '
        . 'WHERE id = ' . $Param{ID};

    return if !$Self->{DBObject}->Prepare( SQL => $SQL );

    if ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        my %Data = (
            ID   => $Param{ID},
            Name => $Data[0],
        );
        return %Data;
    }

    return;
}

=item TextModuleCategoryList()

Returns all TextModuleCategories

    my $CategoryList = $TextModuleObject->TextModuleCategoryList();

=cut

sub TextModuleCategoryList {
    my ( $Self, %Param ) = @_;

    my $SQL = "SELECT DISTINCT(category) FROM kix_text_module WHERE category <> ''";

    return if !$Self->{DBObject}->Prepare( 
        SQL => $SQL,
    );

    my @Result;
    while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        push(@Result, $Data[0]);
    }

    return \@Result;
}


=item TextModuleCategoriesExport()

Exports all TextmoduleCategories into XML or CSV document.

    my $String = $TextModuleObject->TextModuleCategoriesExport(
        Format => 'CSV'|'XML'
        CSVSeparator => ';'
    );

=cut

sub TextModuleCategoriesExport {
    my ( $Self, %Param ) = @_;
    my $Result = "";

    my %TextModuleCategoryList = $Self->TextModuleCategoryList(%Param);
    my @ExportDataArray;

    if ( $Param{Format} eq 'XML' ) {
        push( @ExportDataArray, undef );

        for my $ID ( sort keys %TextModuleCategoryList ) {

            my %TextModuleCategory = $Self->TextModuleCategoryGet( ID => $ID );
            my %CurrTMC = ();
            for my $CurrKey ( keys %TextModuleCategory ) {
                $CurrTMC{$CurrKey}->[0] = undef;
                $CurrTMC{$CurrKey}->[1]->{Content} = $TextModuleCategory{$CurrKey};
            }

            # export *-lists...
            push( @ExportDataArray, \%CurrTMC );
        }

        my @XMLHashArray;
        push( @XMLHashArray, undef );

        my %XMLHashTextModuleCategory = ();
        $XMLHashTextModuleCategory{'TextModuleCategoryList'}->[0] = undef;
        $XMLHashTextModuleCategory{'TextModuleCategoryList'}->[1]->{'TextModuleCategoryEntry'}
            = \@ExportDataArray;

        push( @XMLHashArray, \%XMLHashTextModuleCategory );

        $Result = $Self->{XMLObject}->XMLHash2XML(@XMLHashArray);
    }
    elsif ( $Param{Format} eq 'CSV' ) {
        my @ExportHeadArray;

        for my $ID ( sort keys %TextModuleCategoryList ) {
            my @ExportRowArray;

            my %TextModuleCategory = $Self->TextModuleCategoryGet( ID => $ID );

            # create header
            if ( !@ExportHeadArray ) {
                for my $CurrKey ( sort keys(%TextModuleCategory) ) {
                    push( @ExportHeadArray, $CurrKey );
                }
            }

            # add all keys
            for my $CurrKey ( sort keys(%TextModuleCategory) ) {
                push( @ExportRowArray, $TextModuleCategory{$CurrKey} );
            }

            push( @ExportDataArray, \@ExportRowArray );
        }

        $Result = $Self->{CSVObject}->Array2CSV(
            Head      => \@ExportHeadArray,
            Data      => \@ExportDataArray,
            Separator => $Param{CSVSeparator} || ';',
        );
    }

    return $Result;
}

=item TextModuleCategoriesImport()

Import TextmoduleCategories from XML document.

    my $HashRef = $TextModuleObject->TextModuleCategoriesImport(
        Format  => 'CSV'|'XML'
        Content => '<xml><tag>...</tag>', #required
        CSVSeparator => ';'
        DoNotAdd => 0|1, #DO NOT create new entry if no existing id given
        UserID   => 123, #required
    );

=cut

sub TextModuleCategoriesImport {
    my ( $Self, %Param ) = @_;
    my $Result;

    if ( !$Param{Format} || $Param{Format} eq ' XML' ) {
        $Result = $Self->_ImportTextModuleCategoriesXML(
            %Param,
            XMLString => $Param{Content},
        );
    }
    elsif ( $Param{Format} eq 'CSV' ) {
        $Result = $Self->_ImportTextModuleCategoriesCSV(
            %Param,
        );
    }

    return $Result;

}

=item _ImportTextModuleCategoriesCSV()

import TextModuleCategories from CSV document.

    my $HashRef = $TextModuleObject->_ImportTextModuleCategoriesCSV(
        Content => '...', #required
        CSVSeparator => ';'
        DoNotAdd => 0|1, #DO NOT create new entry if no existing id given
        UserID   => 123, #required
    );

=cut

sub _ImportTextModuleCategoriesCSV {
    my ( $Self, %Param ) = @_;
    my %Result = ();
    my @XMLHash;

    #get default config...
    my $ConfigRef = $Self->{ConfigObject}->Get('AdminResponsesUploads::TextModuleCategoryDefaults');
    my %Config    = ();
    if ( $ConfigRef && ref($ConfigRef) eq 'HASH' ) {
        %Config = %{$ConfigRef};
    }

    #init counters...
    $Result{CountUploaded}     = 0;
    $Result{CountUpdateFailed} = 0;
    $Result{CountUpdated}      = 0;
    $Result{CountInsertFailed} = 0;
    $Result{CountAdded}        = 0;
    $Result{UploadMessage}     = '';

    # check required params...
    for (qw( Content UserID )) {
        if ( !defined( $Param{$_} ) ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # get array from csv data
    my $CSVArray = $Self->{CSVObject}->CSV2Array(
        String => $Param{Content},
        Separator => $Param{CSVSeparator} || ';',
    );

    my $HeadLine = shift @{$CSVArray};

    my $TMArrIndex = 0;
    foreach my $Row ( @{$CSVArray} ) {
        $TMArrIndex++;
        my %UpdateData;
        my $ColumnIdx = 0;
        foreach my $ColumnContent ( @{$Row} ) {
            my $Key = $HeadLine->[$ColumnIdx];
            $UpdateData{$Key} = $ColumnContent;
            $ColumnIdx++;
        }

        $Result{CountUploaded}++;

        #-------------------------------------------------------------------
        # set default values...
        for my $Key ( keys(%Config) ) {
            if ( !$UpdateData{$Key} ) {
                $UpdateData{$Key} = $Config{$Key};
            }
        }

        # check for ID and update...
        if ( $UpdateData{ID} ) {
            my $UpdateResult = 0;
            my $ErrorMessage = "";
            my $Status       = "";

            my %TextModuleCategory2U = $Self->TextModuleCategoryGet(
                ID => $UpdateData{ID}
            );
            if ( !keys(%TextModuleCategory2U) ) {
                $UpdateData{ID} = 0;
                $ErrorMessage = "Specified text module category ID (" . $UpdateData{ID}
                    . ") does not exist - attempting insert. ";
            }

            # update text module category...
            if ( $UpdateData{ID} && $UpdateData{Name} ) {
                $UpdateResult = $Self->TextModuleCategoryUpdate(
                    ID     => $UpdateData{ID},
                    Name   => $UpdateData{Name} || '',
                    UserID => $Param{UserID},
                );
                if ($UpdateResult) {
                    $Result{CountUpdated}++;
                    $Status = 'Update OK';
                }
                else {
                    $Result{CountUpdateFailed}++;
                    $Status = 'Update Failed';
                }
            }
            elsif ( $UpdateData{Name} ) {
                $UpdateResult = $Self->TextModuleCategoryAdd(
                    Name => $UpdateData{Name} || '',
                    UserID => $Param{UserID},
                );
                $UpdateData{ID} = $UpdateResult;
                if ($UpdateResult) {
                    $Result{CountAdded}++;
                    $Status = 'Insert OK';
                }
                else {
                    $Result{CountInsertFailed}++;
                    $Status = 'Insert Failed';
                }
            }
            else {
                $ErrorMessage .= "Name not given!";
            }

            if ($UpdateResult) {

                #create some status/message for feedback...
                $XMLHash[1]->{'TextModuleCategoryList'}->[1]->{'TextModuleCategoryEntry'}
                    ->[$TMArrIndex]->{ImportResultStatus} = $Status;
                $XMLHash[1]->{'TextModuleCategoryList'}->[1]->{'TextModuleCategoryEntry'}
                    ->[$TMArrIndex]->{ImportResultMessage} = $ErrorMessage;
            }
            else {
                $XMLHash[1]->{'TextModuleCategoryList'}->[1]->{'TextModuleCategoryEntry'}
                    ->[$TMArrIndex]->{ImportResultStatus} = $Status;
                $XMLHash[1]->{'TextModuleCategoryList'}->[1]->{'TextModuleCategoryEntry'}
                    ->[$TMArrIndex]->{ImportResultMessage} = $ErrorMessage;
            }
        }

        #no ID => insert/add...
        elsif ( !$Param{DoNotAdd} ) {
            my $NewID        = 0;
            my $ErrorMessage = "";
            my $Status       = "";

            #insert new textmodule category...
            if ( $UpdateData{Name} ) {
                $NewID = $Self->TextModuleCategoryAdd(
                    Name => $UpdateData{Name} || '',
                    UserID => $Param{UserID},
                );
            }
            else {
                $ErrorMessage = "Name not given!";
            }

            if ($NewID) {
                $Result{CountAdded}++;
                $UpdateData{ID} = $NewID;
                $Status = 'Insert OK';

                #create some status/message for feedback...
                $XMLHash[1]->{'TextModuleCategoryList'}->[1]->{'TextModuleCategoryEntry'}
                    ->[$TMArrIndex]->{ImportResultStatus} = $Status;
                $XMLHash[1]->{'TextModuleCategoryList'}->[1]->{'TextModuleCategoryEntry'}
                    ->[$TMArrIndex]->{ImportResultMessage} = $ErrorMessage;

            }
            else {
                $Result{CountInsertFailed}++;
                $Status = 'Insert Failed';
                $XMLHash[1]->{'TextModuleCategoryList'}->[1]->{'TextModuleCategoryEntry'}
                    ->[$TMArrIndex]->{ImportResultStatus} = $Status;
                $XMLHash[1]->{'TextModuleCategoryList'}->[1]->{'TextModuleCategoryEntry'}
                    ->[$TMArrIndex]->{ImportResultMessage} = $ErrorMessage;
            }
        }
    }

    $Result{XMLResultString} = $Self->{XMLObject}->XMLHash2XML(@XMLHash);

    return \%Result;
}

=item _ImportTextModuleCategoriesXML()

import TextModules from XML document.

    my $HashRef = $TextModuleObject->_ImportTextModuleCategoriesXML(
        XMLString => '<xml><tag>...</tag>', #required
        DoNotAdd => 0|1, #DO NOT create new entry if no existing id given
        UserID   => 123, #required
    );

=cut

sub _ImportTextModuleCategoriesXML {
    my ( $Self, %Param ) = @_;
    my %Result = ();

    #get default config...
    my $ConfigRef = $Self->{ConfigObject}->Get('AdminResponsesUploads::TextModuleCategoryDefaults');
    my %Config    = ();
    if ( $ConfigRef && ref($ConfigRef) eq 'HASH' ) {
        %Config = %{$ConfigRef};
    }

    #init counters...
    $Result{CountUploaded}     = 0;
    $Result{CountUpdateFailed} = 0;
    $Result{CountUpdated}      = 0;
    $Result{CountInsertFailed} = 0;
    $Result{CountAdded}        = 0;
    $Result{UploadMessage}     = '';

    # check required params...
    for (qw( XMLString UserID )) {
        if ( !defined( $Param{$_} ) ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    my @XMLHash = $Self->{XMLObject}->XMLParse2XMLHash(
        String => $Param{XMLString}
    );
    my @UpdateArray;

    if (
        $XMLHash[1]
        &&
        ref( $XMLHash[1] ) eq 'HASH'
        && $XMLHash[1]->{'TextModuleCategoryList'}
        && ref( $XMLHash[1]->{'TextModuleCategoryList'} ) eq 'ARRAY'
        && $XMLHash[1]->{'TextModuleCategoryList'}->[1]
        && ref( $XMLHash[1]->{'TextModuleCategoryList'}->[1] ) eq 'HASH'
        && $XMLHash[1]->{'TextModuleCategoryList'}->[1]->{'TextModuleCategoryEntry'}
        && ref( $XMLHash[1]->{'TextModuleCategoryList'}->[1]->{'TextModuleCategoryEntry'} ) eq
        'ARRAY'
        )
    {
        my $TMArrIndex = 0;
        for my $TMArrRef (
            @{ $XMLHash[1]->{'TextModuleCategoryList'}->[1]->{'TextModuleCategoryEntry'} }
            )
        {
            next if ( !defined($TMArrRef) || ref($TMArrRef) ne 'HASH' );

            $TMArrIndex++;
            my %UpdateData = ();
            for my $Key ( %{$TMArrRef} ) {

                if (
                    ref( $TMArrRef->{$Key} ) eq 'ARRAY'
                    && $TMArrRef->{$Key}->[1]
                    && ref( $TMArrRef->{$Key}->[1] ) eq 'HASH'
                    )
                {
                    $UpdateData{$Key} = $TMArrRef->{$Key}->[1]->{Content} || '';
                }
            }

            $Result{CountUploaded}++;

            #-------------------------------------------------------------------
            # set default values...
            for my $Key ( keys(%Config) ) {
                if ( !$UpdateData{$Key} ) {
                    $UpdateData{$Key} = $Config{$Key};
                }
            }

            # check for ID and update...
            if ( $UpdateData{ID} ) {
                my $UpdateResult = 0;
                my $ErrorMessage = "";
                my $Status       = "";

                my %TextModuleCategory2U = $Self->TextModuleCategoryGet(
                    ID => $UpdateData{ID}
                );
                if ( !keys(%TextModuleCategory2U) ) {
                    $UpdateData{ID} = 0;
                    $ErrorMessage = "Specified text module category ID (" . $UpdateData{ID}
                        . ") does not exist - attempting insert. ";
                }

                # update text module category...
                if ( $UpdateData{ID} && $UpdateData{Name} ) {
                    $UpdateResult = $Self->TextModuleCategoryUpdate(
                        ID     => $UpdateData{ID},
                        Name   => $UpdateData{Name} || '',
                        UserID => $Param{UserID},
                    );
                    if ($UpdateResult) {
                        $Result{CountUpdated}++;
                        $Status = 'Update OK';
                    }
                    else {
                        $Result{CountUpdateFailed}++;
                        $Status = 'Update Failed';
                    }
                }
                elsif ( $UpdateData{Name} ) {
                    $UpdateResult = $Self->TextModuleCategoryAdd(
                        Name => $UpdateData{Name} || '',
                        UserID => $Param{UserID},
                    );
                    $UpdateData{ID} = $UpdateResult;
                    if ($UpdateResult) {
                        $Result{CountAdded}++;
                        $Status = 'Insert OK';
                    }
                    else {
                        $Result{CountInsertFailed}++;
                        $Status = 'Insert Failed';
                    }
                }
                else {
                    $ErrorMessage .= "Name not given!";
                }

                if ($UpdateResult) {

                    #create some status/message for feedback...
                    $XMLHash[1]->{'TextModuleCategoryList'}->[1]->{'TextModuleCategoryEntry'}
                        ->[$TMArrIndex]->{ImportResultStatus} = $Status;
                    $XMLHash[1]->{'TextModuleCategoryList'}->[1]->{'TextModuleCategoryEntry'}
                        ->[$TMArrIndex]->{ImportResultMessage} = $ErrorMessage;
                }
                else {
                    $XMLHash[1]->{'TextModuleCategoryList'}->[1]->{'TextModuleCategoryEntry'}
                        ->[$TMArrIndex]->{ImportResultStatus} = $Status;
                    $XMLHash[1]->{'TextModuleCategoryList'}->[1]->{'TextModuleCategoryEntry'}
                        ->[$TMArrIndex]->{ImportResultMessage} = $ErrorMessage;
                }
            }

            #no ID => insert/add...
            elsif ( !$Param{DoNotAdd} ) {
                my $NewID        = 0;
                my $ErrorMessage = "";
                my $Status       = "";

                #insert new textmodule category...
                if ( $UpdateData{Name} ) {
                    $NewID = $Self->TextModuleCategoryAdd(
                        Name => $UpdateData{Name} || '',
                        UserID => $Param{UserID},
                    );
                }
                else {
                    $ErrorMessage = "Name not given!";
                }

                if ($NewID) {
                    $Result{CountAdded}++;
                    $UpdateData{ID} = $NewID;
                    $Status = 'Insert OK';

                    #create some status/message for feedback...
                    $XMLHash[1]->{'TextModuleCategoryList'}->[1]->{'TextModuleCategoryEntry'}
                        ->[$TMArrIndex]->{ImportResultStatus} = $Status;
                    $XMLHash[1]->{'TextModuleCategoryList'}->[1]->{'TextModuleCategoryEntry'}
                        ->[$TMArrIndex]->{ImportResultMessage} = $ErrorMessage;

                }
                else {
                    $Result{CountInsertFailed}++;
                    $Status = 'Insert Failed';
                    $XMLHash[1]->{'TextModuleCategoryList'}->[1]->{'TextModuleCategoryEntry'}
                        ->[$TMArrIndex]->{ImportResultStatus} = $Status;
                    $XMLHash[1]->{'TextModuleCategoryList'}->[1]->{'TextModuleCategoryEntry'}
                        ->[$TMArrIndex]->{ImportResultMessage} = $ErrorMessage;
                }
            }
        }
    }

    $Result{XMLResultString} = $Self->{XMLObject}->XMLHash2XML(@XMLHash);

    return \%Result;
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
                'SELECT object_id FROM kix_text_module_object_link WHERE object_type = ? AND text_module_id = ? ',
            Bind => [ \$Param{ObjectType}, \$Param{TextModuleID} ],
        );
    }
    else {
        return if !$Self->{DBObject}->Prepare(
            SQL =>
                'SELECT text_module_id FROM kix_text_module_object_link WHERE object_type = ? AND object_id = ? ',
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
                    'DELETE FROM kix_text_module_object_link WHERE object_type = ? AND text_module_id = ?',
                Bind => [ \$Param{ObjectType}, \$Param{TextModuleID} ],
            );
        }
        else {
            return $Self->{DBObject}->Do(
                SQL  => 'DELETE FROM kix_text_module_object_link WHERE text_module_id = ?',
                Bind => [ \$Param{TextModuleID} ],
            );
        }
    }
    else {
        return $Self->{DBObject}->Do(
            SQL =>
                'DELETE FROM kix_text_module_object_link WHERE object_type = ? AND object_id = ?',
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

    my $SQL = "INSERT INTO kix_text_module_object_link "
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
    my $SQL = "SELECT count(*) FROM kix_text_module t";

    if ( defined $Param{Type} && $Param{Type} =~ /^UNASSIGNED::(.*?)$/g ) {
        $SQL
            .= " WHERE NOT EXISTS (SELECT object_id FROM kix_text_module_object_link ol WHERE object_type = '"
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

=item _CreateTextModuleExportCSV()

Export all Textmodules into CSV document.

    my $String = $TextModuleObject->_CreateTextModuleExportCSV(
        CSVSeparator => ';'
    );

=cut

sub _CreateTextModuleExportCSV {
    my ( $Self, %Param ) = @_;
    my $Result = "";
    my @ObjectList;
    my $ObjectListString;
    my $SelectedObjectRef;

    my %TextModuleData = $Self->TextModuleList(%Param);
    my @ExportDataArray;
    my @ExportHeadArray;

    for my $CurrHashID ( sort keys %TextModuleData ) {
        my @ExportRowArray;

        my %TextModule = $Self->TextModuleGet(
            ID => $CurrHashID,
        );

        my %CurrTM = ();

        # create header
        if ( !@ExportHeadArray ) {
            for my $CurrKey ( sort keys(%TextModule) ) {
                push( @ExportHeadArray, $CurrKey );
            }
            push( @ExportHeadArray, 'TextModuleCategoryList' );
            push( @ExportHeadArray, 'TextModuleQueueList' );
            push( @ExportHeadArray, 'TextModuleTicketTypeList' );
            push( @ExportHeadArray, 'TextModuleTicketStateList' );
        }

        # add all keys
        for my $CurrKey ( sort keys(%TextModule) ) {
            push( @ExportRowArray, $TextModule{$CurrKey} );
        }

        # get all linked categories....
        $SelectedObjectRef = $Self->TextModuleObjectLinkGet(
            TextModuleID => $CurrHashID,
            ObjectType   => 'TextModuleCategory'
        );

        @ObjectList = ();
        for my $ObjectID ( @{$SelectedObjectRef} ) {
            my $ObjectName = $Self->TextModuleCategoryLookup(
                ID => $ObjectID
            );
            push( @ObjectList, $ObjectName );
        }
        $ObjectListString = join( '|', @ObjectList );
        push( @ExportRowArray, $ObjectListString );

        # get all linked queues....
        $SelectedObjectRef = $Self->TextModuleObjectLinkGet(
            TextModuleID => $CurrHashID,
            ObjectType   => 'Queue'
        );

        @ObjectList = ();
        for my $ObjectID ( @{$SelectedObjectRef} ) {
            my $ObjectName = $Self->{QueueObject}->QueueLookup(
                QueueID => $ObjectID
            );
            push( @ObjectList, $ObjectName );
        }
        $ObjectListString = join( '|', @ObjectList );
        push( @ExportRowArray, $ObjectListString );

        # get all linked ticket types....
        $SelectedObjectRef = $Self->TextModuleObjectLinkGet(
            TextModuleID => $CurrHashID,
            ObjectType   => 'TicketType'
        );

        @ObjectList = ();
        for my $ObjectID ( @{$SelectedObjectRef} ) {
            my $ObjectName = $Self->{TypeObject}->TypeLookup(
                TypeID => $ObjectID
            );
            push( @ObjectList, $ObjectName );
        }
        $ObjectListString = join( '|', @ObjectList );
        push( @ExportRowArray, $ObjectListString );

        # get all linked ticket states....
        $SelectedObjectRef = $Self->TextModuleObjectLinkGet(
            TextModuleID => $CurrHashID,
            ObjectType   => 'TicketState'
        );

        @ObjectList = ();
        for my $ObjectID ( @{$SelectedObjectRef} ) {
            my $ObjectName = $Self->{StateObject}->StateLookup(
                StateID => $ObjectID
            );
            push( @ObjectList, $ObjectName );
        }
        $ObjectListString = join( '|', @ObjectList );
        push( @ExportRowArray, $ObjectListString );

        push( @ExportDataArray, \@ExportRowArray );
    }

    $Result = $Self->{CSVObject}->Array2CSV(
        Head      => \@ExportHeadArray,
        Data      => \@ExportDataArray,
        Separator => $Param{CSVSeparator} || ';',
    );

    return $Result;
}

=item _CreateTextModuleExportXML()

Export all Textmodules into XML document.

    my $String = $TextModuleObject->_CreateTextModuleExportXML();

=cut

sub _CreateTextModuleExportXML {
    my ( $Self, %Param ) = @_;
    my $Result = "";

    my %TextModuleData = $Self->TextModuleList(%Param);
    my @ExportDataArray;
    push( @ExportDataArray, undef );

    for my $CurrHashID ( sort keys %TextModuleData ) {

        my %TextModule = $Self->TextModuleGet(
            ID => $CurrHashID,
        );

        my %CurrTM = ();
        for my $CurrKey ( keys(%TextModule) ) {
            $CurrTM{$CurrKey}->[0] = undef;
            $CurrTM{$CurrKey}->[1]->{Content} = $TextModule{$CurrKey};
        }

        # get all linked categories....
        my $SelectedCategoryRef = $Self->TextModuleObjectLinkGet(
            TextModuleID => $CurrHashID,
            ObjectType   => 'TextModuleCategory'
        );

        my $CategoryIndex = 1;
        $CurrTM{TextModuleCategoryList}->[0] = undef;

        for my $CurrCategoryID ( @{$SelectedCategoryRef} ) {
            my %Category = ();
            $Category{ID}      = $CurrCategoryID;
            $Category{Content} = $Self->TextModuleCategoryLookup(
                ID => $CurrCategoryID
            );

            $CurrTM{TextModuleCategoryList}->[1]->{TextModuleCategory}->[0] = undef;
            $CurrTM{TextModuleCategoryList}->[1]->{TextModuleCategory}->[$CategoryIndex]
                = \%Category;
            $CategoryIndex++;
        }

        if (
            !$CurrTM{TextModuleCategoryList}->[1]->{TextModuleCategory}->[1]
            || ref $CurrTM{TextModuleCategoryList}->[1]->{TextModuleCategory}->[1] ne 'HASH'
            )
        {
            %{ $CurrTM{TextModuleCategoryList}->[1]->{TextModuleCategory}->[1] } = ();
        }

        # get all linked queues....
        my $SelectedQueueRef = $Self->TextModuleObjectLinkGet(
            TextModuleID => $CurrHashID,
            ObjectType   => 'Queue'
        );

        my $QueueIndex = 1;
        $CurrTM{QueueList}->[0] = undef;
        for my $CurrQueueID ( @{$SelectedQueueRef} ) {
            my %Queue = ();
            $Queue{ID}      = $CurrQueueID;
            $Queue{Content} = $Self->{QueueObject}->QueueLookup(
                QueueID => $CurrQueueID
            );
            $CurrTM{QueueList}->[1]->{Queue}->[0] = undef;
            $CurrTM{QueueList}->[1]->{Queue}->[$QueueIndex] = \%Queue;
            $QueueIndex++;
        }

        if (
            !$CurrTM{QueueList}->[1]->{Queue}->[1]
            || ref $CurrTM{QueueList}->[1]->{Queue}->[1] ne 'HASH'
            )
        {
            %{ $CurrTM{QueueList}->[1]->{Queue}->[1] } = ();
        }

        # get all linked ticket types....
        my $SelectedTicketTypeRef = $Self->TextModuleObjectLinkGet(
            TextModuleID => $CurrHashID,
            ObjectType   => 'TicketType'
        );

        my $TicketTypeIndex = 1;
        $CurrTM{TicketTypeList}->[0] = undef;
        for my $CurrTicketTypeID ( @{$SelectedTicketTypeRef} ) {
            my %TicketType = ();
            $TicketType{ID}      = $CurrTicketTypeID;
            $TicketType{Content} = $Self->{TypeObject}->TypeLookup(
                TypeID => $CurrTicketTypeID
            );
            $CurrTM{TicketTypeList}->[1]->{TicketType}->[0] = undef;
            $CurrTM{TicketTypeList}->[1]->{TicketType}->[$TicketTypeIndex] = \%TicketType;
            $TicketTypeIndex++;
        }

        if (
            !$CurrTM{TicketTypeList}->[1]->{TicketType}->[1]
            || ref $CurrTM{TicketTypeList}->[1]->{TicketType}->[1] ne 'HASH'
            )
        {
            %{ $CurrTM{TicketTypeList}->[1]->{TicketType}->[1] } = ();
        }

        # get all linked ticket states....
        my $SelectedTicketStateRef = $Self->TextModuleObjectLinkGet(
            TextModuleID => $CurrHashID,
            ObjectType   => 'TicketState'
        );

        my $TicketStateIndex = 1;
        $CurrTM{TicketStateList}->[0] = undef;
        for my $CurrTicketStateID ( @{$SelectedTicketStateRef} ) {
            my %TicketState = ();
            $TicketState{ID}      = $CurrTicketStateID;
            $TicketState{Content} = $Self->{StateObject}->StateLookup(
                StateID => $CurrTicketStateID
            );
            $CurrTM{TicketStateList}->[1]->{TicketState}->[0] = undef;
            $CurrTM{TicketStateList}->[1]->{TicketState}->[$TicketStateIndex] = \%TicketState;
            $TicketStateIndex++;
        }

        if (
            !$CurrTM{TicketStateList}->[1]->{TicketState}->[1]
            || ref $CurrTM{TicketStateList}->[1]->{TicketState}->[1] ne 'HASH'
            )
        {
            %{ $CurrTM{TicketStateList}->[1]->{TicketState}->[1] } = ();
        }

        # export *-lists...
        push( @ExportDataArray, \%CurrTM );
    }

    my @XMLHashArray;
    push( @XMLHashArray, undef );

    my %XMLHashTextModule = ();
    $XMLHashTextModule{'TextModuleList'}->[0] = undef;
    $XMLHashTextModule{'TextModuleList'}->[1]->{'TextModuleEntry'} = \@ExportDataArray;

    push( @XMLHashArray, \%XMLHashTextModule );

    $Result = $Self->{XMLObject}->XMLHash2XML(@XMLHashArray);

    return $Result;
}

=item TextModulesImport()

import TextModules from XML or CSV document.

    my $HashRef = $TextModuleObject->TextModulesImport(
        Format  => 'CSV'|'XML'
        Content => '<xml><tag>...</tag>', #required
        CSVSeparator => ';'
        DoNotAdd => 0|1, #DO NOT create new entry if no existing id given
        UserID   => 123, #required
    );

=cut

sub TextModulesImport {
    my ( $Self, %Param ) = @_;
    my $Result;

    if ( !$Param{Format} || $Param{Format} eq 'XML' ) {
        $Result = $Self->_ImportTextModuleXML(
            %Param,
            XMLString => $Param{Content},
        );
    }
    elsif ( $Param{Format} eq 'CSV' ) {
        $Result = $Self->_ImportTextModuleCSV(
            %Param,
        );
    }

    return $Result;
}

=item _ImportTextModuleCSV()

import TextModules from CSV document.

    my $HashRef = $TextModuleObject->_ImportTextModuleCSV(
        Content => '...', #required
        CSVSeparator => ';'
        DoNotAdd => 0|1, #DO NOT create new entry if no existing id given
        UserID   => 123, #required
    );

=cut

sub _ImportTextModuleCSV {
    my ( $Self, %Param ) = @_;
    my %Result = ();
    my @XMLHash;

    #get default config...
    my $ConfigRef = $Self->{ConfigObject}->Get('AdminResponsesUploads::TextModuleDefaults');
    my %Config    = ();
    if ( $ConfigRef && ref($ConfigRef) eq 'HASH' ) {
        %Config = %{$ConfigRef};
    }

    #init counters...
    $Result{CountUploaded}     = 0;
    $Result{CountUpdateFailed} = 0;
    $Result{CountUpdated}      = 0;
    $Result{CountInsertFailed} = 0;
    $Result{CountAdded}        = 0;
    $Result{UploadMessage}     = '';

    # check required params...
    for (qw( Content UserID )) {
        if ( !defined( $Param{$_} ) ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # get array from csv data
    my $CSVArray = $Self->{CSVObject}->CSV2Array(
        String => $Param{Content},
        Separator => $Param{CSVSeparator} || ';',
    );

    my $HeadLine = shift @{$CSVArray};

    my $TMArrIndex = 0;
    foreach my $Row ( @{$CSVArray} ) {
        $TMArrIndex++;
        my %UpdateData;
        my $ColumnIdx = 0;
        foreach my $ColumnContent ( @{$Row} ) {
            my $Key = $HeadLine->[$ColumnIdx];
            if ( $Key !~ /(.*?)List$/g ) {
                $UpdateData{$Key} = $ColumnContent;
            }
            else {
                my $ObjectType = $1;
                my $ObjectIdx  = 0;
                my $ObjectID;
                my %ListHash;
                foreach my $ObjectName ( split( /\|/, $ColumnContent ) ) {
                    if ( $ObjectType eq 'TextModuleCategory' ) {
                        $ObjectID = $Self->TextModuleCategoryLookup(
                            Name => $ObjectName,
                        );
                    }
                    elsif ( $ObjectType eq 'Queue' ) {
                        $ObjectID = $Self->{QueueObject}->QueueLookup(
                            Queue => $ObjectName,
                        );
                    }
                    elsif ( $ObjectType eq 'TicketType' ) {
                        $ObjectID = $Self->{TypeObject}->TypeLookup(
                            Type => $ObjectName,
                        );
                    }
                    elsif ( $ObjectType eq 'TicketState' ) {
                        $ObjectID = $Self->{StateObject}->StateLookup(
                            State => $ObjectName,
                        );
                    }
                    $ListHash{ $ObjectIdx++ } = {
                        ID   => $ObjectID,
                        Name => $ObjectName,
                        }
                }
                $UpdateData{$Key} = \%ListHash;
            }
            $ColumnIdx++;
        }

        $Result{CountUploaded}++;

        #-------------------------------------------------------------------
        # set default values...
        for my $Key ( keys(%Config) ) {
            if ( !$UpdateData{$Key} ) {
                $UpdateData{$Key} = $Config{$Key};
            }
        }

        # check for ID and update...
        if ( $UpdateData{ID} ) {
            my $UpdateResult = 0;
            my $ErrorMessage = "";
            my $Status       = "";
            my %TextModule2U = $Self->TextModuleGet(
                ID => $UpdateData{ID}
            );
            if ( !keys(%TextModule2U) ) {
                $UpdateData{ID} = 0;
                $ErrorMessage = "Specified text module ID (" . $UpdateData{ID}
                    . ") does not exist - attempting insert. ";
            }

            # update text module...
            if ( $UpdateData{ID} && $UpdateData{Name} ) {
                $UpdateResult = $Self->TextModuleUpdate(
                    ID         => $UpdateData{ID},
                    ValidID    => $UpdateData{ValidID} || 1,
                    TextModule => $UpdateData{TextModule} || '',
                    Keywords   => $UpdateData{Keywords} || '',
                    Language   => $UpdateData{Language} || '',
                    Name       => $UpdateData{Name} || '',
                    Comment1   => $UpdateData{Comment1} || '',
                    Comment2   => $UpdateData{Comment2} || '',
                    Agent      => $UpdateData{Agent} || '',
                    Customer   => $UpdateData{Customer} || '',
                    Public     => $UpdateData{Public} || '',
                    Subject    => $UpdateData{Subject},
                    UserID     => $Param{UserID},
                );
                if ($UpdateResult) {
                    $Result{CountUpdated}++;
                    $Status = 'Update OK';
                }
                else {
                    $Result{CountUpdateFailed}++;
                    $Status = 'Update Failed';
                }
            }
            elsif ( $UpdateData{Name} ) {
                $UpdateResult = $Self->TextModuleAdd(
                    ValidID    => $UpdateData{ValidID}    || 1,
                    TextModule => $UpdateData{TextModule} || '',
                    Keywords   => $UpdateData{Keywords}   || '',
                    Language   => $UpdateData{Language}   || '',
                    Name       => $UpdateData{Name}       || '',
                    Comment1   => $UpdateData{Comment1}   || '',
                    Comment2   => $UpdateData{Comment2}   || '',
                    Agent      => $UpdateData{Agent}      || '',
                    Customer   => $UpdateData{Customer}   || '',
                    Public     => $UpdateData{Public}     || '',
                    Subject    => $UpdateData{Subject},
                    UserID     => $Param{UserID},
                );
                $UpdateData{ID} = $UpdateResult;
                if ($UpdateResult) {
                    $Result{CountAdded}++;
                    $Status = 'Insert OK';
                }
                else {
                    $Result{CountInsertFailed}++;
                    $Status = 'Insert Failed';
                }
            }
            else {
                $ErrorMessage .= "Name not given!";
            }

            if ($UpdateResult) {
                $ErrorMessage .= $Self->_ImportObjectLinks(
                    UpdateData => \%UpdateData,
                    UserID     => $Param{UserID},
                );

                # create some status/message for feedback...
                $XMLHash[1]->{'TextModuleList'}->[1]->{'TextModuleEntry'}
                    ->[$TMArrIndex]->{ImportResultStatus} = $Status;
                $XMLHash[1]->{'TextModuleList'}->[1]->{'TextModuleEntry'}
                    ->[$TMArrIndex]->{ImportResultMessage} = $ErrorMessage;
            }
            else {
                $XMLHash[1]->{'TextModuleList'}->[1]->{'TextModuleEntry'}
                    ->[$TMArrIndex]->{ImportResultStatus} = $Status;
                $XMLHash[1]->{'TextModuleList'}->[1]->{'TextModuleEntry'}
                    ->[$TMArrIndex]->{ImportResultMessage} = $ErrorMessage;
            }
        }

        #no ID => insert/add...
        elsif ( !$Param{DoNotAdd} ) {
            my $NewID        = 0;
            my $ErrorMessage = "";
            my $Status       = "";

            #insert new textmodule...
            if ( $UpdateData{Name} ) {
                $NewID = $Self->TextModuleAdd(
                    ValidID    => $UpdateData{ValidID}    || 1,
                    TextModule => $UpdateData{TextModule} || '',
                    Keywords   => $UpdateData{Keywords}   || '',
                    Language   => $UpdateData{Language}   || '',
                    Name       => $UpdateData{Name}       || '',
                    Comment1   => $UpdateData{Comment1}   || '',
                    Comment2   => $UpdateData{Comment2}   || '',
                    Agent      => $UpdateData{Agent}      || '',
                    Customer   => $UpdateData{Customer}   || '',
                    Public     => $UpdateData{Public}     || '',
                    Subject    => $UpdateData{Subject},
                    UserID     => $Param{UserID},
                );
            }
            else {
                $ErrorMessage = "Name not given!";
            }

            if ($NewID) {
                $Result{CountAdded}++;
                $UpdateData{ID} = $NewID;
                $Status = 'Insert OK';

                $ErrorMessage .= $Self->_ImportObjectLinks(
                    UpdateData => \%UpdateData,
                    UserID     => $Param{UserID},
                );

                #create some status/message for feedback...
                $XMLHash[1]->{'TextModuleList'}->[1]->{'TextModuleEntry'}
                    ->[$TMArrIndex]->{ImportResultStatus} = $Status;
                $XMLHash[1]->{'TextModuleList'}->[1]->{'TextModuleEntry'}
                    ->[$TMArrIndex]->{ImportResultMessage} = $ErrorMessage;

            }
            else {
                $Result{CountInsertFailed}++;
                $Status = 'Insert Failed';
                $XMLHash[1]->{'TextModuleList'}->[1]->{'TextModuleEntry'}
                    ->[$TMArrIndex]->{ImportResultStatus} = $Status;
                $XMLHash[1]->{'TextModuleList'}->[1]->{'TextModuleEntry'}
                    ->[$TMArrIndex]->{ImportResultMessage} = $ErrorMessage;
            }
        }
    }

    $Result{XMLResultString} = $Self->{XMLObject}->XMLHash2XML(@XMLHash);

    return \%Result;
}

=item _ImportTextModuleXML()

import TextModules from XML document.

    my $HashRef = $TextModuleObject->_ImportTextModuleXML(
        XMLString => '<xml><tag>...</tag>', #required
        DoNotAdd => 0|1, #DO NOT create new entry if no existing id given
        UserID   => 123, #required
    );

=cut

sub _ImportTextModuleXML {
    my ( $Self, %Param ) = @_;
    my %Result = ();

    #get default config...
    my $ConfigRef = $Self->{ConfigObject}->Get('AdminResponsesUploads::TextModuleDefaults');
    my %Config    = ();
    if ( $ConfigRef && ref($ConfigRef) eq 'HASH' ) {
        %Config = %{$ConfigRef};
    }

    #init counters...
    $Result{CountUploaded}     = 0;
    $Result{CountUpdateFailed} = 0;
    $Result{CountUpdated}      = 0;
    $Result{CountInsertFailed} = 0;
    $Result{CountAdded}        = 0;
    $Result{UploadMessage}     = '';

    # check required params...
    for (qw( XMLString UserID )) {
        if ( !defined( $Param{$_} ) ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    my @XMLHash = $Self->{XMLObject}->XMLParse2XMLHash(
        String => $Param{XMLString}
    );
    my @UpdateArray;

    if (
        $XMLHash[1]
        &&
        ref( $XMLHash[1] ) eq 'HASH'
        && $XMLHash[1]->{'TextModuleList'}
        && ref( $XMLHash[1]->{'TextModuleList'} ) eq 'ARRAY'
        && $XMLHash[1]->{'TextModuleList'}->[1]
        && ref( $XMLHash[1]->{'TextModuleList'}->[1] ) eq 'HASH'
        && $XMLHash[1]->{'TextModuleList'}->[1]->{'TextModuleEntry'}
        && ref( $XMLHash[1]->{'TextModuleList'}->[1]->{'TextModuleEntry'} ) eq 'ARRAY'
        )
    {
        my $TMArrIndex = 0;
        for my $TMArrRef ( @{ $XMLHash[1]->{'TextModuleList'}->[1]->{'TextModuleEntry'} } ) {
            next if ( !defined($TMArrRef) || ref($TMArrRef) ne 'HASH' );

            $TMArrIndex++;
            my %UpdateData = ();
            for my $Key ( %{$TMArrRef} ) {
                if (
                    ref( $TMArrRef->{$Key} ) eq 'ARRAY'
                    && $TMArrRef->{$Key}->[1]
                    && ref( $TMArrRef->{$Key}->[1] ) eq 'HASH'
                    )
                {
                    $UpdateData{$Key} = $TMArrRef->{$Key}->[1]->{Content} || '';
                }
            }

            foreach my $ObjectType (qw(TextModuleCategory Queue TicketType TicketState)) {
                my %ObjectList;

                if (
                    ref( $TMArrRef->{ $ObjectType . 'List' } ) eq 'ARRAY'
                    && $TMArrRef->{ $ObjectType . 'List' }->[1]
                    && ref( $TMArrRef->{ $ObjectType . 'List' }->[1] ) eq 'HASH'
                    && $TMArrRef->{ $ObjectType . 'List' }->[1]->{$ObjectType}
                    && ref( $TMArrRef->{ $ObjectType . 'List' }->[1]->{$ObjectType} ) eq 'ARRAY'
                    )
                {
                    my $Index = 1;
                    for my $SubContent (
                        @{ $TMArrRef->{ $ObjectType . 'List' }->[1]->{$ObjectType} }
                        )
                    {
                        next if ( !defined($SubContent) );
                        $ObjectList{$Index}->{ID}   = $SubContent->{ID}      || '0';
                        $ObjectList{$Index}->{Name} = $SubContent->{Content} || '';
                        $Index++;
                    }
                    $UpdateData{ $ObjectType . 'List' } = \%ObjectList
                }
            }

            $Result{CountUploaded}++;

            #-------------------------------------------------------------------
            # set default values...
            for my $Key ( keys(%Config) ) {
                if ( !$UpdateData{$Key} ) {
                    $UpdateData{$Key} = $Config{$Key};
                }
            }

            # check for ID and update...
            if ( $UpdateData{ID} ) {
                my $UpdateResult = 0;
                my $ErrorMessage = "";
                my $Status       = "";

                my %TextModule2U = $Self->TextModuleGet(
                    ID => $UpdateData{ID}
                );
                if ( !keys(%TextModule2U) ) {
                    $UpdateData{ID} = 0;
                    $ErrorMessage = "Specified text module ID (" . $UpdateData{ID}
                        . ") does not exist - attempting insert. ";
                }

                # update text module...
                if ( $UpdateData{ID} && $UpdateData{Name} ) {
                    $UpdateResult = $Self->TextModuleUpdate(
                        ID         => $UpdateData{ID},
                        ValidID    => $UpdateData{ValidID} || 1,
                        TextModule => $UpdateData{TextModule} || '',
                        Keywords   => $UpdateData{Keywords} || '',
                        Language   => $UpdateData{Language} || '',
                        Name       => $UpdateData{Name} || '',
                        Comment1   => $UpdateData{Comment1} || '',
                        Comment2   => $UpdateData{Comment2} || '',
                        Agent      => $UpdateData{Agent} || '',
                        Customer   => $UpdateData{Customer} || '',
                        Public     => $UpdateData{Public} || '',
                        Subject    => $UpdateData{Subject},

                        UserID => $Param{UserID},
                    );
                    if ($UpdateResult) {
                        $Result{CountUpdated}++;
                        $Status = 'Update OK';
                    }
                    else {
                        $Result{CountUpdateFailed}++;
                        $Status = 'Update Failed';
                    }
                }
                elsif ( $UpdateData{Name} ) {
                    $UpdateResult = $Self->TextModuleAdd(
                        ValidID    => $UpdateData{ValidID}    || 1,
                        TextModule => $UpdateData{TextModule} || '',
                        Keywords   => $UpdateData{Keywords}   || '',
                        Language   => $UpdateData{Language}   || '',
                        Name       => $UpdateData{Name}       || '',
                        Comment1   => $UpdateData{Comment1}   || '',
                        Comment2   => $UpdateData{Comment2}   || '',
                        Agent      => $UpdateData{Agent}      || '',
                        Customer   => $UpdateData{Customer}   || '',
                        Public     => $UpdateData{Public}     || '',
                        Subject    => $UpdateData{Subject},

                        UserID => $Param{UserID},
                    );
                    $UpdateData{ID} = $UpdateResult;
                    if ($UpdateResult) {
                        $Result{CountAdded}++;
                        $Status = 'Insert OK';
                    }
                    else {
                        $Result{CountInsertFailed}++;
                        $Status = 'Insert Failed';
                    }
                }
                else {
                    $ErrorMessage .= "Name not given!";
                }

                if ($UpdateResult) {
                    $ErrorMessage .= $Self->_ImportObjectLinks(
                        UpdateData => \%UpdateData,
                        UserID     => $Param{UserID},
                    );

                    # create some status/message for feedback...
                    $XMLHash[1]->{'TextModuleList'}->[1]->{'TextModuleEntry'}
                        ->[$TMArrIndex]->{ImportResultStatus} = $Status;
                    $XMLHash[1]->{'TextModuleList'}->[1]->{'TextModuleEntry'}
                        ->[$TMArrIndex]->{ImportResultMessage} = $ErrorMessage;
                }
                else {
                    $XMLHash[1]->{'TextModuleList'}->[1]->{'TextModuleEntry'}
                        ->[$TMArrIndex]->{ImportResultStatus} = $Status;
                    $XMLHash[1]->{'TextModuleList'}->[1]->{'TextModuleEntry'}
                        ->[$TMArrIndex]->{ImportResultMessage} = $ErrorMessage;
                }
            }

            #no ID => insert/add...
            elsif ( !$Param{DoNotAdd} ) {
                my $NewID        = 0;
                my $ErrorMessage = "";
                my $Status       = "";

                #insert new textmodule...
                if ( $UpdateData{Name} ) {
                    $NewID = $Self->TextModuleAdd(
                        ValidID    => $UpdateData{ValidID}    || 1,
                        TextModule => $UpdateData{TextModule} || '',
                        Keywords   => $UpdateData{Keywords}   || '',
                        Language   => $UpdateData{Language}   || '',
                        Name       => $UpdateData{Name}       || '',
                        Comment1   => $UpdateData{Comment1}   || '',
                        Comment2   => $UpdateData{Comment2}   || '',
                        Agent      => $UpdateData{Agent}      || '',
                        Customer   => $UpdateData{Customer}   || '',
                        Public     => $UpdateData{Public}     || '',
                        Subject    => $UpdateData{Subject},

                        UserID => $Param{UserID},
                    );
                }
                else {
                    $ErrorMessage = "Name not given!";
                }

                if ($NewID) {
                    $Result{CountAdded}++;
                    $UpdateData{ID} = $NewID;
                    $Status = 'Insert OK';

                    $ErrorMessage .= $Self->_ImportObjectLinks(
                        UpdateData => \%UpdateData,
                        UserID     => $Param{UserID},
                    );

                    #create some status/message for feedback...
                    $XMLHash[1]->{'TextModuleList'}->[1]->{'TextModuleEntry'}
                        ->[$TMArrIndex]->{ImportResultStatus} = $Status;
                    $XMLHash[1]->{'TextModuleList'}->[1]->{'TextModuleEntry'}
                        ->[$TMArrIndex]->{ImportResultMessage} = $ErrorMessage;

                }
                else {
                    $Result{CountInsertFailed}++;
                    $Status = 'Insert Failed';
                    $XMLHash[1]->{'TextModuleList'}->[1]->{'TextModuleEntry'}
                        ->[$TMArrIndex]->{ImportResultStatus} = $Status;
                    $XMLHash[1]->{'TextModuleList'}->[1]->{'TextModuleEntry'}
                        ->[$TMArrIndex]->{ImportResultMessage} = $ErrorMessage;
                }
            }
        }
    }

    $Result{XMLResultString} = $Self->{XMLObject}->XMLHash2XML(@XMLHash);

    return \%Result;
}

sub _ImportObjectLinks {
    my ( $Self, %Param ) = @_;
    my $ErrorMessage = '';

    # check required params...
    for (qw( UpdateData UserID )) {
        if ( !defined( $Param{$_} ) ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    foreach my $ObjectType (qw(TextModuleCategory Queue TicketType TicketState)) {

        next if ( ref $Param{UpdateData}->{ $ObjectType . 'List' } ne 'HASH' );

        # delete existing object links...
        if ( scalar keys %{ $Param{UpdateData}->{ $ObjectType . 'List' } } ) {
            $Self->TextModuleObjectLinkDelete(
                TextModuleID => $Param{UpdateData}->{ID},
                ObjectType   => $ObjectType,
            );
            $ErrorMessage .= 'Existing ' . $ObjectType . ' links deleted.';
        }

        # update object links...
        for my $CurrIndex ( keys %{ $Param{UpdateData}->{ $ObjectType . 'List' } } ) {

            my $GivenName = $Param{UpdateData}->{ $ObjectType . 'List' }->{$CurrIndex}->{Name}
                || '';
            my $ObjectName = $GivenName;
            my $GivenID    = $Param{UpdateData}->{ $ObjectType . 'List' }->{$CurrIndex}->{ID} || 0;
            my $ObjectID   = $GivenID;

            if ( !$GivenID && $GivenName ) {
                if ( $ObjectType eq 'TextModuleCategory' ) {
                    $ObjectID = $Self->TextModuleCategoryLookup(
                        Name => $GivenName,
                    );
                }
                elsif ( $ObjectType eq 'Queue' ) {
                    $ObjectID = $Self->{QueueObject}->QueueLookup(
                        Queue => $GivenName,
                    );
                }
                elsif ( $ObjectType eq 'TicketType' ) {
                    $ObjectID = $Self->{TypeObject}->TypeLookup(
                        Type => $GivenName,
                    );
                }
                elsif ( $ObjectType eq 'TicketState' ) {
                    $ObjectID = $Self->{StateObject}->StateLookup(
                        State => $GivenName,
                    );
                }
            }
            elsif ( !$GivenID && !$GivenName ) {
                $ErrorMessage .= " No link created ($ObjectType): no name or ID given.";
            }

            if ( !$ObjectID ) {
                $ErrorMessage
                    .= " No link created ($ObjectType): found no ID for given name ($GivenName).";
            }
            else {
                $Self->TextModuleObjectLinkCreate(
                    TextModuleID => $Param{UpdateData}->{ID},
                    ObjectID     => $ObjectID,
                    ObjectType   => $ObjectType,
                    UserID       => $Param{UserID},
                );
            }
        }
    }

    return $ErrorMessage;
}

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
