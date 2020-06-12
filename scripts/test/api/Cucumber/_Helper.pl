#!perl

sub _Get { 
    my (%Param) = @_;

    my $URIParams;
    foreach my $Key ( qw(Limit Offset Search Filter Fields Sort Include) ) {
        if ( $Param{$Key} ) {
            $URIParams->{lc($Key)} = $Param{$Key};
        }
    }
    if ( $URIParams ) {
        $URIParams = encode_json($URIParams);
    }
use Data::Dumper;
#print STDERR "GETResponseURIParams".Dumper($URIParams);
    my $ua = LWP::UserAgent->new();
    my $req = HTTP::Request->new('GET', $Param{URL}, undef, $URIParams);
    $req->header('Authorization' => 'Token ' . ($Param{Token} || ''));      
    $req->header('Content-Type' => 'application/json'); 
  
    my $Response = $ua->request($req);
use Data::Dumper;
#print STDERR "GETResponse".Dumper($ua->request($req));
#print STDERR "GETResponse".Dumper(decode_json($Response->decoded_content));      
    return ($Response, decode_json($Response->decoded_content));
}

sub _Post {
    my (%Param) = @_;

    my $ua = LWP::UserAgent->new();
    my $req = HTTP::Request->new('POST', $Param{URL});   
    $req->header('Authorization' => 'Token ' . ($Param{Token} || ''));      
    $req->header('Content-Type' => 'application/json'); 
use Data::Dumper;
#print STDERR "Content".Dumper(\%Param);
    if ( $Param{Content} ) {
        my $JSON = _ReplacePlaceholders( encode_json($Param{Content}) );
        $req->content($JSON);
    }
use Data::Dumper;
#print STDERR "POSTResponse".Dumper($ua->request($req));    
    my $Response = $ua->request($req);

    my $DecRes = decode_json($Response->decoded_content);
    
    foreach my $Key (keys %{$DecRes}){
        if ($Key ne "Systeminfo") {        
#print STDERR "DecResgesamt".Dumper($DecRes, $Key);    
#print STDERR "DecRes".Dumper($Response);
#print STDERR "DecRes".Dumper(keys %{$DecRes});
            push (@{S->{$Key."Array"}}, $DecRes->{$Key});
        }
        if ($DecRes->{$Key}) {
            S->{$Key} = $DecRes->{$Key}; 
        }
    }

    return ($Response, decode_json($Response->decoded_content));        
}

sub _Patch {
    my (%Param) = @_;

    my $ua = LWP::UserAgent->new();
    my $req = HTTP::Request->new('PATCH', $Param{URL});   
    $req->header('Authorization' => 'Token ' . ($Param{Token} || ''));      
    $req->header('Content-Type' => 'application/json'); 

    if ( $Param{Content} ) {
        my $JSON = _ReplacePlaceholders( encode_json($Param{Content}) );
        $req->content($JSON);
    }
use Data::Dumper;
#print STDERR "PATCHResponse".Dumper($ua->request($req));  
    my $Response = $ua->request($req);
    return ($Response, decode_json($Response->decoded_content));
}

sub _Delete { 
    my (%Param) = @_;

    my $ua = LWP::UserAgent->new();
    my $req = HTTP::Request->new('DELETE', $Param{URL});
    $req->header('Authorization' => 'Token ' . ($Param{Token} || ''));      
    $req->header('Content-Type' => 'application/json'); 

    my $Response = $ua->request($req);
use Data::Dumper;
#print STDERR "DeleteResponse".Dumper($ua->request($req));     
    return ($Response);
}

sub _ReplacePlaceholders {
    my $Text = shift;

    if ( $Text =~ /__GET_RANDOM_STRING__/ ) {
        my $RandomString = $Kernel::OM->Get('UnitTest::Helper')->GetRandomID();
        $Text =~ s/__GET_RANDOM_STRING__/$RandomString/g;
    }

    return $Text;
}

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.
