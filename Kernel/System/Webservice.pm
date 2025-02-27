# --
# Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Webservice;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Config',
    'Cache',
    'DB',
    'Log',
    'Main',
    'Time',
    'Valid',
    'YAML',
);

=head1 NAME

Kernel::System::Webservice

=head1 SYNOPSIS

Webservice configuration backend.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $WebserviceObject = $Kernel::OM->Get('Webservice');

=cut

sub new {
    my ( $Webservice, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Webservice );

    return $Self;
}

=item WebserviceAdd()

add new Webservices

returns id of new webservice if successful or undef otherwise

    my $ID = $WebserviceObject->WebserviceAdd(
        Name    => 'some name',
        Config  => $ConfigHashRef,
        ValidID => 1,
        UserID  => 123,
    );

=cut

sub WebserviceAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Key (qw(Name Config ValidID UserID)) {
        if ( !$Param{$Key} ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Key!"
                );
            }
            return;
        }
    }

    # check config
    if ( !IsHashRefWithData( $Param{Config} ) ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Webservice Config should be a non empty hash reference!",
            );
        }
        return;
    }

    # check config internals
    if ( !defined $Param{Config}->{Provider} ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Webservice Config Provider should be defined!",
            );
        }
        return;
    }
    if ( defined $Param{Config}->{Provider} ) {
        if ( !IsHashRefWithData( $Param{Config}->{Provider} ) ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Webservice Config Provider should be a non empty hash reference!",
                );
            }
            return;
        }
        if ( !IsHashRefWithData( $Param{Config}->{Provider}->{Transport} ) ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Webservice Config Provider Transport should be a non empty hash reference!",
                );
            }
            return;
        }
    }

    # dump config as string
    my $Config = $Kernel::OM->Get('YAML')->Dump( Data => $Param{Config} );

    # md5 of content
    my $MD5 = $Kernel::OM->Get('Main')->MD5sum(
        String => $Param{Name},
    );

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # sql
    return if !$DBObject->Do(
        SQL =>
            'INSERT INTO api_webservice_config (name, config, config_md5, valid_id, '
            . ' create_time, create_by, change_time, change_by)'
            . ' VALUES (?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$Param{Name}, \$Config, \$MD5, \$Param{ValidID},
            \$Param{UserID}, \$Param{UserID},
        ],
    );

    return if !$DBObject->Prepare(
        SQL  => 'SELECT id FROM api_webservice_config WHERE config_md5 = ?',
        Bind => [ \$MD5 ],
    );

    my $ID;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ID = $Row[0];
    }

    # delete cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => 'Webservice',
    );

    return $ID;
}

=item WebserviceLookup()

get id for webservice name

    my $WebserviceID = $WebserviceObject->WebserviceLookup(
        Name => '...',
    );

get name for webservice id

    my $WebserviceName = $WebserviceObject->WebserviceLookup(
        ID => '...',
    );

=cut

sub WebserviceLookup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Name} && !$Param{ID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Got no Name or ID!',
        );
        return;
    }

    # get webservice list
    my $WebserviceList = $Self->WebserviceList(
        Valid => 0,
    );

    return $WebserviceList->{ $Param{ID} } if $Param{ID};

    # create reverse list
    my %WebserviceListReverse = reverse %{$WebserviceList};

    return $WebserviceListReverse{ $Param{Name} };
}

=item WebserviceGet()

get Webservices attributes

    my $Webservice = $WebserviceObject->WebserviceGet(
        ID   => 123,            # ID or Name must be provided
        Name => 'MyWebservice',
    );

Returns:

    $Webservice = {
        ID         => 123,
        Name       => 'some name',
        Config     => $ConfigHashRef,
        ValidID    => 123,
        CreateTime => '2011-02-08 15:08:00',
        ChangeTime => '2011-02-08 15:08:00',
    };

=cut

sub WebserviceGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ID} && !$Param{Name} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need ID or Name!'
        );
        return;
    }

    # get cache object
    my $CacheObject = $Kernel::OM->Get('Cache');

    # check cache
    my $CacheKey;
    if ( $Param{ID} ) {
        $CacheKey = 'WebserviceGet::ID::' . $Param{ID};
    }
    else {
        $CacheKey = 'WebserviceGet::Name::' . $Param{Name};

    }
    my $Cache = $CacheObject->Get(
        Type => 'Webservice',
        Key  => $CacheKey,
    );
    return $Cache if $Cache;

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # sql
    if ( $Param{ID} ) {
        return if !$DBObject->Prepare(
            SQL => 'SELECT id, name, config, valid_id, create_time, change_time '
                . 'FROM api_webservice_config WHERE id = ?',
            Bind  => [ \$Param{ID} ],
            Limit => 1,
        );
    }
    else {
        return if !$DBObject->Prepare(
            SQL => 'SELECT id, name, config, valid_id, create_time, change_time '
                . 'FROM api_webservice_config WHERE name = ?',
            Bind  => [ \$Param{Name} ],
            Limit => 1,
        );
    }

    # get yaml object
    my $YAMLObject = $Kernel::OM->Get('YAML');

    my %Data;
    while ( my @Data = $DBObject->FetchrowArray() ) {

        my $Config = $YAMLObject->Load( Data => $Data[2] );

        %Data = (
            ID         => $Data[0],
            Name       => $Data[1],
            Config     => $Config,
            ValidID    => $Data[3],
            CreateTime => $Data[4],
            ChangeTime => $Data[5],
        );
    }

    # get the cache TTL (in seconds)
    my $CacheTTL = int(
        $Kernel::OM->Get('Config')->Get('WebserviceConfig::CacheTTL')
            || 3600
    );

    # set cache
    $CacheObject->Set(
        Type  => 'Webservice',
        Key   => $CacheKey,
        Value => \%Data,
        TTL   => $CacheTTL,
    );

    return \%Data;
}

