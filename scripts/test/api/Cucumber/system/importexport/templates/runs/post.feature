Feature: POST request /system/importexport/templates/:TemplateID/runs resource

  Background: 
    Given the API URL is __BACKEND_API_URL__
    Given the API schema files are located at __API_SCHEMA_LOCATION__
    Given I am logged in as agent user "admin" with password "Passw0rd"
    
  Scenario: added a template run
     When added a template run for templateid 1
     Then the response code is 201




     
     
     
     
     