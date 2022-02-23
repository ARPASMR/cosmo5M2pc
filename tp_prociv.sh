#!/bin/bash

# COORDINATE per il ritaglio del grib sulla Lombardia nel sistema ruotato, cioè corrispondenti
# alle seguenti coordinate nel sistema regolare:
#  lonmin=8.3
#  latmin=44,6
#  lonmax=11.5
#  latmax=46.7
# Calcolate con script R (vedi Wikiss)
#
# queste sono nella griglia del cosmo5m
# lon1=-1.21
# lon2=1.03
# lat1=1.61
# lat2=3.70
#
# queste sono nella griglia del cosmoI7
lon1=-1.2
lon2=1.1
lat1=-12.9
lat2=-10.8

vargrib=tp

# pulisco la dir di stoccaggio dei dati estratti
rm $dat_dir/*.dat

# parametri grib_ls
param_1="centre,indicatorOfParameter,indicatorOfTypeOfLevel,level,dataDate,dataTime,startStep,endStep"
param_2="latitudeOfFirstGridPointInDegrees,longitudeOfFirstGridPointInDegrees,latitudeOfLastGridPointInDegrees"
param_3="longitudeOfLastGridPointInDegrees,jDirectionIncrementInDegrees,iDirectionIncrementInDegrees"
param_4="latitudeOfSouthernPoleInDegrees,longitudeOfSouthernPoleInDegrees,Ni,Nj"

param="$param_1,$param_2,$param_3,$param_4"
#
#------ ciclo sulle scadenze ------
#

for step in $(seq 3 3 72)
do
        scad='0-'$step && echo $scad
        echo "$vargrib"_"$step".grb
        grib_copy -w shortName=$vargrib,stepRange=$scad $tmp_dir/pciv/tp_CI7_prociv.grb $tmp_dir/pciv/"$vargrib"_"$step".grb

        # recupero informazioni dal file grib
        grib_ls -p $param $tmp_dir/pciv/"$vargrib"_"$step".grb | sed -n 2,3p > $tmp_dir/pciv/info_grib_"$vargrib".dat

        # ritaglio il dominio sulla Lombardia e converto in netcdf
        cdo -f nc copy -sellonlatbox,$lon1,$lon2,$lat1,$lat2 $tmp_dir/pciv/"$vargrib"_"$step".grb \
          $tmp_dir/pciv/"$vargrib"_"$step"_Lomb.nc

        # produco il file di output passando il controllo allo script R
        Rscript $fun_dir/crea_dat_tp.R  $step

done

#
#------ fine ciclo sulle scadenze ------
#

ls -1 $dat_dir/*dat > $tmp_dir/pciv/list.txt
#elenco linee da rimuovere
while read file
do
  sed '897d;934d;971d;1008d;1045d;1082d;1119d;1156d;1193d;1230d;1231d;1267d' $file > $tmp_dir/pciv/tmp_file.dat
  mv $tmp_dir/pciv/tmp_file.dat $file
done < $tmp_dir/pciv/list.txt

rm -rf $tmp_dir/pciv

rm $tmp_dir/info_*
rm $tmp_dir/*.nc
rm $tmp_dir/*.grb

exit
