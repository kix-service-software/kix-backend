# --
# Copyright (C) 2006-2023 KIX Service Software GmbH, https://www.kixdesk.com 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Translation;

use strict;
use warnings;

use Locale::PO;
use Digest::MD5 qw(md5_hex);

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = qw(
    ClientRegistration
    Config
    DB
    Log
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
        ID => 123                            # required
        IncludeAvailableLanguages => 0|1     # optional
    );

or

    my @PatterList = $TranslationObject->PatternGet(
        ID => [ 123, 124, 125 ]              # required
        IncludeAvailableLanguages => 0|1     # optional
    );

=cut

sub PatternGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    if ( IsArrayRefWithData($Param{ID}) ) {
        # get multiple
        my $Result = $Self->_PatternGet(
            IDs                       => $Param{ID},
            IncludeAvailableLanguages => $Param{IncludeAvailableLanguages} || 0,
        );
        return IsArrayRefWithData($Result) ? @{$Result} : ();
    }
    else {
        # get single
        my $Result = $Self->_PatternGet(
            IDs                       => [ $Param{ID} ],
            IncludeAvailableLanguages => $Param{IncludeAvailableLanguages} || 0,
        );
        return IsArrayRefWithData($Result) ? %{$Result->[0]} : ();
    }
}

sub _PatternGet {
    my ( $Self, %Param ) = @_;

    if ( !IsArrayRefWithData($Param{IDs}) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need IDs!"
        );
        return;
    }

    my $IDStrg = join(',', @{$Param{IDs}});

    # check cache
    my $CacheKey = "PatternGet::" . $IDStrg . "::" . $Param{IncludeAvailableLanguages};
    my $Cache    = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return $Cache if $Cache;

    my @BindRefList = map { \$_ } @{$Param{IDs}};

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => 'SELECT id, value, create_time, create_by, change_time, change_by FROM translation_pattern WHERE id IN ('.(join( ',', map { '?' } @{$Param{IDs}})).')',
        Bind => \@BindRefList
    );

    # fetch the result
    my $Result = $Kernel::OM->Get('DB')->FetchAllArrayRef(
        Columns => [ 'ID', 'Value', 'CreateTime', 'CreateBy', 'ChangeTime', 'ChangeBy' ],
    );

    if ( !IsArrayRefWithData($Result) ) {
        return;
    }

    # add array of available languages if requests
    if ( $Param{IncludeAvailableLanguages} ) {
        my @BindRefList = map { \$_->{ID} } @{$Result};
        return if !$Kernel::OM->Get('DB')->Prepare(
            SQL  => 'SELECT pattern_id, language FROM translation_language WHERE pattern_id IN ('.(join( ',', map { '?' } @{$Result})).') ORDER by language',
            Bind => \@BindRefList
        );
        # fetch the result
        my $LanguageData = $Kernel::OM->Get('DB')->FetchAllArrayRef(
            Columns => [ 'PatternID', 'Language' ],
        );

        foreach my $Pattern ( @{$Result} ) {
            $Pattern->{AvailableLanguages} = [];
            next if !IsArrayRefWithData($LanguageData);

            my @AvailableLanguages;
            foreach my $Language ( @{$LanguageData} ) {
                next if $Language->{PatternID} != $Pattern->{ID};

                if ( ref $Pattern->{AvailableLanguages} eq 'ARRAY' ) {
                    $Pattern->{AvailableLanguages} = [];
                }

                push(@AvailableLanguages, $Language->{Language});
            }
            $Pattern->{AvailableLanguages} = \@AvailableLanguages;
        }
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => $Result,
    );

    return $Result;
}

=item PatternList()

get Pattern list

    my %List = $TranslationObject->PatternList();

=cut

