#!/bin/bash

if grep -q "customConfig:" ./test.yaml
then
    echo "It is already updated. No need to change"
else
    echo "update yaml file"

    sed -i '/fluent\-bit\:/a \
      customConfig:\
        outputs:\
        - tags:\
          - ssp_log\
          - ssp_tp_log\
          - ssp_audit\
          template: \|\
              Name es\
              Host  elasticsearch-es-http.logging.svc\
              Port  9200\
              tls On\
              tls.verify Off\
              Suppress_Type_Name On\
              Replace_Dots On\
              Index \$\{tag\}\
              HTTP_User kibana\
              HTTP_Passwd changeme
' ./test.yaml
fi