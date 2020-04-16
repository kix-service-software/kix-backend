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
    }
    if ($DecRes->{$Key}) {
       S->{$Key} = $DecRes->{$Key}; 
    }
##    if ($DecRes->{ConfigItemID}) {
##         push (@{S->{ConfigItemIDArray}}, $DecRes->{ConfigItemID});
##    }
##    if ($Param{Content} =~ /services/) {
##       print STDERR "POSTResponse".Dumper($ua->request($req)); 
##    }
#    if ($DecRes->{ConfigItemID}) {
#       S->{ConfigItemID} = $DecRes->{ConfigItemID}; 
#    }
#    elsif ($DecRes->{TicketID}) {
#       S->{TicketID} = $DecRes->{TicketID}; 
#    }
    if ($DecRes->{ConfigItemID}) {
       S->{ConfigItemID} = $DecRes->{ConfigItemID}; 
    }
    elsif ($DecRes->{TicketID}) {
       S->{TicketID} = $DecRes->{TicketID}; 
    }
    elsif ($DecRes->{ArticleID}) {
       S->{ArticleID} = $DecRes->{ArticleID}; 
    }
    elsif ($DecRes->{WatcherID}) {
       S->{WatcherID} = $DecRes->{WatcherID}; 
    }
    elsif ($DecRes->{DynamicFieldID}) {
       S->{DynamicFieldID} = $DecRes->{DynamicFieldID}; 
    } 
    elsif ($DecRes->{TextModuleID}) {
       S->{TextModuleID} = $DecRes->{TextModuleID}; 
    } 
    elsif ($DecRes->{ContactID}) {
       S->{ContactID} = $DecRes->{ContactID}; 
    } 
    elsif ($DecRes->{GeneralCatalogItemID}) {
       S->{GeneralCatalogItemID} = $DecRes->{GeneralCatalogItemID}; 
    } 
     elsif ($DecRes->{FAQCategoryID}) {
       S->{FAQCategoryID} = $DecRes->{FAQCategoryID}; 
    } 
     elsif ($DecRes->{FAQArticleID}) {
       S->{FAQArticleID} = $DecRes->{FAQArticleID}; 
    } 
     elsif ($DecRes->{FAQAttachmentID}) {
       S->{FAQAttachmentID} = $DecRes->{FAQAttachmentID}; 
    } 
     elsif ($DecRes->{FAQVoteID}) {
       S->{FAQVoteID} = $DecRes->{FAQVoteID}; 
    } 
     elsif ($DecRes->{MailAccountID}) {
       S->{MailAccountID} = $DecRes->{MailAccountID}; 
    } 
     elsif ($DecRes->{LinkID}) {
       S->{LinkID} = $DecRes->{LinkID}; 
    } 
     elsif ($DecRes->{SystemAddressID}) {
       S->{SystemAddressID} = $DecRes->{SystemAddressID}; 
    } 
     elsif ($DecRes->{SearchProfileID}) {
       S->{SearchProfileID} = $DecRes->{SearchProfileID}; 
    } 
     elsif ($DecRes->{Language}) {
       S->{Language} = $DecRes->{Language}; 
    } 
     elsif ($DecRes->{StandardAttachmentID}) {
       S->{StandardAttachmentID} = $DecRes->{StandardAttachmentID}; 
    } 
     elsif ($DecRes->{TemplateID}) {
       S->{TemplateID} = $DecRes->{TemplateID}; 
    } 
     elsif ($DecRes->{ObjectIconID}) {
       S->{ObjectIconID} = $DecRes->{ObjectIconID}; 
    } 
     elsif ($DecRes->{UserID}) {
       S->{UserID} = $DecRes->{UserID}; 
    } 
     elsif ($DecRes->{PatternID}) {
       S->{PatternID} = $DecRes->{PatternID}; 
    } 
     elsif ($DecRes->{OrganisationID}) {
       S->{OrganisationID} = $DecRes->{OrganisationID}; 
    } 
     elsif ($DecRes->{ServiceID}) {
       S->{ServiceID} = $DecRes->{ServiceID}; 
    } 
     elsif ($DecRes->{QueueID}) {
       S->{QueueID} = $DecRes->{QueueID}; 
    } 
     elsif ($DecRes->{TicketStateID}) {
       S->{TicketStateID} = $DecRes->{TicketStateID}; 
    } 
     elsif ($DecRes->{MailFilterID}) {
       S->{MailFilterID} = $DecRes->{MailFilterID}; 
    } 
     elsif ($DecRes->{RoleID}) {
       S->{RoleID} = $DecRes->{RoleID}; 
    } 
     elsif ($DecRes->{PermissionID}) {
       S->{PermissionID} = $DecRes->{PermissionID}; 
    } 
     elsif ($DecRes->{ClientID}) {
         push (@{S->{ClientIDArray}}, $DecRes->{ClientID});
    }
    elsif ($DecRes->{AddressID}) {
         push (@{S->{AddressIDArray}}, $DecRes->{AddressID});
    }
      elsif ($DecRes->{UserPreferenceID}) {
       S->{UserPreferenceID} = $DecRes->{UserPreferenceID}; 
    }
      elsif ($DecRes->{SLAID}) {
       S->{SLAID} = $DecRes->{SLAID}; 
    }
      elsif ($DecRes->{ChecklistItemID}) {
       S->{ChecklistItemID} = $DecRes->{ChecklistItemID}; 
    }
      elsif ($DecRes->{NotificationID}) {
       S->{NotificationID} = $DecRes->{NotificationID}; 
    }
      elsif ($DecRes->{ImageID}) {
       S->{ImageID} = $DecRes->{ImageID}; 
    }
      elsif ($DecRes->{execPlanId}) {
       S->{execPlanId} = $DecRes->{execPlanId}; 
    }
      elsif ($DecRes->{JobID}) {
       S->{JobID} = $DecRes->{JobID}; 
    }
      elsif ($DecRes->{ExecPlanID}) {
       S->{ExecPlanID} = $DecRes->{ExecPlanID}; 
    }
      elsif ($DecRes->{MacroID}) {
       S->{MacroID} = $DecRes->{MacroID}; 
    } 
      elsif ($DecRes->{MacroActionID}) {
       S->{MacroActionID} = $DecRes->{MacroActionID}; 
    } 
      elsif ($DecRes->{macroId}) {
       S->{macroId} = $DecRes->{macroId}; 
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