sub PatternList {
    my ( $Self, %Param ) = @_;
    my %PatternList;

    # check cache
    my $CacheKey = "PatternList";
    my $Cache    = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL => 'SELECT id, value FROM translation_pattern'
    );

    # fetch the result
    my $Data = $Kernel::OM->Get('DB')->FetchAllArrayRef(
        Columns => [ 'ID', 'Value' ],
    );

    # data found...
    if ( IsArrayRefWithData($Data) ) {

        # prepare the result
        foreach my $Row ( @{$Data} ) {
            $PatternList{ $Row->{ID} } = $Row->{Value};
        }

        # set cache
        $Kernel::OM->Get('Cache')->Set(
            Type  => $Self->{CacheType},
            TTL   => $Self->{CacheTTL},
            Key   => $CacheKey,
            Value => \%PatternList,
        );
    }

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
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # check cache
    my $CacheKey = "PatternExistsCheck::$Param{Value}";
    my $Cache    = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return $Cache if $Cache;

    # generate MD5 sum of value
    my $MD5 = Digest::MD5::md5_hex($Param{Value});

    $Kernel::OM->Get('DB')->Prepare(
        SQL  => 'SELECT id FROM translation_pattern WHERE value_md5= ?',
        Bind => [ \$MD5 ]
    );

    # fetch the result
    my $PatternID;
    while (my @Row = $Kernel::OM->Get('DB')->FetchrowArray()) {
        $PatternID = $Row[0];
    }

    if ( $PatternID ) {
        # set cache
        $Kernel::OM->Get('Cache')->Set(
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
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $_!"
                );
            }
            return;
        }
    }

    # check if the Pattern already exists
    my $ID = $Self->PatternExistsCheck(
        Value => $Param{Value}
    );
    if ( $ID ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "An identical pattern already exists!"
            );
        }
        return;
    }

    # generate MD5 sum of value
    my $MD5 = Digest::MD5::md5_hex($Param{Value});

    # sql
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'INSERT INTO translation_pattern '
            . '(value, value_md5, create_time, create_by, change_time, change_by) '
            . 'VALUES (?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$Param{Value}, \$MD5, \$Param{UserID}, \$Param{UserID}
        ],
    );

    # get new Pattern id
    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL   => 'SELECT id FROM translation_pattern WHERE value_md5= ?',
        Bind  => [ \$MD5 ],
        Limit => 1,
    );

    # fetch the result
    while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
        $ID = $Row[0];
    }
    return if !$ID;

    # reset cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'Translation.Pattern',
        ObjectID  => $ID,
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
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $_!"
                );
            }
            return;
        }
    }

    # check if the Pattern already exists
    my $ID = $Self->PatternExistsCheck(
        Value => $Param{Value}
    );
    if ( $ID && $ID != $Param{ID} ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "An identical Pattern already exists!"
            );
        }
        return;
    }

    # generate MD5 sum of value
    my $MD5 = Digest::MD5::md5_hex($Param{Value});

    # sql
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'UPDATE translation_pattern SET value = ?, value_md5= ?, change_time = current_timestamp, change_by = ? WHERE id = ?',
        Bind => [
            \$Param{Value}, \$MD5, \$Param{UserID}, \$Param{ID}
        ],
    );

    # reset cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Translation.Pattern',
        ObjectID  => $Param{ID},
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
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # delete assigned languages
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'DELETE FROM translation_language WHERE pattern_id = ?',
        Bind => [ \$Param{ID} ],
    );

    # delete pattern
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'DELETE FROM translation_pattern WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );

    # reset cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'Translation.Pattern',
        ObjectID  => $Param{ID},
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
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $_!"
                );
            }
            return;
        }
    }

    $Param{IsDefault} = $Param{IsDefault} || 0;

    # check if the PatternID exists
    my %Pattern = $Self->PatternGet(
        ID => $Param{PatternID},
    );
    if ( !%Pattern ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "PatternID $Param{PatternID} doesn't exist!"
            );
        }
        return;
    }

    # check if the translation already exists
    my %TranslationLanguage = $Self->TranslationLanguageGet(
        PatternID => $Param{PatternID},
        Language  => $Param{Language},
    );
    if ( %TranslationLanguage ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "This translation language already exists!"
            );
        }
        return;
    }

    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'INSERT INTO translation_language '
            . '(value, language, is_default, pattern_id, create_time, create_by, change_time, change_by) '
            . 'VALUES (?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$Param{Value}, \$Param{Language}, \$Param{IsDefault},
            \$Param{PatternID}, \$Param{UserID}, \$Param{UserID}
        ],
    );

    # reset cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'Translation.Language',
        ObjectID  => $Param{PatternID}.'::'.$Param{Language},
    );

    return 1;
}

=item TranslationLanguageGet()

get translation language

    my %Translation = $TranslationObject->TranslationLanguageGet(
        PatternID => 123            # required
        Language  => '...'          # required
    );

or

    my @Translation = $TranslationObject->TranslationLanguageGet(
        PatternID => [ 123, 124, 125 ]      # required
        Language  => '...'                  # required
    );

=cut

