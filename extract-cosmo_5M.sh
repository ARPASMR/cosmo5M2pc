#!/bin/bash

### script originali acquisizione/plottaggio Bolam U. Pellegrini
### piratati MS giugno 2014 per estrarre COSMO da arkimet e plottare
### modificati EP gennaio 2018 per estrarre COSMO_5M da arkimet e produrre i plottaggi
### GPM: aggiunto pezzo febbraio 2020 per estrazione punto griglia per ATS Milano
### Usage:
### extract-cosmo_5M.sh <data (aaaammgg)> <run (00-12)>

### importo le configurazioni
source /opt/cosmo_5M/conf/variabili_ambiente
# ------------------------------------------------------------

### utilizzo dello script e settaggio date/run
usage="Utilizzo: `basename $0` <data(aaaammgg)> <run>"
usage1="Se non si specifica la data, viene usata quella odierna ed il run delle 00"

dataoggi=$(date +%Y%m%d)
dataieri=$(date -d yesterday +%Y%m%d)

if [ "$1" == "-h" ] || [ "$1" == "--help" ]
then
        echo $usage
        echo $usage1
        exit
fi

if [ ! $1 ]
then
        echo "manca la data della corsa"
        echo $usage
        echo $usage1
        dataplot=$dataoggi
else
        dataplot=$1
fi

if [ ! $2 ]
then
        echo "manca il run"
        echo $usage
        echo $usage1
        run="00"
else
        run=$2
fi

# ------------------------------------------------------------

### variabili
# cntrl esecuzione
nomescript=`basename $0 .sh`
export fieldset=`basename $0 .sh |cut -d'-' -f2`
cntrl=$log_dir/control_plot_$fieldset.$dataplot"_"$run
cntrl_pciv=$log_dir/control_pciv_$fieldset.$dataplot"_"$run

# date
day=`echo $dataplot | awk '{print substr($0,7,2)}'`
month=`echo $dataplot | awk '{print substr($0,5,2)}'`
year=`echo $dataplot | awk '{print substr($0,1,4)}'`
stringalog=$day" "$month" "$year

# filesystem aggiunto per disseminazione ad ATS Milano
atsdir=ATS-MI
cntrl_ats=${log_dir}/control_ats_$fieldset.$dataplot"_"$run
# ------------------------------------------------------------

### definizione interrogazione ad arkiweb
dataxarki=${dataplot:0:4}"-"${dataplot:4:2}"-"${dataplot:6:2}
scad=73
dataset="cosmo_5M_ita"
datasetbk="cosmo_5M_ita_backup"
gribcheck=${tmp_dir}/arkicheck.txt
accessofields="https://"$usr_arpaer":"$pwd_arpaer"@"$arkiweb"/fields"
accessodata="https://"$usr_arpaer":"$pwd_arpaer"@"$arkiweb"/data"
stringaqryhead="query=reftime:="$dataxarki" "$run":00; product: "
# estraggo prima le variabili su livelli di pressione
# geopotenziale, temperatura ed umidita' specifica fino a 500 hPa
stringaqryP1="GRIB1,80,2,6 or GRIB1,80,2,11 or GRIB1,80,2,51; level:GRIB1,100,1000 or GRIB1,100,950 or GRIB1,100,925 or GRIB1,100,850 or GRIB1,100,700 or GRIB1,100,500"
# vento e rh fino a 200 hPa
stringaqryP2="GRIB1,80,2,33 or GRIB1,80,2,34 or GRIB1,80,2,52; level:GRIB1,100,1000 or GRIB1,100,950 or GRIB1,100,925 or GRIB1,100,850 or GRIB1,100,700 or GRIB1,100,500 or GRIB1,100,300 or GRIB1,100,200"
stringaqry3D_1="$stringaqryhead $stringaqryP1"
stringaqry3D_2="$stringaqryhead $stringaqryP2"
# variabili al suolo (GRIB1,1): non è necessario specificare livelli
stringaqry0M="GRIB1,80,2,8 or GRIB1,80,2,61 or GRIB1,80,2,78 or GRIB1,80,2,79 or GRIB1,80,2,71 or GRIB1,80,2,73 or GRIB1,80,2,74 or GRIB1,80,2,75 or GRIB1,80,201,145 or GRIB1,80,201,146"
# variabili a 10m
stringaqry10M="GRIB1,80,2,33 or GRIB1,80,2,34 or GRIB1,80,201,187; level:GRIB1,105,10"
# variabili a 2m
stringaqry2M="GRIB1,80,2,11 or GRIB1,80,2,17; level:GRIB1,105,2"
# per zero termico (GRIB1,4 freezing level) e mslp (GRIB1,102 mean sea level) estraggo senza livelli
stringaqryXM="GRIB1,80,201,084 or GRIB1,80,2,2"
stringaqry2D_1="$stringaqryhead $stringaqry0M"
stringaqry2D_2="$stringaqryhead $stringaqry10M"
stringaqry2D_3="$stringaqryhead $stringaqry2M"
stringaqry2D_4="$stringaqryhead $stringaqryXM"
# ------------------------------------------------------------

