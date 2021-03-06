
#sap flux model

#functions
####################################################
tnorm <- function(n,lo,hi,mu,sig){   #normal truncated lo and hi

  if(length(lo) == 1 & length(mu) > 1)lo <- rep(lo,length(mu))
  if(length(hi) == 1 & length(mu) > 1)hi <- rep(hi,length(mu))

  q1 <- pnorm(lo,mu,sig)
  q2 <- pnorm(hi,mu,sig)

  z <- runif(n,q1,q2)
  z <- qnorm(z,mu,sig)
  z[z == Inf]  <- lo[z == Inf]
  z[z == -Inf] <- hi[z == -Inf]
  z
}


tnorm.mvt <- function(avec,muvec,smat,lo,hi){   
  # truncated multvariate normal
  # avec are current values (e.g., Gibbs sampling)
  # if there are no current values, pass any integer as the first argument
  # muvec is the vector of means
  # smat is the covariance matrix 

  if(length(avec) == 1)avec <- muvec
  avec[avec < lo] <- lo[avec < lo]
  avec[avec > hi] <- hi[avec > hi]
  for(k in 1:length(muvec)){
    piece1 <- smat[-k,k] %*% solve(smat[-k,-k])
    muk <- muvec[k] + piece1 %*% (avec[-k] - muvec[-k])
    sgk <- smat[k,k] - piece1 %*% smat[k,-k]
    if(sgk < .000000001)sgk <- .000000001
    avec[k] <- tnorm(1,lo[k],hi[k],muk,sqrt(sgk))
  }
  avec
}
####################################################

SA.est <- function(a1,a2,rin,rout) {
  Adep <- a1 + (sqrt(2*pi)*a2)*(pnorm(1,a1,a2) - .5)           #area under profile
  cj   <- qnorm(((Adep-a1)/2)/(sqrt(2*pi)*a2)+.5,a1,a2)-a1/2   #relative centroid of profile
  dd   <- Adep * (rout-rin) * pi * 2 * (rin + cj * (rout-rin)) #effective area of sapwood
  dd                                                             #units = cm^2
  }
  
##########################################  
#estimate diameter inside bark
dib   <- function(s,d) {
  if(s == 'acru') d <- .97 * d
  if(s == 'list') d <- d - (3.580 * exp(0.021 * d))/10
  if(s == 'litu') d <- d - (9.687 * exp(0.019 * d))/10
  if(s == 'pita') d <- d - (0.04 + 0.09*d)
  if(s == 'qual') d <- d - (1.99 * d + 1.322)/10
  if(s == 'qust') d <- d - (1.99 * d + 1.322)/10
  if(s == 'quru') d <- .93 * d
  d
  }

#########################################################
#Estimate heartwood diameter

hd   <- function(s,d) {
 
  ss<- c( 'acru',  'list', 'litu',  'pita',  'qual',  'qufa',  'qust')
  a <- c(-3.1649, -1.8682, 0.1364, -9.1969, -2.9843, -2.9843, -2.9843)
  b <- c( 1.6820,  0.4921, 0.5460,  0.7679,  0.9569,  0.9569,  0.9569)
  y <- a[which(ss == s)] + b[which(ss == s)] * d
  if(s == 'acru') y <- exp(a[which(ss == s)] + b[which(ss == s)] * log(d)) 
  y[y<0] <- 0
  y
  }
  
###########################################  

rescale <- function() {
  for(j in 1:nspec){
    d <- treed[treesp==species[j]]
    site <- SITE[treesp==species[j]]
    d <- dib(species[j],d)
    rout <- d/2
    rin  <- hd(species[j],d)/2
    sa   <- SA.est(bag[1,j],bag[2,j],rin,rout)
    specvars[species[j],'SA-LOWER']   <- sum(sa[site=='LOWER'])/10000#/.34/10000
    specvars[species[j],'SA-UPPER']   <- sum(sa[site=='UPPER'])/10000#/3.2/10000
    specvars[species[j],'SA-ALL'] <- sum(sa)/10000#/3.54/10000
  }
       
  SAPtree <- matrix(specvars[species[specindex],c(2,5)],2,byrow=T)
  SAPtree <- SAPtree[cbind(rindex,c(1:nprobe))]

  list(specvars = specvars, SAPtree = SAPtree)
}

###########################################

glagMat <- function(glast,gs,dt,tau){
	
#  dtmat <- matrix(dt,(nt-1),ncol(gs))
#  glast + (gs - glast)*(1 - exp(-dtmat*(rep(tau,each=(nt-1))^-1)))

  glast + (gs - glast)*(1 - exp(-dt%*%t(tau^-1)))

}
####################################################

gssMat <- function(gspec,aspec,blitespec,bmoistspec){

  out <- func_gQmat(blitespec,Q)*func_gMmat(bmoistspec,M)*func_gDmat(gspec,aspec,D)
    colnames(out) <- paste(species[site.all[,'specindex']],
                         SITE[site.all[,'SITE']],sep='.')
  out  
  }
####################################################

func_gMmat <- function(bmoistspec,M){  #note: using deficit, not M
	
  if(!DEF){
    bm1 <- matrix(bmoistspec[1,site.all[,'specindex']],nt,dim(site.all)[1],byrow=T)
    bm2 <- matrix(bmoistspec[2,site.all[,'specindex']],nt,dim(site.all)[1],byrow=T)
    Mm  <- matrix(M[,site.all[,'SITE']],nt,dim(site.all)[1])
    
    if(!Gaussf_M) {
	f<-Mm*0
      f[Mm<bm2,] <- 1 + bm1[Mm<bm2] * log ((Mm[Mm<bm2])/(bm2[Mm<bm2]))
      f[Mm >= bm2] <- 1
      f[f<0]<-0
      f
	  }

    if(Gaussf_M) {
      f <- exp(-.5*((Mm - bm2)/bm1)^2)
      f[Mm > bm2] <- 1
      }
	  
    f
  }
  if(DEF) {
    bm1 <- matrix(bmoistspec[site.all[,'specindex']],nt,dim(site.all)[1],byrow=T)
    DD  <- deficit[,site.all[,1]]
    
    f <- exp(-bm1*DD)
  }

  f
}
####################################################

func_gQmat <- function(blitespec,Q){

   bl1 <- matrix(blitespec[1,site.all[,'specindex']],nt,dim(site.all)[1],byrow=T)
   bl2 <- matrix(blitespec[2,site.all[,'specindex']],nt,dim(site.all)[1],byrow=T)
   Qm  <- matrix(Q[,site.all[,'SITE']],nt,dim(site.all)[1])
   #1 - exp(-1/bl1*Qm^bl2)
   1 - bl1 * exp(-Qm/(bl2))  #may add bstat here
    #(1 - bl1 * exp(-Qm/(bl2)))/(1 - bl1 * exp(-2000/(bl2)))#force to equal 1 at 2000 par
  }
####################################################

func_gDmat <- function(gspec,aspec,D){
   
   Dm <- matrix(D[,site.all[,'SITE']],nt,dim(site.all)[1])
   Dm[Dm<exp(-2)] <- exp(-2)
   if(!Dreg){
     out <- matrix(gspec[site.all[,'specindex']],nt,dim(site.all)[1],byrow=T) *               #new
           (1- matrix(aspec[site.all[,'specindex']],nt,dim(site.all)[1],byrow=T)*log(Dm))  #new
     } else {
	 out <- matrix(gspec[site.all[,'specindex']],nt,dim(site.all)[1],byrow=T) -               #old
            matrix(aspec[site.all[,'specindex']],nt,dim(site.all)[1],byrow=T)*log(Dm)       #old
     }
  out
}

####################################################

qt <- function(la,sa,dvec,tvec){ #to be multiplied by Gt

 nd <- length(dvec)
 lr <- la/sa
 e <- dvec*(tvec + 273)/273/44.6  #mmol m-2 s-1 kPa-1 to mm s-1 
 e <- e/(115.8 + .4236*tvec) #mm s-1 to g m-2 s-1 
 e*lr
}

####################################################

func_ph <- function(deep,aig,ba,SECTION) {             #mean sensor value
  if(!SECTION&!EFFSAI){
    phi <- exp(-(deep - ba[1,specindex])^2/2/ba[2,specindex]^2)
    phi[deep < ba[1,specindex]] <- 1
  	phi <- phi
	}
  if(SECTION|EFFSAI) {
    phi <- rep(1,nprobe)
	phi <- phi*ba[cbind(depthindex,specindex)]
    }
  phi * aig
}

####################################################

pred_jt <- function(aig,ba,bstat,SECTION){ 
	# sap flux depth, crown status; a vector over trees

  phi <- func_ph(depth,aig,ba,SECTION)
  bstat <- bstat[specindex]^Status
  phi*bstat
}

###########################################
 WJcalc <- function(W0,E,DT,A) {
	  if(!year %in% seq(1980,2020,by=4)){
        W    <- W0+(E - A*W0/DT)*DT
		W[W<0] <- 0
        J    <- A*W/DT
	    }
  
      if(year %in% seq(1980,2020,by=4)){
        W    <- W0+(E - A*W0/DT)*DT
		W[W<0] <- 0
        J    <- A*W/DT
	    }

		
    list(W = W, J = J)
  }
 
###########################################
#estimates LAI from sapwood area

LA.est <- function(s,AS,d) {
  if(s=='acru') dd <- 10^(-0.197 + 0.843 * log10(AS)) 
  if(s=='list') dd <- AS * 0.20
  if(s=='litu') dd <- (AS - 0.157) / 5.028
  if(s=='pita') dd <- AS * 0.20 #from Drake et al. 2010
  if(s=='qual') dd <- (AS - 0.363) / 1.428
  if(s=='qust') dd <- (AS - 0.363) / 1.428
  if(s=='quru') dd <- AS * 0.13 #from Oren et al 
  dd                                                           
  }

###########################################
#estimates effective outer sapwood area of a tree on sapwood profiles and dbh

SA.est <- function(a1,a2,rin,rout) {
  Adep <- a1 + (sqrt(2*pi)*a2)*(pnorm(1,a1,a2) - .5)           #area under profile
  cj   <- qnorm(((Adep-a1)/2)/(sqrt(2*pi)*a2)+.5,a1,a2)-a1/2   #relative centroid of profile
  dd   <- Adep * (rout-rin) * pi * 2 * (rin + cj * (rout-rin)) #effective area of sapwood
  dd                                                             #units = cm^2
  }
  
