 Feature: GET request to the /system/communication/sendertypes/:ChannelID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get an existing sendertype
    When I get the sendertype with SenderTypeID 1
    Then the response code is 200
    And the response object is SenderTypeResponse
    And the attribute "SenderType.Name" is "agent"