### start the engines and trap processi, 20130430
echo
echo "** inizio script `basename $0`: `date` ***************************************"
orainizio=$(date +%s)
echo "File di controllo: $cntrl"
echo

echo
echo "... Verifico che non ci sia già un processo in corso..."
echo
export LOCKDIR=$log_dir/$nomescript-$dataplot-$run.lock && echo "lockdir -----> $LOCKDIR"

T_MAX=5400

if mkdir "$LOCKDIR" 2>/dev/null
then
        echo "acquisito lockdir: $LOCKDIR"
        echo $$ > $LOCKDIR/PID
else
        echo "Script \"$nomescript.sh\" già in esecuzione alle ore `date +%H%M` con PID: $(<$LOCKDIR/PID)"
        echo "controllo durata esecuzione script"
        ps --no-heading -o etime,pid,lstart -p $(<$LOCKDIR/PID)|while read PROC_TIME PROC_PID PROC_LSTART
        do
                SECONDS=$[$(date +%s) - $(date -d"$PROC_LSTART" +%s)]
                echo "------Script \"$nomescript.sh\" con PID $(<$LOCKDIR/PID) in esecuzione da $SECONDS secondi"
                if [ $SECONDS -gt $T_MAX ]
                then
                        echo "$PROC_PID in esecuzione da più di $T_MAX secondi, lo killo"
                        pkill -15 -g $PROC_PID
                        # inserisco messaggio a LogAnalyzer
                        logger -is -p user.crit "TAGMETEO extract-COSMO_5M: processo $PROC_PID in timeout ($T_MAX), lo killo" -t "MODELLI_ELABORAZIONI"
                fi
        done
        echo
        
        exit 1
fi

trap "rm -fvr "$LOCKDIR";
rm -fv $tmp_dir/$$"_"*;
echo;
echo \"** fine script `basename $0`: `date` ***************************************\";
exit" EXIT HUP INT QUIT TERM
# ------------------------------------------------------------

### controllo che i dati non siano già stati plottati (in questo caso esco), altrimenti proseguo
echo
echo "... Verifico se le mappe e le estrazioni sono già state fatte..."

if [ -s $cntrl ]
then
        echo
        echo "  => Dati $fieldset data $dataplot corsa $run gia' plottati, esco"
        echo
        exit
fi
# ------------------------------------------------------------

### interrogo arkiweb senza scaricare i dati e se va buon fine conto le scadenze,
### altrimenti esco ed eventualmente emetto un warning su LogAnalyzer
echo -e "... Controllo che i file grib di "$dataset" siano presenti su arkiweb:\n"
echo -e " uso tp come campo civetta e verifico che siano presenti le $scad scadenze\n"

gribtest="GRIB1,80,2,61"
stringatest="query=reftime:="$dataxarki" "$run":00; product: "$gribtest

# interrogazione di arkiweb
curl -sgG --data-urlencode "datasets[]=$dataset" --data-urlencode "$stringatest"\
  $accessofields | jq '.stats ["c"]' > $gribcheck

echo "***************************"
cat $gribcheck
echo "***************************"

if [ "$?" -ne "0" ]
then
        echo -e "  => I file grib non sono presenti: provo con la corsa di backup\n"
        rm $gribcheck
        curl -sgG --data-urlencode "datasets[]=$datasetbk" --data-urlencode "$stringatest"\
          $accessofields | jq '.stats ["c"]' > $gribcheck
#       cat $gribcheck
        if [ "$?" -ne "0" ]
        then
                echo -e "  => Neanche i file grib di backup sono presenti: esco dalla procedura\n"
        fi
        # inserisco messaggio a LogAnalyzer: orari limite 6 UTC per run delle 00 e 17 UTC per il run delle 12
        orario=$[`echo $(date +%H) | awk '{print $0 + 0}'` + 0]
        case $run in
                00) if [ $orario -ge 6 ]
                    then
                    then
                        logger -is -p user.warning "TAGMETEO extract-COSMO_5M: ancora non disponibile il file grib cosmo 5M delle 00" \
                          -t "MODELLI_ACQUISIZIONE"
                    fi;;
                12) if [ $orario -ge 17 ]
                    then
                        logger -is -p user.warning "TAGMETEO extract-COSMO_5M: ancora non disponibile il file grib cosmo 5M delle 12" \
                          -t "MODELLI_ACQUISIZIONE"
                    fi;;
        esac
        exit 1
else
        echo -e "  => I file grib sono presenti su arkiweb, proseguo\n"
fi

# conteggio delle scadenze: se il num non è corretto esco dalla procedura
echo "Verifico che il numero degli elementi nel grib sia corretto"
n_elem=$(head -1 $gribcheck)
if [ ${n_elem} -lt ${scad} ]
then
        echo -e "  => Numero di scadenze incomplete: esco dalla procedura\n"
        rm $gribcheck
        exit
else
        echo -e "  => Numero di scadenze complete: scarico il dataset\n"
        rm $gribcheck
fi
# ------------------------------------------------------------

