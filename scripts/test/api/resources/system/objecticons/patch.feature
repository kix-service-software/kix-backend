Feature: PATCH request to the /system/objecticons/:ObjectIconID resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"

  Scenario: update a objecticon
    Given a objecticon
    Then the response code is 201  
    When I update this objecticon
    Then the response code is 200
#    And the response object is ObjectIconPostPatchResponse
    When I delete this objecticon
    Then the response code is 204

