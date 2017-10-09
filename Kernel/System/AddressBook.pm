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

    return $Self;
}

=item AddressGet()

Get a email address.

    my $Result = $AddressBookObject->AddressGet(
        ID      => '...',
    );

=cut

sub AddressGet {
    my ( $Self, %Param ) = @_;
    
    my %Result;

    # check required params...
    if ( !$Param{ID} ) {
        $Self->{LogObject}->Log( 
            Priority => 'error', 
            Message  => 'DeleteAddress: Need ID!' );
        return;
    }
   
    # check cache
    my $CacheKey = 'AddressGet::ID::' . $Param{ID};
    my $Cache    = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;
    
    return if !$Self->{DBObject}->Prepare( 
        SQL   => "SELECT id, email FROM addressbook WHERE id=$Param{ID}",
        Limit => 50, 
    );

    my $Count = 0;
    while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        $Result{ $Data[0] } = $Data[1];
    }

    return %Result;   

}


=item AddressAdd()

Adds a new email address

    my $Result = $AddressBookObject->AddressAdd(
        Email => 'some email address',
    );

=cut

sub AddressAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Email)) {
        if ( !defined( $Param{$_} ) ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    my $EmailLower = lc($Param{Email});
  
    # do the db insert...
    my $DBInsert = $Self->{DBObject}->Do(
        SQL  => "INSERT INTO addressbook (email, email_lower) VALUES (?, ?)",
        Bind => [
            \$Param{Email},
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
                \$Param{Email}
            ],
        );

        while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
            return $Row[0];
        }
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
    for my $Needed (qw(ID Email)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }
    
    my $EmailLower = $Param{Email};

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # update group in database
    return if !$DBObject->Do(
        SQL => 'UPDATE addressbook SET email = ?, email_lower = ? WHERE id = ?',
        Bind => [
            \$Param{Email}, \$EmailLower, \$Param{ID},
        ],
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

    return $Self->{DBObject}->Do(
        SQL  => 'DELETE FROM addressbook',
    );
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
        AddressBookID      => '...',
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

    # reset cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => $Self->{CacheType},
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
