Feature: POST request to the /system/dynamicfields resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: create a dynamicfield
    When I create a dynamicfield
    Then the response code is 201
    When I delete this dynamicfield
    Then the response code is 204

  Scenario: create a dynamicfield with same name
    When I create a dynamicfield with same name
    Then the response code is 201
    When I create a dynamicfield with same name
    Then the response code is 409
    And the response object is Error
    And the error code is "Object.AlreadyExists"
    And the error message is "Cannot create DynamicField. Another DynamicField with the name already exists."
    When I delete this dynamicfield
    Then the response code is 204