dib   <- function(s,d) {
  if(s == 'acru') d <- .97 * d
  if(s == 'cato') d <- d - (.105 + 3.070)
  if(s == 'list') d <- d - (3.580 * exp(0.021 * d))/10
  if(s == 'litu') d <- d - (9.687 * exp(0.019 * d))/10
  if(s == 'pita') d <- d - (0.04 + 0.09*d)
  if(s %in% c('qual','qumi','qust')) d <- d - (1.99 * d + 1.322)/10
  if(s %in% c('quco','qufa','quph','quru','quve')) d <- .93 * d
  d
  }
  
#########################################################
#Estimate heartwood diameter

hd   <- function(s,d) {
 
  ss<- c( 'acru',  'cato',  'list',  'litu',  'pita',  'qual',  'qufa',  'qumi',  'qust',  'quph')
  
  a <- c(-3.6293, -7.9787, -2.0290, -0.2457, -9.2071, -2.9914, -2.9914, -2.9914, -2.9914, -2.9914)
  b <- c( 1.7974,  1.0623,  0.4858,  0.5307,  0.7450,  0.9462,  0.9462,  0.9462,  0.9462,  0.9462)
  y <- a[which(ss == s)] + b[which(ss == s)] * d
  if(s == 'acru') y <- exp(a[which(ss == s)] + b[which(ss == s)] * log(d)) 
  y[y<0] <- 0
  y
  }
  
###########################################  

rescale <- function() {
  for(j in 1:nspec){
    d <- treed[treesp==species[j]]
    site <- SITE[treesp==species[j]]
    d <- dib(species[j],d)
    rout <- d/2
    rin  <- hd(species[j],d)/2
    sa   <- SA.est(bag[1,j],bag[2,j],rin,rout)
    specvars[species[j],'SA-LOWER']   <- sum(sa[site=='LOWER'])/10000#/.34/10000
    specvars[species[j],'SA-UPPER']   <- sum(sa[site=='UPPER'])/10000#/3.2/10000
    specvars[species[j],'SA-ALL'] <- sum(sa)/10000#/3.54/10000
  }
       
  SAPtree <- matrix(specvars[species[specindex],c(2,5)],2,byrow=T)
  SAPtree <- SAPtree[cbind(rindex,c(1:nprobe))]

  list(specvars = specvars, SAPtree = SAPtree)
}

###########################################

update_datapars <- function(){  #update ba for depth model and bstat for canopy

    jmat <- Jtmat[,site.sensor]
    ub <- rep(0,nspec)

  if(!SECTION){
	pba    <- tnorm.mvt(as.vector(bag),as.vector(bag),pcovba,    ##
                          as.vector(loba),as.vector(hiba)) 
	pba    <- matrix(pba,ncol=nspec,byrow=F)
    }
  if(SECTION){
  	nd<-length(unique(depth))
  	pba    <- matrix(1,length(DEPTH),nspec)
      pba[1,] <- tnorm(nspec,loba[1,],hiba[1,],bag[1,],sqrt(pcovba[1,1]))    
  	if(nd==3){
   	  pba[2,] <- tnorm(nspec,loba[2,],hiba[2,],bag[2,],sqrt(pcovba[2,2]))
        pba[nd,]<-(1-(pba[1,]*SAratio[1]+pba[2,]*SAratio[2]))/SAratio[3]
	  }else{
	  pba[nd,]<-(1-(pba[1,]*SAratio[1]))/(SAratio[2]+SAratio[3])
		
		
		}}
	
    mnow <- jmat*matrix(pred_jt(aig,bag,bstat,SECTION),nt,nprobe,byrow=T)
    mnew <- jmat*matrix(pred_jt(aig,pba,bstat,SECTION),nt,nprobe,byrow=T)

    pnow <- rep(0,nspec)
    pnew <- pnow
  
    for(j in 1:nspec){

    if(SECTION){
	pnow[j] <- sum(dnorm(Jdata[notmiss[notmiss[,2] %in% which(specindex==j),]],
                 mnow[notmiss[notmiss[,2] %in% which(specindex==j),]],
                 sqrt(verror),log=T)) + 
                 sum(dnorm(bag[,j],prior.ba[,j],vb,log=T)) 
      pnew[j] <- sum(dnorm(Jdata[notmiss[notmiss[,2] %in% which(specindex==j),]],
                 mnew[notmiss[notmiss[,2] %in% which(specindex==j),]],
                 sqrt(verror),log=T)) + 
                 sum(dnorm(pba[,j],prior.ba[,j],vb,log=T)) 
	  }

    if(!SECTION){
	  pnow[j] <- sum(dnorm(Jdata[notmiss[notmiss[,2] %in% which(specindex==j),]],
                 mnow[notmiss[notmiss[,2] %in% which(specindex==j),]],
                 sqrt(verror),log=T)) + 
                 sum(dnorm(bag[,j],prior.ba[,j],rbind(sb1[j],sb2[j]),log=T)) 
      pnew[j] <- sum(dnorm(Jdata[notmiss[notmiss[,2] %in% which(specindex==j),]],
                 mnew[notmiss[notmiss[,2] %in% which(specindex==j),]],
                 sqrt(verror),log=T)) + 
                 sum(dnorm(pba[,j],prior.ba[,j],rbind(sb1[j],sb2[j]),log=T)) 
	  }	  
    }

  aa <- exp(pnew - pnow)
  z  <- runif(nspec,0,1)
  wa <- which(z < aa,arr.ind=T)
  bag[,wa]  <- pba[,wa]

  ub[wa] <- ub[wa]+1
  
if(BS){
  ubs <- rep(0,nspec)
  pb   <- tnorm(nspec,priormat['lobstat',],priormat['hibstat',],bstat,pcovbs)

  mnow <- jmat*matrix(pred_jt(aig,bag,bstat,SECTION),nt,nprobe,byrow=T)
  mnew <- jmat*matrix(pred_jt(aig,bag,pb,SECTION),nt,nprobe,byrow=T)

  pnow <- rep(0,nspec)
  pnew <- pnow

  for (j in 1:nspec){
    pnow[j] <- sum(dnorm(Jdata[notmiss[notmiss[,2] %in% which(specindex==j),]],
                 mnow[notmiss[notmiss[,2] %in% which(specindex==j),]],
                 sqrt(verror),log=T)) + 
               dnorm(bstat[j],priormat['prior.bstat',j],sqrt(priormat['prior.Vbst',j]),log=T) 
    pnew[j] <- sum(dnorm(Jdata[notmiss[notmiss[,2] %in% which(specindex==j),]],
                 mnew[notmiss[notmiss[,2] %in% which(specindex==j),]],
                 sqrt(verror),log=T)) + 
               dnorm(pb[j],priormat['prior.bstat',j],sqrt(priormat['prior.Vbst',j]),log=T)
  }

  aa <- exp(pnew - pnow)
  z  <- runif(nspec,0,1)
  wa <- which(z < aa,arr.ind=T)
  bstat[wa]  <- pb[wa]
  ubs[wa] <- ubs[wa] + 1
  }

  if(BS) out <- list(bag = bag, bstat = bstat, ub = ub, ubs = ubs)
  if(!BS) out <- list(bag = bag, ub = ub)
  out
}

