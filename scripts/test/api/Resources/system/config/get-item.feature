 Feature: GET request to the /system/config/:Option resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get an existing config
    When I get the config with Option "WebUserAgent::Timeout"
    Then the response code is 200
    And the attribute "SysConfigOption.Value" is "15"

  Scenario: get an existing config
    When I get the config with Option "SendmailNotificationEnvelopeFrom::FallbackToEmailFrom"
    Then the response code is 200
    And the attribute "SysConfigOption.Value" is "1"