=item WebserviceUpdate()

update Webservice attributes

returns 1 if successful or undef otherwise

    my $Success = $WebserviceObject->WebserviceUpdate(
        ID      => 123,
        Name    => 'some name',
        Config  => $ConfigHashRef,
        ValidID => 1,
        UserID  => 123,
    );

=cut

sub WebserviceUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Key (qw(ID Name Config ValidID UserID)) {
        if ( !$Param{$Key} ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Need $Key!"
                );
            }
            return;
        }
    }

    # check config
    if ( !IsHashRefWithData( $Param{Config} ) ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Webservice Config should be a non empty hash reference!",
            );
        }
        return;
    }

    # check config internals
    if ( !defined $Param{Config}->{Provider} ) {
        if ( !$Param{Silent} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Webservice Config Provider should be defined!",
            );
        }
        return;
    }
    if ( defined $Param{Config}->{Provider} ) {
        if ( !IsHashRefWithData( $Param{Config}->{Provider} ) ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Webservice Config Provider should be a non empty hash"
                        . " reference!",
                );
            }
            return;
        }
        if ( !IsHashRefWithData( $Param{Config}->{Provider}->{Transport} ) ) {
            if ( !$Param{Silent} ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Webservice Config Provider Transport should be a"
                        . " non empty hash reference!",
                );
            }
            return;
        }
    }

    # dump config as string
    my $Config = $Kernel::OM->Get('YAML')->Dump( Data => $Param{Config} );

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    # check if config and valid_id is the same
    return if !$DBObject->Prepare(
        SQL   => 'SELECT config, valid_id, name FROM api_webservice_config WHERE id = ?',
        Bind  => [ \$Param{ID} ],
        Limit => 1,
    );

    my $ConfigCurrent;
    my $ValidIDCurrent;
    my $NameCurrent;
    while ( my @Data = $DBObject->FetchrowArray() ) {
        $ConfigCurrent  = $Data[0];
        $ValidIDCurrent = $Data[1];
        $NameCurrent    = $Data[2];
    }

    return 1 if $ValidIDCurrent eq $Param{ValidID}
        && $Config eq $ConfigCurrent
        && $NameCurrent eq $Param{Name};

    # sql
    return if !$DBObject->Do(
        SQL => 'UPDATE api_webservice_config SET name = ?, config = ?, '
            . ' valid_id = ?, change_time = current_timestamp, '
            . ' change_by = ? WHERE id = ?',
        Bind => [
            \$Param{Name}, \$Config, \$Param{ValidID}, \$Param{UserID},
            \$Param{ID},
        ],
    );

    # delete cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => 'Webservice',
    );

    return 1;
}

=item WebserviceDelete()

delete a Webservice

returns 1 if successful or undef otherwise

    my $Success = $WebserviceObject->WebserviceDelete(
        ID      => 123,
        UserID  => 123,
    );

=cut

sub WebserviceDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Key (qw(ID UserID)) {
        if ( !$Param{$Key} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Key!"
            );
            return;
        }
    }

    # check if exists
    my $Webservice = $Self->WebserviceGet(
        ID => $Param{ID},
    );
    return if !IsHashRefWithData($Webservice);

    # delete web service
    return if !$Kernel::OM->Get('DB')->Do(
        SQL  => 'DELETE FROM api_webservice_config WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );

    # delete cache
    $Kernel::OM->Get('Cache')->CleanUp(
        Type => 'Webservice',
    );

    return 1;
}

=item WebserviceList()

get Webservice list

    my $List = $WebserviceObject->WebserviceList();

    or

    my $List = $WebserviceObject->WebserviceList(
        Valid => 0, # optional, defaults to 1
    );

=cut

sub WebserviceList {
    my ( $Self, %Param ) = @_;

    # get cache object
    my $CacheObject = $Kernel::OM->Get('Cache');

    # check cache
    my $Valid = 1;
    if ( !$Param{Valid} ) {
        $Valid = '0';
    }
    my $CacheKey = 'WebserviceList::Valid::' . $Valid;
    my $Cache    = $CacheObject->Get(
        Type => 'Webservice',
        Key  => $CacheKey,
    );
    return $Cache if ref $Cache;

    my $SQL = 'SELECT id, name FROM api_webservice_config';

    if ( !defined $Param{Valid} || $Param{Valid} eq 1 ) {

        # get valid object
        my $ValidObject = $Kernel::OM->Get('Valid');

        $SQL .= ' WHERE valid_id IN (' . join ', ', $ValidObject->ValidIDsGet() . ')';
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('DB');

    return if !$DBObject->Prepare( SQL => $SQL );

    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Data{ $Row[0] } = $Row[1];
    }

    # get the cache TTL (in seconds)
    my $CacheTTL = int(
        $Kernel::OM->Get('Config')->Get('WebserviceConfig::CacheTTL')
            || 3600
    );

    # set cache
    $CacheObject->Set(
        Type  => 'Webservice',
        Key   => $CacheKey,
        Value => \%Data,
        TTL   => $CacheTTL,
    );

    return \%Data;
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
