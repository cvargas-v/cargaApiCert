#!bin/bash
#########################################
####   Charge Api Certificates      #####
####  Integration Operation Team    #####
####    creationDate:09-06-2021     #####
#########################################

ruta="/home/osb122prd/CargaApiCert"
source ${ruta}/cfg/config.cfg

curl -u ${ApiUser}:${ApiPass} -k --request GET ${apiURL} | grep "<l7:Encoded>" >${ruta}/tmp/output.txt


for linea in $(cat ${ruta}/tmp/output.txt)
do
   #CREATE CERTS ONE BY ONE
   cont=`expr $cont + 1`
   echo "-----BEGIN CERTIFICATE-----" >${ruta}/tmp/cert${cont}.crt 
   echo $linea | sed "s/<l7\:Encoded>//g;s/<\/l7\:Encoded>//g" | fold -w 64 >>${ruta}/tmp/cert${cont}.crt
   echo "-----END CERTIFICATE-----" >>${ruta}/tmp/cert${cont}.crt
   echo "" >>${ruta}/tmp/cert${cont}.crt

   #echo $linea

   ##INFO CERTIFICATE
   subject=`openssl x509 -in ${ruta}/tmp/cert${cont}.crt -noout -subject `
   spaceCN=`echo ${subject} | grep -o "=" | wc -l`
   validatename=`openssl x509 -in ${ruta}/tmp/cert${cont}.crt -noout -subject | awk -F "/" '{print $'${spaceCN}'}' | sed "s/CN=//g"`  
   validate=`echo ${validatename} | grep -o "@" | wc -l`
   if [[ $validate -gt 0 ]]
   then
      spaceCN=`expr ${spaceCN} - 1`
      name=`openssl x509 -in ${ruta}/tmp/cert${cont}.crt -noout -subject | awk -F "/" '{print $'${spaceCN}'}' | sed "s/CN=//g"`
   else
      name=`openssl x509 -in ${ruta}/tmp/cert${cont}.crt -noout -subject | awk -F "/" '{print $'${spaceCN}'}' | sed "s/CN=//g"`
   fi   


   dateStartCert=`openssl x509 -in ${ruta}/tmp/cert${cont}.crt -startdate -noout | awk -F "=" '{print $2}'`
   dateEndCert=`openssl x509 -in ${ruta}/tmp/cert${cont}.crt -enddate -noout | awk -F "=" '{print $2}'`
   
   formatDateBegin=`date --date="${dateStartCert}" "+%d/%m/%y %H:%M:%S"`
   formatDateEnd=`date --date="${dateEndCert}" "+%d/%m/%y %H:%M:%S"`
 

   echo "Nombre API: "$name
   echo $spaceCN
   echo $subject
   echo "Cert Desde: "$formatDateBegin
   echo "Cert Hasta: "$formatDateEnd
   echo "------------------------------"

   ##INSERT DATABASE
   sql="BEGIN
           INSERT INTO OP_CERT_DOMAIN (ENVIRONMENT, ALIAS,FROMDATE,UNTILDATE)
           VALUES ('APIM', '${name}',TO_DATE('${formatDateBegin}','DD/MM/YY HH24:MI:SS'),TO_DATE('${formatDateEnd}','DD/MM/YY HH24:MI:SS'));
        EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
        UPDATE OP_CERT_DOMAIN
        SET UPDATEDATE = SYSDATE, FROMDATE = TO_DATE('${formatDateBegin}','DD/MM/YY HH24:MI:SS'), UNTILDATE = TO_DATE('${formatDateEnd}','DD/MM/YY HH24:MI:SS')
        WHERE ALIAS = '${name}';
        END;
        /
        COMMIT;"
    #AND FROMDATE = TO_DATE('${formatDateBegin}','DD/MM/YY HH24:MI:SS') AND UNTILDATE = TO_DATE('${formatDateEnd}','DD/MM/YY HH24:MI:SS')

    #echo $sql

   
    # If sqlplus is not installed, then exit
    if ! command -v sqlplus > /dev/null; then
     echo "SQL*Plus is required..."
    exit 1
    fi

     # Connect to the database, run the query, then disconnect
     echo -e "SET PAGESIZE 0\n SET FEEDBACK OFF\n $sql" | \
     sqlplus -S -L "$ORACLE_USERNAME/$ORACLE_PASSWORD@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=$ORACLE_HOST)(PORT=$ORACLE_PORT))(CONNECT_DATA=(SERVICE_NAME=$ORACLE_DATABASE)))"
 
done


#eliminamos temporales
rm -r ${ruta}/tmp/*

#Eliminamos archivddos mayores a 7 dias
total=`find $ruta/logs/* -mtime +7 | wc -l`

if [ $total != 0 ]
then
   find $ruta/logs/* -mtime +7 -exec rm {} \;
else
   echo "No hay archivos a borrar"
fi