update_processpars <- function(){ #update gsr, a, light, sm

  ul   <- rep(0,nspec)
  um   <- ul
  ug   <- ul
  Evec <- 1 - exp(-dt%*%t(tau[site.all[,'specindex']]^-1))

  for(j in 1:nsite) 
    Gtmat[wdD[wdD[,2]==j,1],site.all[,1]==j] <- NA 
  
  vnow   <- c(gspec,aspec)
  vnew   <- vnow

  ks <- c(1:nspec)
  kn <- ks + nspec

  if(!Dreg) 
    vnew <- tnorm.mvt(vnow,vnow,pcovga,c(priormat['loG',],priormat['loA',]),        #new
            c(priormat['hiG',],priormat['hiA',]))                                 #new

  #gsref old - begin
  if(Dreg){
    if (dim(site.all)[1]>1)gsprop <- tnorm.mvt(gspec,gspec,pcovga[ks,ks],
                          priormat['loG',],priormat['hiG',])
    if(dim(site.all)[1]==1) gsprop <- tnorm(1,priormat['loG',1],priormat['hiG',1],gspec,
                          sqrt(pcovga[ks,ks]))
  
    vnew   <- c(gsprop,aspec)
    #lamda|gsref
    for(k in kn){
      piece1  <- pcovga[k,-k] %*% solve(pcovga[-k,-k]) 
      muk     <- aspec[k-nspec] + piece1 %*% (vnew[-k] - vnow[-k])
      sgk     <- pcovga[k,k] - piece1 %*% pcovga[k,-k]
      vnew[k] <- tnorm(1,minpropa*gsprop[k-nspec],min(gsprop[k-nspec]/log(max(D)),maxpropa*gsprop[k-nspec]),muk,sqrt(sgk))
      }
    }
  #gsref old - end
  
  pm <- matrix(vnew,2,nspec,byrow=T)
 
  Gs    <- gssMat(gspec,aspec,blitespec,bmoistspec)
#so high D Gs props aren't negative
  Gs[Gs<priorgt.lo] <- priorgt.lo[Gs<priorgt.lo]
  Gs[Gs>priorgt.hi] <- priorgt.hi[Gs>priorgt.hi]
  for(j in 1:nsite){ 
    Gs[wdD[wdD[,2]==j,1],site.all[,1]==j] <- NA 
    Gs[M[,j]<moistdef,site.all[,1]==j] <- NA
    Gs[Q[,j]<lightdef,site.all[,1]==j] <- NA
    Gt <- Gtmat
    Gt[wdD[wdD[,2]==j,1],site.all[,1]==j] <- NA 
    Gt[M[,j]<moistdef,site.all[,1]==j] <- NA	
    Gt[Q[,j]<lightdef,site.all[,1]==j] <- NA
	}	
	  
  
	  
  pnow <- dnorm(aspec,priormat['prior.A',],priormat['prior.sdA',],log=T)         #new
  if(Dreg) pnow <-  dnorm(aspec,priormat['prior.A',]*pm[1,],priormat['prior.sdA',],log=T)  #old

	pnow  <- pnow + tapply(apply(as.matrix(dnorm(Gt[-1,],glagMat(Gt[-nt,],Gs[-1,],dt,tau[site.all[,'specindex']]),
                         sqrt(sigma*Evec),log=T)),2,sum,na.rm=T),site.all[,'specindex'],sum,na.rm=T) +
             dnorm(gspec,priormat['prior.G',],priormat['prior.sdG',],log=T)
         
  if(Dreg) mod <- gspec  

  Gp    <- gssMat(pm[1,],pm[2,],blitespec,bmoistspec)
xx<-which(Gp<priorgt.lo)
if(length(xx)>0)  Gp[xx] <- priorgt.lo[xx]
xx<-which(Gp>priorgt.hi)
if(length(xx)>0)  Gp[Gp>priorgt.hi] <- priorgt.hi[xx]
  for(j in 1:nsite){ 
    Gp[wdD[wdD[,2]==j,1],site.all[,1]==j] <- NA  
    Gp[M[,j]<moistdef,site.all[,1]==j] <- NA
    Gp[Q[,j]<lightdef,site.all[,1]==j] <- NA
    }
  pnew <- dnorm(pm[2,],priormat['prior.A',],priormat['prior.sdA',],log=T)         #new
  if(Dreg) pnew <-  dnorm(pm[2,],priormat['prior.A',]*pm[1,],priormat['prior.sdA',],log=T)  #old

  pnew  <- pnew + tapply(apply(as.matrix(dnorm(Gt[-1,],glagMat(Gt[-nt,],Gp[-1,],dt,tau[site.all[,'specindex']]),
                         sqrt(sigma*Evec),log=T)),2,sum,na.rm=T),site.all[,'specindex'],sum,na.rm=T) +
             dnorm(pm[1,],priormat['prior.G',],priormat['prior.sdG',],log=T)
	
  if(nspec>1){
    aa <- exp(pnew - pnow)
    z  <- runif(nspec,0,1)
    wa <- which(z < aa,arr.ind=T)
    gspec[wa] <- pm[1,wa]
    aspec[wa] <- pm[2,wa]
    ug[wa] <- 1
    }

  if(nspec==1){
    aa <- exp(pnew - pnow)
    z  <- runif(nspec,0,1)
    if(z<aa) {gspec <- pm[1,1]
             aspec <- pm[2,1] 
             ug <- 1}
    }
      
  plite <- tnorm.mvt(as.vector((blitespec)),as.vector((blitespec)),pcovQ,    ##
                    as.vector(priormat[c('loB1','loB2'),]),                  ##
                    as.vector(priormat[c('hiB1','hiB2'),]))                  ##
  pl    <- matrix(plite,2,byrow=F)                                           ##

  Gs    <- gssMat(gspec,aspec,blitespec,bmoistspec)
  Gs[Gs<priorgt.lo] <- priorgt.lo[Gs<priorgt.lo]
  Gs[Gs>priorgt.hi] <- priorgt.hi[Gs>priorgt.hi]

  for(j in 1:nsite){ 
    Gs[wdD[wdD[,2]==j,1],site.all[,1]==j] <- NA 
    Gs[M[,j]<moistdef,site.all[,1]==j] <- NA
    Gs[Q[,j]<lightdef,site.all[,1]==j] <- NA
  }	
  
    pnow  <- tapply(apply(as.matrix(dnorm(Gtmat[-1,],glagMat(Gtmat[-nt,],Gs[-1,],dt,tau[site.all[,'specindex']]),
                         sqrt(sigma*Evec),log=T)),2,sum,na.rm=T),site.all[,'specindex'],sum,na.rm=T) +
             apply(dnorm(blitespec,priormat[c('prior.B1','prior.B2'),],
                   priormat[c('prior.sd1','prior.sd2'),],log=T),2,sum)
        
  Gp    <- gssMat(gspec,aspec,pl,bmoistspec)
  Gp[Gp<priorgt.lo] <- priorgt.lo[Gp<priorgt.lo]
  Gp[Gp>priorgt.hi] <- priorgt.hi[Gp>priorgt.hi]

  for(j in 1:nsite){ 
    Gp[wdD[wdD[,2]==j,1],site.all[,1]==j] <- NA  
    Gp[M[,j]<moistdef,site.all[,1]==j] <- NA
    Gp[Q[,j]<lightdef,site.all[,1]==j] <- NA
  }
    pnew  <- tapply(apply(as.matrix(dnorm(Gtmat[-1,],glagMat(Gtmat[-nt,],Gp[-1,],dt,tau[site.all[,'specindex']]),
                         sqrt(sigma*Evec),log=T)),2,sum,na.rm=T),site.all[,'specindex'],sum,na.rm=T) +
             apply(dnorm(pl,priormat[c('prior.B1','prior.B2'),],
                   priormat[c('prior.sd1','prior.sd2'),],log=T),2,sum)

  if(nspec>1){
    aa <- exp(pnew - pnow)
    z  <- runif(nspec,0,1)
    wa <- which(z < aa,arr.ind=T)
    blitespec[,wa]  <- pl[,wa]
    ul[wa] <- 1
  }

  if(nspec==1){
    aa <- exp(pnew - pnow)
    z  <- runif(nspec,0,1)
    if(z<aa) {blitespec <- pl
             ul <- 1}
    }


  pmoist <- tnorm.mvt(as.vector((bmoistspec)),as.vector((bmoistspec)),pcovM,    ##
                    as.vector(priormat[c('loB3','loB4'),]),                  ##
                    as.vector(priormat[c('hiB3','hiB4'),]))                  ##
  pm    <- matrix(pmoist,2,byrow=F)                                           ##

  Gs    <- gssMat(gspec,aspec,blitespec,bmoistspec)
  Gs[Gs<priorgt.lo] <- priorgt.lo[Gs<priorgt.lo]
  Gs[Gs>priorgt.hi] <- priorgt.hi[Gs>priorgt.hi]
  for(j in 1:nsite){ 
    Gs[wdD[wdD[,2]==j,1],site.all[,1]==j] <- NA 
    Gs[Q[,j]<lightdef,site.all[,1]==j] <- NA
  }  
  
  
  
    pnow  <- tapply(apply(as.matrix(dnorm(Gtmat[-1,],glagMat(Gtmat[-nt,],Gs[-1,],dt,tau[site.all[,'specindex']]),
                         sqrt(sigma*Evec),log=T)),2,sum,na.rm=T),site.all[,'specindex'],sum,na.rm=T) +
             apply(dnorm(bmoistspec,priormat[c('prior.B3','prior.B4'),],
                   priormat[c('prior.sd3','prior.sd4'),],log=T),2,sum)
        
  Gp    <- gssMat(gspec,aspec,blitespec,pm)
  Gp[Gp<priorgt.lo] <- priorgt.lo[Gp<priorgt.lo]
  Gp[Gp>priorgt.hi] <- priorgt.hi[Gp>priorgt.hi]

  for(j in 1:nsite){ 
    Gp[wdD[wdD[,2]==j,1],site.all[,1]==j] <- NA  
    Gp[Q[,j]<lightdef,site.all[,1]==j] <- NA
  }
    pnew  <- tapply(apply(as.matrix(dnorm(Gtmat[-1,],glagMat(Gtmat[-nt,],Gp[-1,],dt,tau[site.all[,'specindex']]),
                         sqrt(sigma*Evec),log=T)),2,sum,na.rm=T),site.all[,'specindex'],sum,na.rm=T) +
             apply(dnorm(pm,priormat[c('prior.B3','prior.B4'),],
                   priormat[c('prior.sd3','prior.sd4'),],log=T),2,sum)

  if(nspec>1){
    aa <- exp(pnew - pnow)
    z  <- runif(nspec,0,1)
    wa <- which(z < aa,arr.ind=T)
    bmoistspec[,wa]  <- pm[,wa]
    um[wa] <- 1
  }

  if(nspec==1){
    aa <- exp(pnew - pnow)
    z  <- runif(nspec,0,1)
    if(z<aa) {bmoistspec <- pm
             um <- 1}
    }

  list(gsr = gspec,a = aspec, bl = blitespec, bm = bmoistspec, ug = ug, um = um, ul = ul)

}

update_sigma <- function(){

  Evec <- matrix( (1 - exp(-dt%*%t(tau[site.all[,'specindex']]^-1))), (nt-1), dim(site.all)[1])
  ssq  <- (Gtmat[-1,] - glagMat(Gtmat[-nt,],Gsmat[-1,],dt,tau[site.all[,'specindex']]) )^2/Evec

  u1 <- s1 + length(Gtmat[-1,])/2
  u2 <- s2 + .5*sum(ssq,na.rm=T)
  1/rgamma(1,u1,u2)
}

update_tau <- function(){

  ptau <- tnorm(nspec,priormat['lotau',1],priormat['hitau',1],tau,.000005)

  Enow  <- matrix( (1 - exp(-dt%*%t(tau[site.all[,'specindex']]^-1))), (nt-1), dim(site.all)[1])
  Enew  <- matrix( (1 - exp(-dt%*%t(ptau[site.all[,'specindex']]^-1))), (nt-1), dim(site.all)[1])

  gtnow <- glagMat(Gtmat[-nt,],Gsmat[-1,],dt,tau[site.all[,'specindex']])
  gtnew <- glagMat(Gtmat[-nt,],Gsmat[-1,],dt,ptau[site.all[,'specindex']])

  if(dim(site.all)[1]>1){
    pnow  <- apply(dnorm(Gtmat[-1,],gtnow,sqrt(Enow*sigma),log=T),2,sum,na.rm=T) 
	pnow  <- tapply(pnow,site.all[,'specindex'],sum,na.rm=T) + dnorm(tau,priormat['prior.tau',],priormat['prior.sdtau',],log=T)
      
    pnew  <- apply(dnorm(Gtmat[-1,],gtnew,sqrt(Enew*sigma),log=T),2,sum,na.rm=T) 
	pnew  <- tapply(pnew,site.all[,'specindex'],sum,na.rm=T) + dnorm(ptau,priormat['prior.tau',],priormat['prior.sdtau',],log=T)
    
    aa <- exp(pnew - pnow)
    z  <- runif(nspec,0,1)
    wa <- which(z < aa,arr.ind=T)
    tau[wa] <- ptau[wa]
    }
  if(nspec==1){
    pnow  <- sum(dnorm(Gtmat[-1,],gtnow,sqrt(Enow*sigma),log=T),na.rm=T) +
             dnorm(tau,priormat['prior.tau',],priormat['prior.sdtau',],log=T)
      
    pnew  <- sum(dnorm(Gtmat[-1,],gtnew,sqrt(Enew*sigma),log=T),na.rm=T) +
             dnorm(ptau,priormat['prior.tau',],priormat['prior.sdtau',],log=T)
    aa <- exp(pnew - pnow)
    z  <- runif(nspec,0,1)
    if(z<aa) tau <- ptau
    }
        
  tau
}


