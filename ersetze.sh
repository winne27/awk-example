#!/bin/bash
ANWE=(AENDERUNGSDIENST_HV ANIS     ARDAP          BESTANDSBEWERTUNG BSP     FAXINFOSYSTEME KLEINANWENDUNGEN KUNDENSTAMM     LIEFERANTENSTAMM     VAS     WEBSERVICE)
echo "Start" > /home/sag/schaeffer/ersetze.log
echo "Start" > /home/sag/schaeffer/ersetze.stat
for (( i = 0 ; i < ${#ANWE[@]} ; i++ ))
#for i in 4
do
  gawk -F ':' -v ANWE=${ANWE[$i]} '
    BEGIN                {
                           vorlauf = 1;
                           i = 0;
                           iaktmax = 1
                           iakt = 1;
                           suchenCheckFile = 0;
                           vorletztesChecken = 0;
                           DEBUG = "/home/sag/schaeffer/ersetze.log";
                           print "*************************">>DEBUG;
                           print "****** " ANWE " gestartet">>DEBUG;
                           print "*************************">>DEBUG;
                         }
    /^#/                 {print $0;next;}
    /^:/                 {print $0;next;}
    vorlauf == 1 && FILENAME != "/home/sag/schaeffer/check_file_exit.txt"{ 
                           vorlauf = 0;imax = i;suchenFilename = 1;vz = NR -1;
                         }
    vorlauf == 1 && $1 == ANWE{
                           i++;
                           a[i,"bereich"] = $1;
                           a[i,"filename"] = $2;
                           a[i,"step"] = $3;
                           a[i,"exec"] = $4;
                           a[i,"dname"] = $5;
                           split($6,b,",");
                           for (j in b)
                           {
                             posi = index(b[j],"DSN=")
                             if (posi > 0) 
                             {
                               dsn = substr(b[j],posi + 4);
                               split(dsn,c,".");
                               k = length(c); 
                               for (m=1;m<=k;m++)
                               {
                                  if (substr(c[m],1,3) == "LSC") c[m] = "LSC&DB_ID#" 
                               } 
                               a[i,"dsn"] = c[k - 1] "." c[k];
                             }
                           }
                           a[i,"ersetze"] = 0
                           next;
                         } 
    vorlauf == 1         {next;}
    iakt > imax          {if (vorletztesChecken == 0){print $0;next;}}
                         {ausgabe = $0}
    /^<JOBI client/      {
                           split($0,b,".");
                           if (suchenFilename == 0)
                           {
                             if (b[2] > a[iaktmax,"filename"])
                             {
                               iakt = iaktmax + 1
                               if (iakt > iaktmax) iaktmax = iakt
                               suchenFilename = 1
                             } 
                           }
                           if (suchenFilename == 1)
                           {
                             while (b[2] > a[iakt,"filename"] && iakt <= imax)
                             {
                               print "--x-- " a[iakt,"filename"] " nicht gefunden" >>DEBUG
                               iakt++;
                               if (iakt > iaktmax) iaktmax = iakt
                             }
                             if (b[2] == a[iakt,"filename"])
                             {
                               suchenFilename = 0;
                               aktFilename = a[iakt,"filename"]; 
                               print "+++++ " a[iakt,"filename"] " gefunden" >>DEBUG
                               vorletztesChecken = 0;
                               split("", vlCheckArray)  ### Array loeschen
                             }
                           }
                         } 
    /^</                 {print $0;next;}
    /set_gdg/            {print $0;next;}
    suchenFilename == 0  || vorletztesChecken == 1{
                           if (vorletztesChecken == 1)
                           {
                             for (var in vlCheckArray)
                             {
                               if (index($0,a[var,"dsn"]) > 0)
                               {
                                 iakt = var
                                 delete vlCheckArray[var]
                                 iakt = iakt + 0
                                 break
                               }
                             }
                           } 
                           posi = index($0,a[iakt,"dsn"])
                           if ( iakt <= imax && posi > 0 )
                           {
                             if (index($0,"check_file ") > 0)
                             {
                               ausgabe = $0;
                               sub(/check_file /,"check_file_exit ",ausgabe);
                               print a[iakt,"dsn"] " ersetze (direkt) in Zeile " NR-vz >>DEBUG
                               a[iakt,"ersetze"] = 1
                               iakt++;
                               if (iakt > iaktmax) iaktmax = iakt
                               if (iakt <= imax && a[iakt,"filename"] > aktFilename) suchenFilename = 1;
                             }
                             else if (index($0,a[iakt,"dname"]) > 0)
                             {
                               suchenCheckFile = 1;
                               suchenCount = 0;
                               print "!!!!! " a[iakt,"step"] ":" a[iakt,"dsn"]  ":" a[iakt,"dname"] ":" a[iakt,"dsn"]  ":" iakt " gefunden in Zeile " NR-vz>>DEBUG
                             }
                             else if (index($0,"export") > 0)
                             {
                               suchenCheckFile = 1;
                               suchenCount = 0;
                               print "????? " a[iakt,"step"] ":" a[iakt,"dsn"]  ":" a[iakt,"dname"] ":" a[iakt,"dsn"] ":" iakt " gefunden in Zeile " NR-vz>>DEBUG
                             }
                           }  
                         }
    suchenCheckFile == 1 {
                           if (index($0,"check_file ") > 0)
                           {
                             ausgabe = $0;
                             sub(/check_file /,"check_file_exit ",ausgabe);
                             print "check_file ersetzt in Zeile " NR-vz >>DEBUG
                             a[iakt,"ersetze"] = 1
                             iakt++;
                             if (iakt > iaktmax) iaktmax = iakt
                             if (iakt <= imax && a[iakt,"filename"] > aktFilename) suchenFilename = 1;
                             suchenCheckFile = 0;
                           }
                           else if (index($0,"check_file_exit ") > 0)
                           {
                             suchenCheckFile = 0;
                             a[iakt,"ersetze"] = 2
                             iakt++;
                             if (iakt > iaktmax) iaktmax = iakt
                             print "check_file_exit bereits vorhanden in Zeile " NR-vz >>DEBUG
                             if (iakt <= imax && a[iakt,"filename"] > aktFilename) suchenFilename = 1;
                           }
                           else
                           {
                             suchenCount++;
                             if (suchenCount > 2)
                             {
                               suchenCheckFile = 0;
                               print iakt":kein check_file gefunden" >>DEBUG
                               vlCheckArray[iakt] = 1
                               vorletztesChecken = 1;
                               iakt++;
                               if (iakt > iaktmax) iaktmax = iakt
                             }
                           }
                         }
                         {print ausgabe;} 
    END                  {
                           zNichts = 0
                           zErsetzt = 0
                           zBereits = 0 
                           for (i=1;i<=imax;i++)
                           {
                             if (a[i,"ersetze"] == 0) zNichts++ 
                             if (a[i,"ersetze"] == 1) zErsetzt++
                             if (a[i,"ersetze"] == 2) zBereits++
                             if (a[i,"ersetze"] == 0)
                             print a[i,"bereich"] ":" a[i,"filename"] ":" a[i,"step"] ":" a[i,"exec"] ":" a[i,"dname"] ":" a[i,"dsn"] ":" a[i,"ersetze"]>>"/home/sag/schaeffer/ersetze.stat"
                           } 
                           print zNichts ":" zErsetzt ":" zBereits >>"/home/sag/schaeffer/ersetze.stat"
                         }
  ' /home/sag/schaeffer/check_file_exit.txt /home/sag/schaeffer/exports/${ANWE[$i]}.xml > /home/sag/schaeffer/imports/${ANWE[$i]}.xml
  if [ $i -gt 99 ] 
  then 
    i=99 
  fi
done
