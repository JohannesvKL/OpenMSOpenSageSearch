## add default CRAN mirror in case the user's config does not have one
options(repos = list(CRAN="http://cran.rstudio.com/"))

if (!require(ggplot2)) install.packages("ggplot2")
library("ggplot2")
if (!require(reshape2)) install.packages("reshape2")
library("reshape2")
if (!require(plyr)) install.packages("plyr")
library("plyr")

file.table.in = commandArgs(TRUE)[1] ## file.table.in = "residuals.csv"
file.plot.out = commandArgs(TRUE)[2] ## file.plot.out = "residuals.png"

cat(paste0("Reading file '", file.table.in, "' to plot residual masses ..."))

d = read.csv(file.table.in, comment.char = "#", strip.white = TRUE, fill = FALSE)
head(d)

## check if header is complete
required_cols = c("RT", "intensity", "mz.ref", "mz.before", "mz.after", "ppm.before", "ppm.after")
if (!all(required_cols %in% colnames(d))) {
  stop(paste0("File '", file.table.in, "' has missing columns. Required are: ", paste(required_cols, sep="", collapse=", "), "."))  
}

dpm = melt(d[, grep("^mz.[ab]", colnames(d), invert = TRUE)], id.vars = c("RT", "mz.ref", "intensity"))
head(dpm)
## for peptide ID data:
##   - mz.ref will be mostly unique (assume oversampling of at most 3)
##   - and RT of more than 10min
## otherwise we assume direct-injection (and facet-wrap by each mz-ref) 
##    - unless its more than 100 facets... which will be hard to read
if ((length(unique(d$mz.ref)) / nrow(d) > 0.333  && diff(range(d$RT, na.rm = TRUE)) > 600) 
    || length(unique(d$mz.ref)) > 100 ) {
  dpm2 = dpm
  dpm2$masstrace = ""
} else {
  ## for direct-injection, every spectrum will repeatedly give multiple 'mz.ref'
  ## annotate mz.ref with average intensity
  dpm2 = ddply(dpm, "mz.ref", function(x) {
    x$masstrace = paste0("m/z ",
                         # we want zero/space padded masses, such that ggplot will sort them by mass automatically
                         format(round(x$mz.ref, 5), nsmall = 5, width = 9, zero.print = TRUE),
                         " ~ int ",
                         format(median(x$intensity), scientific = TRUE, digits = 2))
    return(x)
  })
}
head(dpm2)

#getOption("device") ## RStudioGD
#options(device = "pdf")
#dev.new(filename = file.plot.out, file = file.plot.out)
png(filename = file.plot.out, width=15, height=10, units="cm", res=300)

pl = ggplot(dpm2) + 
       geom_hline(yintercept = 0, colour="grey") +
       geom_hline(yintercept = c(-1,1), colour = "grey", linetype = "dotdash") +
       facet_wrap(~ masstrace) + 
       geom_point(aes(x = RT, y = value, color = variable), alpha=0.6) +
       scale_color_manual(values = c("ppm.before" = "#FF2222", "ppm.after" = "#2222FF"),
                          labels = c("before", "after"),
                          name = "error") +
       ggtitle("Calibrant's mass error over time") +
       xlab("RT [sec]") +
       ylab("mass error [ppm]")
print(pl)

dev.off()
