#!perl

use Hash::Flatten;

########################################################################################################
# Given
########################################################################################################

Given qr/the API URL is (.*?)$/, sub {
  my $URL = $1;
  if ( $URL =~ /^__(.*?)__$/g ) {
     $URL = $ENV{$1};
  }

  isnt($URL, '', 'API URL given');
  S->{API_URL} = $URL;
};

Given qr/the API schema files are located at (.*?)$/, sub {
  my $APISchemaDirectory = $1;
  if ( $APISchemaDirectory =~ /^__(.*?)__$/g ) {
     $APISchemaDirectory = $ENV{$1};
  }

  isnt($APISchemaDirectory, '', 'API schema file location given');
  S->{API_SCHEMA_LOCATION} = $APISchemaDirectory;
};

Given qr/I am logged in as (.*?) user "(.*?)" with password "(.*?)"/, sub {
   my $AuthRequest = {
      UserType => ucfirst($1),
      UserLogin => $2, 
      Password => $3,
   };
   my $ua = LWP::UserAgent->new();
   my $req = HTTP::Request->new('POST', S->{API_URL}.'/auth');
   $req->header('Content-Type' => 'application/json');
   $req->content(encode_json($AuthRequest));
   my $resp = $ua->request($req);
   my $Content = decode_json($resp->decoded_content);
   is($resp->code, 201, 'checking login response code');
   isnt($Content->{Token}, '', 'Token exists');
   S->{Token} = $Content->{Token};
};

Given qr/an empty request object of type (.*?)$/, sub {
   S->{$1} = {};
};

########################################################################################################
# When
########################################################################################################

#When qr/I query the collection of (\w+) (\w+)$/, sub {
#   ( S->{Response}, S->{ResponseContent} ) = _Get(
#      Token => S->{Token},
#      URL   => S->{API_URL}.'/'.$1.'s/' .$2,
#   );
#};

#When qr/I query the collection of (\w+)$/, sub {
#   ( S->{Response}, S->{ResponseContent} ) = _Get(
#      Token => S->{Token},
#      URL   => S->{API_URL}.'/'.$1,
#   );
#};


########################################################################################################
# Then
########################################################################################################

Then qr/the error code is "(.*?)"$/, sub {
  is(S->{ResponseContent}->{Code}, $1, 'checking error code')
};

Then qr/the error message is "(.*?)"$/, sub {
  is(S->{ResponseContent}->{Message}, $1, 'checking error message')
};

Then qr/the response code is (\d+)/, sub {
  is(S->{Response}->code, $1, 'Response code matches');
};

Then qr/the response object is (.*?)$/, sub {
  my $SchemaName = $1;
  my $Schema = $Kernel::OM->Get('Main')->FileRead(
     Directory => S->{API_SCHEMA_LOCATION},
     Filename  => $SchemaName .'.json'
  );
  isnt($Schema, undef, 'read schema file');
  is(ref $Schema, 'SCALAR', 'get schema file content');

  my $Validator = JSON::Validator->new();
  $Validator->schema($$Schema);

  my @Result = $Validator->validate(S->{ResponseContent});
  use Data::Dumper;
  is(@Result, 0, 'validate response object '.Dumper(\@Result));
};

Then qr/the response has no content/, sub {
  is(S->{Response}->content, '', 'Response is empty');
};

Then qr/the attribute "(.*?)" is "(.*?)"$/, sub {
  my $Attribute = $1;
  my $Value = $2;

  my $FlatContent = Hash::Flatten::flatten(
      S->{ResponseContent},
      {
          HashDelimiter => '.',
          ArrayDelimiter => ':',
      }
  );

  is($FlatContent->{$Attribute}, $Value, 'Check attribute value in response');
};

Then qr/the attribute "(.*?)" of the "(.*?)" item (\d+) is "(.*?)"$/, sub {
  is(S->{ResponseContent}->{$2}->[$3]->{$1}, $4, 'Check attribute value in response');
};

Then qr/the response contains (\d+) items of type "(.*?)"$/, sub {
  is(@{S->{ResponseContent}->{$2}}, $1, 'Check response item count');
  my $Anzahl = @{S->{ResponseContent}->{$2}};
};

Then qr/the (.*?) header is set/, sub {
  isnt(S->{Response}->header($1), '', $1.' header is set');
};

Then qr/the response contains the following items of type (.*?)$/, sub {
    my $Object = $1;
    my $Index = 0;
 
    foreach my $Row ( @{ C->data } ) {
        foreach my $Attribute ( keys %{$Row}) {
            C->dispatch( 'Then', "the attribute \"$Attribute\" of the \"$Object\" item ". $Index ." is \"$Row->{$Attribute}\"" );
        }
        $Index++
    }
};



#=======================work=================================
Then qr/the response content is$/, sub {
    print STDERR Dumper(S->{ResponseContent});
#print STDERR Dumper(S->{ResponseContent}->{$2}->[$3]->{$1});
#    print STDERR Dumper(S->{ResponseContent}->{FAQArticle}->[0]);
#    print STDERR Dumper(S->{AddressIDArray});
#    print STDERR Dumper(S->{ResponseContent}->{FAQHistory}->[0]->{Name});
};



1;




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
