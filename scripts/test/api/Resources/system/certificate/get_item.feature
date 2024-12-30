Feature: GET request to the /system/certificates/:CertificateID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
      
  Scenario: get an existing certificate
    Given a certificate
    When I get this certificate
    Then the response code is 200
#    Then the response content is
    And the response contains the following items type of Certificate
      | CType | Email            | Fingerprint                                                 | Hash     | Issuer                                                                                                                                                             | Modulus                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          | Serial | Subject                                                                                                                            | Type |
      | SMIME | admin@cape-it.de | EC:28:B6:04:8D:0E:01:CE:F3:4D:A0:11:A4:05:1D:9C:08:98:E7:E1 | 523be3b9 | C =  DE, ST =  DE, L =  DE, O =  DE, OU =  Univention Corporate Server, CN =  Univention Corporate Server Root CA (ID= qWoXT2Sg), emailAddress =  admin@cape-it.de | F56C31A6D5F2CDA88EB4C2BC690CF520FA143156103A8A6720A6F2C491F4BDA6CDD76A423E474EE1AE240549B9570F9FB54B4D908A39F8BE3B1BE17611170A348FCF0FEC8DCC12805F7D186D8C12F127E5CB4500457D6BB5B73F13D75876267EBBCD460DB26C12D6CDBD8248C3FEBB0464EE4C5C293A909654CA6EC8063B70B8DCFC392EA69D5D5B6F606418397D4377BCAD63C1B564BB47632635948296F63B0673A4B8550E45F2BE076B81036D45812837E64A637F6B742CDAF087EE0AD271553F8D9AE724EFAF812AB18C7C7F5450F224F820DE40CB59233EF4549C41838C44B8199C5FC537F6AD024A3AE991455A8E401F9D480D53ED71EFB8F73B4C0E31 | 02D3   | C =  DE, ST =  DE, L =  DE, O =  DE, OU =  Univention Corporate Server, CN =  fjacquemin.openvpn, emailAddress =  admin@cape-it.de | Cert |
#    When I delete this certificate
#    Then the response code is 204
#      | CType | Email            | Filename   | Fingerprint                                                 | Hash     | Issuer                                                                                                                                                             | Modulus                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          | Private | Serial | Subject                                                                                                                            | Type |
#      | SMIME | admin@cape-it.de | KIX_Cert_8 | EC:28:B6:04:8D:0E:01:CE:F3:4D:A0:11:A4:05:1D:9C:08:98:E7:E1 | 523be3b9 | C =  DE, ST =  DE, L =  DE, O =  DE, OU =  Univention Corporate Server, CN =  Univention Corporate Server Root CA (ID= qWoXT2Sg), emailAddress =  admin@cape-it.de | F56C31A6D5F2CDA88EB4C2BC690CF520FA143156103A8A6720A6F2C491F4BDA6CDD76A423E474EE1AE240549B9570F9FB54B4D908A39F8BE3B1BE17611170A348FCF0FEC8DCC12805F7D186D8C12F127E5CB4500457D6BB5B73F13D75876267EBBCD460DB26C12D6CDBD8248C3FEBB0464EE4C5C293A909654CA6EC8063B70B8DCFC392EA69D5D5B6F606418397D4377BCAD63C1B564BB47632635948296F63B0673A4B8550E45F2BE076B81036D45812837E64A637F6B742CDAF087EE0AD271553F8D9AE724EFAF812AB18C7C7F5450F224F820DE40CB59233EF4549C41838C44B8199C5FC537F6AD024A3AE991455A8E401F9D480D53ED71EFB8F73B4C0E31 | No      | 02D3   | C =  DE, ST =  DE, L =  DE, O =  DE, OU =  Univention Corporate Server, CN =  fjacquemin.openvpn, emailAddress =  admin@cape-it.de | Cert |





    