sub TranslationLanguageGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(PatternID Language)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    if ( IsArrayRefWithData($Param{PatternID}) ) {
        # get multiple
        my $Result = $Self->_TranslationLanguageGet(
            PatternIDs => $Param{PatternID},
            Language   => $Param{Language},
        );
        return @{$Result};
    }
    else {
        # get single
        my $Result = $Self->_TranslationLanguageGet(
            PatternIDs => [ $Param{PatternID} ],
            Language   => $Param{Language},
        );
        return IsArrayRefWithData($Result) ? %{$Result->[0]} : ();
    }
}

sub _TranslationLanguageGet {
    my ( $Self, %Param ) = @_;

    if ( !IsArrayRefWithData($Param{PatternIDs}) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need IDs!"
        );
        return;
    }

    my $IDStrg = join(',', @{$Param{PatternIDs}});

    # check cache
    my $CacheKey = "TranslationLanguageGet::" . ($IDStrg || '') . "::$Param{Language}";
    my $Cache    = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return $Cache if $Cache;

    my @BindRefList = map { \$_ } ( $Param{Language}, @{$Param{PatternIDs}} );

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL  => 'SELECT pattern_id, language, value, is_default, create_time, create_by, change_time, change_by FROM translation_language WHERE language = ? AND pattern_id IN ('.(join( ',', map { '?' } @{$Param{PatternIDs}})).')',
        Bind => \@BindRefList
    );

    # fetch the result
    my $Result = $Kernel::OM->Get('DB')->FetchAllArrayRef(
        Columns => [ 'PatternID', 'Language', 'Value', 'IsDefault', 'CreateTime', 'CreateBy', 'ChangeTime', 'ChangeBy' ],
    );

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => $Result,
    );

    return $Result;
}

=item TranslationLanguageList()

get list of translation languages for a given PatternID

    my %List = $TranslationObject->TranslationLanguageList(
        PatternID => 123           # required
    );

or

    my @List = $TranslationObject->TranslationLanguageList(
        PatternID => [ 123, 124, 125 ]          # required
    );

=cut

sub TranslationLanguageList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(PatternID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    if ( IsArrayRefWithData($Param{PatternID}) ) {
        # get multiple
        my $Result = $Self->_TranslationLanguageList(
            PatternIDs => $Param{PatternID}
        );
        return @{$Result};
    }
    else {
        # get single
        my $Result = $Self->_TranslationLanguageList(
            PatternIDs => [ $Param{PatternID} ]
        );
        return IsArrayRefWithData($Result) ? %{$Result->[0]} : ();
    }
}

sub _TranslationLanguageList {
    my ( $Self, %Param ) = @_;

    if ( !IsArrayRefWithData($Param{PatternIDs}) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need PatternIDs!"
        );
        return;
    }

    my $IDStrg = join(',', @{$Param{PatternIDs}});

    # check cache
    my $CacheKey = "TranslationLanguageList::$IDStrg";
    my $Cache    = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return $Cache if $Cache;

    my @BindRefList = map { \$_ } ( @{$Param{PatternIDs}} );

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL => 'SELECT pattern_id, language, value FROM translation_language WHERE pattern_id IN ('.(join( ',', map { '?' } @{$Param{PatternIDs}})).')',
        Bind  => \@BindRefList,
    );

    # fetch the result
    my $Data = $Kernel::OM->Get('DB')->FetchAllArrayRef(
        Columns => [ 'PatternID', 'Language', 'Value' ],
    );

    if ( !IsArrayRefWithData($Data) ) {
        return;
    }

    my @Result;
    foreach my $Row ( @{$Data} ) {
        push(@Result, {
            $Row->{Language} => $Row->{Value}
        });
    }

    # set cache
    $Kernel::OM->Get('Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \@Result,
    );

    return \@Result;
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
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $_!"
                );
            }
            return;
        }
    }

    # check if the ID exists
    my %Translation = $Self->TranslationLanguageGet(
        PatternID => $Param{PatternID},
        Language  => $Param{Language}
    );
    if ( !%Translation ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Translation language $Param{Language} doesn't exist for given pattern!"
            );
        }
        return;
    }

    $Param{IsDefault} = $Param{IsDefault} || 0;

    # sql
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'UPDATE translation_language SET value = ?, is_default = ?, change_time = current_timestamp, change_by = ? WHERE pattern_id = ? AND language = ?',
        Bind => [
            \$Param{Value}, \$Param{IsDefault}, \$Param{UserID},
            \$Param{PatternID}, \$Param{Language}
        ],
    );

    # reset cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'Translation.Language',
        ObjectID  => $Param{PatternID}.'::'.$Param{Language},
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
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'DELETE FROM translation_language WHERE pattern_id = ? AND language = ?',
        Bind => [ \$Param{PatternID}, \$Param{Language} ],
    );

    # reset cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'Translation.Language',
        ObjectID  => $Param{PatternID}.'::'.$Param{Language},
    );

    return 1;
}

