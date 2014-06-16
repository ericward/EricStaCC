# Initialize Sap Flux Model Inputs

rm(list = ls())
#library(mvtnorm) #disable if on DSCR cluster, enable on older versions of R

# Data and Run Name
  DIRECTORY<-'H:/DATA/PINEMAP Tier 3/2014 Feb Report and VA paper/formatted input VA new'
  DATA   <- 'other'  #'wireless' or 'face' or 'other'
  RUN    <- 'grw_CC'
  BY.RING <- FALSE
  RING   <- NA #ring number for FACE runs of individual rings
  Prefix <- 'VaIII_0612_0414'  #for 'other' data, prefix on sap flux files (before year)
  YEAR   <- 2012 #starting year
  TreatI <- 1
  MinInt <- 163/366 #optional starting decimal year
  MaxInt <- 274/366 #optional ending decimal year
  intval  <- c(MinInt,MaxInt) #select segment to analyze 
  can.choose <- 1 #if not MULTCAN, which column of data to use
  TITLE  <- paste(RUN,YEAR,sep=".") #prefix to add to output title
  ng    <- 20000 #number of gibb samples
  
  
# Switched for Optional Features
  gapfill   <- 31*48 #maximum gap to model
  #radial profile options
  FLAT      <- F    # use flat depth profile?
  EFFSAI    <- T    # use outside flux with effective SAI?
  effsai    <- 0.88  # if EFFSAI, give scaling factor
  SECTION   <- F    # T = use sapwood sections F = use continuous depth profile
  NSECTION	<- NA	  # if SECTION, the number of sapwood sections
  RAND      <- T    # use random effects?
  BS        <- F    # use canopy status?
  DPAR      <- F    # estimate data model parameters? 
  SAIunits  <- 0	  #0 if unitless (i.e. m2/m2), 1 if cm2/m2 (or m2/ha)
  PLOTSALA  <- 0    #0 if average plot SAI and LAI used, 1 if plot specific
  #soil moisture options
  DEF       <- F    # use ET based moisture deficit?
  RELM      <- F    # use relative extractable soil moisture?
  Gaussf_M  <- T    # use Gaussian function ofor SM effect?
  #hydraulic options
  CAP       <- F    # model with capacitance lag
  FIX.CAP   <- F	  # use a fixed alpha, instead of fitting
  FIX.ALPHA <- (0.0155/60) #fixed alpha value
  TC        <- 0    #absolute lag for sap flux data  
  #process parameter fit options
  moistdef  <- 0.05  # minimum vol moisture for VPD effect estimation
  lightdef  <- 1000  # minimum light value for moisture and VPD effect estimation
  Dreg      <- F    #use Gref - lam*ln(D) instead of Gref * (1-lam*ln(D))  
  #user-specific options
  REMOTE    <- F    # if on cluster and you want to run each year seperately, set to TRUE         
  MULTCAN   <- F    # model as multiple canopies?
  MultYear  <- T    #Run years simultaneously


####if not Dave or Eric's data
if(DATA == 'other'){
year <- YEAR
TREATS <- c('CC','CD','FC','FD') #Treatment Matrix
Treat <- TREATS[TreatI]
#check and select interval
intval  <- c(MinInt,MaxInt) #select segment to analyze    
SENS.FILE <-paste(DIRECTORY,'/','VAIIISF052012to042014',Treat,'id.csv',sep='')
FLUX.FILE <- paste(DIRECTORY,'/','VAIIISF052012to042014',Treat,'.csv',sep='')
PAR.FILE  <-paste(DIRECTORY,'/',Prefix,'_PAR.csv',sep='')
SM.FILE   <-paste(DIRECTORY,'/',Prefix,'_VSM.csv',sep='')
VPD.FILE  <-paste(DIRECTORY,'/',Prefix,'_VPD.csv',sep='')
TEMP.FILE <- paste(DIRECTORY,'/',Prefix,'_AirT.csv',sep='')
SAI.FILE  <- paste(DIRECTORY,'/',Prefix,'_SAI.csv',sep='')
LAI.FILE  <- paste(DIRECTORY,'/',Prefix,'_DailyLAI','.csv',sep='')
if(SECTION) DIST.FILE <- paste(DIRECTORY,'/','ASdist','.csv',sep='')

}


 
###########Eric's FACE DATA: initialize treatments
  ntreat <- 0
  nfact  <- 0
 if(DATA == 'face'){
    treats <- c('Cb','Ft')
    
	Cb<-c('A','E')
    Ft<-c('C','F')
	ii    <- TreatI
	year <- YEAR
	  #check and select interval
  intval  <- c(MinInt,MaxInt) #select segment to analyze    
  #year <- trunc(min(intval))
  #intval <- intval - year
 
  treatmat <- expand.grid(get(treats[1]),get(treats[2]))
	  treatmat <- matrix(as.character(unlist(treatmat)),nrow=dim(treatmat)[1])
      colnames(treatmat) <- treats
	  
    treatmat <- cbind(treatmat,Treat=paste(treatmat[,1],treatmat[,2],sep=""))
	nfact  <- length(treats)
	ntreat <- dim(treatmat)[1]

	Treat<-treatmat[ii,'Treat']
    TreatPeriod<-paste(treatmat[ii,'Treat'],year,sep='')
    if(year<2001|year>2004|treatmat[ii,'Ft']=='C'){
    if(treatmat[ii,'Cb']=='A') rings<-cbind("A",c(1,5,6,8)) else rings<-cbind('E',c(2,3,4,7))}else{
	  if(treatmat[ii,'Cb']=='A') rings<-cbind("A",c(8)) else rings<-cbind("E",c(7))
	  }

    Fert<-treatmat[ii,'Ft']
    Carb<-treatmat[ii,'Cb']
    SENS.FILE <-paste(DIRECTORY,'/',Carb,Fert,year,'cleanJSid_hw.csv',sep='')
    FLUX.FILE <- paste(DIRECTORY,'/',Carb,Fert,year,'cleanJS_hw.csv',sep='')
    PAR.FILE  <-paste(DIRECTORY,'/','PAR',year,Carb,'.csv',sep='')
    SM.FILE   <-paste(DIRECTORY,'/','M',year,Carb,'.csv',sep='')
    VPD.FILE  <-paste(DIRECTORY,'/','AveUpD',year,Carb,'.csv',sep='')
    TEMP.FILE <- paste(DIRECTORY,'/','AirTempUp',Carb,'.csv',sep='')
    SAI.FILE  <- paste(DIRECTORY,'/','SAI_hw','.csv',sep='')
    LAI.FILE  <- paste(DIRECTORY,'/','DailyLAInew',year,'_hw.csv',sep='')
    if(SECTION) DIST.FILE <- paste(DIRECTORY,'/','ASdist_hw','.csv',sep='')

  }




  
source('SF.functions.r')


source('SF.Setup.r')

#if(!REMOTE) cov.cor <- cov.plot()




source('SF.Gibbs.r')
