Feature: POST request /system/textmodules resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: added a textmodule
     When added a textmodule
     Then the response code is 201
     Then the response object is TextModulePostPatchResponse
     When I delete this textmodule
     Then the response code is 204