=item TranslationList()

get the translation list

    my @List = $TranslationObject->TranslationList();

returns

    [
        {
            'Pattern'   => 'this is a pattern',
            'Languages' => {
                'de' => '...',
                'en' => '...'
            }
        },
        {
            ...
        }
    ]

=cut

sub TranslationList {
    my ( $Self, %Param ) = @_;
    my @TranslationList;

    # check cache
    my $CacheKey = "TranslationList";
    my $Cache    = $Kernel::OM->Get('Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return @{$Cache} if $Cache;

    return if !$Kernel::OM->Get('DB')->Prepare(
        SQL => 'SELECT tp.value, tl.language, tl.value FROM translation_pattern tp, translation_language tl WHERE tl.pattern_id = tp.id ORDER BY tp.value'
    );

    # fetch the result
    my $Data = $Kernel::OM->Get('DB')->FetchAllArrayRef(
        Columns => [ 'Pattern', 'Language', 'Value' ],
    );

    # data found...
    if ( IsArrayRefWithData($Data) ) {
        # prepare the result
        my %Result;
        foreach my $Row ( @{$Data} ) {
            $Result{$Row->{Pattern}}->{Pattern} = $Row->{Pattern};
            $Result{$Row->{Pattern}}->{Languages}->{$Row->{Language}} = $Row->{Value};
        }

        @TranslationList = values %Result;

        # set cache
        $Kernel::OM->Get('Cache')->Set(
            Type  => $Self->{CacheType},
            TTL   => $Self->{CacheTTL},
            Key   => $CacheKey,
            Value => \@TranslationList,
        );
    }

    return @TranslationList;
}

=item CleanUp()

    Deletes all entries

    my $Success = $TranslationObject->CleanUp(
        UserID => '...',       # required
    );

=cut

sub CleanUp {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # delete languages
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'DELETE FROM translation_language',
    );

    # delete patterns
    return if !$Kernel::OM->Get('DB')->Do(
        SQL => 'DELETE FROM translation_pattern',
    );

    # reset cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    # push client callback event
    $Kernel::OM->Get('ClientNotification')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'Translation.Pattern',
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
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    if ( !$Param{File} && !$Param{Content} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need File or Content!"
        );
        return;
    }

    if ( $Param{File} && $Param{Content} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need File OR Content, not both!"
        );
        return;
    }

    if ( $Param{Content} ) {
        # store content in temp file
        my ($FH, $Filename) = $Kernel::OM->Get('FileTemp')->TempFile(
            Suffix => '.po'
        );

        if ( !$Filename ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Unable to create temporary file!"
            );
            return;
        }

        # set UTF8 flag
        $Kernel::OM->Get('Encode')->EncodeInput(
            \$Param{Content}
        );

        my $Result = $Kernel::OM->Get('Main')->FileWrite(
            Location  => $Filename,
            Content   => \$Param{Content},
            Mode      => 'binmode'
        );

        if ( !$Result ) {
            $Kernel::OM->Get('Log')->Log(
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
        my $EncodeObject = $Kernel::OM->Get('Encode');

        foreach my $MsgId ( sort keys %{$Items} ) {
            $CountTotal++;

            # the pattern is obsolete, go to the next one
            next if $Items->{$MsgId}->obsolete;

            my $MsgStr = $EncodeObject->EncodeInput($Items->{$MsgId}->msgstr);
            $MsgId =~ s/(?<!\\)"//g;
            $MsgId =~ s/\\"/"/g;
            if ($MsgStr) {
                $MsgStr =~ s/(?<!\\)"//g;
                $MsgStr =~ s/\\"/"/g;
            }

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
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => "Unable to add translation pattern for $MsgId!"
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
                        $Kernel::OM->Get('Log')->Log(
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
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => "Unable to create translation language '$Param{Language}' for PatternID $PatternID!"
                    );
                }
            }

            $CountOK++;
        }
    }

    # reset cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => $Self->{CacheType},
    );

    return ( $CountTotal, $CountOK );
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
