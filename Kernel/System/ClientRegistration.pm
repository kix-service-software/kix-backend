# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ClientRegistration;

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

Kernel::System::ClientRegistration

=head1 SYNOPSIS

Add address book functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create a ClientRegistration object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $ClientRegistrationObject = $Kernel::OM->Get('Kernel::System::ClientRegistration');

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

    $Self->{CacheType} = 'ClientRegistration';
    
    return $Self;
}

=item ClientRegistrationGet()

Get a client registration.

    my $Result = $ClientRegistrationObject->ClientRegistrationGet(
        ClientID      => '...',
    );

=cut

sub ClientRegistrationGet {
    my ( $Self, %Param ) = @_;
    
    my %Result;

    # check required params...
    if ( !$Param{ClientID} ) {
        $Self->{LogObject}->Log( 
            Priority => 'error', 
            Message  => 'Need ClientID!' 
        );
        return;
    }
   
    # check cache
    my $CacheKey = 'ClientRegistrationGet::' . $Param{ClientID};
    my $Cache    = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;
    
    return if !$Self->{DBObject}->Prepare( 
        SQL   => "SELECT client_id, callback_url, authentication FROM client_registration WHERE client_id = ?",
        Bind => [ \$Param{ClientID} ],
    );

    my %Data;
    
    # fetch the result
    while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        %Data = (
            ClientID       => $Data[0],
            CallbackURL    => $Data[1],
            Authentication => $Data[2],
        );
    }
    
    # no data found...
    if ( !%Data ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Registration for client '$Param{ClientID}' not found!",
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


=item ClientRegistrationAdd()

Adds a new client registration

    my $Result = $ClientRegistrationObject->ClientRegistrationAdd(
        ClientID       => 'CLIENT1',
        CallbackURL    => '...',
        Authentication => '...',            # optional
    );

=cut

sub ClientRegistrationAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ClientID CallbackURL)) {
        if ( !defined( $Param{$_} ) ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # do the db insert...
    my $DBInsert = $Self->{DBObject}->Do(
        SQL  => "INSERT INTO client_registration (client_id, callback_url, authentication) VALUES (?, ?, ?)",
        Bind => [
            \$Param{ClientID},
            \$Param{CallbackURL},
            \$Param{Authentication},
        ],
    );

    #handle the insert result...
    if ($DBInsert) {

        # delete cache
        $Self->{CacheObject}->CleanUp(
            Type => $Self->{CacheType}
        );

        return $Param{ClientID};
    }
    else {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "DB insert failed!",
        );
    }

    return;
}

=item ClientRegistrationList()

Returns a ArrayRef with all registered ClientIDs

    my $ClientIDs = $ClientRegistrationObject->ClientRegistrationList();

=cut

sub ClientRegistrationList {
    my ( $Self, %Param ) = @_;
    my $WHEREClauseExt = '';
    my %Result;

    # check cache
    my $CacheTTL = 60 * 60 * 24 * 30;   # 30 days
    my $CacheKey = 'ClientRegistrationList';
    my $CacheResult = $Self->{CacheObject}->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey
    );
    return %{$CacheResult} if (IsHashRefWithData($CacheResult));
  
    my $SQL = "SELECT client_id FROM client_registration";

    return if !$Self->{DBObject}->Prepare( 
        SQL   => $SQL,
    );

    my @Result;
    while ( my @Data = $Self->{DBObject}->FetchrowArray() ) {
        push(@Result, $Data[0]);
    }

    # set cache
    $Self->{CacheObject}->Set(
        Type           => $Self->{CacheType},
        Key            => $CacheKey,
        Value          => \@Result,
        TTL            => $CacheTTL,
    );

    return \@Result;
}

=item ClientRegistrationDelete()

Delete a client registration.

    my $Result = $ClientRegistrationObject->ClientRegistrationDelete(
        ClientID      => '...',
    );

=cut

sub ClientRegistrationDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ClientID)) {
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
        SQL  => 'DELETE FROM client_registration WHERE client_id = ?',
        Bind => [ \$Param{ClientID} ],
    );

    # delete cache
    $Self->{CacheObject}->CleanUp(
        Type => $Self->{CacheType}
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