update_alpha <- function(){ ##FIX
  
  uk   <- rep(0,nspec)

  if(!year %in% seq(1980,2020,by=4))
     DT <- dt*365*24*60*60
  
  if(year %in% seq(1980,2020,by=4))
     DT <- dt*366*24*60*60

	 #draw alpha
  if(nspec>1) 
    palpha <- tnorm.mvt(alpha,alpha,pcovK,priormat['loalpha',],priormat['hialpha',])
  if(nspec==1) 
    palpha <- tnorm(1,priormat['loalpha',],priormat['hialpha',],alpha,pcovK)

  C <- matrix(pred_jt(aig,bag,bstat,SECTION),nt,nprobe,byrow=T)  

	gmat <- Gtmat
    jnow <- Jtmat
	wnow <- Wtmat
	jnew <- jnow
	wnew <- wnow
	
	for(t in 2:nt){
	  
	  tmp <- WJcalc(wnew[t-1,],Gtmat[t-1,]*e.qt[t-1,],DT[t-1],palpha)
	    wnew[t,] <- tmp$W
	    jnew[t,] <- tmp$J
	  }
	jnow<- jnow[,site.sensor]
	jnew<- jnew[,site.sensor]
	
	jnow[is.na(Jdata)] <- NA
	jnew[is.na(Jdata)] <- NA
	  
    #v <- 
	#V <- 
	
	pnow  <- tapply(apply(dnorm(Jdata[-1,],jnow[-1,]*C[-1,],sqrt(verror),log=T),2,sum,na.rm=T),specindex,sum)
    pnew  <- tapply(apply(dnorm(Jdata[-1,],jnew[-1,]*C[-1,],sqrt(verror),log=T),2,sum,na.rm=T),specindex,sum)
	
	pnow  <- pnow + dnorm(alpha,priormat['prior.alpha',],priormat['prior.alpha',],log=T)
    pnew  <- pnew + dnorm(palpha,priormat['prior.alpha',],priormat['prior.alpha',],log=T)
    
    aa <- exp(pnew - pnow)
    z  <- runif(nspec,0,1)
    wa <- which(z < aa,arr.ind=T)
    alpha[wa] <- palpha[wa]
    uk[wa]  <- 1    
	
  list(alpha = alpha, uk = uk)
}

update_verror <- function(){

  jmat <- Jtmat[,site.sensor]
  jmat[is.na(Jdata)] <- NA

  mnow <- jmat*matrix(pred_jt(aig,bag,bstat,SECTION),nt,nprobe,byrow=T)  
  
  u1 <- v1 + length(notmiss)/2
  u2 <- v2 + .5*sum( (Jdata[notmiss] - mnow[notmiss])^2 ,na.rm=T)
  1/rgamma(1,u1,u2)

}
update_gt_CAP <- function(){


  Ev <- 1 - exp(-dt%*%t(tau[site.all[,'specindex']]^-1))   #stomatal lag
  smat <- matrix(0,dim(site.all)[1],nsite)

  deficit[1,] <- deficit_0

  C <- matrix(pred_jt(aig,ba,bstat,SECTION),nt,nprobe,byrow=T)
  if(PLOTSALA) C <- C*lrrat  
  jkeep <- (Jdata*0+1)
        
#  Jtmat <- Jtmat*0	
#  Wtmat <- Wtmat*0
  
  if(!year %in% seq(1980,2020,by=4))
     DT <- dt*365*24*60*60
  
  if(year %in% seq(1980,2020,by=4))
     DT <- dt*366*24*60*60

  
  for(t in 1:nt){

    smat <- smat*0
    V    <- rep(0,dim(site.all)[1])
    v    <- V
         
	#initialize Jtmat[t,] at t = starts to zero, since all starts are at 3am
#	if(t %in% starts){	 
	
#	  tmp <- WJcalc(Wtmat[t,]*0,Gtmat[t,]*e.qt[t,],dt[t],kap)
#        Wtmat[t,] <- tmp$W
#        Jtmat[t,] <- tmp$J
#	  }

	if(t %in% starts){	 
	
	  tmp <- WJcalc(Wtmat[t,]*0,0,DT[t],alpha)  #FIX
        Wtmat[t,] <- tmp$W
        Jtmat[t,] <- tmp$J
	  }
	  
    if(!t %in% starts){                                   #transition from t-1 to t
    #sap flux
	  
      tmp <- WJcalc(Wtmat[t-1,],Gtmat[t-1,]*e.qt[t-1,],DT[t-1],alpha)
        Wtmat[t,] <- tmp$W
        Jtmat[t,] <- tmp$J
	
      B <- Gtmat[t-1,] + (Gsmat[t,] - Gtmat[t-1,])*Ev[t-1,]
      v <- v + B/sigma/Ev[t-1,]
      V <- V + 1/sigma/Ev[t-1,]
    }
    if(!t %in% stops){                                  #transition from t to t+1

	  JKij <- (Jdata[t+1,] - alpha[site.sensor] * C[t,] * Wtmat[t,site.sensor] *( 1 - alpha[site.sensor])/DT[t]) * 
	          (alpha[site.sensor] * C[t,] * e.qt[t,site.sensor])
	  
	  JK2  <- (alpha[site.sensor] * C[t,] * e.qt[t,site.sensor])^2

	
      Vo  <- JK2 * jkeep[t,] /verror
      vo  <- JKij * jkeep[t,] /verror
	  
      V <- V + tapply(Vo,site.sensor,sum,na.rm=T)
      v <- v + tapply(vo,site.sensor,sum,na.rm=T)

      A  <- (Gtmat[t+1,] - Gsmat[t+1,]*Ev[t,])*(1 - Ev[t,])
      V  <- V + (1 - Ev[t,])^2/sigma/Ev[t,]
      v  <- v + A/sigma/Ev[t,]
    }
    
	#draw Gtmat[t,]
    
	Gtmat[t,] <- tnorm(dim(site.all)[1],priorgt.lo[t,],priorgt.hi[t,],v/V,sqrt(1/V))

#    if(!t %in% starts){                                   #transition from t-1 to t
    #sap flux
	  
#      tmp <- WJcalc(Wtmat[t-1,],Gtmat[t,]*e.qt[t,],dt[t-1],kap)
#        Wtmat[t,] <- tmp$W
#        Jtmat[t,] <- tmp$J
#    }
	#calculate Jtmat[t,] based on Jtmat[t-1,] and Gtmat[t,]
	  #if(!t %in% starts)
	  #  Jtmat[t,] <- Jtmat[t-1,] + (Gtmat[t,]*e.qt[t,] - Jtmat[t-1,])*Ew[t-1,]
	  
	#  LAItemp <- specvars[cbind(site.all[,'specindex'],c(1,4)[site.all[,'SITE']])]
    #Et[t,] <- tapply(1000*Gtmat[t,]*D[t,site.all[,'SITE']]*(Temp[t,site.all[,'SITE']]/273 + 1)/44600/
    #      (115.8 + .4226*Temp[t,site.all[,'SITE']])*LAItemp,site.all[,'SITE'],sum,na.rm=T)

    #if(t > 1)deficit[t,] <- deficit[t-1,] + Et[t,]*exp(ad - bd*deficit[t-1,])
    #deficit[t,is.finite(M[t,]) & M[t,] > moistdef] <- 0

  }

  list(Gtmat = Gtmat, Jtmat = Jtmat, Wtmat = Wtmat)

}


update_gt_NOCAP <- function(){


  Ev <- 1 - exp(-dt%*%t(tau[site.all[,'specindex']]^-1))   #stomatal lag
  #Ew <- 1 - exp(-dt%*%t(kap[site.sensor]^-1))   #capacitance lag

  deficit[1,] <- deficit_0

      e.qt <- qt(LAIspecies,SAPspecies,D[,site.all[,1]],Temp[,site.all[,1]])
      C <- matrix(pred_jt(aig,bag,bstat,SECTION),nt,nprobe,byrow=T)  
      e.qt <- e.qt[,site.sensor]
	  
      qa2 <- (e.qt^2*C^2)
      jqa <- Jdata*e.qt*C	
	  #jqa <- (Jdata[-1,]-(1-Ew)*Jdata[-nt,])*e.qt*C	
	  jkeep <- (Jdata*0+1)
	  
  for(t in 1:nt){

    V    <- rep(0,dim(site.all)[1])
    v    <- V
    
    	
  #observations
    Vo <- tapply(qa2[t,]*jkeep[t,]/verror,site.sensor,sum,na.rm=T)
	vo <- tapply(jqa[t,]*jkeep[t,]/verror,site.sensor,sum,na.rm=T)

	V <- Vo
	v <- vo
	
   if(!t %in% starts){                                   #transition from t-1 to t
    #sap flux
	#Vo <- tapply(qa2[t-1,]*Ew[t-1,]*jkeep[t-1,]/verror,site.sensor,sum,na.rm=T)
	#vo <- tapply(jqa[t-1,]*Ew[t-1,]*jkeep[t-1,]/verror,site.sensor,sum,na.rm=T)

	#V <- Vo
	#v <- vo

	#conductance
      B <- Gtmat[t-1,] + (Gsmat[t,] - Gtmat[t-1,])*Ev[t-1,]
      V <- V + 1/sigma/Ev[t-1,]
      v <- v + B/sigma/Ev[t-1,]
    }
    if(!t %in% stops){                                  #transition from t to t+1
      A  <- (Gtmat[t+1,] - Gsmat[t+1,]*Ev[t,])*(1 - Ev[t,])
      V  <- V + ((1 - Ev[t,])^2)/sigma/Ev[t,]
      v  <- v + A/sigma/Ev[t,]
    }
    Gtmat[t,] <- tnorm(dim(site.all)[1],priorgt.lo[t,],priorgt.hi[t,],v/V,sqrt(1/V))

	#  LAItemp <- specvars[cbind(site.all[,'specindex'],c(1,4)[site.all[,'SITE']])]
    #Et[t,] <- tapply(1000*Gtmat[t,]*D[t,site.all[,'SITE']]*(Temp[t,site.all[,'SITE']]/273 + 1)/44600/
    #      (115.8 + .4226*Temp[t,site.all[,'SITE']])*LAItemp,site.all[,'SITE'],sum,na.rm=T)

    #if(t > 1)deficit[t,] <- deficit[t-1,] + Et[t,]*exp(ad - bd*deficit[t-1,])
    #deficit[t,is.finite(M[t,]) & M[t,] > moistdef] <- 0

  }

  list(Gtmat = Gtmat)

}

