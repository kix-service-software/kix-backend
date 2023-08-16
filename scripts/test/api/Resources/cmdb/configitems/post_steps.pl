use warnings;
use strict;

use Cwd;
use lib cwd();
use lib cwd() . '/Kernel/cpan-lib';
use lib cwd() . '/plugins';
use lib cwd() . '/scripts/test/api/Cucumber';

use LWP::UserAgent;
use HTTP::Request;
use JSON::MaybeXS qw(encode_json decode_json);
use JSON::Validator;

use Test::More;
use Test::BDD::Cucumber::StepFile;

use Data::Dumper;

use Kernel::System::ObjectManager;

$Kernel::OM = Kernel::System::ObjectManager->new();

# require our helper
require '_Helper.pl';

# require our common library
require '_StepsLib.pl';

# feature specific steps

Given qr/a configitem$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/cmdb/configitems',
      Token   => S->{Token},
      Content => {
		   ConfigItem => {
		      ClassID => 10,
		      Version => {
		         Name => "test ci xx1111",
		         DeplStateID => 16,
		         InciStateID => 2,
		         Data => {
		            Vendor => "testvendor",
		            NIC => [
		               {
		                  NIC => "e1000",
		                  IPoverDHCP => [
		                     39
		                  ],
		                  IPAddress => [
		                     "192.168.1.0",
		                     "192.168.1.1",
		                     "192.168.1.2",
		                     "192.168.1.3"
		                  ],
		               }
		            ],
					Attachment => [
						 {
							 Content =>  "cdfrdrfde",
							 ContentType =>  "application/pdf",
							 Filename =>  "Test2.pdf"
						 }
					],
		            SectionWarranty => [
		               {
		                  FirstUsageDate => "04-09-2018"
		               }
		            ]
		         }
		      },
		      Images => [
		         {
		            Filename => "SomeImage.jpg",
		            ContentType => "image/jpeg",
		            Content => "..."
		         }
		      ]
		   }
	  }
   );
};

Given qr/a configitem with attachment$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/cmdb/configitems',
      Token   => S->{Token},
      Content => {
		   ConfigItem => {
		      ClassID => 4,
		      Version => {
		         Name => "test ci xx1111 attachment",
		         DeplStateID => 16,
		         InciStateID => 2,
		         Data => {
		            Vendor => "testvendor",
		            NIC => [
		               {
		                  NIC => "e1000",
		                  IPoverDHCP => [
		                     39
		                  ],
		                  IPAddress => [
		                     "192.168.1.0",
		                     "192.168.1.1",
		                     "192.168.1.2",
		                     "192.168.1.3"
		                  ],
		               }
		            ],
					Attachment => [
						 {
							 Content     =>  "cdfrdrfde",
							 ContentType =>  "application/pdf",
							 Filename    => "Test2.pdf"
						 }
					],
		         }
		      },
		      Images => [
		         {
		            Filename => "SomeImage.jpg",
		            ContentType => "image/jpeg",
		            Content => "..."
		         }
		      ]
		   }
	  }
   );
};

Given qr/(\d+) of configitems$/, sub {
    my $Name;
    my $DeplStateID;

	for (my $i=0;$i<$1;$i++){
		if ($i == 2) {
			$Name = 'test ci xx1111_filter';
			$DeplStateID = 12;
		}
		else {
			$Name = 'test ci xx1111test' . rand();
			$DeplStateID = 16;
		}
		(S->{Response}, S->{ResponseContent}) = _Post(
			URL     => S->{API_URL} . '/cmdb/configitems',
			Token   => S->{Token},
			Content => {
				ConfigItem => {
					ClassID    => 4,
					Version    => {
						Name        => "test ci xx1111",
						DeplStateID => $DeplStateID,
						InciStateID => 2,
						Data        => {
							Vendor => "testvendor",
							NIC    => [
								{
									NIC        => "e1000",
									IPoverDHCP => [
										39
									],
									IPAddress  => [
										"192.168.1.0",
										"192.168.1.1",
										"192.168.1.2",
										"192.168.1.3"
									],
								}
							],
							Attachment => [
								{
									Content     => "cdfrdrfde",
									ContentType => "application/pdf",
									Filename    => "Test2.pdf"
								}
							],
						}
					},
					Images     => [
						{
							Filename    => "SomeImage.jpg",
							ContentType => "image/jpeg",
							Content     => "..."
						}
					]
				}
			}
		);
   }
};


