## #############################################################################
## Date:        April 2018 (updated June 2022 for new R)
## Author:      Allison M. Burns
## Filename:    PearsonNetworkPlot.R
## Project:     Brain Region cFos correlations
## Description: For each behavioral paradigm (homecage, context only, recall,
##              extinction) calculate correlation of cFos density and build
##              correlation plot.
##
## Input:       CSV file of cFos density calculated for each brain region by
##              behavioral paradigm. The density of cFos-positive cells
##              (cFos+/mm2) was averaged over 2–6 sections per animal. Brain
##              region correlations reflecting fewer than four pairs were
##              excluded for all subsequent visualization and analysis.
## 
## Output:      Circos plot indicating which brain regions are simulateously
##              activated (and to which extent) during each behavioural
##              paradigm. 
## #############################################################################

library(igraph)
library(Hmisc)
library(reshape)
library(fields)

################################################################################
## Load and wrangle data
################################################################################
data <- read.csv("../data_files/cFosData_bas.csv")
exp <- c('Homecage','Context','Recall','Extinction')

## Remove irrelevant brain regions (+ freezing data)
data <- data[lapply(data$Brain.Region,function(x) { nchar(as.character(x)) } ) > 1,]
data <- data[-grep("MD|AT|freezing",data$Brain.Region),]
br <- as.character(data$Brain.Region)

## Define cutoffs
p.cutoff <- 0.1 
n.cutoff <- 4
r.cutoff <- 0.5

getExpCorrelations <- function(exp,data){
    ## Get Experimental information and remove freezing row
    data <- data[,grep(exp,colnames(data))]
    rownames(data) <- br
    data <- t(data)
    
    ## Get correlations and p.values of correlations
    myCorVals <- rcorr(data)
    
    corVals <- cbind(melt(myCorVals[[1]]),
                     melt(myCorVals[[3]])[3],
                     melt(myCorVals[[2]])[3])
    colnames(corVals) <- c("BR1","BR2","r.val","p.val","n.val")
    corVals <- corVals[!duplicated(corVals[3:5]),] 
    corVals <- corVals[corVals$p.val <= p.cutoff &
                       corVals$n.val > n.cutoff &
                       corVals$r.val >= r.cutoff,]
    corVals <- na.omit(corVals)
}

BRcorrs <- lapply(exp,getExpCorrelations,data)

################################################################################
## Build iGraph Correlation plots
################################################################################
## Set node size as proportion of cFos for each exp vs homecage
nodeSize <- function(i,exp,data){
    ## homecage values
    homecage <- data[,grep(exp[[1]],colnames(data))]
    rownames(homecage) <- br
    homecage <- t(homecage)
    
    ## Get Experimental information and remove freezing
    experiment <- data[,grep(exp[[i]],colnames(data))]
    rownames(experiment) <- br
    experiment <- t(experiment)

    ## Define node size as proportion of cFos for each exp vs homecage
    node.sizes <- colSums(experiment,na.rm=TRUE) / colSums(homecage,na.rm=TRUE)
    round(node.sizes,2)
}

node.size <- lapply(seq(1:length(exp)), nodeSize, exp, data)

## Set colors for nodes by general brain region
HPP <- "green4"
COR <- "royalblue4"
THA <- "red2"
AMY <- "cadetblue1"
BRcols <- list(c(rep(HPP,6),rep(THA,4),rep(AMY,2),rep(COR,4)),
               c(rep(HPP,6),rep(THA,4),rep(AMY,2),rep(COR,4)),
               c(rep(HPP,6),rep(THA,4),rep(AMY,2),rep(COR,4)),
               c(rep(HPP,6),'grey',THA,rep(THA,2),rep(AMY,2),rep(COR,4)))

## Set colors for edges
Min = r.cutoff
Max = 1
## Make vector of colors for values below threshold
rampcols = colorRampPalette(colors = c("white","black"),space = "Lab") (106) 
rampbreaks = seq(Min,Max,length.out=length(rampcols)+1)
## Add edge color information to correlation data
BRcorrs <- lapply(BRcorrs,function(data){
    data$color <- unlist(lapply(data$r.val,function(x) {
        rampcols[which.min(abs(rampbreaks - x))]
    }))
    data
})

## Build plot
CorrelationCircosPlot <- function(i,BRcorrs,node.size){
    experiment <- BRcorrs[[i]]
    node.sizes <- node.size[[i]]
    ## Format data
    net <- graph_from_data_frame(d=experiment, vertices=br)
    n <- length(node.sizes)
    radian.rescale <- function(x, start=0, direction=1) {
        c.rotate <- function(x) (x + start) %% (2 * pi) * direction
        c.rotate(scales::rescale(x, c(0, 2 * pi), range(x)))
    }
    lab.locs <- radian.rescale(x=1:n, direction=-1, start=0)
    
    ## Circle layout
    V(net)$size <- (node.sizes[match(br,names(node.sizes))])*6
    V(net)$color <- BRcols[[i]]
    V(net)$frame.color <- BRcols[[i]]
    V(net)$label.cex <- 1
    V(net)$label.dist <- rep(3,n)
    
    V(net)$label.degree <- lab.locs
    V(net)$label.family <- "sans"
    V(net)$label.color <- 'black'
    E(net)$arrow.mode <- 0
    
    l <- layout_in_circle(net)
    plot(net, layout=l, main = exp[[i]])
}

pdf("../figure_files/correlation_network.pdf",width=14,height=3)
par(mfrow=c(1,5))
## Plot Circos Plots
lapply(seq(1:length(BRcorrs)),CorrelationCircosPlot,BRcorrs,node.size)
## Add edge legend
image.plot(nlevel=100,
             legend.only=TRUE,
             horizontal=FALSE,
             legend.width=1.25,
             col=rampcols,
             breaks=rampbreaks,
             new=TRUE,
             legend.lab="R values",
             legend.cex=.75,
             axis.args=c(cex.axis=1))
## Add brain region legend
plot(1, type="n", axes=FALSE, xlab="", ylab="")
legend(0.7,1.2, c("Hippocampus","Thalamus", "Amygdala","Cortex"), pch=21, pt.bg=unique(BRcols[[1]]), pt.cex=4.6, cex=2, bty="n", ncol=1,pt.lwd =0)
dev.off()