update_rint <- function(){  #update random intercepts

  jmat <- Jtmat[,site.sensor]
  if(PLOTSALA) jmat<-jmat*lrrat
  jmat[is.na(Jdata)] <- NA
  rint <- meana[specindex]

    j2ik <- tapply(jmat[notmiss]^2,notmiss[,2],sum,na.rm=T)
    jjik <- tapply(jmat[notmiss]*Jdata[notmiss],notmiss[,2],sum,na.rm=T)

  if(!SECTION&!EFFSAI){
    evec <- exp(-(depth - bag[1,specindex])^2/2/(bag[2,specindex]^2))
    evec[depth<bag[1,specindex]] <- 1}
    
  if(SECTION) evec <- bag[cbind(depthindex,specindex)]
	if(EFFSAI) evec <- bag[cbind(depthindex,specindex)]*0+1/effsai
	
    v <- evec*(bstat[specindex]^Status)*jjik/verror + meana[specindex]/va
    V <- 1/((evec^2)*(bstat[specindex]^(2*Status))*j2ik/verror + 1/va)

    rint <- tnorm(nprobe,lor,hir,v*V,sqrt(V))
  if(EFFSAI){
  rave<-mean(rint)
  rint<-rint/rave/effsai}
  
  if(SECTION) {
	 if(length(DEPTH)==length(SAratio)){
	 rave<-0
		for(i in 1:length(DEPTH)){
		rave<-rave+mean(rint[depth==DEPTH[i]])*(SAratio[i])
		}
	 } else {	
	 rave<-mean(rint[depth==DEPTH[1]])*(SAratio[1])+mean(rint[depth==DEPTH[2]])*(SAratio[2]+SAratio[3])      
    	if(max(depth)==1){
		rave<-mean(rint[depth==1])/outer.ratio
		}
  	}
	rint<-rint/as.numeric(rave[1])
}
  ## rescale to intercept
  if(!SECTION&!EFFSAI) rint <- rint * meana[specindex] / tapply(rint,specindex,mean)[specindex]  
  rint

}

update_va <- function(){    #variance for random effects

  z1 <- va1 + nprobe/2
  z2 <- va2 + .5*sum( (aig-meana[specindex])^2) 
  1/rgamma(1,z1,z2)
}

priormatrix <- function(){  #set up prior matrix, values not species-specific

priorlist <- c('prior.A','prior.sdA','loA','hiA','prior.B1','prior.B2',
               'prior.B3','prior.B4',
               'prior.sd1','prior.sd2','prior.sd3','prior.sd4',
               'loB1','loB2','loB3','loB4','hiB1','hiB2','hiB3','hiB4',
               'prior.G','prior.sdG','loG','hiG','prior.ba1','prior.ba2',
               'prior.sda1','prior.sda2',
               'prior.aig',
               'loba1','loba2','hiba1','hiba2',
               'prior.tau','prior.sdtau','lotau','hitau',
			   'prior.alpha','prior.sdalpha','loalpha','hialpha',
			   'prior.bstat','lobstat','hibstat','prior.Vbst')
nprior <- length(priorlist)

priormat <- matrix(0,nprior,nspec)
colnames(priormat) <- species
rownames(priormat) <- priorlist

priormat['prior.A',]    <- .6
priormat['prior.sdA',]  <- 25   #old   
if(!Dreg) priormat['prior.sdA',]  <- .2  #new
priormat['loA',]        <- 0.45
priormat['hiA',]        <- 0.85

priormat['prior.sdG',]  <- 50

priormat['prior.B1',]   <- .95  #light
priormat['prior.B2',]   <- 400 #mmol m-2 s-1

priormat['prior.sd1',]  <- .1
priormat['prior.sd2',]  <- 200
priormat['loB1',]       <- .8
priormat['loB2',]       <- 200
priormat['hiB1',]       <- .99
priormat['hiB2',]       <- 600   

if (DEF){
priormat['prior.B3',]   <- .5   #deficit
priormat['prior.B4',]   <- .5
priormat['prior.sd3',]  <- .5
priormat['prior.sd4',]  <- 1
priormat['hiB3',]       <- 4
priormat['hiB4',]       <- 1
priormat['loB3',]       <- 0
priormat['loB4',]       <- .1
}
if(!DEF & !RELM){
priormat['prior.B3',]   <- .25   #measured moisture
priormat['prior.B4',]   <- mean(M)
priormat['prior.sd3',]  <- 1
priormat['prior.sd4',]  <- 1
priormat['hiB3',]       <- .5
priormat['hiB4',]       <- max(M)
priormat['loB3',]       <- .05
priormat['loB4',]       <- min(M)
}
if(!DEF & RELM){
priormat['prior.B3',]   <- .2   #measured moisture
priormat['prior.B4',]   <- max(.35,min(M))
priormat['prior.sd3',]  <- .5
priormat['prior.sd4',]  <- .1
priormat['hiB3',]       <- 0.4
priormat['hiB4',]       <- 0.6
priormat['loB3',]       <- .02
priormat['loB4',]       <- 0.1
}

priormat['loba1',]         <- .01  #data model
priormat['loba2',]         <- .1
priormat['hiba1',]         <- 1
priormat['hiba2',]         <- 1
if(SECTION){
priormat['loba1',]         <- 0.1  #data model for section sapwood
priormat['hiba1',]         <- 2
}

priormat['prior.sda1',]    <- .001
priormat['prior.sda2',]    <- .001
priormat['prior.bstat',]   <- 1
priormat['lobstat',]       <- .2
priormat['hibstat',]       <- 4
priormat['prior.Vbst',]    <- .5

priormat['prior.aig',]     <- #2 #dummy value for pita
                              rep(1,nspec)        #relativized to outer xylem
                              #c(1.56658,1.557963,1.431794,1.0,1.0)  #mean
                              #c(1,1.557963,1.431794,1.0,1.0)        #mean_acruFLAT

priormat['loG',]       <- 10
priormat['hiG',]       <- 250

priormat['prior.tau',]   <-   10/60/24/365   #based on Woods and Turner 1971 and Naumberg and Ellsworth 2000
priormat['prior.sdtau',] <-   1/60/24/365  
priormat['lotau',]       <-    10/60/24/365  
priormat['hitau',]       <-  10/60/24/365 

#ALPHA in seconds^-1
priormat['prior.alpha',]   <-  2/3600 #((1-exp(-1))^(TC))/(1-(1-exp(-1))^(TC)) 
if(year %in% seq(1980,2020,by=4)) priormat['prior.alpha',]   <-  1/366/24
priormat['prior.sdalpha',] <-   2/3600  
priormat['loalpha',]       <-  1/3600/3#((1-exp(-1))^(TC))/(1-(1-exp(-1))^(TC)) #30/60/24/365  
priormat['hialpha',]       <-  4/3600#((1-exp(-1))^(TC))/(1-(1-exp(-1))^(TC)) #30/60/24/365 

priormat

}

specpriors <- function(sname){  #species-specific priors

  if(sname %in% c('acru','ACRU')){
    gmean <- 88 
	bamean <- c(.1375,.4555)  #curved acru
              #c(1,.4)      #flat acru
  }
  if(sname %in% c('cato','CATO')){
    gmean <- 44
    bamean <- c(.1,.4)
  }
  if(sname %in% c('LIST','list')){
    gmean <- 85
    bamean <- c(.222,.343)
  }
  if(sname %in% c('LITU','litu')){
    gmean <- 97
    bamean <- c(.055,.568)
  }
  if(sname == 'pita'){
    gmean <- 110
    bamean <- c(1/13.5,0.196) #based on results of Ford et al. 2004
  }
  if(sname %in% c('QUAL','qual')){
    gmean <- 18
    bamean <- c(1,.4)
  }
  if(sname %in% c('QUST','qust')){
    gmean <- 18
    bamean <- c(1,.4)
  }
  if(sname %in% c('QUMI','qumi')){
    gmean <- 18
    bamean <- c(1,.4)
  }
  if(sname %in% c('QUPH','quph')){
    gmean <- 126
    bamean <- c(1,.4)
  }
  if(sname %in% c('QURU','quru')){
    gmean <- 126
    bamean <- c(1,.4)
  }
  
  list(g = gmean, ba = bamean)
}

###########################################


getTime <- function(input) {
  ly <- seq(1980,2020,by=4)
  xxx<-which(input[,'year'] %in% ly)

  if(max(input[,'Time'])>=30)
    out <- input[,'year'] + (input[,'DOY']-1)/365 + trunc(input[,'Time']/100)/24/365 + 
	       (input[,'Time']-trunc(input[,'Time']/100)*100)/60/24/365
  if(max(input[,'Time'])<30)
    out <- input[,'year'] + (input[,'DOY']-1)/365 + input[,'Time']/24/365
  
	
  if(length(xxx)>0){
    if(max(input[xxx,'Time'])>=30) 
      out[xxx] <- input[xxx,'year'] + (input[xxx,'DOY']-1)/366 + trunc(input[xxx,'Time']/100)/24/366 + 
	              (input[xxx,'Time']-trunc(input[xxx,'Time']/100)*100)/60/24/366
    if(max(input[xxx,'Time'])<30) 
      out[xxx] <- input[xxx,'year'] + (input[xxx,'DOY']-1)/366 + input[xxx,'Time']/24/366
    }
  out
  }

