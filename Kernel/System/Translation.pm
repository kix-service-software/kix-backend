# --
# Copyright (C) 2006-2018 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Translation;

use strict;
use warnings;

use Locale::PO;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DB',
    'Kernel::System::Log',
);

our $DisableWarnings = 0;

BEGIN { $SIG{'__WARN__'} = sub { warn $_[0] if !$DisableWarnings } }  # suppress warnings if not activated

=head1 NAME

Kernel::System::Translation - global translation management

=head1 SYNOPSIS

All translation functions to manage/insert/update/delete/... languages/translations/... to a database/config file.

=head1 PUBLIC INTERFACE

=over 4

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{CacheType} = 'Translation';
    $Self->{CacheTTL}  = 60 * 60 * 24 * 20;    

    return $Self;
}

=item PatternGet()

get Pattern

    my %Pattern = $TranslationObject->PatternGet(
        ID => 123           # required
    );

=cut

sub PatternGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # check cache
    my $CacheKey = "PatternGet::$Param{ID}";
    my $Cache    = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL  => 'SELECT id, value, create_time, create_by, change_time, change_by FROM kix_translation_pattern WHERE id = ?',
        Bind => [ \$Param{ID} ] 
    );

    # fetch the result
    my %Pattern;
    while (my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray()) {
        $Pattern{ID}         = $Row[0];
        $Pattern{Value}      = $Row[1];
        $Pattern{CreateTime} = $Row[2];
        $Pattern{CreateBy}   = $Row[3];
        $Pattern{ChangeTime} = $Row[4];
        $Pattern{ChangeBy}   = $Row[5];
    }

    # set cache
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Pattern,
    );

    return %Pattern;
}

=item PatternList()

get Pattern list

    my %List = $TranslationObject->PatternList();

=cut

sub PatternList {
    my ( $Self, %Param ) = @_;

    # check cache
    my $CacheKey = "PatternList";
    my $Cache    = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    $Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL => 'SELECT id, value FROM kix_translation_pattern'
    );

    # fetch the result
    my %PatternList;
    while (my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray()) {
        $PatternList{ $Row[0] } = $Row[1];
    }

    # set cache
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%PatternList,
    );

    return %PatternList;
}

=item PatternExistsCheck()

check if a pattern exists

    my $PatternID = $TranslationObject->PatternLookup( 
        Value => '...'                  # required
    );

=cut

sub PatternExistsCheck {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Value)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # check cache
    my $CacheKey = "PatternExistsCheck::$Param{Value}";
    my $Cache    = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return $Cache if $Cache;

    $Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL  => 'SELECT id FROM kix_translation_pattern WHERE value = ?',
        Bind => [ \$Param{Value} ] 
    );

    # fetch the result
    my $PatternID;
    while (my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray()) {
        $PatternID = $Row[0];
    }

    if ( $PatternID ) {
        # set cache
        $Kernel::OM->Get('Kernel::System::Cache')->Set(
            Type  => $Self->{CacheType},
            TTL   => $Self->{CacheTTL},
            Key   => $CacheKey,
            Value => $PatternID,
        );
    }

    return $PatternID;
}

=item PatternAdd()

    Inserts a new Pattern entry

    my $ID = $TranslationObject->PatternAdd(
        Value  => '...',        # required
        UserID => '...',        # required
    );

=cut

sub PatternAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Value UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # check if the Pattern already exists
    my $ID = $Self->PatternExistsCheck(
        Value => $Param{Value}
    );
    if ( $ID ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "An identical pattern already exists!"
        );
        return;
    }

    # sql
    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => 'INSERT INTO kix_translation_pattern '
            . '(value, create_time, create_by, change_time, change_by) '
            . 'VALUES (?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$Param{Value}, \$Param{UserID}, \$Param{UserID}
        ],
    );

    # get new Pattern id
    return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL   => 'SELECT id FROM kix_translation_pattern WHERE value = ?',
        Bind  => [ \$Param{Value} ],
        Limit => 1,
    );

    # fetch the result
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        $ID = $Row[0];
    }
    return if !$ID;

    # reset cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
        Event    => 'CREATE',
        Object   => 'Translation.Pattern',
        ObjectID => $ID,
    );

    return $ID;
}

=item PatternUpdate()

    Update an existing Pattern entry

    my $Success = $TranslationObject->PatternUpdate(
        ID     => 123           # required
        Value  => '...',        # required
        UserID => '...',        # required
    );

=cut

sub PatternUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID Value UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # check if the Pattern already exists
    my $ID = $Self->PatternExistsCheck(
        Value => $Param{Value}
    );
    if ( $ID && $ID != $Param{ID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "An identical Pattern already exists!"
        );
        return;
    }

    # sql
    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => 'UPDATE kix_translation_pattern SET value = ?, change_time = current_timestamp, change_by = ? WHERE id = ?',
        Bind => [
            \$Param{Value}, \$Param{UserID}, \$Param{ID}
        ],
    );

    # reset cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
        Event    => 'UPDATE',
        Object   => 'Translation.Pattern',
        ObjectID => $Param{ID},
    );

    return 1;
}

