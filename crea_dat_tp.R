#
#
#

# carica la libreria R per trattare i file netCDF
library(ncdf4)

# legge i percorsi dalle variabili d'ambiente
pro_dir<-Sys.getenv("fun_dir")
dirin  <-paste(Sys.getenv("tmp_dir"), "/pciv", sep = "")
dirout <-paste(Sys.getenv("arc_dir"), "/prot_civ", sep = "")

# carica le funzioni per la rotazione delle coordinate
source(paste(pro_dir,'geo2rot.R',sep='/'))

# legge il parametro passato (step)
args <- commandArgs(TRUE)
step=args[1]

# imposta alcune variabili
varname='tp'
filein<-paste(dirin,'/',varname,'_',step,'_Lomb.nc',sep='')
varcode='var61'  # nel file netCDF la tp viene chiamata var61 !!
dataset='LMSMR4A052' # serve solo per essere scritto nell'intestazione del file di output ma
                     # non ha nessuna utilità!

#
# ****** Inizio elaborazione *****************************************************************
#

# legge il file da trattare
ncfile_var <- nc_open(filein)

# legge dati e coordinate
var <- ncvar_get(ncfile_var, varcode)
rlat <- ncvar_get(ncfile_var, "rlat")
rlon <- ncvar_get(ncfile_var, "rlon")

nlat<-length(rlat)
nlon<-length(rlon)

# legge il file dei metadati prodotto da tp_prociv.sh
info<-read.table(paste(dirin,'/','info_grib_',varname,'.dat',sep=''),header = TRUE)
date=info$dataDate

# recupera le inforamzioni da scrivere sull'intestazione del file di output
yyyy<-substr(date,1,4)
mm  <-substr(date,5,6)
dd  <-substr(date,7,8)
run <-sprintf("%0.2d",info$dataTime/100)
scad<-paste('0',info$endStep,sep='')

if(info$indicatorOfTypeOfLevel=='sfc'){
  typeOfLevel=105
} else if(info$indicatorOfTypeOfLevel=='pl') {
  typeOfLevel=100
}

level=sprintf("%0.5d",info$level)
#centre=info$centre
centre=200
table=sprintf("%0.3d",2)
code=sprintf("%0.3d",info$indicatorOfParameter)

lat_pole= -info$latitudeOfSouthernPoleInDegrees
lon_pole= info$longitudeOfSouthernPoleInDegrees-180

rlat_first<-sprintf("%9.3f",info$latitudeOfFirstGridPointInDegrees)
rlon_first<-sprintf("%9.3f",info$longitudeOfFirstGridPointInDegrees)
rlat_last<-sprintf("%9.3f",info$latitudeOfLastGridPointInDegrees)
rlon_last<-sprintf("%9.3f",info$longitudeOfLastGridPointInDegrees)
resol<-sprintf("%9.3f",info$iDirectionIncrementInDegrees+0.00001)

nlon_full<-sprintf("%9.3d",info$Ni) # nlon full domain
nlat_full<-sprintf("%9.3d",info$Nj) # nlat full domain

geo_cord_first<-rot2geo(lon_pole,lat_pole,info$longitudeOfFirstGridPointInDegrees,info$latitudeOfFirstGridPointInDegrees,0)
geo_cord_last <-rot2geo(lon_pole,lat_pole,info$longitudeOfLastGridPointInDegrees,info$latitudeOfLastGridPointInDegrees,0)

lat_first<-sprintf("%9.3f",geo_cord_first$y)
lon_first<-sprintf("%9.3f",geo_cord_first$x)
lat_last<-sprintf("%9.3f",geo_cord_last$y)
lon_last<-sprintf("%9.3f",geo_cord_last$x)

scad<-sprintf("%0.2d",as.numeric(gsub("\\D", "",filein)))
fileout=paste(dirout,'/',varname,'_cosmoi7_',run,'_',date,'_',scad,'.dat',sep='')

# ------ SCRITTURA DELL'INTESTAZIONE ------
write(dataset,file=fileout,sep='\n',append=TRUE)
#il secondo record è 1 se il campo è scalare, 2 se è vettoriale
write('1',file=fileout,sep='\n',append=TRUE)
#record con la data
write(paste(yyyy,mm,dd,run,'00',sep=' '),file=fileout,sep='\n',append=TRUE)
#record con la scadenza
write(paste('001','00000',scad,'004',sep=' '),file=fileout,sep='\n',append=TRUE)
#record con le inforamzioni sui livelli
write(paste(typeOfLevel,level,'000',sep=' '),file=fileout,sep='\n',append=TRUE)
#record con le informazioni sul centro di emissione e sulla variabile
write(paste(centre,table,code,'000','000','000',sep=' '),file=fileout,sep='\n',append=TRUE)
#record relativo al tipo di grigliato e al polo di rotazione
#10 vuol dire che ho un grigliato ruotato, -1 che sto cosiderando una sottoarea
write(paste(' 10 -1   ',sprintf("%5.3f",90-lat_pole),'   ',sprintf("%5.3f",lon_pole+180),'    0.000',sep=''),file=fileout,sep='\n',append=TRUE)

write(paste(rlat_first,rlat_last,resol,nlat_full,lat_first,lat_last,'    44.60    46.70',sep=''),file=fileout,sep='\n',append=TRUE)
write(paste(rlon_first,rlon_last,resol,nlon_full,lon_first,lon_last,'     8.30    11.50',sep=''),file=fileout,sep='\n',append=TRUE)

var_t<-t(var)

# ------ SCRITTURA DEI DATI ------
for (ilat in 1:nlat) {
   for (ilon in 1:nlon) {
        geo_cord<-rot2geo(lon_pole,lat_pole,rlon[ilon],rlat[ilat],0)

        lon<-geo_cord$x
        lat<-geo_cord$y
        riga<-paste(sprintf("%9.3f",rlat[ilat]),sprintf("%6.3f",rlon[ilon]),sprintf("%6.3f",lat),sprintf("%6.3f",lon),
                    sprintf("%8.4f",var_t[ilat,ilon]),sep='   ')

        write(riga,file=fileout,sep='\n',append=TRUE)
   }
}

write('999.000  999.000  999.000  999.000     0.000000',file=fileout,append=TRUE)
