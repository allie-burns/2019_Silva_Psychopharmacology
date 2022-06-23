## #############################################################################
## Date:        April 2018 (updated June 2022 for new R)
## Author:      Allison M. Burns
## Filename:    PearsonCorrelationHeatmaps.R    
## Project:     Brain Region cFos correlations
## Description: For each behavioral paradigm (homecage, context only, recall,
##              extinction) calculate correlation of cFos density for 18 brain
##              regions and build heatmap of correlation values.
##
## Input:       CSV file of cFos density calculated for each brain region by
##              behavioral paradigm. The density of cFos-positive cells
##              (cFos+/mm2) was averaged over 2–6 sections per animal. Brain
##              region correlations reflecting fewer than four pairs were
##              excluded for all subsequent visualization and analysis.
## 
## Output:      Heatmap of correlation values with overlaid p-values for each
##              behavioral paradigm.
## #############################################################################

library(Hmisc)

################################################################################
## Load data and define experiments
################################################################################
data <- read.csv("../data_files/cFosData_bas.csv")
exp <- c('Homecage','Context','Recall','Extinction')

################################################################################
## Build heatmap of cFos density for each experimental paradigm
################################################################################
expLoop <- function(exp,data) {
    ## #########################################################################
    ## Get correlations for each experiment
    ## #########################################################################
    ## Subset behavioral paradigm cFos density information
    experiment <- data[grep(exp,colnames(data))]
    rownames(experiment) <- data$Brain.Region

    ## Re-order for visualization
    myOrder <- rownames(experiment)[c(1:6,13:18,10:12,8,7,9)]
    experiment <- experiment[myOrder,]
    experiment <- t(experiment)
    experiment <- experiment[,-grep("MD|AT",colnames(experiment))]

    ## Find correlations
    myCorVals <- rcorr(experiment,type=c("pearson"))
    r.vals <- round(myCorVals[[1]],2)
    n.vals <- round(myCorVals[[2]],2)
    p.vals <- round(myCorVals[[3]],2)

    ## Set star values based on p.values for correlations
    star.vals <- p.vals
    star.vals[p.vals <= 0.05 & p.vals > 0.01 & !is.na(p.vals)] <- '*'
    star.vals[p.vals <= 0.01 & p.vals > 0.001 &  !is.na(p.vals)] <- '**'
    star.vals[p.vals <= 0.001 & !is.na(p.vals)] <- '***'
    star.vals[p.vals > 0.05 & !is.na(p.vals)] <- ' '

    ## If fewer than 4 cFos density values, set corr-val out of color range
    r.vals[n.vals < 4] <- 1.1

    ## #########################################################################
    ## Use correlation plot to view relationships between replicates
    ## #########################################################################
    ## Build the color vector (for centering 0 values on white)
    nHalf = length(r.vals)/2
    Min = -1
    Max = 1 
    Thresh = 0

    ## Make vector of colors for values below threshold
    rc1 = colorRampPalette(colors = c("navy", "white"), space="Lab")(nHalf)    
    ## Make vector of colors for values above threshold
    rc2 = colorRampPalette(colors = c("white", "red4"), space="Lab")(nHalf)
    rampcols = c(rc1, rc2,'grey')
    ## In your example, this line sets the color for values between 49 and 51. 
    rampcols[c(nHalf, nHalf+1)] = rgb(t(col2rgb("white")), maxColorValue=256) 
    rb1 = seq(Min, Thresh, length.out=nHalf+1)
    rb2 = seq(Thresh, Max, length.out=nHalf+1)[-1]
    rampbreaks = c(rb1, rb2,1.1)
    
    ## Set labels
    labels = colnames(r.vals)
    
    vals <- list(r.vals,n.vals,p.vals,star.vals)
    names(vals) <- c("r.values","n.values","p.values","star.vals")
    
    txt.col <- r.vals
    txt.col[r.vals == 1.1] <- 'grey'
    txt.col[r.vals < 1.1] <- 'black'    

    n.col <- n.vals
    n.col[n.col >= 0] <- 'black'
    
    txt.col <- list(txt.col,
                    n.col,
                    txt.col,
                    txt.col)
    
    makeHeatmaps <- function(i,vals){
        values <- vals[[i]]
        txt <- txt.col[[i]]
        
        ## Plot for r.vals
        par(mar=c(4,4,3,3))
        image(t(r.vals),col=rampcols,breaks=rampbreaks,axes=FALSE)
        a <- seq(0,1,by=(1/(ncol(r.vals)-1)))
        b <- seq(0,1,by=(1/(nrow(r.vals)-1)))
        axis(side=1,at=a,labels=labels,las=2,cex.axis=1)
        axis(side=2,at=a,labels=labels,las=2,cex.axis=1)
        title(paste(exp),cex=1.25)
        lapply(seq(1:length(a)),function(i) { text(b,a[i],
                                                   values[i,],
                                                   cex=2.25,
                                                   col=txt[i,]) })
    }
    
    lapply(4,makeHeatmaps,vals)
    
}

pdf("../figure_files/correlation_heatmap.pdf", width=21, height=14)
par(mfrow=c(2,2))
lapply(exp, expLoop, data)
dev.off()