### scarico i dati
echo -e "  => Il run richiesto è disponibile, lo scarico"
echo
# scarico il grib da arkiweb:
# 1. campi su livelli di pressione fino a 500 hPa
curl -gG --data-urlencode "datasets[]=$dataset" --data-urlencode "$stringaqry3D_1" $accessodata > $tmp_dir/tmp.grb
# 2. campi su livelli di pressione fino a 200 hPa
curl -gG --data-urlencode "datasets[]=$dataset" --data-urlencode "$stringaqry3D_2" $accessodata >> $tmp_dir/tmp.grb
# 3. campi su sfc
curl -gG --data-urlencode "datasets[]=$dataset" --data-urlencode "$stringaqry2D_1" $accessodata >> $tmp_dir/tmp.grb
# 4. campi a 10m
curl -gG --data-urlencode "datasets[]=$dataset" --data-urlencode "$stringaqry2D_2" $accessodata >> $tmp_dir/tmp.grb
# 5. campi a 2m
curl -gG --data-urlencode "datasets[]=$dataset" --data-urlencode "$stringaqry2D_3" $accessodata >> $tmp_dir/tmp.grb
# 6. campi su altri livelli
curl -gG --data-urlencode "datasets[]=$dataset" --data-urlencode "$stringaqry2D_4" $accessodata >> $tmp_dir/tmp.grb

if [ `ls -ltr $tmp_dir/tmp.grb | awk '{print $5}'` -lt 3000000 ]
then
        echo
        echo "  => file scaricato da arkiweb e' probabilmente corrotto, esco"
        echo
        # inserisco messaggio a LogAnalyzer
        logger -is -p user.crit "TAGMETEO extract-COSMO_5M: file grib run delle $run incompleto o corrotto" -t "MODELLI_ACQUISIZIONI"
        exit
else
        echo
        echo "  => Download OK, proseguo..."
        # inserisco messaggio a LogAnalyzer:
        logger -is -p user.info "TAGMETEO extract-COSMO_5M: grib run delle $run scaricati" -t "MODELLI_ACQUISIZIONI"
fi
# ------------------------------------------------------------

### estrazione e disseminazione dati per protezione civile
if [ ! -d $tmp_dir/pciv ]; then mkdir $tmp_dir/pciv; fi
# estraggo il campo di interesse (TP)
grib_copy -w shortName=tp $tmp_dir/tmp.grb $tmp_dir/pciv/tp_prociv.grb

# "rimappo", cioè interpolo, la griglia del cosmo5m sulla griglia del cosmoI7 (per mantenere in vita questo processo quando
# verrà cessata la disseminazione del cosmoI7 a fine febbraio 2018)
cdo remapbil,$con_dir/grid_cosmoI7 $tmp_dir/pciv/tp_prociv.grb $tmp_dir/pciv/tp_CI7_prociv.grb
rm -f $tmp_dir/pciv/tp_prociv.grb

# lancio lo script di estrazione dei dati
echo -e "\nScript per l estrazione dei dati e la produzione dei file .dat per la protezione civile"
$bin_dir/tp_prociv.sh

echo -e "\nOK, dati $dataset elaborati, file .dat del $datagrib $run prodotti" > $cntrl_pciv
echo "fine estrazione dati per protezione civile del $datagrib $run alle ore: `date`"

# copio su ftp arpa i dati estratti per protezione civile
REMOTEDIR='cosmoi7'
  ftp -n $ftparpa <<END_SCRIPT
  quote USER $usr_ftpdpc
  quote PASS $pwd_ftpdpc
  cd $REMOTEDIR
  lcd $arc_dir/prot_civ
  prompt
  mput *.dat
  quit
END_SCRIPT

echo "COPIATI!!"

# pulizie
rm $arc_dir/prot_civ/*.dat
# ------------------------------------------------------------

### saltiamo le parti non essenziali (plottaggi) [...]

### Pulizie
rm -f $tmp_dir/tmp.grb

echo -e "\n...Rimozione directory piu' vecchie di 5 giorni forecast $fieldset $run su Ghost..."
find $web_dir/$fieldset$run/ -maxdepth 1 -type d -mtime +5 -exec rm -vr {} \;

# plottaggi ed esecuzione di questo script
echo "Rimuovo i files di log piu' vecchi di 10 giorni"
find $log_dir/ -iname "*.log" -ctime +10 -exec rm -vf {} \;
echo "Ora rimuovo i files di controllo piu' vecchi di 10 giorni"
find $log_dir/ -iname "control_plot*" -ctime +10 -exec rm -vf {} \;

# file di controllo ats e dpc
find $log_dir/ -iname "cntrl_ats*" -ctime +10 -exec rm -vf {} \;
find $log_dir/ -iname "cntrl_pciv*" -ctime +10 -exec rm -vf {} \;
# ------------------------------------------------------------

### Fine script
echo "******fine script: `basename $0` alle ore: `date` ************************"
#logger -is -p user.info "$nomescript terminato con successo!" -t "PREVISORE"
exit 0
# ------------------------------------------------------------