getDay <- function(input) {
ly <- seq(1980,2020,by=4)
  outx<-input[,'year'] + (input[,'DOY']-1)/365
  xxx<-which(input[,'year'] %in% ly)
  outx[xxx]<-input[xxx,'year'] + (input[xxx,'DOY']-1)/366
  outx
  }

###############################
snip <- function(tm,st1, st2){
  ly <- seq(1980,2020,by=4)

  tm <- tm-trunc(tm)
  hhmm <- seq(0.5,2,.5)/24
  
  eq <- which(findInterval(tm*365 - trunc(tm*365),hhmm)==1) #times at equilibrium
  if(trunc(timeall[1]) %in% ly)
    eq <- which(findInterval(tm*366 - trunc(tm*366),hhmm)==1) #times at equilibrium
  
  snew1 <- eq[min(which(eq>=st1))]
  snew2 <- eq[max(which(eq<=st2))]

  list(snew1 = snew1, snew2 = snew2)    
  }  
  
###########################################  

inData <- function(){
    
  for(j in 1:length(year)){
    if(j == 1){
	b2       <- as.matrix(read.csv(SENS.FILE[j],header=T))  #import sensor metadata
      datamat  <- as.matrix(read.csv(FLUX.FILE[j],header=T))  #import sensor flux data

      leafarea <- as.matrix(read.csv(LAI.FILE[j],header=T))   #import leaf area data
      saparea  <- as.matrix(read.csv(SAI.FILE[j],header=T))   #import sapwood area data

      Q.dat<-as.matrix(read.csv(PAR.FILE[j],header=T))        #import light data
      M.dat<-as.matrix(read.csv(SM.FILE[j],header=T))         #import soil moisture data
      D.dat<-as.matrix(read.csv(VPD.FILE[j],header=T))        #import vpd data
      T.dat<-as.matrix(read.csv(TEMP.FILE[j],header=T))       #import temperature data
      }
	if(j>1){
	  datamat  <- rbind(datamat,as.matrix(read.csv(FLUX.FILE[j],header=T)))
	  leafarea <- rbind(leafarea,as.matrix(read.csv(LAI.FILE[j],header=T)))
	  saparea  <- rbind(saparea,as.matrix(read.csv(SAI.FILE[j],header=T)))
	  
	  Q.dat <- rbind(Q.dat,as.matrix(read.csv(PAR.FILE[j],header=T)))
	  M.dat <- rbind(M.dat,as.matrix(read.csv(SM.FILE[j],header=T)))
	  D.dat <- rbind(D.dat,as.matrix(read.csv(VPD.FILE[j],header=T)))
	  T.dat <- rbind(T.dat,as.matrix(read.csv(TEMP.FILE[j],header=T)))
	  }
    }
  leafarea<-leafarea[is.na(leafarea[,1])==0,]
  
  LAIspecies <- leafarea         #leaf area (m^2 m^-2)
  if (SAIunits==0) SAPspecies <- saparea   #sapwood area (m^2 m^-2)
  if (SAIunits==1) SAPspecies <- saparea/10000    #sapwood area (m^2 m^-2)
  
  probe   <- b2[,'colname']      #probe name
  pindex  <- which(colnames(datamat) %in%  probe,arr.ind=T) #columns with flux data
  if(length(pindex)<1){
	 for(i in 1:length(probe)){probe[i]<-paste('X',probe[i],sep='')}
  	 pindex  <- which(colnames(datamat) %in%  probe,arr.ind=T) #columns with flux data
}
   ddm<-dim(datamat)
   cnm<-colnames(datamat)
   datamat<-matrix(as.numeric(datamat),ddm[1],ddm[2])
   colnames(datamat)<-cnm

  if(TC>0) { #lag data by TC timesteps
	datamat <- datamat[-(1:TC),]

	D.dat       <- D.dat[-((nt-(TC-1)):dim(D.dat)[1]),]
	Q.dat       <- Q.dat[-((nt-(TC-1)):dim(Q.dat)[1]),]
	M.dat       <- M.dat[-((nt-(TC-1)):dim(M.dat)[1]),]
	T.dat       <- T.dat[-((nt-(TC-1)):dim(T.dat)[1]),]

	saparea          <- saparea[-((nt-(TC-1)):dim(saparea)[1]),]
	
    }
  
  #indices for covariates
  Q.col   <- colnames(Q.dat)[-(1:4)]
  D.col   <- colnames(D.dat)[-(1:4)]
  M.col   <- colnames(M.dat)[-(1:4)]
  T.col   <- colnames(T.dat)[-(1:4)]

  #species names and indices
  species <- as.character(sort(unique(b2[,'Species'])))
  nspec   <- length(species)
  specindex <- match(b2[,'Species'],species)

  #plot names and indices
 if(DATA=='face') plots   <- as.character(sort(unique(b2[,'Ring'])))
 if(DATA=='wireless') plots   <- as.character(sort(unique(b2[,'Site']))) 
 if(DATA=='other') plots   <- as.character(sort(unique(b2[,'Rep']))) 
 nplot   <- length(plots)
  if(DATA=='face') plotindex <- match(b2[,'Ring'],plots)
  if(DATA=='wireless') plotindex <- match(b2[,'Site'],plots)
  if(DATA=='other') plotindex <- match(b2[,'Rep'],plots)
    
  #ratio of sapwood at different depths
  SAratio <- numeric(0)
  if(SECTION) {
    SAratio <- as.matrix(read.csv(DIST.FILE,header=T))  
	  snames <- colnames(SAratio)
        SAratio <- SAratio[SAratio[,'year']==year,]
	if(length(dim(SAratio))>1) SAratio<-SAratio[match(Treat,SAratio[,'Treat']),]
  	  SAratio <- matrix(SAratio, ncol=NSECTION+3)
	  colnames(SAratio) <- snames
	}
	
  specvars <- matrix(NA,nspec,nplot)
  cs <- 'n'
  colnames(specvars) <- outer(cs,plots,paste,sep='-')
  rownames(specvars) <- species

  if(DATA=='face') {spectab <- table(b2[,'Species'],b2[,'Ring'])}
  if(DATA=='wireless'){spectab <- table(b2[,'Species'],b2[,'Site'])}
  if(DATA=='other'){spectab <- table(b2[,'Species'],b2[,'Rep'])}
  
  for (i in 1:nplot) specvars[,paste('n-',plots[i],sep="")] <- spectab[,plots[i]]

  Q     <- numeric(0)
  D     <- numeric(0)
  M     <- numeric(0)
  Temp  <- numeric(0)
  Jdata <- numeric(0)

 datacols <- c('year','JDT','DOY','Time')

 dgaps   <- numeric(0)

 
   #get data range (set to whole range now)
   checkrow <- apply(is.finite(datamat[,pindex]),1,sum,na.rm=T)
   #cc      <- min(which(cumsum(checkrow) > 0),na.rm=T)
   #if(min(which(LAIspecies>0))>cc) 

   cc<-1
   cm<-length(datamat[,1])
   #cm      <- max(which(checkrow > 0),na.rm=T)



   #get gaps
   crow  <- which(checkrow > 0)
   gaps  <- diff(crow)
   dd    <- which(gaps > gapfill)
   dgaps <- c(dgaps,dd)

   skipit <- numeric(0)
   if(cc>1) skipit <- c(1:(cc-1))

   if(length(dd)>0)
   for(jj in 1:length(dd)){
     skipit <- c(skipit,c((1+crow[dd[jj]]):(crow[dd[jj]] + gaps[dd[jj]])))
   }
   if(cm<nrow(datamat)) skipit <- c(skipit,c((cm+1):nrow(datamat)))
   
   #create keep vectors
   checkrow <- c(1:nrow(datamat))
   if(length(skipit)>0) checkrow <- checkrow[-skipit]

   Q.keep    <- match(getTime(datamat[checkrow,]),getTime(Q.dat))
   D.keep    <- match(getTime(datamat[checkrow,]),getTime(D.dat))
   M.keep    <- match(getTime(datamat[checkrow,]),getTime(M.dat))
   Temp.keep <- match(getTime(datamat[checkrow,]),getTime(T.dat))
   LAI.keep  <- match(getDay(datamat[checkrow,]),getDay(leafarea))
   #SAI.keep  <- match(getTime(datamat[checkrow,]),getTime(saparea))
   SAI.keep  <- match(round(getTime(datamat[checkrow,]),7),round(getTime(saparea),7))
   SITE <- matrix(unlist(strsplit(Q.col,"\\.")),ncol=length(Q.col))[2,]
   LSITE<-SITE
   if(!MULTCAN) SITE <- SITE[can.choose]

  if(DATA=='face'){
  	#if(MULTCAN){
  	siteindex <- match(b2[,'Ring'],LSITE)#}else{
  		#siteindex<-rep(1,length(b2[,1]))
  		#}
  	}
   if(DATA=='wireless'){siteindex <- match(b2[,'Site'],SITE)}
   if(DATA=='other'){siteindex <- (b2[,'Rep'])}
     
   if(DATA=='face') tmp <- match(paste(species[specindex],".R",SITE[siteindex],".",Fert,sep=""),colnames(leafarea))
   if(DATA=='wireless') tmp <- match(paste(species[specindex],SITE[siteindex],sep="."),colnames(leafarea))
   if(DATA=='other') tmp <- match(paste(species[specindex],".R",siteindex,".",Treat,sep=""),colnames(leafarea))
   
###start here###
   
   if(MULTCAN){
     Q      <- Q.dat[Q.keep,Q.col]           #automate ncol
     D      <- D.dat[D.keep,D.col]           #automate ncol
     M      <- M.dat[M.keep,M.col] #automate ncol
     if(max(M,na.rm=T) > 1) M <- M/100     #if in percent change to fraction
     Temp   <- T.dat[Temp.keep,T.col]           #automate ncol
     }
	 
   if(!MULTCAN) {
     Q      <- matrix(Q.dat[Q.keep,Q.col[matrix(unlist(strsplit(Q.col,"\\.")),2)[2,]==SITE]],ncol=1)           #automate ncol
     D      <- matrix(D.dat[D.keep,D.col[matrix(unlist(strsplit(D.col,"\\.")),2)[2,]==SITE]],ncol=1)           #automate ncol
     M      <- matrix(M.dat[M.keep,M.col[matrix(unlist(strsplit(M.col,"\\.")),2)[2,]==SITE]],ncol=1)           #automate ncol
     if(max(M,na.rm=T) > 1) M <- M/100                     #if in percent change to fraction
     Temp   <- matrix(T.dat[Temp.keep,T.col[matrix(unlist(strsplit(T.col,"\\.")),2)[2,]==SITE]],ncol=1)        #automate ncol
	 }

  #exclude time points where no data are available at 
  #  beginning and end of study period 
  Jdata  <- datamat[checkrow,pindex]
  if(DATA=='face') tmp2 <- match(paste(species[specindex],".R",LSITE[siteindex],".",Fert,sep=""),colnames(leafarea))
  if(DATA=='wireless') tmp2 <- match(paste(species[specindex],".",LSITE[siteindex],sep=""),colnames(leafarea))
    if(DATA=='other') tmp2 <- match(paste(species[specindex],".R",siteindex,".",Treat,sep=""),colnames(leafarea))
    
  if(SAIunits==1){ 
	SAPtree <- saparea[SAI.keep,tmp2]/10000
	SAPspecies <- saparea[SAI.keep,sort(unique(tmp))]/10000}
  if(SAIunits==0){
 	SAPtree <- saparea[SAI.keep,tmp2]
	SAPspecies <- saparea[SAI.keep,sort(unique(tmp))]}

  LAItree <- leafarea[LAI.keep,tmp2]
  
  LAIspecies <- leafarea[LAI.keep,sort(unique(tmp))]

  if(!MULTCAN) {
    SAPspecies <- matrix(0,nrow(LAItree),ncol=nspec)
    LAIspecies <- matrix(0,nrow(LAItree),ncol=nspec)
    for(s in 1:nspec){
	if(DATA=='face') tmp <- match(paste(species[specindex[specindex==s]],".R",SITE[siteindex[specindex==s]],".",Fert,sep=""),colnames(leafarea))
 if(DATA=='wireless') tmp <- match(paste(species[specindex[specindex==s]],SITE[siteindex[specindex==s]],sep="."),colnames(leafarea))
  if(DATA=='other') tmp <- match(paste(species[specindex[specindex==s]],'.R',siteindex[specindex==s],'.',Treat,sep=""),colnames(leafarea))
	if(length(unique(tmp2))>1){
		if(SAIunits==1) SAPspecies[,s] <- apply(saparea[SAI.keep,unique(tmp2)]/10000,1,mean,na.rm=T)
		if(SAIunits==0) SAPspecies[,s] <- apply(saparea[SAI.keep,unique(tmp2)],1,mean,na.rm=T)
      	LAIspecies[,s] <- apply(leafarea[LAI.keep,unique(tmp2)],1,mean,na.rm=T)	
	  }else{
		if(SAIunits==1) SAPspecies[,s] <-saparea[SAI.keep,unique(tmp2)]/10000
		if(SAIunits==0) SAPspecies[,s] <-saparea[SAI.keep,unique(tmp2)]
 		LAIspecies[,s] <- leafarea[LAI.keep,unique(tmp2)]	  	
	  	}
	}}
	
  datamat <- datamat[checkrow,]

  
  #year  <- unique(datamat[,'year'])
  yrvec <- datamat[,'year']
  timeall <- getTime(datamat)
  nt   <- length(timeall)
  dt   <- diff(timeall)
  Jdata[!is.finite(Jdata)] <- NA

  #vectors of starts and stops to remove data gaps
  gaps <- which(diff(timeall) > diff(timeall)[1]*gapfill) + 1  #where new seq begins
  starts <- c(1,gaps)
  stops  <- c((gaps-1),nt)  
  #dt[stops[-length(stops)]] <- dt[starts[-1]]  #what does this do?

  #plot covariates
  if(length(M)==nt){
    par(mfrow=c(5,1),mar=c(2,4,2,2))
    plot(timeall,Temp,type='l')
    plot(timeall,D,type='l')
    plot(timeall,Q,type='l')
    plot(timeall,M,type='l',ylim=range(M,na.rm=T))
  }
  
  if(length(M)>nt){
    par(mfrow=c(5,1),mar=c(2,4,2,2))
    plot(timeall,Temp[,1],type='l')
    plot(timeall,D[,1],type='l')
    plot(timeall,Q[,1],type='l')
    plot(timeall,M[,1],type='l',ylim=range(M,na.rm=T))
  }
  
#  ntime <- length(keeptime)
 
  ntree <- nrow(b2) #number of sensors

  Status <- as.integer(b2[,'Status'])  #0 - suppressed, 1 - codominant

  #Jdata[wdD,] <- NA

  nprobe  <- ncol(Jdata) #number of sensors, why repeat this???

  #plot sap flux data
  plot(timeall,Jdata[,1],col=1,ylim=c(0,150),type='l')
  for(j in 1:nprobe){
   lines(timeall,Jdata[,j],col=j)
  }

  # draw depth values
  if(SECTION|EFFSAI) depth <- as.numeric(b2[,'Depth'])
  if(EFFSAI&max(depth)>1) print('Should use only depth 1 sensors if EFFSAI selected')
  if(!SECTION&!EFFSAI)  {
    rad <- matrix(NA,dim(b2)[1],2)
    
	for(j in 1:length(species))
	  rad[which(b2[,'Species']==species[j]),2] <- 
	    dib(species[j],as.numeric(b2[b2[,'Species']==species[j],paste('DBH',min(year),sep="")]))/2 	#is it okay to use the minimum year?
  
    for(j in 1:dim(rad)[1])
      rad[j,1] <- hd(b2[j,'Species'],rad[j,2]*2)/2
      colnames(rad) <- c('rin','rout')

	depth <- as.numeric(b2[,'Depth'])/apply(rad,1,diff)
	
	}
  
  #if(RELM & MULTCAN) M <- (M - matrix(apply(M,2,min),nt,ncol(M),byrow=T))/
  #              (matrix(apply(M,2,max),nt,ncol(M),byrow=T) - matrix(apply(M,2,min),nt,ncol(M),byrow=T))

  #if(RELM & !MULTCAN) M <- (M - min(M))/(max(M) - min(M))
             	
  list(Q = Q, M = M, D = D, Temp = Temp, ntree = ntree, nprobe = nprobe, 
       depth = depth, Status = Status, Jdata = Jdata, starts = starts, 
       stops = stops, gaps = gaps, timeall = timeall, nt = nt, plots = plots, nplot = nplot, 
       LAIspecies = LAIspecies, LAItree = LAItree, specindex = specindex, plotindex = plotindex, 
       siteindex = siteindex, SAPspecies = SAPspecies, SAPtree = SAPtree, probe = probe, SITE = SITE, 
       species = species, nspec = nspec, specvars = specvars, SAratio = SAratio)

}