When qr/I create a configitem$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/cmdb/configitems',
      Token   => S->{Token},
      Content => {
		   ConfigItem => {
		      ClassID => 4,
		      Version => {
		         Name => "test ci xx1111",
		         DeplStateID => 16,
		         InciStateID => 2,
		         Data => {
		            Vendor => "testvendor",
		            NIC => [
		               {
		                  NIC => "e1000",
		                  IPoverDHCP => [
		                     39
		                  ],
		                  IPAddress => [
		                     "192.168.1.0",
		                     "192.168.1.1",
		                     "192.168.1.2",
		                     "192.168.1.3"
		                  ],
		               }
		            ],
		         }
		      },
		      Images => [
		         {
		            Filename => "SomeImage.jpg",
		            ContentType => "image/jpeg",
		            Content => "..."
		         }
		      ]
		   }
	  }
   );
};

When qr/I create a configitem with not existing class id$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/cmdb/configitems',
      Token   => S->{Token},
      Content => {
           ConfigItem => {
              ClassID => 44,
              Version => {
                 Name => "test ci xx1111",
                 DeplStateID => 16,
                 InciStateID => 2,
                 Data => {
                    Vendor => "testvendor",
                    NIC => [
                       {
                          NIC => "e1000",
                          IPoverDHCP => [
                             39
                          ],
                          IPAddress => [
                             "192.168.1.0",
                             "192.168.1.1",
                             "192.168.1.2",
                             "192.168.1.3"
                          ],
                       }
                    ],
                 }
              },
              Images => [
                 {
                    Filename => "SomeImage.jpg",
                    ContentType => "image/jpeg",
                    Content => "..."
                 }
              ]
           }
      }
   );
};

When qr/I create a configitem with no class id$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/cmdb/configitems',
      Token   => S->{Token},
      Content => {
           ConfigItem => {
              ClassID => undef,
              Version => {
                 Name => "test ci xx1111",
                 DeplStateID => 16,
                 InciStateID => 2,
                 Data => {
                    Vendor => "testvendor",
                    NIC => [
                       {
                          NIC => "e1000",
                          IPoverDHCP => [
                             39
                          ],
                          IPAddress => [
                             "192.168.1.0",
                             "192.168.1.1",
                             "192.168.1.2",
                             "192.168.1.3"
                          ],
                       }
                    ],
                 }
              },
              Images => [
                 {
                    Filename => "SomeImage.jpg",
                    ContentType => "image/jpeg",
                    Content => "..."
                 }
              ]
           }
      }
   );
};

When qr/I create a configitem with no incistate id$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Post(
      URL     => S->{API_URL}.'/cmdb/configitems',
      Token   => S->{Token},
      Content => {
           ConfigItem => {
              ClassID => 4,
              Version => {
                 Name => "test ci xx1111",
                 DeplStateID => 16,
                 InciStateID => undef,
                 Data => {
                    Vendor => "testvendor",
                    NIC => [
                       {
                          NIC => "e1000",
                          IPoverDHCP => [
                             39
                          ],
                          IPAddress => [
                             "192.168.1.0",
                             "192.168.1.1",
                             "192.168.1.2",
                             "192.168.1.3"
                          ],
                       }
                    ],
                 }
              },
              Images => [
                 {
                    Filename => "SomeImage.jpg",
                    ContentType => "image/jpeg",
                    Content => "..."
                 }
              ]
           }
      }
   );
};