=item PatternDelete()

    Deletes an existing Pattern entry

    my $ID = $TranslationObject->PatternDelete(
        ID     => 123,          # required
        UserID => '...',       # required
    );

=cut

sub PatternDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # delete pattern
    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => 'DELETE FROM kix_translation_pattern WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );

    # delete assigned languages
    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => 'DELETE FROM kix_translation_language WHERE pattern_id = ?',
        Bind => [ \$Param{ID} ],
    );

    # reset cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
        Event    => 'DELETE',
        Object   => 'Translation.Pattern',
        ObjectID => $Param{ID},
    );

    return 1;
}

=item TranslationLanguageAdd()

Inserts a new translation language 

    my $ID = $TranslationObject->TranslationLanguageAdd(
        PatternID  => 123,          # required
        Language   => $language,    # required
        Value      => '...',        # required
        IsDefault => 0|1,           # optional
        UserID     => '...',        # required
    );

=cut

sub TranslationLanguageAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(PatternID Value Language UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    $Param{IsDefault} = $Param{IsDefault} || 0;

    # check if the PatternID exists
    my %Pattern = $Self->PatternGet(
        ID => $Param{PatternID},
    );
    if ( !%Pattern ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "PatternID $Param{PatternID} doesn't exist!"
        );
        return;
    }

    # check if the translation already exists
    my %TranslationLanguage = $Self->TranslationLanguageGet(
        PatternID => $Param{PatternID},
        Language  => $Param{Language},
    );
    if ( %TranslationLanguage ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "This translation language already exists!"
        );
        return;
    }

    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => 'INSERT INTO kix_translation_language '
            . '(value, language, is_default, pattern_id, create_time, create_by, change_time, change_by) '
            . 'VALUES (?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$Param{Value}, \$Param{Language}, \$Param{IsDefault},
            \$Param{PatternID}, \$Param{UserID}, \$Param{UserID}
        ],
    );

    # reset cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
        Event    => 'CREATE',
        Object   => 'Translation.Language',
        ObjectID => $Param{PatternID}.'::'.$Param{Language},
    );

    return 1;
}

=item TranslationLanguageGet()

get translation language

    my %Translation = $TranslationObject->TranslationLanguageGet(
        PatternID => 123            # required
        Language  => '...'          # required
    );

=cut

sub TranslationLanguageGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(PatternID Language)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # check cache
    my $CacheKey = "TranslationLanguageGet::$Param{PatternID}::$Param{Language}";
    my $Cache    = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL  => 'SELECT pattern_id, language, value, is_default, create_time, create_by, change_time, change_by FROM kix_translation_language WHERE pattern_id = ? AND language = ?',
        Bind => [ \$Param{PatternID}, \$Param{Language} ] 
    );

    # fetch the result
    my %TranslationLanguage;
    while (my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray()) {
        $TranslationLanguage{PatternID}  = $Row[0];
        $TranslationLanguage{Language}   = $Row[1];
        $TranslationLanguage{Value}      = $Row[2];
        $TranslationLanguage{IsDefault}  = $Row[3];
        $TranslationLanguage{CreateTime} = $Row[4];
        $TranslationLanguage{CreateBy}   = $Row[5];
        $TranslationLanguage{ChangeTime} = $Row[6];
        $TranslationLanguage{ChangeBy}   = $Row[7];
    }

    # set cache
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%TranslationLanguage,
    );

    return %TranslationLanguage;
}

=item TranslationLanguageList()

get list of translation languages for a given PatternID

    my %List = $TranslationObject->TranslationLanguageList(
        PatternID => 123           # required
    );

=cut

sub TranslationLanguageList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(PatternID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # check cache
    my $CacheKey = "TranslationLanguageList::$Param{PatternID}";
    my $Cache    = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL => 'SELECT language, value FROM kix_translation_language WHERE pattern_id = ?',
        Bind  => [ \$Param{PatternID} ],
    );

    # fetch the result
    my %TranslationLanguageList;
    while (my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray()) {
        $TranslationLanguageList{ $Row[0] } = $Row[1];
    }

    # set cache
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%TranslationLanguageList,
    );

    return %TranslationLanguageList;
}

=item TranslationLanguageUpdate()

Update an existing translation language entry

    my $Success = $TranslationObject->TranslationLanguageUpdate(
        PatternID => 123           # required
        Language  => '...'         # required
        Value     => '...',        # optional
        IsDefault => 0|1,          # optional
        UserID    => '...',        # required
    );

=cut

