Feature: POST request to the /system/certificates resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: create a certificate
    When I create a certificate
    Then the response code is 201
#    Then the response object is ConfigItemClassDefinitionPostResponse
    When I delete this certificate
    Then the response code is 204

  Scenario: create a second certificate
    When I create a second certificate
    Then the response code is 201
#    Then the response object is ConfigItemClassDefinitionPostResponse
    When I delete this certificate
    Then the response code is 204

  Scenario: create a private certificate (error)
    When I create a private certificate
    Then the response code is 400
    And the response object is Error
    And the error code is "Object.UnableToCreate"
    And the error message is "Could not create Certificate! ( Error: Need Certificate of Private Key first -9ECB510F20C017B6148875CFCB8666962F3BF2D05CD1B5E4A324D9C27B4240D1BE979E8AAC37433CE5A68BD9BA901685A0E6FEA80BE65B6350BC6C89B28C54BD7AD57B1892F60EEC37CD7D4BD37157583748035E6BD2703AE0F85805EF6B97896EB64B42FBA9D0FA631C4FDA09F165597E4CC3E2AEB32F28F0D6956D1E7589956DE29E7D676F686F04228F9DBE45AFB310CBA6A39C490D08DDD67C4C87B6C797980A0FB7ADF45A2E2146B9C47AF664C0A19439D270FFF2F0C5533C27C2F3E1AAC1CEB8BDEBEE63B81ACCB8AB5915A116C2141D16758E792FC478C813834C796C32F20501EBDE37224F85941F590DC6BC8B0720658EE4BF1EC4387119F327787B)! )"




