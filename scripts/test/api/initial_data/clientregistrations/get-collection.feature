 Feature: GET request to the /clientregistration resource

  Background:
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: get the list of existing clientregistration
    When I query the collection of clientregistration
    Then the response code is 200
#    And the response object is ClientRegistrationCollectionResponse
#    Then the response contains 1 items of type "ClientRegistration"
#    And the response contains the following items of type ClientRegistration
#      | ClientID                            | NotificationInterval |
#      | kix-agent-portal-development-userid | 5                    |