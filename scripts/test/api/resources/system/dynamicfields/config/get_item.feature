Feature: GET request to the /system/dynamicfields/:DynamicFieldID/config resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
      
  Scenario: get an existing dynamicfield
    Given a dynamicfield
    Then the response code is 200
    When I get this dynamicfield config
    Then the response code is 200
    And the attribute "DynamicFieldConfig.DefaultValue" is "259200"
#    And the attribute "DynamicField.DefaultValue" is ""
    When I delete this dynamicfield
    Then the response code is 204
    And the response has no content


    
