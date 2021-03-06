#' Adjust for batch effects using an empirical Bayes framework
#' 
#' ComBat allows users to adjust for batch effects in datasets where 
#' the batch covariate is known, using methodology described in 
#' Johnson et al. 2007. It uses either parametric or non-parametric 
#' empirical Bayes frameworks for adjusting data for batch effects.  
#' Users are returned an expression matrix that has been corrected 
#' for batch effects. The input data are assumed to be cleaned and 
#' normalized before batch effect removal. 
#' 
#' @param dat Genomic measure matrix (dimensions probe x sample) - for example, 
#' expression matrix
#' @param batch {Batch covariate (only one batch allowed)}
#' @param mod Model matrix for outcome of interest and other covariates besides 
#' batch
#' @param par.prior (Optional) TRUE indicates parametric adjustments 
#' will be used, FALSE indicates non-parametric adjustments will be used
#' @param prior.plots (Optional) TRUE give prior plots with black as 
#' a kernel estimate of the empirical batch effect density and red as 
#' the parametric
#' @param mean.only (Optional) FALSE If TRUE ComBat only corrects the 
#' mean of the batch effect (no scale adjustment)
#' @param ref.batch (Optional) if specified with a string of 
#' batch name, this batch will be treated as reference during adjustment.
#' The reference batch itself won't change.
#' 
#' @return data A probe x sample genomic measure matrix, adjusted for 
#' batch effects.
#' 
#' @export
#' 

