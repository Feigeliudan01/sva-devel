# Tests the ComBat output in the bladder batch dataset
library(sva)
library(bladderbatch)
data(bladderdata)
library(testthat)
context("ComBat test on bladder batch data")

test_that("check ComBat output with several different parameters on bladder cancer data",{
  # get expression data, phenotype, and batch
  pheno = pData(bladderEset)
  edata = exprs(bladderEset)
  batch = pheno$batch
  
  # set up full and reduced models for testing
  mod = model.matrix(~as.factor(cancer), data=pheno)
  mod0 = model.matrix(~1, data=pheno)

  #run ComBat without covariates:
  combat_edata = ComBat(dat=edata, batch=batch, mod=NULL, par.prior=TRUE, prior.plots=FALSE)
  pValuesComBat = f.pvalue(combat_edata,mod,mod0)
  expect_equal(sum(pValuesComBat<=.05),12468)

  #run ComBat without covariates (using the NULL model):
  combat_edata = ComBat(dat=edata, batch=batch, mod=mod0, par.prior=TRUE, prior.plots=FALSE)
  pValuesComBat_null = f.pvalue(combat_edata,mod,mod0)
  expect_equal(pValuesComBat_null,pValuesComBat)

  #Check to see if the prior.plots option works
  combat_edata = ComBat(dat=edata, batch=batch, prior.plots=TRUE)
  pValuesComBat_null = f.pvalue(combat_edata,mod,mod0)
  expect_equal(pValuesComBat_null,pValuesComBat)
  
  #run ComBat without covariates non-parametric (small dataset):
  combat_edata = ComBat(dat=edata[1:100,], batch=batch, par.prior=FALSE, prior.plots=FALSE)
  pValuesComBat = f.pvalue(combat_edata,mod,mod0)
  expect_equal(sum(pValuesComBat<=.05),78) 
  
  #run ComBat with covariates:
  combat_edata = ComBat(dat=edata, batch=batch, mod=mod, par.prior=TRUE, prior.plots=FALSE)
  pValuesComBat = f.pvalue(combat_edata,mod,mod0)
  expect_equal(sum(pValuesComBat<.05),18507)
  
  #run ComBat with covariates, mean.only=TRUE:
  combat_edata = ComBat(dat=edata, batch=batch, mod=mod, par.prior=TRUE, prior.plots=FALSE, mean.only=TRUE)
  pValuesComBat = f.pvalue(combat_edata,mod,mod0)
  expect_equal(sum(pValuesComBat<.05),17115)
  
  
  ######## Check reference version on bladder data in all situations above
  
  #run ComBat without covariates:
  combat_edata = ComBat(dat=edata, batch=batch, mod=NULL, 
                        par.prior=TRUE, prior.plots=FALSE,
                        ref.batch="batch1")
  pValuesComBat = f.pvalue(combat_edata,mod,mod0)
  expect_equal(sum(pValuesComBat<=.05),11614)
  
  #run ComBat without covariates (using the NULL model m0 and same batch):
  combat_edata = ComBat(dat=edata, batch=batch, mod=mod0, 
                        par.prior=TRUE, prior.plots=FALSE,
                        ref.batch="batch1")
  pValuesComBat_null = f.pvalue(combat_edata,mod,mod0)
  expect_equal(pValuesComBat_null,pValuesComBat)
  
  #Check to see if the prior.plots option works
  combat_edata = ComBat(dat=edata, batch=batch, prior.plots=TRUE,
                        ref.batch="batch1")
  pValuesComBat_null = f.pvalue(combat_edata,mod,mod0)
  expect_equal(pValuesComBat_null,pValuesComBat)
  
  #run ComBat without covariates non-parametric (small dataset):
  combat_edata = ComBat(dat=edata[1:100,], batch=batch, 
                        par.prior=FALSE, prior.plots=FALSE,
                        ref.batch="batch2")
  pValuesComBat = f.pvalue(combat_edata,mod,mod0)
  expect_equal(sum(pValuesComBat<=.05),76) 
  
  #run ComBat with covariates:
  combat_edata = ComBat(dat=edata, batch=batch, 
                        mod=mod, par.prior=TRUE, 
                        prior.plots=FALSE, ref.batch="batch2")
  pValuesComBat = f.pvalue(combat_edata,mod,mod0)
  expect_equal(sum(pValuesComBat<.05),19122)
  
  #run ComBat with covariates, mean.only=TRUE:
  combat_edata = ComBat(dat=edata, batch=batch, 
                        mod=mod, par.prior=TRUE, 
                        prior.plots=FALSE, mean.only=TRUE,
                        ref.batch="batch3")
  pValuesComBat = f.pvalue(combat_edata,mod,mod0)
  expect_equal(sum(pValuesComBat<.05),18153)
})