spltname <- function(x,on) return(matrix(unlist(strsplit(x,on)),length(x),byrow=T))


getSection <- function(){

  if(!MultYear ) wt <- which(trunc(timeall)%in%year & (timeall-trunc(timeall)) >= intval[1] & (timeall-trunc(timeall)) <= intval[2])
  if(MultYear )  wt <- which((timeall-year) >= intval[1] & (timeall-year) <= intval[2])

  nt      <- length(wt)
  stri    <-findInterval(starts,wt,all.inside=T)
  stri    <-stri[which(stri!=(nt-1))]
  stpi	  <-findInterval(stops,wt,all.inside=T)
  stpi    <-stpi[which(stpi!=1)]
  st1     <- unique(wt[stri])
  st2     <- unique(wt[stpi])
 
  if(!wt[1] %in% st1)  st1 <- c(wt[1],st1)
  if(!wt[nt] %in% st2) st2 <- c(st2,wt[nt])

  ##begin -- start and stop timeseries at 3am
  #tmp <- snip(timeall,st1,st2)
   # st1 <- tmp$snew1
    #st2 <- tmp$snew2
  
  #if start isn't bw midnite and 4 am, make next midnite
   ly <- seq(1980,2020,by=4)
  tm <- timeall[wt]-trunc(timeall[wt])
   if(trunc(timeall[1]) %in% ly){
   	ddd<-366}else{ddd<-365}
   	ttt<-tm*ddd - trunc(tm*ddd)
 if(ttt[1]>4/24){st1<-st1+floor(24-ttt[1]*24)*2}

  
  
  tmp <- as.integer()
  for(j in 1:length(st1))
    tmp <- c(tmp,st1[j]:st2[j])
  wt <- tmp
  ##end
	
  timenew <- timeall[wt]

  st1     <- st1 - wt[1] + 1
  st2     <- st2 - wt[1] + 1

  timeall <- timenew
  nt      <- length(timeall)

  abline(v=c(timeall[1],timeall[nt]),lwd=5,col='red')

  gaps <- which(diff(timeall) > diff(timeall)[1]*gapfill) + 1  #where new seq begins
  starts <- c(1,gaps)
  stops  <- c((gaps-1),nt)  

  Jdata <- Jdata[wt,]

  np <- nsite
  if(!MULTCAN) np <- nsite

    Temp  <- matrix(Temp[wt,],ncol=np)
    Q     <- matrix(Q[wt,],ncol=np)
    M     <- matrix(M[wt,],ncol=np)
    D     <- matrix(D[wt,],ncol=np)

	
  LAItree    <- matrix(LAItree[wt,],length(wt))
  LAIspecies <- matrix(LAIspecies[wt,],length(wt))
  SAPtree    <- matrix(SAPtree[wt,],length(wt))
  SAPspecies <- matrix(SAPspecies[wt,],length(wt))
  
  deficit <- matrix(0,nt,np)
  dt    <- diff(timeall)
  dt[stops[-length(stops)]] <- dt[starts[-1]]
  dt[stops[-length(stops)]] <- dt[starts[-1]]
  
  dt[dt > dt[1]*2] <- dt[1]*2  #remove large dt's
  
#  #gap fill soil moisture --temporary
#    for(ss in 1:np) {
#      y  <- diff(log(M[,ss]))
#      wy <- which(y < .02,arr.ind=T)
#      y  <- y[wy]
#      x <- cbind(rep(1,nt),M[,ss],Temp[,ss])[-nt,]
#      x  <- x[wy,]
#      b  <- solve(crossprod(x))%*%crossprod(x,y)
#      for(t in 1:(nt-1)){
#  	    if(!is.finite(M[t+1,ss])){
#  	 	  M[t+1,ss] <- M[t,ss]*exp(as.vector(c(1,M[t,ss],Temp[t,ss]))%*%b)
#  	}}}
	
if(np==1){  
  par(mfrow=c(5,1),mar=c(2,4,2,2))
  plot(timeall,Temp,type='l')
  plot(timeall,D,type='l')
  plot(timeall,Q,type='l')
  plot(timeall,M,type='l')
  plot(timeall,Jdata[,1],ylim=c(0,100),type='l')
  for(j in 1:nprobe){
   lines(timeall,Jdata[,j],col=j)
   }

  for(j in 1:length(starts)){
   xx <- timeall[starts[j]:stops[j]]
   lines(xx,rep(100,length(xx)),lwd=5)
   }
  }
if(np>1) {
  par(mfrow=c(5,1),mar=c(2,4,2,2))
  plot(timeall,Temp[,1],type='l')
  plot(timeall,D[,1],type='l')
  plot(timeall,Q[,1],type='l')
  plot(timeall,M[,1],type='l')
  plot(timeall,Jdata[,1],ylim=c(0,100))
  for(j in 1:nprobe){
   lines(timeall,Jdata[,j],col=j)
   }

  for(j in 1:length(starts)){
   xx <- timeall[starts[j]:stops[j]]
   lines(xx,rep(100,length(xx)),lwd=5)
   }
  }  

  list(starts = starts, stops = stops, Jdata = Jdata, Temp = Temp, 
       Q = Q, M = M, D = D, deficit = deficit, timeall = timeall, dt = dt,
	   LAItree = LAItree, LAIspecies = LAIspecies, SAPtree = SAPtree, 
	   SAPspecies = SAPspecies)
}


