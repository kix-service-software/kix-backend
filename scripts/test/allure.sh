#!/bin/bash

rm -rfv "$PHERKIN_ALLURE_OUTDIR" || true
mkdir -pv "$PHERKIN_ALLURE_OUTDIR"
chmod 777 "$PHERKIN_ALLURE_OUTDIR"
export API_SCHEMA_LOCATION=$KIX_BACKEND_PATH/doc/API/V1/schemas

echo "executing API $1 tests..."
if [ "$1" == "startinitial" ]; then
  pherkin -o Allure $KIX_BACKEND_PATH/scripts/test/api/InitialData
elif [ "$1" == "start" ]; then
  pherkin -o Allure $KIX_BACKEND_PATH/scripts/test/api/Resources
elif [ "$1" == "proinitial" ]; then
  pherkin -o Allure $KIX_BACKEND_PATH/plugins/KIXPro/scripts/test/api/InitialData
elif [ "$1" == "pro" ]; then
  pherkin -o Allure $KIX_BACKEND_PATH/plugins/KIXPro/scripts/test/api/Resources
elif [ "$1" == "mpinitial" ]; then
  pherkin -o Allure $KIX_BACKEND_PATH/plugins/KIXMaintenancePlan/scripts/test/api/InitialData
elif [ "$1" == "mp" ]; then
  pherkin -o Allure $KIX_BACKEND_PATH/plugins/KIXMaintenancePlan/scripts/test/api/Resources
elif [ "$1" == "itil" ]; then
  pherkin -o Allure $KIX_BACKEND_PATH/plugins/KIXITILPractices/scripts/test/api/ITILPracticesImport
elif [ "$1" == "connect" ]; then
  pherkin -o Allure $KIX_BACKEND_PATH/plugins/KIXConnect/scripts/test/api/Resources
elif [ "$1" == "webservice" ]; then
  pherkin -o Allure $KIX_BACKEND_PATH/plugins/KIXConnectWebservice/scripts/test/api/Resources
elif [ "$1" == "migration" ]; then
  pherkin -o Allure $KIX_BACKEND_PATH/plugins/KIXPro/scripts/test/api/MirgationData
elif [ "$1" == "permission" ]; then
  pherkin -o Allure $KIX_BACKEND_PATH/plugins/KIXPro/scripts/test/api/CoreFunctions/PermissionBaseTests
elif [ "$1" == "imexport" ]; then
  pherkin -o Allure $KIX_BACKEND_PATH/plugins/KIXPro/scripts/test/api/CoreFunctions/Ex-Import-Backend
elif [ "$1" == "wildcardpermissions" ]; then
  pherkin -o Allure $KIX_BACKEND_PATH/plugins/KIXPro/scripts/test/api/CoreFunctions/WildcardPermissions
elif [ "$1" == "multiblecustomerids" ]; then
  pherkin -o Allure $KIX_BACKEND_PATH/plugins/KIXPro/scripts/test/api/CoreFunctions/AffectedAssetsContactOrganisationOnCreateConfigitem
elif [ "$1" == "performanceusertypecustomer" ]; then
  pherkin -o Allure $KIX_BACKEND_PATH/plugins/KIXPro/scripts/test/api/CoreFunctions/AffectedAssetsContactOrganisationOnCreateConfigitem
elif [ "$1" == "kixplugins" ]; then
  pherkin -o Allure $KIX_BACKEND_PATH/plugins/KIXPro/scripts/test/api/CoreFunctions/KIXPlugins
else
  echo "Fehler ... Command pruefen."
  exit 1
fi
FILES_TO_SEND=$(ls -dp1 $PHERKIN_ALLURE_OUTDIR/* || echo -n "")
if [ -z "$FILES_TO_SEND" ]; then
    echo "no report files for $1"
    echo "exiting..."
    exit 1
fi

FILES=""
for FILE in $FILES_TO_SEND; do
    FILES+="-F files[]=@$FILE ";
done
ALLUREPROJECTID=kix18-api-$1-test
SERVER_URL="$ALLURE_SERVER_URL/allure-docker-service/send-results?project_id=$ALLUREPROJECTID&force_project_creation=true"
curl --noproxy "*" -X POST "$SERVER_URL" -H "Content-Type: multipart/form-data" $FILES -ik

echo "TEST $1 beendet !"
