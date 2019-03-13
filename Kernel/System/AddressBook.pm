# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::AddressBook;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);
use vars qw(@ISA);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::CacheInternal',
    'Kernel::System::DB',
    'Kernel::System::Log',
);

=head1 NAME

Kernel::System::AddressBook

=head1 SYNOPSIS

Add address book functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create a AddressBook object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $AddressBookObject = $Kernel::OM->Get('Kernel::System::AddressBook');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get needed objects
    $Self->{ConfigObject} = $Kernel::OM->Get('Kernel::Config');
    $Self->{DBObject}     = $Kernel::OM->Get('Kernel::System::DB');
    $Self->{CacheObject}  = $Kernel::OM->Get('Kernel::System::Cache');
    $Self->{LogObject}    = $Kernel::OM->Get('Kernel::System::Log');
    $Self->{CacheType} = 'AddressBook';
    
    return $Self;
}

=item AddressGet()

Get a email address.

    my $Result = $AddressBookObject->AddressGet(
        AddressID      => '...',
    );

=cut

sub AddressGet {
    my ( $Self, %Param ) = @_;
    
    my %Result;

    # check required params...
    if ( !$Param{AddressID} ) {
        $Self->{LogObject}->Log( 
            Priority => 'error', 
            Message  => 'DeleteAddress: Need AddressID!' );
        return;
    }
   
    # check cache
    my $CacheKey = 'AddressGet::' . $Param{AddressID};
    my $Cache    = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;
    
    return if !$Self->{DBObject}->Prepare( 
        SQL   => "SELECT id, email FROM addressbook WHERE id = ?",
        Bind => [ \$Param{AddressID} ],
        Limit => 50, 
    );

    my %Data;
    
    # fetch the result
    while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        %Data = (
            AddressID    => $Data[0],
            EmailAddress => $Data[1],
        );
    }
    
    # no data found...
    if ( !%Data ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "AddressBook '$Param{AddressID}' not found!",
        );
        return;
    }
    
    # set cache
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Data,
    ); 
       
    return %Data;   

}


=item AddressAdd()

Adds a new email address

    my $Result = $AddressBookObject->AddressAdd(
        EmailAddress => 'some email address',
    );

=cut

sub AddressAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(EmailAddress)) {
        if ( !defined( $Param{$_} ) ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    my $EmailLower = lc($Param{EmailAddress});
  
    # do the db insert...
    my $DBInsert = $Self->{DBObject}->Do(
        SQL  => "INSERT INTO addressbook (email, email_lower) VALUES (?, ?)",
        Bind => [
            \$Param{EmailAddress},
            \$EmailLower
        ],
    );

    #handle the insert result...
    if ($DBInsert) {

        # delete cache
        $Self->{CacheObject}->CleanUp(
            Type => $Self->{CacheType}
        );

        return 0 if !$Self->{DBObject}->Prepare(
            SQL  => 'SELECT max(id) FROM addressbook WHERE email = ?',
            Bind => [ 
                \$Param{EmailAddress}
            ],
        );

        my $ID;
        while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
            $ID = $Row[0];
        }

        # push client callback event
        $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
            Event    => 'CREATE',
            Object   => 'AddressBook',
            ObjectID => $ID,
        );

        return $ID;
    }
    else {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "AddAddress::DB insert failed!",
        );
    }

    return 0;
}

sub AddressUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(AddressID EmailAddress)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }
    
    my $EmailLower = $Param{EmailAddress};

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # update address in database
    return if !$DBObject->Do(
        SQL => 'UPDATE addressbook SET email = ?, email_lower = ? WHERE id = ?',
        Bind => [
            \$Param{EmailAddress}, \$EmailLower, \$Param{AddressID},
        ],
    );

    # delete cache
    $Self->{CacheObject}->CleanUp(
        Type => $Self->{CacheType}
    );

    # push client callback event
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
        Event    => 'UPDATE',
        Object   => 'AddressBook',
        ObjectID => $Param{AddressID},
    );

    return 1;
}

=item Empty()

Deletes all entries.

    my $Result = $AddressBookObject->Empty();

=cut

sub Empty {
    my ( $Self, %Param ) = @_;

    # delete cache
    $Self->{CacheObject}->CleanUp(
        Type => $Self->{CacheType}
    );

    return if !$Self->{DBObject}->Do(
        SQL  => 'DELETE FROM addressbook',
    );

    # push client callback event
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
        Event    => 'DELETE',
        Object   => 'AddressBook',
    );

    return 1
}

=item AddressList()

Returns all (matching) email address entries

    my %Hash = $AddressBookObject->AddressList(
        Search => '...'             # optional
        Limit  => 123               # optional
        SearchCaseSensitive => 0|1  # optional
    );

=cut

sub AddressList {
    my ( $Self, %Param ) = @_;
    my $WHEREClauseExt = '';
    my %Result;

    # check cache
    my $CacheTTL = 60 * 60 * 24 * 30;   # 30 days
    my $CacheKey = 'AddressList::'.$Param{Search};
    my $CacheResult = $Self->{CacheObject}->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey
    );
    return %{$CacheResult} if (IsHashRefWithData($CacheResult));
  
    if ( $Param{Search} ) {
        my $Email = $Param{Search};
        $Email =~ s/\*/%/g;
        if ($Param{SearchCaseSensitive}) {
            $WHEREClauseExt .= " AND email like \'$Email\'";
        }
        else {
            $WHEREClauseExt .= " AND email_lower like \'".lc($Email)."\'";
        }
    }

    my $SQL = "SELECT id, email FROM addressbook WHERE 1=1";

    return if !$Self->{DBObject}->Prepare( 
        SQL   => $SQL . $WHEREClauseExt . " ORDER by email",
        Limit => $Param{Limit}, 
    );

    my $Count = 0;
    while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        $Result{ $Data[0] } = $Data[1];
    }

    # set cache
    $Self->{CacheObject}->Set(
        Type           => $Self->{CacheType},
        Key            => $CacheKey,
        Value          => \%Result,
        TTL            => $CacheTTL,
    );

    return %Result;
}

=item AddressDelete()

Delete a email addresses.

    my $Result = $AddressBookObject->AddressDelete(
        AddressID      => '...',
    );

=cut

sub AddressDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(AddressID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');
    return if !$DBObject->Prepare(
        SQL  => 'DELETE FROM addressbook WHERE id = ?',
        Bind => [ \$Param{AddressID} ],
    );

    # delete cache
    $Self->{CacheObject}->CleanUp(
        Type => $Self->{CacheType}
    );

    # push client callback event
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
        Event    => 'UPDATE',
        Object   => 'AddressBook',
        ObjectID => $Param{AddressID},
    );

    return 1;
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