## plot midday Js by parameter
midJs <- function(Js,covar,label,i) {
  TT <- which((365*(timeall-2007)-trunc(365*(timeall-2007)))>.45 & 
              (365*(timeall-2007)-trunc(365*(timeall-2007)))<.55)
  Jscol <- which(specindex==i)
  covar <- covar[TT]
  for (m in 1:length(Jscol)) {
    if(m==1) plot(covar,Js[TT,Jscol[m]],xlab=label,ylab='Js',main=species[i],
                  xlim=range(covar,na.rm=T),ylim=range(Js[TT,],na.rm=T))
    if(m>1) points(covar,Js[TT,Jscol[m]],col=m)
  }
}

plot.lags <-function() {
 meanlag  <- rep(0,nprobe+nspec)
hours    <- 24*(365*(timeall-trunc(timeall))-trunc(365*(timeall-trunc(timeall))))   
hours <- which(hours>=0 & hours<=24) 

par(mfrow=c(3,4))
  QT <- qt(LAIspecies[j], mean(SAPtree[specindex==j]), D[hours], Temp[hours])
  for (j in 1:nprobe) {
    ccx <- ccf(D[hours],Jdata[hours,j],type='correlation',lag.max=6,
    na.action=na.contiguous,plot=F)
    print(paste(probe[j],species[specindex[j]],Status[j],sep='-'))
    print(ccx)
    plot(ccx,type='l',main=paste(probe[j],species[specindex[j]],Status[j],sep='-'))
    meanlag[j] <- ccx[[4]][which(ccx[[1]]==max(ccx[[1]]))]
    abline(v=meanlag[j])
  }
  
  ccx <- ccf(D[hours],apply(Jdata[hours,which(specindex==1)],1,mean,na.rm=T),type='correlation',lag.max=6,
  na.action=na.contiguous,plot=F)
  print(species[1])
  print(ccx)
  plot(ccx,type='l',main='average')
  meanlag[nprobe+1] <- ccx[[4]][which(ccx[[1]]==max(ccx[[1]]))]
  abline(v=meanlag[nprobe+1])
  for(j in 2:nspec) {
    ccx <- ccf(D[hours],apply(Jdata[hours,which(specindex==j)],1,mean,na.rm=T),type='correlation',lag.max=6,
    na.action=na.exclude,plot=F)
    print(species[j])
    print(ccx)
    lines(ccx[['lag']],ccx[['acf']],col=j)
    meanlag[nprobe+j] <- ccx[[4]][which(ccx[[1]]==max(ccx[[1]]))]
    abline(v=meanlag[nprobe+j],col=j)  
  }
  legend('topleft',legend=species,text.col=1:4)
 

pdf('lags.pdf')
par(mfrow=c(1,1))
for(j in 1:nprobe){
  plot(timeall,Jdata[,j],ylim=c(0,100),type='l',lwd=3,xlim=c(2007.68,2007.69))
#  lines(timeall,Jpred[,j],col='red')
  title(paste(species[specindex[j]],Status[j],probe[j],sep='-'))
  lines(timeall[-((nt-2):nt)],Jdata[-(1:3),j],col='blue',lwd=2,lty=2)
  lines(timeall,D*10,col='blue',lwd=2)
  lines(timeall,Q/50,col='orange',lwd=2)
#  lines(timeall,gmean[,specindex[j]],col='purple')
  legend('topleft',legend=c('Jdata','D*10','Q/50'),text.col=c('black','blue','orange'))
  abline(v=seq(2007,2008,by=1/365),lty=2)
}

#dev.print(device=postscript,file='conductanceBySpec.ps',width=7, height=10, horizontal=FALSE)
dev.off()

}

loop.conv <- function() {
    par(mfrow=c(5,max(2,nspec)),mai=c(.2,.4,.4,.1))
    for(jj in 1:nspec) {
      plot(1:g,ggibbs[1:g,jj],type='l',xlab='gibbs step',
           ylab=colnames(ggibbs)[jj],main=colnames(ggibbs)[jj])
	  lines((g-39):g,ggibbs[(g-39):g,jj],col='red')
      }
    for(jj in 1:nspec) {
      plot(1:g,agibbs[1:g,jj],type='l',xlab='gibbs step',
           ylab=colnames(agibbs)[jj],main=colnames(agibbs)[jj])
	  lines((g-39):g,agibbs[(g-39):g,jj],col='red')
	  }
    for(jj in 1:nspec) {
      plot(lgibbs[1:g,jj*2-1],lgibbs[1:g,jj*2],type='l',xlab='bl1',
           ylab='bl2',main=species[jj])
	  lines(lgibbs[(g-39):g,jj*2-1],lgibbs[(g-39):g,jj*2],col='red')
      }
    for(jj in 1:nspec) {
      plot(mgibbs[1:g,jj*2-1],mgibbs[1:g,jj*2],type='l',xlab='bm1',
           ylab='bm2',main=species[jj])
	  lines(mgibbs[(g-39):g,jj*2-1],mgibbs[(g-39):g,jj*2],col='red')
      }
   plot(1:g,vgibbs[1:g,1],type='l',xlab='gibbs step',
           ylab=colnames(vgibbs)[1],main=colnames(vgibbs)[1])
      plot(1:g,vgibbs[1:g,2],type='l',xlab='gibbs step',
           ylab=colnames(vgibbs)[2],main=colnames(vgibbs)[2])   
      plot(1:g,vgibbs[1:g,3],type='l',xlab='gibbs step',
           ylab=colnames(vgibbs)[3],main=colnames(vgibbs)[3])   
  
  if(mean(agibbs[(g-39):g,],na.rm=T)>5)
    boxplot(as.data.frame(agibbs[(g-39):g,]/ggibbs[(g-39):g,]),labels=species,
	  main='lambda:Gref')
  if(mean(agibbs[(g-39):g,],na.rm=T)<5)
    boxplot(as.data.frame(agibbs[(g-39):g,]),labels=species,
	  main='lambda')

    boxplot(as.data.frame(vgibbs[(g-39):g,grep('kap',colnames(vgibbs))]),labels=species,
	  main='kappa')
	  
  }
	  
	  
#calculate sensitivities
getSens <- function(x,b,sigma,r,q){

  rs   <- c(1:2)[c(1:2) != r]
  k <- dim(x)[2]
  
  kseq <- c(1:k)
  kInt <- grep('X',colnames(x))
  kMain <- kseq[-kInt]

  main4X <- matrix(unlist(strsplit(colnames(x)[kInt],'X')),ncol=2,byrow=T)

  sumq1 <- sumq2 <- 0

  for(j in kInt){

     sumq1 <- sumq1 + b[j,r]*x[,j]
     sumq2 <- sumq2 + b[j,rs]*x[,j]

  }

  b[q,r] + sumq1 + sigma[1,2]/sigma[rs,rs]*(b[q,rs] + sumq2)
}	  

cov.plot <- function(){
  for(j in 1:length(year)){
    ly  <- seq(1980,2020,by=4)
    ykeep <- which(trunc(timeall)==year[j])
    tmp <- which(trunc(((timeall[ykeep]-trunc(timeall[ykeep]))*365-
           trunc((timeall[ykeep]-trunc(timeall[ykeep]))*365))*24)==12)
    if(year[j] %in% ly)
    tmp <- which(trunc(((timeall[ykeep]-trunc(timeall[ykeep]))*366-
           trunc((timeall[ykeep]-trunc(timeall[ykeep]))*366))*24)==12)
    if(j==1) mid <- tmp
    if(j>1)  mid <- c(mid,tmp)
    }
  
  par(mfrow=c(1,1),family='serif')
  pairs(cbind(D[mid,1],Q[mid,1],M[mid,1]),labels=c(expression(italic(D[t])),expression(italic(Q[t])),expression(italic(M[jt]))))
  cov.cor <- cor(cbind(D[mid,1],Q[mid,1],M[mid,1]))
  
  cov.cor

  }