ComBat <- function(dat, batch, mod=NULL, par.prior=TRUE,
                   prior.plots=FALSE,mean.only=FALSE,
                   ref.batch="") {
  # make batch a factor and make a set of indicators for batch
  if(mean.only==TRUE){
    cat("Using the 'mean only' version of ComBat\n")
  }
  if(length(dim(batch))>1){
    stop("This version of ComBat only allows one batch variable")
  }  ## to be updated soon!
  batch <- as.factor(batch)
  batchmod <- model.matrix(~-1+batch)  
  cat("Found",nlevels(batch),'batches\n')
  
  # A few other characteristics on the batches
  n.batch <- nlevels(batch)
  batches <- list()
  for (i in 1:n.batch){
    batches[[i]] <- which(batch == levels(batch)[i])
  } # list of samples in each batch  
  n.batches <- sapply(batches, length)
  if(any(n.batches==1)){
    mean.only=TRUE
    cat("Note: one batch has only one sample, setting mean.only=TRUE\n")
  }
  n.array <- sum(n.batches)
  
  #combine batch variable and covariates
  design <- cbind(batchmod,mod)
     
  # check for intercept in covariates, and drop if present
  check <- apply(design, 2, function(x) all(x == 1))
  design <- as.matrix(design[,!check])
  
  # Number of covariates or covariate levels
  cat("Adjusting for",ncol(design)-ncol(batchmod),
      'covariate(s) or covariate level(s)\n')
  
  # Check if the design is confounded
  if(qr(design)$rank<ncol(design)){
    #if(ncol(design)<=(n.batch)){stop("Batch variables are redundant! Remove one or more of the batch variables so they are no longer confounded")}
    if(ncol(design)==(n.batch+1)){stop("The covariate is confounded with batch! Remove the covariate and rerun ComBat")}
    if(ncol(design)>(n.batch+1)){
      if((qr(design[,-c(1:n.batch)])$rank<ncol(design[,-c(1:n.batch)]))){stop('The covariates are confounded! Please remove one or more of the covariates so the design is not confounded')
      }else{stop("At least one covariate is confounded with batch! Please remove confounded covariates and rerun ComBat")}}
  }
  
  ## Check for missing values
  NAs = any(is.na(dat))
  if(NAs){
    cat(c('Found',sum(is.na(dat)),'Missing Data Values\n'),sep=' ')
  }
  #print(dat[1:2,])
  
  ###### Check for ref batch
  ref.batch.bool <- FALSE
  if(class(ref.batch)!="character"){
    stop("ref.batch should be a string.\n")
  }
  if(ref.batch!=""){
    cat("Using 'reference batch' version of ComBat\n")
    ref.batch.bool <- TRUE
    if(!(ref.batch %in% colnames(design))){
      stop("Input reference batch is not available.\n")
    }
    ref.id <- which(colnames(batchmod)==ref.batch)
  }
  
  
  ##Standardize Data across genes
  cat('Standardizing Data across genes\n')
  if (!NAs){
    B.hat <- solve(t(design)%*%design)%*%t(design)%*%t(as.matrix(dat))
  }else{
    B.hat=apply(dat,1,Beta.NA,design)
    rownames(B.hat) <- colnames(design)
  } #Standarization Model
  
  
  ##### add in choice for ref batch version
  if(ref.batch.bool){
    grand.mean <- t(B.hat[ref.batch, ])
  }else{
    grand.mean <- t(n.batches/n.array)%*%B.hat[1:n.batch,]
  }
  
  if (!NAs){
    if(ref.batch.bool){
      ref.dat <- dat[, batches[[ref.id]]]
      n.ref.dat <- n.batches[[ref.id]]
      var.pooled <- ((ref.dat-t(design[batches[[ref.id]], ]%*%B.hat))^2)%*%rep(1/n.ref.dat,n.ref.dat)
    }else{
      var.pooled <- ((dat-t(design%*%B.hat))^2)%*%rep(1/n.array,n.array)
    }
  }else{
    if(ref.batch.bool){
      ref.dat <- dat[, batches[[ref.id]]]
      n.ref.dat <- n.batches[[ref.id]]
      var.pooled <- apply(ref.dat-t(design[batches[[ref.id]], ]%*%B.hat),1,var,na.rm=T)
    }else{
      var.pooled <- apply(dat-t(design%*%B.hat),1,var,na.rm=T)
    }
  }
  
  stand.mean <- t(grand.mean)%*%t(rep(1,n.array))
  if(!is.null(design)){
    tmp <- design
    tmp[,c(1:n.batch)] <- 0
    stand.mean <- stand.mean+t(tmp%*%B.hat)
  }
  
  s.data <- (dat-stand.mean)/(sqrt(var.pooled)%*%t(rep(1,n.array)))
  
  
  ##Get regression batch effect parameters
  cat("Fitting L/S model and finding priors\n")
  batch.design <- design[,1:n.batch]
  if (!NAs){
    gamma.hat <- solve(t(batch.design)%*%batch.design)%*%t(batch.design)%*%t(as.matrix(s.data))
  }else{
    gamma.hat=apply(s.data,1,Beta.NA,batch.design)    
  }
  delta.hat <- NULL
  for (i in batches){
    if(mean.only==TRUE){
      delta.hat <- rbind(delta.hat,rep(1,nrow(s.data)))
    }
    else{
      delta.hat <- rbind(delta.hat,apply(s.data[,i], 1, var,na.rm=T))
    }
  }
  ######## gamma.hat[ref] and delta.haf[ref] are very close to N(0,1)
  ######## didn't manually set them to be 0 and 1
  
  ##Find Priors
  gamma.bar <- apply(gamma.hat, 1, mean)
  t2 <- apply(gamma.hat, 1, var)
  a.prior <- apply(delta.hat, 1, aprior)
  b.prior <- apply(delta.hat, 1, bprior)
  
  
  ##Plot empirical and parametric priors
  
  if (prior.plots & par.prior){
    par(mfrow=c(2,2))
    tmp <- density(gamma.hat[1,])
    plot(tmp,  type='l', main="Density Plot")
    xx <- seq(min(tmp$x), max(tmp$x), length=100)
    lines(xx,dnorm(xx,gamma.bar[1],sqrt(t2[1])), col=2)
    qqnorm(gamma.hat[1,])	
    qqline(gamma.hat[1,], col=2)	
    
    tmp <- density(delta.hat[1,])
    invgam <- 1/rgamma(ncol(delta.hat),a.prior[1],b.prior[1])
    tmp1 <- density(invgam)
    plot(tmp,  typ='l', main="Density Plot", ylim=c(0,max(tmp$y,tmp1$y)))
    lines(tmp1, col=2)
    qqplot(delta.hat[1,], invgam, xlab="Sample Quantiles", ylab='Theoretical Quantiles')	
    lines(c(0,max(invgam)),c(0,max(invgam)),col=2)	
    title('Q-Q Plot')
  }
  
  ##Find EB batch adjustments
  
  gamma.star <- delta.star <- NULL
  if(par.prior){
    cat("Finding parametric adjustments\n")
    for (i in 1:n.batch){
      if(mean.only){
        gamma.star <- rbind(gamma.star,postmean(gamma.hat[i,],gamma.bar[i],1,1,t2[i]))
        delta.star <- rbind(delta.star,rep(1,nrow(s.data)))
      }else{
        temp <- it.sol(s.data[,batches[[i]]],gamma.hat[i,],delta.hat[i,],gamma.bar[i],t2[i],a.prior[i],b.prior[i])
        gamma.star <- rbind(gamma.star,temp[1,])
        delta.star <- rbind(delta.star,temp[2,])
      }
    }
  }else{
    cat("Finding nonparametric adjustments\n")
    for (i in 1:n.batch){
      if(mean.only){delta.hat[i,]=1}
      temp <- int.eprior(as.matrix(s.data[,batches[[i]]]),gamma.hat[i,],delta.hat[i,])
      gamma.star <- rbind(gamma.star,temp[1,])
      delta.star <- rbind(delta.star,temp[2,])
    }
  }
  
  
  ### Normalize the Data ###
  cat("Adjusting the Data\n") 
  
  bayesdata <- s.data    
  
  j <- 1
  for (i in batches){
    bayesdata[,i] <- (bayesdata[,i]-t(batch.design[i,]%*%gamma.star))/(sqrt(delta.star[j,])%*%t(rep(1,n.batches[j])))
    j <- j+1
  }  
  
  bayesdata <- (bayesdata*(sqrt(var.pooled)%*%t(rep(1,n.array))))+stand.mean  
  
  ##### Do not change ref batch in reference version
  if(ref.batch.bool){
    bayesdata[, batches[[ref.id]]] <- dat[, batches[[ref.id]]]
  }
  
  return(bayesdata)  
}