sub TranslationLanguageUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(PatternID Language UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # check if the ID exists
    my %Translation = $Self->TranslationLanguageGet(
        PatternID => $Param{PatternID},
        Language  => $Param{Language}
    );
    if ( !%Translation ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Translation language $Param{Language} doesn't exist for given pattern!"
        );
        return;
    }

    $Param{IsDefault} = $Param{IsDefault} || 0;

    # sql
    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => 'UPDATE kix_translation_language SET value = ?, is_default = ?, change_time = current_timestamp, change_by = ? WHERE pattern_id = ? AND language = ?',
        Bind => [
            \$Param{Value}, \$Param{IsDefault}, \$Param{UserID}, 
            \$Param{PatternID}, \$Param{Language}
        ],
    );

    # reset cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
        Event    => 'UPDATE',
        Object   => 'Translation.Language',
        ObjectID => $Param{PatternID}.'::'.$Param{Language},
    );

    return 1;
}

=item TranslationLanguageDelete()

Deletes an existing translation language entry

    my $ID = $TranslationObject->TranslationLanguageDelete(
        PatternID  => 123,          # required
        Language   => '...'         # required
    );

=cut

sub TranslationLanguageDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(PatternID Language)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => 'DELETE FROM kix_translation_language WHERE pattern_id = ? AND language = ?',
        Bind => [ \$Param{PatternID}, \$Param{Language} ],
    );

    # reset cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
        Event    => 'DELETE',
        Object   => 'Translation.Language',
        ObjectID => $Param{PatternID}.'::'.$Param{Language},
    );

    return 1;
}

=item ImportPO()

Import a PO content

    my $Result = $TranslationObject->ImportPO(
        Language => '...'         # required
        File     => '...',        # required if Content is not given
        Content  => '...',        # required if File is not given
        UserID   => 123           # required
    );

=cut

sub ImportPO {
    my ( $Self, %Param ) = @_;
    my $CountTotal = 0;
    my $CountOK = 0;

    # check needed stuff
    for (qw(Language)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    if ( !$Param{File} && !$Param{Content} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need File or Content!"
        );
        return;
    }

    if ( $Param{File} && $Param{Content} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need File OR Content, not both!"
        );
        return;
    }

    if ( $Param{Content} ) {
        # store content in temp file
        my ($FH, $Filename) = $Kernel::OM->Get('Kernel::System::FileTemp')->TempFile(
            Suffix => '.po'
        );

        if ( !$Filename ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Unable to create temporary file!"
            );
            return;
        }

        my $Result = $Kernel::OM->Get('Kernel::System::Main')->FileWrite(
            Location => $Filename,
            Content  => \$Param{Content}
        );

        if ( !$Result ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Unable to write content to temporary file!"
            );
            return;
        }

        $Param{File} = $Filename;
    }

    my $Items;
    {
        $DisableWarnings = 1;
        $Items = Locale::PO->load_file_ashash($Param{File});
        $DisableWarnings = 0;
    }

    if ( IsHashRefWithData($Items) ) {        
        my $EncodeObject = $Kernel::OM->Get('Kernel::System::Encode');

        foreach my $MsgId ( sort keys %{$Items} ) {
            $CountTotal++;

            my $MsgStr = $EncodeObject->EncodeInput($Items->{$MsgId}->msgstr);
            $MsgId =~ s/"//g;
            $MsgStr =~ s/"//g;

            # the pattern is empty, go to the next one
            next if !$MsgId;

            my $PatternID = $Self->PatternExistsCheck(
                Value => $MsgId,
            );

            if ( !$PatternID ) {
                # create new pattern entry
                $PatternID = $Self->PatternAdd(
                    Value  => $MsgId,
                    UserID => $Param{UserID},
                );
                if ( !$PatternID ) {
                    $Kernel::OM->Get('Kernel::System::Log')->Log(
                        Priority => 'error',
                        Message  => "Unable to add translation pattern !"
                    );
                    next;
                }
            }

            # we don't have a translation for this language so go to the next pattern
            next if !$MsgStr;

            # create or update language translation
            my %Translation = $Self->TranslationLanguageGet(
                PatternID => $PatternID,
                Language  => $Param{Language},
            );

            if ( %Translation ) {
                # update existing translation but only if it is still the default
                if ( $Translation{IsDefault} ) {
                    my $Result = $Self->TranslationLanguageUpdate(
                        PatternID => $PatternID,
                        Language  => $Param{Language},
                        Value     => $MsgStr,
                        IsDefault => 1,
                        UserID    => $Param{UserID},
                    );
                    if ( !$Result ) {
                        $Kernel::OM->Get('Kernel::System::Log')->Log(
                            Priority => 'error',
                            Message  => "Unable to update translation language '$Param{Language}' for PatternID $PatternID!"
                        );
                    }
                }
            }
            else {
                # create a new one
                my $Result = $Self->TranslationLanguageAdd(
                    PatternID => $PatternID,
                    Language  => $Param{Language},
                    Value     => $MsgStr,
                    IsDefault => 1,
                    UserID    => $Param{UserID},
                );
                if ( !$Result ) {
                    $Kernel::OM->Get('Kernel::System::Log')->Log(
                        Priority => 'error',
                        Message  => "Unable to create translation language '$Param{Language}' for PatternID $PatternID!"
                    );
                }
            }

            $CountOK++;
        }
    }

    # reset cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    return ( $CountTotal, $CountOK );
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
