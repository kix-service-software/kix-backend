 Feature: GET request to the /system/communication/channels/:ChannelID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get an existing channel
    When I get the channel with ChannelID 2
    Then the response code is 200
    And the response object is ChannelResponse
    And the attribute "Channel.Name" is "email"

